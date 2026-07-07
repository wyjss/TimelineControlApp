#include "devices/DeviceCommand_Serial.h"
#include "devices/DeviceConstants.h"

namespace {

const char *kHexPayloadPattern = "^([0-9A-Fa-f]{2})(\\s+[0-9A-Fa-f]{2})*$";
constexpr int kDefaultBaudRate = 9600;

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

QString DeviceCommand_Serial::protocolName()
{
    return QStringLiteral("serial");
}

