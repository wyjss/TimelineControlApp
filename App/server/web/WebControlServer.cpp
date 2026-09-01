#include "WebControlServer.h"

#include "../httplib.h"
#include "../../runtime/TimelineRuntime.h"
#include "../../runtime/devices/Device.h"
#include "../../runtime/devices/DeviceModel.h"
#include "../../runtime/timeline/Timeline.h"
#include "../../runtime/timeline/TimelineCommand.h"
#include "../../runtime/timeline/TimelineManager.h"
#include "../../runtime/timeline/TimelineModel.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QMetaObject>
#include <QThread>


namespace {

void sendJson(httplib::Response &response, int status, const QJsonObject &body)
{
    response.status = status;
    response.set_header("Cache-Control", "no-store");
    response.set_content(QJsonDocument(body).toJson(QJsonDocument::Compact).toStdString(),
                         "application/json; charset=utf-8");
}

QJsonObject errorResponse(const QString &code, const QString &message)
{
    return {
        {QStringLiteral("ok"), false},
        {QStringLiteral("error"), QJsonObject{
             {QStringLiteral("code"), code},
             {QStringLiteral("message"), message}
         }}
    };
}

QString playbackStateName(TimelineManager::PlaybackState state)
{
    switch (state) {
    case TimelineManager::Running:
        return QStringLiteral("running");
    case TimelineManager::Paused:
        return QStringLiteral("paused");
    case TimelineManager::Completed:
        return QStringLiteral("completed");
    default:
        return QStringLiteral("stopped");
    }
}

QString timelineStateName(Timeline::State state)
{
    switch (state) {
    case Timeline::Waiting:
        return QStringLiteral("waiting");
    case Timeline::Running:
        return QStringLiteral("running");
    case Timeline::Completed:
        return QStringLiteral("completed");
    default:
        return QStringLiteral("stopped");
    }
}

QString commandStateName(TimelineCommand::State state)
{
    switch (state) {
    case TimelineCommand::Running:
        return QStringLiteral("running");
    case TimelineCommand::Succeeded:
        return QStringLiteral("succeeded");
    case TimelineCommand::Failed:
        return QStringLiteral("failed");
    case TimelineCommand::Skipped:
        return QStringLiteral("skipped");
    default:
        return QStringLiteral("idle");
    }
}

} // namespace


WebControlServer::WebControlServer(TimelineRuntime *runtime, const QString &webRoot)
    : m_runtime(runtime)
    , m_webRoot(webRoot)
{
}

WebControlServer::~WebControlServer()
{
    stop();
}

