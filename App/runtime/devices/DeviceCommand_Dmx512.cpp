#include "devices/DeviceCommand_Dmx512.h"

namespace {

const char *kChannelKey = "channel";
const char *kValueKey = "value";

} // namespace

using namespace TimelineControl;

DeviceCommand_Dmx512::DeviceCommand_Dmx512(QObject *parent)
    : DeviceCommand(QStringLiteral("DMX Cue"), parent)
{
    auto *channelField = new DeviceParamSpec(QString::fromLatin1(kChannelKey),
                                             tr("Channel"),
                                             1,
                                             DeviceParamSpec::IntType,
                                             DeviceParamSpec::TextEditor,
                                             this);
    channelField->setMinimum(1);
    channelField->setMaximum(512);
    addCreationInputField(channelField);
    connect(channelField, &DeviceParamSpec::valueChanged, this, &DeviceCommand_Dmx512::channelChanged);

    auto *valueField = new DeviceParamSpec(QString::fromLatin1(kValueKey),
                                           tr("Value"),
                                           255,
                                           DeviceParamSpec::IntType,
                                           DeviceParamSpec::SliderEditor,
                                           this);
    valueField->setMinimum(0);
    valueField->setMaximum(255);
    valueField->setStepSize(1);
    addCreationInputField(valueField);
    connect(valueField, &DeviceParamSpec::valueChanged, this, &DeviceCommand_Dmx512::valueChanged);
}

DeviceCommand_Dmx512::DeviceCommand_Dmx512(const QString &name,
                                           int channel,
                                           int value,
                                           QObject *parent)
    : DeviceCommand_Dmx512(parent)
{
    setName(name);
    setChannel(channel);
    setValue(value);
}

int DeviceCommand_Dmx512::channel() const
{
    return channelField() ? channelField()->intValue() : 1;
}

void DeviceCommand_Dmx512::setChannel(int channel)
{
    if (channelField())
        channelField()->setValue(channel);
}

int DeviceCommand_Dmx512::value() const
{
    return valueField() ? valueField()->intValue() : 255;
}

void DeviceCommand_Dmx512::setValue(int value)
{
    if (valueField())
        valueField()->setValue(value);
}

QString DeviceCommand_Dmx512::protocol() const
{
    return protocolName();
}

QString DeviceCommand_Dmx512::protocolName()
{
    return QStringLiteral("dmx512");
}

