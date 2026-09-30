#include "devices/executors/UdpCommandExecutor.h"

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"

#include "runtime/utils.h"

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
    QByteArray payload;
    auto varData = params.value(DeviceKey::Payload);

    if (varData.type() == QVariant::ByteArray) {
        payload = varData.toByteArray();
    } else {
        payload = varData.toString().toUtf8();
    }

	if (m_ip.isEmpty() || payload.isEmpty()) {
		emit executionFinished(executionId, command, false, tr("UDP 地址或数据为空"));
        return;
    }
    
	if (params.value(DeviceKey::PayloadType, "").toString() == DeviceKey::PayloadType_Hex) {
		QByteArray data;
        if (!Utils::toHexData(payload, &data)) {
			emit executionFinished(executionId, command, false, tr("无效的hex数据"));
			return;
		}
		LOG_DEBUG("转换16进制数据:" << payload);
        payload = data;
	} else
    {
        
    }
   
    QUdpSocket sock;
    auto size = sock.writeDatagram(payload, QHostAddress(m_ip), m_port);

	LOG_DEBUG("send udp order: " << payload);
	LOG_DEBUG("send udp order ip: " << m_ip << m_port);

    if (size == payload.size()) {
        emit executionFinished(executionId, command, true, "");
    } else {
        emit executionFinished(executionId, command, false, "发送失败");
    }
}