bool WebControlServer::start(const QString &host, quint16 port)
{
    if (m_running)
        return true;

    stop();
    if (!m_runtime || host.trimmed().isEmpty())
        return false;

    m_server = std::make_unique<httplib::Server>();
    m_server->Get("/", [this](const httplib::Request &, httplib::Response &response) {
        serveAsset(QStringLiteral("index.html"), "text/html; charset=utf-8", response);
    });
    m_server->Get("/index.html", [this](const httplib::Request &, httplib::Response &response) {
        serveAsset(QStringLiteral("index.html"), "text/html; charset=utf-8", response);
    });
    m_server->Get("/assets/app.css", [this](const httplib::Request &, httplib::Response &response) {
        serveAsset(QStringLiteral("assets/app.css"), "text/css; charset=utf-8", response);
    });
    m_server->Get("/assets/app.js", [this](const httplib::Request &, httplib::Response &response) {
        serveAsset(QStringLiteral("assets/app.js"), "application/javascript; charset=utf-8", response);
    });
    m_server->Get("/api/v1/status", [this](const httplib::Request &request, httplib::Response &response) {
        if (authorize(request, response)) {
            const QJsonObject body = statusSnapshot();
            sendJson(response, body.value(QStringLiteral("ok")).toBool() ? 200 : 503, body);
        }
    });
    m_server->Post("/api/v1/queue", [this](const httplib::Request &request, httplib::Response &response) {
        if (!authorize(request, response))
            return;

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(
            QByteArray::fromStdString(request.body), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            sendJson(response, 400, errorResponse(QStringLiteral("invalid_json"),
                                                  QStringLiteral("请求内容不是有效 JSON")));
            return;
        }

        QJsonObject body;
        const int status = updateQueue(document.object().value(QStringLiteral("timelineIds")).toArray(), body);
        sendJson(response, status, body);
    });
    m_server->Post("/api/v1/playback-devices", [this](const httplib::Request &request, httplib::Response &response) {
        if (!authorize(request, response))
            return;

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(
            QByteArray::fromStdString(request.body), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            sendJson(response, 400, errorResponse(QStringLiteral("invalid_json"),
                                                  QStringLiteral("请求内容不是有效 JSON")));
            return;
        }

        QJsonObject body;
        const int status = updatePlaybackDevices(
            document.object().value(QStringLiteral("deviceIds")).toArray(), body);
        sendJson(response, status, body);
    });
    m_server->Post("/api/v1/control", [this](const httplib::Request &request, httplib::Response &response) {
        if (!authorize(request, response))
            return;

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(
            QByteArray::fromStdString(request.body), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            sendJson(response, 400, errorResponse(QStringLiteral("invalid_json"),
                                                  QStringLiteral("请求内容不是有效 JSON")));
            return;
        }

        QJsonObject body;
        const int status = control(document.object(), body);
        sendJson(response, status, body);
    });
    m_server->set_error_handler([](const httplib::Request &, httplib::Response &response) {
        if (response.body.empty()) {
            sendJson(response,
                     response.status,
                     errorResponse(response.status == 404
                                       ? QStringLiteral("not_found")
                                       : QStringLiteral("http_error"),
                                   response.status == 404
                                       ? QStringLiteral("请求的资源不存在")
                                       : QStringLiteral("请求无法处理")));
        }
    });
    m_server->set_payload_max_length(64 * 1024);

    if (!m_server->bind_to_port(host.trimmed().toStdString(), port)) {
        m_server.reset();
        return false;
    }

    m_running = true;
    m_thread = std::thread([this]() {
        m_server->listen_after_bind();
        m_running = false;
    });
    return true;
}

void WebControlServer::stop()
{
    if (m_server)
        m_server->stop();
    if (m_thread.joinable())
        m_thread.join();
    m_running = false;
    m_server.reset();
}

bool WebControlServer::isRunning() const
{
    return m_running;
}

void WebControlServer::setAccessToken(const QString &accessToken)
{
    if (!m_running)
        m_accessToken = accessToken.trimmed();
}

bool WebControlServer::authorize(const httplib::Request &request,
                                 httplib::Response &response) const
{
    if (m_accessToken.isEmpty())
        return true;

    const std::string bearer = "Bearer " + m_accessToken.toStdString();
    if (request.get_header_value("Authorization") == bearer
        || request.get_header_value("X-Control-Token") == m_accessToken.toStdString())
        return true;

    response.set_header("WWW-Authenticate", "Bearer");
    sendJson(response, 401, errorResponse(QStringLiteral("unauthorized"),
                                          QStringLiteral("访问令牌无效")));
    return false;
}

bool WebControlServer::invokeRuntime(
    const std::function<void(TimelineRuntime *)> &operation) const
{
    const QPointer<TimelineRuntime> runtime = m_runtime;
    if (!runtime)
        return false;
    if (QThread::currentThread() == runtime->thread()) {
        operation(runtime);
        return true;
    }

    return QMetaObject::invokeMethod(runtime, [runtime, operation]() {
        if (runtime)
            operation(runtime);
    }, Qt::BlockingQueuedConnection);
}

