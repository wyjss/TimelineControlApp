#include "devices/DeviceCommand_Serial.h"
#include "devices/DeviceConstants.h"

#include <QByteArray>
#include <QIODevice>
#include <QSerialPort>
#include <QStringList>

namespace {

const char *kHexPayloadPattern = "^([0-9A-Fa-f]{2})(\\s+[0-9A-Fa-f]{2})*$";
constexpr int kDefaultBaudRate = 9600;
constexpr int kWriteTimeoutMs = 3000;

} // namespace

using namespace TimelineControl;

DeviceCommand_Serial::DeviceCommand_Serial(QObject *parent)
    : DeviceCommand(QStringLiteral("串口指令"), parent)
{
	auto *serialPortField = new DeviceParamSpec(DeviceKey::SerialPort,
												tr("串口"),
												QStringLiteral("COM0"),
												DeviceParamSpec::StringType,
												DeviceParamSpec::TextEditor,
												this);
	serialPortField->setPlaceholderText(QStringLiteral("COM1"));
	serialPortField->setRequired(true);
	addCreationInputField(serialPortField);
	connect(serialPortField, &DeviceParamSpec::valueChanged, this, &DeviceCommand_Serial::serialPortChanged);

    auto *baudRateField = new DeviceParamSpec(DeviceKey::BaudRate,
                                              tr("波特率"),
                                              kDefaultBaudRate,
                                              DeviceParamSpec::IntType,
                                              DeviceParamSpec::TextEditor,
                                              this);
    baudRateField->setRequired(true);
    baudRateField->setMinimum(1);
    baudRateField->setMaximum(4000000);
    addCreationInputField(baudRateField);
    connect(baudRateField, &DeviceParamSpec::valueChanged, this, &DeviceCommand_Serial::baudRateChanged);

    auto *payloadField = new DeviceParamSpec(DeviceKey::Payload,
                                             tr("数据内容"),
                                             QString(),
                                             DeviceParamSpec::StringType,
                                             DeviceParamSpec::TextEditor,
                                             this);
    payloadField->setPlaceholderText(QStringLiteral("A5 5A 01 00"));
    payloadField->setPattern(QString::fromLatin1(kHexPayloadPattern));
    payloadField->setRequired(true);
    addCreationInputField(payloadField);
    connect(payloadField, &DeviceParamSpec::valueChanged, this, &DeviceCommand_Serial::payloadChanged);
}

DeviceCommand_Serial::DeviceCommand_Serial(const QString &name,
                                           const QString &payload,
                                           QObject *parent)
    : DeviceCommand_Serial(parent)
{
    setName(name);
    setPayload(payload);
}

QString DeviceCommand_Serial::serialPort() const
{
    return serialPortField() ? serialPortField()->stringValue() : QString();
}

void DeviceCommand_Serial::setSerialPort(const QString& serialPort)
{
    if (serialPortField())
        serialPortField()->setValue(serialPort);
}

int DeviceCommand_Serial::baudRate() const
{
    return baudRateField() ? baudRateField()->intValue() : kDefaultBaudRate;
}

void DeviceCommand_Serial::setBaudRate(int baudRate)
{
    if (baudRateField())
        baudRateField()->setValue(baudRate);
}

QString DeviceCommand_Serial::payload() const
{
    return payloadField() ? payloadField()->stringValue() : QString();
}

void DeviceCommand_Serial::setPayload(const QString &payload)
{
    if (payloadField())
        payloadField()->setValue(payload);
}

QString DeviceCommand_Serial::protocol() const
{
    return protocolName();
}

void DeviceCommand_Serial::execute()
{
    const QString portName = serialPort().trimmed();
    if (portName.isEmpty()) {
        emit executionFinished(false, tr("串口不能为空"));
        return;
    }

    const QStringList payloadParts = payload().simplified().split(QLatin1Char(' '), Qt::SkipEmptyParts);
    QByteArray bytes;
    bytes.reserve(payloadParts.size());
    for (const QString &part : payloadParts) {
        bool itemOk = false;
        const int value = part.toInt(&itemOk, 16);
        if (!itemOk || part.size() != 2 || value < 0 || value > 0xff) {
            emit executionFinished(false, tr("数据内容必须为十六进制字节"));
            return;
        }
        bytes.append(static_cast<char>(value));
    }
    if (bytes.isEmpty()) {
        emit executionFinished(false, tr("数据内容必须为十六进制字节"));
        return;
    }

    QSerialPort serialPort;
    serialPort.setPortName(portName);
    serialPort.setBaudRate(baudRate());
    serialPort.setDataBits(QSerialPort::Data8);
    serialPort.setParity(QSerialPort::NoParity);
    serialPort.setStopBits(QSerialPort::OneStop);
    serialPort.setFlowControl(QSerialPort::NoFlowControl);

    if (!serialPort.open(QIODevice::WriteOnly)) {
        emit executionFinished(false, tr("无法打开串口 %1：%2").arg(portName, serialPort.errorString()));
        return;
    }

    const qint64 queuedBytes = serialPort.write(bytes);
    if (queuedBytes != bytes.size()) {
        emit executionFinished(false, tr("串口写入失败：%1").arg(serialPort.errorString()));
        return;
    }

    if (!serialPort.waitForBytesWritten(kWriteTimeoutMs)) {
        emit executionFinished(false, tr("串口写入超时：%1").arg(serialPort.errorString()));
        return;
    }

    emit executionFinished(true, QString());
}

QString DeviceCommand_Serial::protocolName()
{
    return QStringLiteral("serial");
}

