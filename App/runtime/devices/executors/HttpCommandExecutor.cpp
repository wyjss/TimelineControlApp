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

    LOG_INFO(command->name() << url);

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
        const QVariant status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute);
        int statusCode = status.isValid() ? status.toInt() : -1;
        
        bool success = statusCode >= 200 & statusCode < 400;
        bool connectFailed = statusCode == -1;
        QString message;
        // 成功
        if (success) {
            ;
		} else {
            if (reply->property("timedOut").toBool()) {
                message = "HTTP 请求超时";
            } else if (statusCode == -1) {
                message = reply->errorString();
            } else {
                message = QString("HTTP %1").arg(statusCode);
                message += reply->readAll();
            }
		}
        
        if (connectFailed) {
            LOG_ERROR("http连接错误，禁用2000ms" << reply->url());
            markFailed(message);
        }
        emit executionFinished(executionId, command, success, message);
    });
    connect(reply, &QNetworkReply::finished, reply, &QObject::deleteLater);
}