bool WebControlServer::serveAsset(const QString &relativePath,
                                  const char *contentType,
                                  httplib::Response &response) const
{
    QFile file(m_webRoot + QLatin1Char('/') + relativePath);
    if (!file.open(QIODevice::ReadOnly)) {
        sendJson(response, 404, errorResponse(QStringLiteral("asset_not_found"),
                                              QStringLiteral("网页资源不存在")));
        return false;
    }

    response.set_header("Cache-Control", "no-cache");
    response.set_header("X-Content-Type-Options", "nosniff");
    response.set_header("X-Frame-Options", "DENY");
    response.set_header("Content-Security-Policy",
                        "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'");
    response.set_content(file.readAll().toStdString(), contentType);
    return true;
}

QJsonObject WebControlServer::statusSnapshot() const
{
    QJsonObject result;
    if (!invokeRuntime([&result](TimelineRuntime *runtime) {
        TimelineManager *manager = runtime->timelineManager();
        const QStringList playQueue = manager->playQueue();
        QJsonArray timelines;
        for (Timeline *timeline : manager->timelineModel()->items()) {
            QJsonArray commands;
            qint64 durationMs = timeline->durationMs();
            for (TimelineCommand *command : timeline->commandModel()->commands()) {
                durationMs = qMax(durationMs,
                                  command->startTimeMs() + command->durationMs());
                commands.append(QJsonObject{
                    {QStringLiteral("id"), command->id()},
                    {QStringLiteral("name"), command->commandName()},
                    {QStringLiteral("deviceId"), command->targetDeviceId()},
                    {QStringLiteral("startTimeMs"), command->startTimeMs()},
                    {QStringLiteral("durationMs"), command->durationMs()},
                    {QStringLiteral("state"), commandStateName(command->state())},
                    {QStringLiteral("error"), command->errorMessage()}
                });
            }

            timelines.append(QJsonObject{
                {QStringLiteral("id"), timeline->id()},
                {QStringLiteral("name"), timeline->name()},
                {QStringLiteral("state"), timelineStateName(timeline->state())},
                {QStringLiteral("currentTimeMs"), timeline->currentTimeMs()},
                {QStringLiteral("durationMs"), durationMs},
                {QStringLiteral("queuePosition"), playQueue.indexOf(timeline->id())},
                {QStringLiteral("commands"), commands}
            });
        }

        QJsonArray devices;
        for (Device *device : runtime->deviceModel()->items()) {
            devices.append(QJsonObject{
                {QStringLiteral("id"), device->id()},
                {QStringLiteral("name"), device->name()},
                {QStringLiteral("type"), device->deviceType()},
                {QStringLiteral("online"), device->isOnline()}
            });
        }

        result = {
            {QStringLiteral("ok"), true},
            {QStringLiteral("planName"), runtime->currentPlanName()},
            {QStringLiteral("playbackState"), playbackStateName(manager->playbackState())},
            {QStringLiteral("currentTimeMs"), manager->currentTimeMs()},
            {QStringLiteral("currentTimelineId"), manager->currentTimeline()
                ? manager->currentTimeline()->id()
                : QString()},
            {QStringLiteral("queueIndex"), manager->playQueueIndex()},
            {QStringLiteral("playQueue"), QJsonArray::fromStringList(playQueue)},
            {QStringLiteral("playbackDevices"),
             QJsonArray::fromStringList(manager->getPlaybackDevices())},
            {QStringLiteral("timelines"), timelines},
            {QStringLiteral("devices"), devices}
        };
    })) {
        return errorResponse(QStringLiteral("runtime_unavailable"),
                             QStringLiteral("播控运行时不可用"));
    }
    return result;
}

