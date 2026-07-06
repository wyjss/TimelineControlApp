#include "devices/executors/HttpCommandExecutor.h"

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTcpSocket>
#include <QNetworkProxy>
#include <QTimer>
#include <QUrl>


using namespace TimelineControl;

HttpCommandExecutor::HttpCommandExecutor(const QString &ip, int port, QObject *parent)
    : DeviceCommandExecutor(parent)
    , m_ip(ip)
    , m_port(port)
{
}

void HttpCommandExecutor::executeImpl(DeviceCommand *command, const QVariantMap &params)
{
    const QString path = params.value(DeviceKey::ApiPath).toString();
    if (m_ip.isEmpty() || path.isEmpty()) {
        emit executionFinished(command, false, tr("HTTP 地址或路径为空"));
        return;
    }

    QUrl url;
    url.setScheme(QStringLiteral("http"));
    url.setHost(m_ip);
    url.setPort(m_port);
    url.setPath(path);
    if (!url.isValid()) {
        emit executionFinished(command, false, tr("HTTP URL 无效"));
        return;
    }

    QNetworkRequest request(url);
    if (!m_manager)
        m_manager = new QNetworkAccessManager(this);
    const QString method = params.value(DeviceKey::HttpMethod).toString();
    if (method.isEmpty()) {
        emit executionFinished(command, false, tr("HTTP 方法为空"));
        return;
    }
    QNetworkReply *reply = method == QStringLiteral("POST")
        ? m_manager->post(request, params.value(DeviceKey::HttpBody).toString().toUtf8())
        : m_manager->get(request);

    QTimer::singleShot(5000, reply, [reply]() {
        if (reply->isRunning()) {
            reply->setProperty("timedOut", true);
            reply->abort();
        }
    });

    connect(reply, &QNetworkReply::finished, this, [this, command, reply]() {
        const QVariant status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute);
        const int httpStatus = status.toInt();
        const bool success = reply->error() == QNetworkReply::NoError
            && (!status.isValid() || httpStatus < 400);
        QString message;
        if (!success) {
            message = reply->property("timedOut").toBool()
                ? tr("HTTP 请求超时")
                : (reply->error() == QNetworkReply::NoError ? tr("HTTP %1").arg(httpStatus) : reply->errorString());
            markFailed(message);
        }
        emit executionFinished(command, success, message);
    });
    connect(reply, &QNetworkReply::finished, reply, &QObject::deleteLater);
}

bool HttpCommandExecutor::checkOnlineImpl(const QVariantMap &params)
{
    const QString ip = params.value(DeviceKey::Ip).toString().trimmed();
    const int port = params.value(DeviceKey::IpPort).toInt();
    if (ip.isEmpty() || port <= 0)
        return false;

    QTcpSocket socket;
    socket.setProxy(QNetworkProxy::NoProxy);
    socket.connectToHost(ip, port);
    const bool connected = socket.waitForConnected(1000);
    socket.abort();
    return connected;
}
