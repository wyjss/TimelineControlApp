#include "devices/executors/TcpCommandExecutor.h"

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"

#include "runtime/utils.h"

#define LC "[TcpCommandExecutor] "
#include "LogMacros.h"
#include <QTcpSocket>
#include <QTimer>
#include <QUrl>



TcpCommandExecutor::TcpCommandExecutor(const QString &ip, int port, QObject *parent)
    : DeviceCommandExecutor(parent)
    , m_ip(ip)
    , m_port(port)
{
}

void TcpCommandExecutor::executeImpl(const QString &executionId,
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
        emit executionFinished(executionId, command, false, tr("tcp 地址或数据为空"));
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
   
    QTcpSocket* sock = new QTcpSocket(this);
    QTimer* timer = new QTimer(sock);
    timer->setSingleShot(true);

    connect(sock, &QTcpSocket::connected, this, [this, executionId, command, payload, sock, timer]() {
        LOG_DEBUG("send tcp order: " << payload);
        LOG_DEBUG("send tcp order ip: " << m_ip << m_port);

        if (sock->write(payload) != payload.size()) {
            timer->stop();
            sock->disconnect(this);
            sock->abort();
            sock->deleteLater();
            emit executionFinished(executionId, command, false, tr("TCP 发送失败"));
            return;
        }

        // 等待写缓冲区的数据全部发出后断开连接。
        sock->disconnectFromHost();
    });
    connect(sock, &QTcpSocket::disconnected, this, [this, executionId, command, sock, timer]() {
        timer->stop();
        sock->deleteLater();
        emit executionFinished(executionId, command, true, "");
    });
    connect(sock, QOverload<QAbstractSocket::SocketError>::of(&QTcpSocket::error),
            this, [this, executionId, command, sock, timer](QAbstractSocket::SocketError) {
        const QString message = sock->errorString();
        timer->stop();
        sock->disconnect(this);
        sock->abort();
        sock->deleteLater();
        emit executionFinished(executionId, command, false, message);
    });
    connect(timer, &QTimer::timeout, this, [this, executionId, command, sock]() {
        sock->disconnect(this);
        sock->abort();
        sock->deleteLater();
        emit executionFinished(executionId, command, false, tr("TCP 连接或发送超时"));
    });

    timer->start(5000);
    sock->connectToHost(m_ip, m_port);
}
