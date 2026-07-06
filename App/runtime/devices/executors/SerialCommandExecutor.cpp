#include "devices/executors/SerialCommandExecutor.h"

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"

#include <QByteArray>
#include <QIODevice>
#include <QSerialPort>
#include <QSerialPortInfo>
#include <QStringList>

using namespace TimelineControl;

namespace {

constexpr int kWriteTimeoutMs = 3000;

}

SerialCommandExecutor::SerialCommandExecutor(const QString &portName, QObject *parent)
    : DeviceCommandExecutor(parent)
    , m_portName(portName)
{
}

void SerialCommandExecutor::executeImpl(DeviceCommand *command, const QVariantMap &params)
{
    const QStringList parts = params.value(DeviceKey::Payload).toString().simplified().split(QLatin1Char(' '), Qt::SkipEmptyParts);
    QByteArray bytes;
    bytes.reserve(parts.size());
    for (const QString &part : parts) {
        bool ok = false;
        const int value = part.toInt(&ok, 16);
        if (!ok || part.size() != 2 || value < 0 || value > 0xff) {
            emit executionFinished(command, false, tr("串口数据必须是十六进制字节"));
            return;
        }
        bytes.append(static_cast<char>(value));
    }
    if (bytes.isEmpty()) {
        emit executionFinished(command, false, tr("串口数据不能为空"));
        return;
    }

    if (!m_port)
        m_port = new QSerialPort(this);
    const int baudRate = params.value(DeviceKey::BaudRate).toInt();
    if (baudRate <= 0) {
        emit executionFinished(command, false, tr("串口波特率无效"));
        return;
    }
    m_port->setBaudRate(baudRate);
    if (!m_port->isOpen()) {
        m_port->setPortName(m_portName);
        m_port->setDataBits(QSerialPort::Data8);
        m_port->setParity(QSerialPort::NoParity);
        m_port->setStopBits(QSerialPort::OneStop);
        m_port->setFlowControl(QSerialPort::NoFlowControl);
        if (!m_port->open(QIODevice::WriteOnly)) {
            const QString message = tr("无法打开串口 %1：%2").arg(m_portName, m_port->errorString());
            markFailed(message);
            emit executionFinished(command, false, message);
            return;
        }
    }

    if (m_port->write(bytes) != bytes.size()) {
        const QString message = tr("串口写入失败：%1").arg(m_port->errorString());
        markFailed(message);
        emit executionFinished(command, false, message);
        return;
    }

    if (!m_port->waitForBytesWritten(kWriteTimeoutMs)) {
        const QString message = tr("串口写入超时：%1").arg(m_port->errorString());
        markFailed(message);
        emit executionFinished(command, false, message);
        return;
    }

    emit executionFinished(command, true, QString());
}

bool SerialCommandExecutor::checkOnlineImpl(const QVariantMap &params)
{
    const QString portName = params.value(DeviceKey::SerialPort).toString().trimmed();
    const QList<QSerialPortInfo> ports = QSerialPortInfo::availablePorts();
    for (const QSerialPortInfo &port : ports) {
        if (port.portName() == portName)
            return true;
    }

    return false;
}
