#include "ResourceSyncManager.h"

#include "utils.h"
#include "devices/DeviceConstants.h"
#include "devices/DeviceModel.h"

#include <QFile>
#include <QFileInfo>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
#include <QVariantMap>

ResourceSyncManager::ResourceSyncManager(DeviceModel *deviceModel, QObject *parent)
    : QObject(parent)
    , m_deviceModel(deviceModel)
    , m_network(new QNetworkAccessManager(this))
{
    connect(Utils::AVOptionsMgr::getInstance(), &Utils::AVOptionsMgr::optionsChanged,
            this, &ResourceSyncManager::refreshResources);
    refreshResources();
}

QVariantList ResourceSyncManager::resources() const
{
    return m_resources;
}

QVariantList ResourceSyncManager::jobs() const
{
    return m_jobs;
}

bool ResourceSyncManager::busy() const
{
    return m_busy;
}

QString ResourceSyncManager::errorMessage() const
{
    return m_errorMessage;
}

void ResourceSyncManager::refreshResources()
{
    QVariantList resources;
    auto *optionsManager = Utils::AVOptionsMgr::getInstance();
    for (const QString &category : {QStringLiteral("video"), QStringLiteral("audio")}) {
        const bool video = category == QStringLiteral("video");
        const QVariantList &options = video
            ? optionsManager->getVideoOptions() : optionsManager->getAudioOptions();
        for (const QVariant &option : options) {
            const QString source = option.toString();
            if (source.isEmpty())
                continue;

            const QString path = video
                ? Utils::getVideoRealSource(source) : Utils::getAudioRealSource(source);
            const QFileInfo info(path);
            if (!info.isFile())
                continue;

            resources.append(QVariantMap{
                {QStringLiteral("key"), category + QLatin1Char('/') + info.fileName()},
                {QStringLiteral("category"), category},
                {QStringLiteral("name"), info.fileName()},
                {QStringLiteral("path"), info.absoluteFilePath()},
                {QStringLiteral("size"), info.size()},
                {QStringLiteral("readable"), info.isReadable()}
            });
        }
    }

    if (resources == m_resources)
        return;
    m_resources = resources;
    emit resourcesChanged();
}

bool ResourceSyncManager::startSync(const QStringList &resourceKeys, const QStringList &deviceIds)
{
    if (m_busy)
        return false;

    m_errorMessage.clear();
    if (resourceKeys.isEmpty() || deviceIds.isEmpty()) {
        m_errorMessage = tr("请选择资源和目标 PC");
        emit errorMessageChanged();
        return false;
    }

    refreshResources();
    QStringList keys = resourceKeys;
    keys.removeDuplicates();
    QVariantList selectedResources;
    for (const QString &key : keys) {
        QVariantMap resource;
        for (const QVariant &value : m_resources) {
            const QVariantMap candidate = value.toMap();
            if (candidate.value(QStringLiteral("key")).toString() == key) {
                resource = candidate;
                break;
            }
        }
        if (resource.isEmpty() || !resource.value(QStringLiteral("readable")).toBool()) {
            m_errorMessage = tr("资源不存在或不可读取：%1").arg(key);
            emit errorMessageChanged();
            return false;
        }
        selectedResources.append(resource);
    }

    QStringList ids = deviceIds;
    ids.removeDuplicates();
    QVariantList jobs;
    for (const QString &id : ids) {
        Device *device = m_deviceModel->deviceById(id);
        if (!device || !device->supportsProtocol(DeviceProtocol::Pc)
            || !device->isOnline()
            || device->configValues().value(DeviceKey::Ip).toString().trimmed().isEmpty()) {
            m_errorMessage = tr("目标 PC 不存在、离线或未配置 IP：%1").arg(device ? device->name() : id);
            emit errorMessageChanged();
            return false;
        }
        for (const QVariant &value : selectedResources) {
            QVariantMap job = value.toMap();
            job.insert(QStringLiteral("deviceId"), id);
            job.insert(QStringLiteral("deviceName"), device->name());
            job.insert(QStringLiteral("ip"), device->configValues().value(DeviceKey::Ip).toString().trimmed());
            job.insert(QStringLiteral("targetPath"),
                       (job.value(QStringLiteral("category")).toString() == QStringLiteral("video")
                            ? DeviceConstants::LocalVideoPrefix : DeviceConstants::LocalAudioPrefix)
                       + job.value(QStringLiteral("name")).toString());
            job.insert(QStringLiteral("state"), QStringLiteral("pending"));
            job.insert(QStringLiteral("sentBytes"), 0);
            job.insert(QStringLiteral("error"), QString());
            jobs.append(job);
        }
    }

    m_jobs = jobs;
    m_currentJobIndex = -1;
    m_busy = true;
    emit errorMessageChanged();
    emit jobsChanged();
    emit busyChanged();
    startNextUpload();
    return true;
}

