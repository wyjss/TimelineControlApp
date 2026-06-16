#include "devices/DeviceCommand_Serial.h"

#include <QRegularExpression>

namespace {

const char *kHexKey = "hex";
const char *kPayloadKey = "payload";

bool isHexPayload(const QString &payload)
{
    static const QRegularExpression pattern(QStringLiteral("^([0-9A-Fa-f]{2})(\\s+[0-9A-Fa-f]{2})*$"));
    return pattern.match(payload.trimmed()).hasMatch();
}

} // namespace

namespace TimelineControl {

DeviceCommand_Serial::DeviceCommand_Serial(QObject *parent)
    : DeviceCommand(QStringLiteral("Serial Cue"), parent)
{
    setHex(true);
    setPayload(QStringLiteral(""));
}

DeviceCommand_Serial::DeviceCommand_Serial(const QString &name,
                                           const QString &payload,
                                           bool hex,
                                           QObject *parent)
    : DeviceCommand(name, parent)
{
    setHex(hex);
    setPayload(payload);
}

bool DeviceCommand_Serial::isHex() const
{
    return m_hex;
}

void DeviceCommand_Serial::setHex(bool hex)
{
    if (m_hex == hex)
        return;

    m_hex = hex;
    emit hexChanged();
}

QString DeviceCommand_Serial::payload() const
{
    return m_payload;
}

void DeviceCommand_Serial::setPayload(const QString &payload)
{
    if (m_payload == payload)
        return;

    m_payload = payload;
    emit payloadChanged();
}

QString DeviceCommand_Serial::protocol() const
{
    return protocolName();
}

QString DeviceCommand_Serial::protocolName()
{
    return QStringLiteral("serial");
}

QJsonObject DeviceCommand_Serial::paramsToJson() const
{
    QJsonObject params;
    params.insert(QString::fromLatin1(kHexKey), isHex());
    params.insert(QString::fromLatin1(kPayloadKey), payload());
    return params;
}

bool DeviceCommand_Serial::loadParamsFromJson(const QJsonObject &params)
{
    if (params.contains(QString::fromLatin1(kHexKey)))
        setHex(params.value(QString::fromLatin1(kHexKey)).toBool(isHex()));

    if (params.contains(QString::fromLatin1(kPayloadKey)))
        setPayload(params.value(QString::fromLatin1(kPayloadKey)).toString(payload()));

    return true;
}

QString DeviceCommand_Serial::validateParams() const
{
    if (payload().trimmed().isEmpty())
        return tr("Payload is required");

    if (isHex() && !isHexPayload(payload()))
        return tr("Payload must be hex bytes");

    return QString();
}

QList<DeviceParamSpec *> DeviceCommand_Serial::createCreationInputFields(QObject *parent) const
{
    QList<DeviceParamSpec *> fields = DeviceCommand::createCreationInputFields(parent);

    auto *hexField = new DeviceParamSpec(QStringLiteral("hex"),
                                         tr("Hex"),
                                         isHex(),
                                         DeviceParamSpec::BoolType,
                                         DeviceParamSpec::ToggleEditor,
                                         parent);
    fields.append(hexField);

    auto *payloadField = new DeviceParamSpec(QStringLiteral("payload"),
                                             tr("Payload"),
                                             payload(),
                                             DeviceParamSpec::StringType,
                                             DeviceParamSpec::TextEditor,
                                             parent);
    payloadField->setRequired(true);
    payloadField->setPlaceholderText(QStringLiteral("A5 5A 01 00"));
    fields.append(payloadField);

    return fields;
}

} // namespace TimelineControl

