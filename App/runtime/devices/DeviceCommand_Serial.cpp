#include "devices/DeviceCommand_Serial.h"
#include "devices/DeviceConstants.h"

namespace {

const char *kHexPayloadPattern = "^([0-9A-Fa-f]{2})(\\s+[0-9A-Fa-f]{2})*$";

} // namespace

using namespace TimelineControl;

DeviceCommand_Serial::DeviceCommand_Serial(QObject *parent)
    : DeviceCommand(QStringLiteral("Serial Cue"), parent)
{
	auto *serialPortField = new DeviceParamSpec(DeviceKey::SerialPort,
												tr("Serial Port"),
												QStringLiteral("COM0"),
												DeviceParamSpec::StringType,
												DeviceParamSpec::TextEditor,
												this);
	serialPortField->setPlaceholderText(QStringLiteral("COM1"));
	addCreationInputField(serialPortField);
	connect(serialPortField, &DeviceParamSpec::valueChanged, this, &DeviceCommand_Serial::serialPortChanged);

    auto *payloadField = new DeviceParamSpec(DeviceKey::Payload,
                                             tr("Payload"),
                                             QString(),
                                             DeviceParamSpec::StringType,
                                             DeviceParamSpec::TextEditor,
                                             this);
    payloadField->setPlaceholderText(QStringLiteral("A5 5A 01 00"));
    payloadField->setPattern(QString::fromLatin1(kHexPayloadPattern));
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

}

QString DeviceCommand_Serial::protocolName()
{
    return QStringLiteral("serial");
}

