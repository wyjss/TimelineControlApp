#include "devices/DeviceCommand.h"

#include "devices/DeviceCommand_Dmx512.h"
#include "devices/DeviceCommand_Http.h"
#include "devices/DeviceCommand_PC.h"
#include "devices/DeviceCommand_Serial.h"

#include <QJsonValue>
#include <QVariant>
#include <QtGlobal>

namespace {

const char *kProtocolKey = "protocol";
const char *kNameKey = "name";
const char *kStartTimeMsKey = "startTimeMs";
const char *kDurationMsKey = "durationMs";
const char *kParamsKey = "params";

using TimelineControl::DeviceParamSpec;

qint64 jsonInt64Value(const QJsonObject &json, const QString &key, qint64 fallback)
{
    const QJsonValue value = json.value(key);
    if (value.isUndefined() || value.isNull())
        return fallback;

    if (value.isString()) {
        bool ok = false;
        const qint64 parsedValue = value.toString().toLongLong(&ok);
        return ok ? parsedValue : fallback;
    }

    return value.toVariant().toLongLong();
}

QString normalizedProtocolName(const QString &protocol)
{
    return protocol.trimmed().toLower();
}

DeviceParamSpec *makeField(QObject *parent,
                           const QString &key,
                           const QString &label,
                           DeviceParamSpec::ValueType valueType,
                           const QVariant &value,
                           DeviceParamSpec::EditorHint editorHint = DeviceParamSpec::AutoEditor,
                           bool required = false)
{
    auto *field = new DeviceParamSpec(key, label, value, valueType, editorHint, parent);
    field->setRequired(required);
    return field;
}

QVariantList toVariantList(const QList<DeviceParamSpec *> &fields)
{
    QVariantList result;
    result.reserve(fields.size());
    for (DeviceParamSpec *field : fields)
        result.append(QVariant::fromValue(field));
    return result;
}

DeviceParamSpec *findField(const QList<DeviceParamSpec *> &fields, const QString &key)
{
    const QString normalizedKey = key.trimmed();
    if (normalizedKey.isEmpty())
        return nullptr;

    for (DeviceParamSpec *field : fields) {
        if (field && field->key() == normalizedKey)
            return field;
    }

    return nullptr;
}

} // namespace

