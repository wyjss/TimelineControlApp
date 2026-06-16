#include "devices/DeviceCommand_Dmx512.h"

namespace {

const char *kChannelKey = "channel";
const char *kValueKey = "value";

} // namespace

namespace TimelineControl {

DeviceCommand_Dmx512::DeviceCommand_Dmx512(QObject *parent)
    : DeviceCommand(QStringLiteral("DMX Cue"), parent)
{
}

DeviceCommand_Dmx512::DeviceCommand_Dmx512(const QString &name,
                                           int channel,
                                           int value,
                                           QObject *parent)
    : DeviceCommand(name, parent)
{
    setChannel(channel);
    setValue(value);
}

int DeviceCommand_Dmx512::channel() const
{
    return m_channel;
}

void DeviceCommand_Dmx512::setChannel(int channel)
{
    if (m_channel == channel)
        return;

    m_channel = channel;
    emit channelChanged();
}

int DeviceCommand_Dmx512::value() const
{
    return m_value;
}

void DeviceCommand_Dmx512::setValue(int value)
{
    if (m_value == value)
        return;

    m_value = value;
    emit valueChanged();
}

QString DeviceCommand_Dmx512::protocol() const
{
    return protocolName();
}

QString DeviceCommand_Dmx512::protocolName()
{
    return QStringLiteral("dmx512");
}

QJsonObject DeviceCommand_Dmx512::paramsToJson() const
{
    QJsonObject params;
    params.insert(QString::fromLatin1(kChannelKey), channel());
    params.insert(QString::fromLatin1(kValueKey), value());
    return params;
}

bool DeviceCommand_Dmx512::loadParamsFromJson(const QJsonObject &params)
{
    if (params.contains(QString::fromLatin1(kChannelKey)))
        setChannel(params.value(QString::fromLatin1(kChannelKey)).toInt(channel()));

    if (params.contains(QString::fromLatin1(kValueKey)))
        setValue(params.value(QString::fromLatin1(kValueKey)).toInt(value()));

    return true;
}

QString DeviceCommand_Dmx512::validateParams() const
{
    if (channel() < 1 || channel() > 512)
        return tr("DMX channel must be between 1 and 512");

    if (value() < 0 || value() > 255)
        return tr("DMX value must be between 0 and 255");

    return QString();
}

QList<DeviceParamSpec *> DeviceCommand_Dmx512::createCreationInputFields(QObject *parent) const
{
    QList<DeviceParamSpec *> fields = DeviceCommand::createCreationInputFields(parent);

    auto *channelField = new DeviceParamSpec(QStringLiteral("channel"),
                                             tr("Channel"),
                                             channel(),
                                             DeviceParamSpec::IntType,
                                             DeviceParamSpec::TextEditor,
                                             parent);
    channelField->setRequired(true);
    channelField->setMinimum(1);
    channelField->setMaximum(512);
    fields.append(channelField);

    auto *valueField = new DeviceParamSpec(QStringLiteral("value"),
                                           tr("Value"),
                                           value(),
                                           DeviceParamSpec::IntType,
                                           DeviceParamSpec::SliderEditor,
                                           parent);
    valueField->setRequired(true);
    valueField->setMinimum(0);
    valueField->setMaximum(255);
    valueField->setStepSize(1);
    fields.append(valueField);

    return fields;
}

} // namespace TimelineControl

