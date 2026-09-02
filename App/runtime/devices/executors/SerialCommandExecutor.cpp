#include "devices/executors/SerialCommandExecutor.h"

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"

#include <QByteArray>
#include <QNetworkAccessManager>
#include <QNetworkProxy>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QStringList>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>


namespace {

constexpr int kServerPort = 11357;
constexpr int kSerialTimeoutMs = 3000;
constexpr int kRequestTimeoutMs = 5000;

}

SerialCommandExecutor::SerialCommandExecutor(const QString &ip, const QString &portName, QObject *parent)
    : DeviceCommandExecutor(parent)
    , m_ip(ip)
    , m_portName(portName)
{
}

void SerialCommandExecutor::executeImpl(const QString &executionId,
                                        DeviceCommand *command,
                                        const QVariantMap &params)
{
    const QStringList parts = params.value(DeviceKey::SerialPayload).toString().simplified().split(QLatin1Char(' '), Qt::SkipEmptyParts);
    QByteArray bytes;
    bytes.reserve(parts.size());
    for (const QString &part : parts) {
        bool ok = false;
        const int value = part.toInt(&ok, 16);
        if (!ok || part.size() != 2 || value < 0 || value > 0xff) {
            emit executionFinished(executionId, command, false, tr("串口数据必须是十六进制字节"));
            return;
        }
        bytes.append(static_cast<char>(value));
    }
    bytes = params.value(DeviceKey::SerialPayload).toString().simplified().remove(' ').toLatin1();
    if (bytes.isEmpty()) {
        emit executionFinished(executionId, command, false, tr("串口数据不能为空"));
        return;
    }

    const int baudRate = params.value(DeviceKey::BaudRate).toInt();
    if (baudRate <= 0) {
        emit executionFinished(executionId, command, false, tr("串口波特率无效"));
        return;
    }
    if (m_ip.isEmpty() || m_portName.isEmpty()) {
        emit executionFinished(executionId, command, false, tr("串口服务地址或串口名称为空"));
        return;
    }

    QUrl url;
    url.setScheme(QStringLiteral("http"));
    url.setHost(m_ip);
    url.setPort(kServerPort);
    url.setPath(QStringLiteral("/serial/execute"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("port"), m_portName);
    query.addQueryItem(QStringLiteral("baud"), QString::number(baudRate));
    query.addQueryItem(QStringLiteral("timeout"), QString::number(kSerialTimeoutMs));
    query.addQueryItem("cmd", bytes);
    url.setQuery(query);

   // url = "http://127.0.0.1:11357/version";
    if (!m_manager) {
		m_manager = new QNetworkAccessManager(this);
		m_manager->setProxy(QNetworkProxy::NoProxy);
    }
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/octet-stream"));
    QNetworkReply *reply = m_manager->get(request);
    QTimer::singleShot(kRequestTimeoutMs, reply, [reply]() {
        if (reply->isRunning()) {
            reply->setProperty("timedOut", true);
            reply->abort();
        }
    });

    connect(reply, &QNetworkReply::finished, this, [this, executionId, command, reply]() {
        const QVariant status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute);
        const int httpStatus = status.toInt();
        const bool success = reply->error() == QNetworkReply::NoError
            && (!status.isValid() || httpStatus < 400);
        QString message;
        if (!success) {
            const QString response = QString::fromUtf8(reply->readAll()).trimmed();
            message = reply->property("timedOut").toBool()
                ? tr("串口 HTTP 请求超时")
                : (!response.isEmpty() ? response
                                       : (reply->error() == QNetworkReply::NoError
                                              ? tr("HTTP %1").arg(httpStatus)
                                              : reply->errorString()));
        }
        emit executionFinished(executionId, command, success, message);
    });
    connect(reply, &QNetworkReply::finished, reply, &QObject::deleteLater);
}