namespace TimelineControl {

DeviceCommand::DeviceCommand(QObject *parent)
    : QObject(parent)
{
}

DeviceCommand::DeviceCommand(const QString &name, QObject *parent)
    : QObject(parent)
    , m_name(name)
{
}

QString DeviceCommand::name() const
{
    return m_name;
}

void DeviceCommand::setName(const QString &name)
{
    if (m_name == name)
        return;

    m_name = name;
    emit nameChanged();
}

DeviceCommand *DeviceCommand::createForProtocol(const QString &protocol, QObject *parent)
{
    const QString normalizedProtocol = normalizedProtocolName(protocol);
    if (normalizedProtocol == DeviceCommand_Dmx512::protocolName())
        return new DeviceCommand_Dmx512(parent);
    if (normalizedProtocol == DeviceCommand_Http::protocolName())
        return new DeviceCommand_Http(parent);
    if (normalizedProtocol == DeviceCommand_PC::protocolName())
        return new DeviceCommand_PC(parent);
    if (normalizedProtocol == DeviceCommand_Serial::protocolName())
        return new DeviceCommand_Serial(parent);

    return nullptr;
}

DeviceCommand *DeviceCommand::createFromJson(const QJsonObject &json, QObject *parent)
{
    auto *command = createForProtocol(json.value(QString::fromLatin1(kProtocolKey)).toString(), parent);
    if (!command)
        return nullptr;

    if (!command->loadFromJson(json)) {
        delete command;
        return nullptr;
    }

    return command;
}

QJsonObject DeviceCommand::toJson() const
{
    QJsonObject json;
    json.insert(QString::fromLatin1(kProtocolKey), protocol());
    json.insert(QString::fromLatin1(kNameKey), name());
    json.insert(QString::fromLatin1(kStartTimeMsKey), QJsonValue::fromVariant(startTimeMs()));
    json.insert(QString::fromLatin1(kDurationMsKey), QJsonValue::fromVariant(durationMs()));
    json.insert(QString::fromLatin1(kParamsKey), paramsToJson());
    return json;
}

bool DeviceCommand::loadFromJson(const QJsonObject &json)
{
    const QString jsonProtocol = normalizedProtocolName(json.value(QString::fromLatin1(kProtocolKey)).toString());
    if (!jsonProtocol.isEmpty() && jsonProtocol != normalizedProtocolName(protocol()))
        return false;

    if (json.contains(QString::fromLatin1(kNameKey)))
        setName(json.value(QString::fromLatin1(kNameKey)).toString(name()));

    setStartTimeMs(jsonInt64Value(json, QString::fromLatin1(kStartTimeMsKey), startTimeMs()));
    setDurationMs(jsonInt64Value(json, QString::fromLatin1(kDurationMsKey), durationMs()));

    return loadParamsFromJson(json.value(QString::fromLatin1(kParamsKey)).toObject());
}

QString DeviceCommand::validate() const
{
    if (name().trimmed().isEmpty())
        return tr("Command name is required");

    if (startTimeMs() < 0)
        return tr("Start time must not be negative");

    if (durationMs() < 0)
        return tr("Duration must not be negative");

    return validateParams();
}

DeviceCommand *DeviceCommand::clone(QObject *parent) const
{
    return createFromJson(toJson(), parent);
}

qint64 DeviceCommand::startTimeMs() const
{
    return m_startTimeMs;
}

void DeviceCommand::setStartTimeMs(qint64 startTimeMs)
{
    const qint64 normalizedStartTimeMs = qMax<qint64>(0, startTimeMs);
    if (m_startTimeMs == normalizedStartTimeMs)
        return;

    m_startTimeMs = normalizedStartTimeMs;
    emit startTimeMsChanged();
}

qint64 DeviceCommand::durationMs() const
{
    return m_durationMs;
}

void DeviceCommand::setDurationMs(qint64 durationMs)
{
    const qint64 normalizedDurationMs = qMax<qint64>(0, durationMs);
    if (m_durationMs == normalizedDurationMs)
        return;

    m_durationMs = normalizedDurationMs;
    emit durationMsChanged();
}

void DeviceCommand::addCreationInputField(DeviceParamSpec *field)
{
    if (!field)
        return;

    ensureCreationInputFields();
    if (field->parent() != this)
        field->setParent(this);

    m_creationInputFields.append(field);
}

void DeviceCommand::addExecutionInputField(DeviceParamSpec *field)
{
    if (!field)
        return;

    ensureExecutionInputFields();
    if (field->parent() != this)
        field->setParent(this);

    m_executionInputFields.append(field);
}

QVariantList DeviceCommand::creationInputFields() const
{
    ensureCreationInputFields();
    return toVariantList(m_creationInputFields);
}

QVariantList DeviceCommand::executionInputFields() const
{
    ensureExecutionInputFields();
    return toVariantList(m_executionInputFields);
}

DeviceParamSpec *DeviceCommand::creationInputField(const QString &key) const
{
    ensureCreationInputFields();
    return findField(m_creationInputFields, key);
}

DeviceParamSpec *DeviceCommand::executionInputField(const QString &key) const
{
    ensureExecutionInputFields();
    return findField(m_executionInputFields, key);
}

DeviceParamSpec *DeviceCommand::fieldByKey(const QString &key) const
{
    if (auto *field = creationInputField(key))
        return field;

    return executionInputField(key);
}

QList<DeviceParamSpec *> DeviceCommand::createCreationInputFields(QObject *parent) const
{
    return QList<DeviceParamSpec *>{
        makeField(parent,
                  QStringLiteral("name"),
                  tr("Name"),
                  DeviceParamSpec::StringType,
                  name(),
                  DeviceParamSpec::TextEditor,
                  true)
    };
}

QList<DeviceParamSpec *> DeviceCommand::createExecutionInputFields(QObject *parent) const
{
    auto *startTimeField = makeField(parent,
                                    QStringLiteral("startTimeMs"),
                                    tr("Start Time"),
                                    DeviceParamSpec::IntType,
                                    QVariant::fromValue(startTimeMs()),
                                    DeviceParamSpec::TextEditor);
    startTimeField->setMinimum(0);
    startTimeField->setSuffix(QStringLiteral("ms"));

    auto *durationField = makeField(parent,
                                    QStringLiteral("durationMs"),
                                    tr("Duration"),
                                    DeviceParamSpec::IntType,
                                    QVariant::fromValue(durationMs()),
                                    DeviceParamSpec::TextEditor);
    durationField->setMinimum(0);
    durationField->setSuffix(QStringLiteral("ms"));

    return QList<DeviceParamSpec *>{startTimeField, durationField};
}

void DeviceCommand::ensureCreationInputFields() const
{
    if (!m_creationInputFields.isEmpty())
        return;

    m_creationInputFields = createCreationInputFields(const_cast<DeviceCommand *>(this));
}

void DeviceCommand::ensureExecutionInputFields() const
{
    if (!m_executionInputFields.isEmpty())
        return;

    m_executionInputFields = createExecutionInputFields(const_cast<DeviceCommand *>(this));
}

} // namespace TimelineControl