void ResourceSyncManager::startNextUpload()
{
    if (!m_busy)
        return;

    while (++m_currentJobIndex < m_jobs.size()) {
        QVariantMap job = m_jobs[m_currentJobIndex].toMap();
        if (job.value(QStringLiteral("state")).toString() != QStringLiteral("pending"))
            continue;

        auto *file = new QFile(job.value(QStringLiteral("path")).toString(), this);
        if (!file->open(QIODevice::ReadOnly)) {
            job.insert(QStringLiteral("state"), QStringLiteral("failed"));
            job.insert(QStringLiteral("error"), tr("无法打开文件：%1").arg(file->errorString()));
            m_jobs[m_currentJobIndex] = job;
            delete file;
            continue;
        }

        QUrl url;
        url.setScheme(QStringLiteral("http"));
        url.setHost(job.value(QStringLiteral("ip")).toString());
        url.setPort(11357);
        url.setPath(QStringLiteral("/uploadFile"));
        // 单独编码参数值，保留文件名中的中文、空格、+、& 等字符。
        url.setQuery(QStringLiteral("path=") + QString::fromLatin1(
            QUrl::toPercentEncoding(job.value(QStringLiteral("targetPath")).toString())));

        QNetworkRequest request(url);
        request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/octet-stream"));
        request.setHeader(QNetworkRequest::ContentLengthHeader, file->size());
        request.setAttribute(QNetworkRequest::DoNotBufferUploadDataAttribute, true);
        request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
        m_network->setNetworkAccessible(QNetworkAccessManager::Accessible);
        QNetworkReply *reply = m_network->post(request, file);
        file->setParent(reply);
        m_reply = reply;
        job.insert(QStringLiteral("size"), file->size());
        job.insert(QStringLiteral("state"), QStringLiteral("uploading"));
        m_jobs[m_currentJobIndex] = job;
        const int index = m_currentJobIndex;

        connect(reply, &QNetworkReply::uploadProgress, this, [this, index](qint64 sent, qint64) {
            QVariantMap job = m_jobs[index].toMap();
            const qint64 bytes = qBound(qint64(0), sent, job.value(QStringLiteral("size")).toLongLong());
            if (job.value(QStringLiteral("sentBytes")).toLongLong() == bytes)
                return;
            job.insert(QStringLiteral("sentBytes"), bytes);
            m_jobs[index] = job;
            emit jobsChanged();
        });
        connect(reply, &QNetworkReply::finished, this, [this, reply, index]() {
            QVariantMap job = m_jobs[index].toMap();
            const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            const bool success = reply->error() == QNetworkReply::NoError && status >= 200 && status < 300;
            job.insert(QStringLiteral("state"), success ? QStringLiteral("succeeded") : QStringLiteral("failed"));
            if (success) {
                job.insert(QStringLiteral("sentBytes"), job.value(QStringLiteral("size")));
            } else {
                QString error = status > 0 ? tr("HTTP %1").arg(status) : reply->errorString();
                if (status > 0 && reply->error() != QNetworkReply::NoError)
                    error += QStringLiteral("：") + reply->errorString();
                const QString response = QString::fromUtf8(reply->readAll()).trimmed();
                if (!response.isEmpty())
                    error += QStringLiteral("：") + response;
                job.insert(QStringLiteral("error"), error);
            }
            m_jobs[index] = job;
            m_reply = nullptr;
            reply->deleteLater();
            emit jobsChanged();
            startNextUpload();
        });
        emit jobsChanged();
        return;
    }

    m_busy = false;
    emit jobsChanged();
    emit busyChanged();
}

void ResourceSyncManager::stopSync()
{
    if (!m_busy)
        return;

    for (int index = 0; index < m_jobs.size(); ++index) {
        QVariantMap job = m_jobs[index].toMap();
        const QString state = job.value(QStringLiteral("state")).toString();
        if (state != QStringLiteral("pending") && state != QStringLiteral("uploading"))
            continue;
        job.insert(QStringLiteral("state"), QStringLiteral("cancelled"));
        job.insert(QStringLiteral("error"), state == QStringLiteral("uploading")
            ? tr("已停止上传，目标文件可能已被写入") : tr("已取消，未上传"));
        m_jobs[index] = job;
    }
    if (m_reply) {
        m_reply->disconnect(this);
        m_reply->abort();
        m_reply->deleteLater();
        m_reply = nullptr;
    }
    m_busy = false;
    emit jobsChanged();
    emit busyChanged();
}

void ResourceSyncManager::retryFailed()
{
    if (m_busy)
        return;

    bool hasFailed = false;
    for (int index = 0; index < m_jobs.size(); ++index) {
        QVariantMap job = m_jobs[index].toMap();
        if (job.value(QStringLiteral("state")).toString() != QStringLiteral("failed"))
            continue;
        job.insert(QStringLiteral("state"), QStringLiteral("pending"));
        job.insert(QStringLiteral("sentBytes"), 0);
        job.insert(QStringLiteral("error"), QString());
        m_jobs[index] = job;
        hasFailed = true;
    }
    if (!hasFailed)
        return;

    m_errorMessage.clear();
    m_currentJobIndex = -1;
    m_busy = true;
    emit errorMessageChanged();
    emit jobsChanged();
    emit busyChanged();
    startNextUpload();
}
