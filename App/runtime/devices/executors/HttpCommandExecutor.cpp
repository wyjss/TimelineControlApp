#include "devices/executors/HttpCommandExecutor.h"

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"

#define LC "[HttpCommandExecutor] "
#include "LogMacros.h"
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QUrl>



HttpCommandExecutor::HttpCommandExecutor(const QString &ip, int port, QObject *parent)
    : DeviceCommandExecutor(parent)
    , m_ip(ip)
    , m_port(port)
{
}

void HttpCommandExecutor::executeImpl(const QString &executionId,
                                      DeviceCommand *command,
                                      const QVariantMap &params)
{
    const QString path = params.value(DeviceKey::ApiPath).toString();
    if (m_ip.isEmpty() || path.isEmpty()) {
        emit executionFinished(executionId, command, false, tr("HTTP 地址或路径为空"));
        return;
    }

    QUrl url;
    url.setScheme(QStringLiteral("http"));
    url.setHost(m_ip);
    url.setPort(m_port);
    const int queryIndex = path.indexOf(QLatin1Char('?'));
    url.setPath(queryIndex < 0 ? path : path.left(queryIndex));
    if (queryIndex >= 0)
        url.setQuery(path.mid(queryIndex + 1));
    if (!url.isValid()) {
        emit executionFinished(executionId, command, false, tr("HTTP URL 无效"));
        return;
    }

    QNetworkRequest request(url);
    if (!m_manager)
        m_manager = new QNetworkAccessManager(this);
    const QString method = params.value(DeviceKey::HttpMethod).toString();
    if (method.isEmpty()) {
        emit executionFinished(executionId, command, false, tr("HTTP 方法为空"));
        return;
    }

    LOG_INFO("POST REQUEST");
    QNetworkReply *reply = method == QStringLiteral("POST")
        ? m_manager->post(request, params.value(DeviceKey::HttpBody).toString().toUtf8())
        : m_manager->get(request);

    QTimer::singleShot(5000, reply, [reply]() {
        if (reply->isRunning()) {
            reply->setProperty("timedOut", true);
            reply->abort();
            LOG_ERROR("timeout, request force quit");
        }
    });

    connect(reply, &QNetworkReply::finished, this, [this, executionId, command, reply]() {
        LOG_INFO("REPLY REQUEST");
        const QVariant status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute);
        const int httpStatus = status.toInt();
        const bool success = reply->error() == QNetworkReply::NoError
            && (!status.isValid() || httpStatus < 400);
        QString message;
        if (!success) {
            message = reply->property("timedOut").toBool()
                ? tr("HTTP 请求超时")
                : (reply->error() == QNetworkReply::NoError ? tr("HTTP %1").arg(httpStatus) : reply->errorString());
            
            if (reply->error() == QNetworkReply::ConnectionRefusedError) {
                LOG_ERROR("http连接错误，禁用2000ms" << reply->url());
				markFailed(message);
            }
        }
        emit executionFinished(executionId, command, success, message);
    });
    connect(reply, &QNetworkReply::finished, reply, &QObject::deleteLater);
}
