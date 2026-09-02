#include "devices/executors/UdpCommandExecutor.h"

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"

#define LC "[UdpCommandExecutor] "
#include "LogMacros.h"
#include <QUdpSocket>
#include <QTimer>
#include <QUrl>



UdpCommandExecutor::UdpCommandExecutor(const QString &ip, int port, QObject *parent)
    : DeviceCommandExecutor(parent)
    , m_ip(ip)
    , m_port(port)
{
}

void UdpCommandExecutor::executeImpl(const QString &executionId,
                                     DeviceCommand *command,
                                     const QVariantMap &params)
{
    const QString path = params.value(DeviceKey::Payload).toString();
    if (m_ip.isEmpty() || path.isEmpty()) {
        emit executionFinished(executionId, command, false, tr("HTTP 地址或路径为空"));
        return;
    }

    auto data = path.toUtf8();
    QUdpSocket sock;
    auto size = sock.writeDatagram(data, QHostAddress(m_ip), m_port);
    LOG_DEBUG("send udp order: " << data);
    if (size == data.size()) {
        emit executionFinished(executionId, command, true, "");
    } else {
        emit executionFinished(executionId, command, false, "发送失败");
    }
}