int WebControlServer::updateQueue(const QJsonArray &timelineIds,
                                  QJsonObject &response) const
{
    QStringList ids;
    for (const QJsonValue &value : timelineIds) {
        const QString id = value.toString().trimmed();
        if (id.isEmpty() || ids.contains(id)) {
            response = errorResponse(QStringLiteral("invalid_queue"),
                                     QStringLiteral("节目队列包含无效或重复项目"));
            return 400;
        }
        ids.append(id);
    }

    bool accepted = false;
    if (!invokeRuntime([&accepted, &ids](TimelineRuntime *runtime) {
        accepted = runtime->timelineManager()->setPlayQueue(ids);
    })) {
        response = errorResponse(QStringLiteral("runtime_unavailable"),
                                 QStringLiteral("播控运行时不可用"));
        return 503;
    }
    if (!accepted) {
        response = errorResponse(QStringLiteral("queue_rejected"),
                                 QStringLiteral("仅停止状态可修改队列，且所有节目必须存在"));
        return 409;
    }

    response = statusSnapshot();
    return 200;
}

int WebControlServer::updatePlaybackDevices(const QJsonArray &deviceIds,
                                            QJsonObject &response) const
{
    QStringList ids;
    for (const QJsonValue &value : deviceIds) {
        const QString id = value.toString().trimmed();
        if (id.isEmpty() || ids.contains(id)) {
            response = errorResponse(QStringLiteral("invalid_devices"),
                                     QStringLiteral("设备选择包含无效或重复项目"));
            return 400;
        }
        ids.append(id);
    }

    bool stopped = false;
    bool valid = false;
    if (!invokeRuntime([&stopped, &valid, &ids](TimelineRuntime *runtime) {
        TimelineManager *manager = runtime->timelineManager();
        stopped = manager->playbackState() == TimelineManager::Stopped;
        valid = true;
        for (const QString &id : ids) {
            if (!runtime->deviceModel()->deviceById(id)) {
                valid = false;
                break;
            }
        }
        if (stopped && valid)
            manager->setPlaybackDevices(ids);
    })) {
        response = errorResponse(QStringLiteral("runtime_unavailable"),
                                 QStringLiteral("播控运行时不可用"));
        return 503;
    }
    if (!valid) {
        response = errorResponse(QStringLiteral("invalid_devices"),
                                 QStringLiteral("选择的设备不存在"));
        return 400;
    }
    if (!stopped) {
        response = errorResponse(QStringLiteral("devices_locked"),
                                 QStringLiteral("仅停止状态可修改播控设备"));
        return 409;
    }

    response = statusSnapshot();
    return 200;
}

int WebControlServer::control(const QJsonObject &request,
                              QJsonObject &response) const
{
    const QString action = request.value(QStringLiteral("action")).toString().trimmed();
    bool accepted = false;
    if (!invokeRuntime([&accepted, action, request](TimelineRuntime *runtime) {
        TimelineManager *manager = runtime->timelineManager();
        if (action == QStringLiteral("start")) {
            QStringList ids;
            for (const QJsonValue &value : request.value(QStringLiteral("timelineIds")).toArray())
                ids.append(value.toString());
            if (ids.isEmpty())
                ids = manager->playQueue();
            accepted = manager->playbackState() == TimelineManager::Stopped
                && manager->startPlayback(ids);
        } else if (action == QStringLiteral("pause")) {
            accepted = manager->playbackState() == TimelineManager::Running;
            if (accepted)
                manager->pausePlayback();
        } else if (action == QStringLiteral("resume")) {
            accepted = manager->playbackState() == TimelineManager::Paused;
            if (accepted)
                manager->resumePlayback();
        } else if (action == QStringLiteral("stop")) {
            accepted = manager->playbackState() != TimelineManager::Stopped;
            if (accepted)
                manager->stopPlayback();
        }
    })) {
        response = errorResponse(QStringLiteral("runtime_unavailable"),
                                 QStringLiteral("播控运行时不可用"));
        return 503;
    }
    if (!accepted) {
        response = errorResponse(QStringLiteral("control_rejected"),
                                 QStringLiteral("当前状态无法执行该播控操作"));
        return 409;
    }

    response = statusSnapshot();
    return 200;
}
