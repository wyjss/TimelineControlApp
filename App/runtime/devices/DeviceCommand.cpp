#include "devices/DeviceCommand.h"

#include "devices/DeviceCommandFactory.h"
#include "devices/DeviceConstants.h"

#include <QVariant>

namespace {

const char *kProtocolKey = "protocol";
const char *kExecutionInputFieldsKey = "executionInputFields";

} // namespace


DeviceCommand::DeviceCommand(QObject *parent)
    : DeviceCommand(QString(), QString(), parent)
{
}

DeviceCommand::DeviceCommand(const QString &protocol, const QString &name, QObject *parent)
    : DeviceCommand(protocol, name, QString(), parent)
{
}

DeviceCommand::DeviceCommand(const QString &protocol,
                             const QString &name,
                             const QString &commandType,
                             QObject *parent)
    : QObject(parent)
    , m_protocol(protocol.trimmed())
    , m_commandType(commandType.trimmed())
{
    auto *nameField = DeviceParamSpec::createForKey(DeviceKey::Name);
    nameField->setValue(name);
    nameField->setDefaultValue(name);
	connect(nameField, &DeviceParamSpec::valueChanged, this, &DeviceCommand::nameChanged);
	addCreationInputField(nameField);
}

QString DeviceCommand::name() const
{
    return getField(DeviceKey::Name)->stringValue();
}

void DeviceCommand::setName(const QString &name)
{
    getField(DeviceKey::Name)->setValue(name);
}

QString DeviceCommand::protocol() const
{
    return m_protocol;
}

QString DeviceCommand::commandType() const
{
    return m_commandType;
}

DeviceParamSpec* DeviceCommand::getField(const QString& key) const
{
    return m_creationInputFieldMap.value(key, nullptr);
}

QJsonObject DeviceCommand::toJson() const
{
    QJsonObject json;

    json.insert(QString::fromLatin1(kProtocolKey), protocol());
    if (!commandType().isEmpty())
        json.insert(DeviceKey::CommandType, commandType());

    for (DeviceParamSpec *field : m_creationInputFields)
        json.insert(field->key(), QJsonValue::fromVariant(field->value()));

    return json;
}

bool DeviceCommand::loadFromJson(const QJsonObject &json)
{
    const QString jsonProtocol = json.value(QString::fromLatin1(kProtocolKey)).toString();
    if (!jsonProtocol.isEmpty() && jsonProtocol != protocol())
        return false;

    if (json.value(DeviceKey::CommandType).toString() != commandType())
        return false;

    for (auto itr = json.begin(); itr != json.end(); ++itr) {
        if (auto field = getField(itr.key()))
            field->setValue(itr.value().toVariant());
    }

    const QJsonObject executionInputFields = json.value(QString::fromLatin1(kExecutionInputFieldsKey)).toObject();
    for (DeviceParamSpec *field : m_executionInputFields) {
        if (executionInputFields.contains(field->key()))
            field->setValue(executionInputFields.value(field->key()).toVariant());
    }

    return true;
}

QVariantMap DeviceCommand::resolvedParams(const QVariantMap &) const
{
    QVariantMap params = m_configMap;
    params.remove(QString::fromLatin1(kExecutionInputFieldsKey));

    for (DeviceParamSpec *field : m_creationInputFields)
        params.insert(field->key(), field->value());

    return params;
}

DeviceCommand *DeviceCommand::clone(QObject *parent) const
{
    return DeviceCommandFactory::createFromJson(toJson(), parent);
}

void DeviceCommand::addCreationInputField(DeviceParamSpec *field)
{
    if (!field)
        return;

    if (m_creationInputFieldMap.contains(field->key()))
        return;

    if (field->parent() != this)
        field->setParent(this);

    m_creationInputFieldMap[field->key()] = field;
    m_creationInputFields.append(field);

    connect(field, &DeviceParamSpec::valueChanged, this, &DeviceCommand::emitFieldChanged);
}

void DeviceCommand::addExecutionInputField(DeviceParamSpec *field)
{
    if (!field)
        return;

    if (field->parent() != this)
        field->setParent(this);

    m_executionInputFields.append(field);
}

QVariantList DeviceCommand::creationInputFields() const
{
    QVariantList result;
    result.reserve(m_creationInputFields.size());
    for (DeviceParamSpec *field : m_creationInputFields)
        result.append(QVariant::fromValue(field));
    return result;
}

void DeviceCommand::updateConfigMap(const QVariantMap &configMap)
{
    const QString executionInputFieldsKey = QString::fromLatin1(kExecutionInputFieldsKey);
    for (auto it = configMap.cbegin(); it != configMap.cend(); ++it) {
        if (it.key() == executionInputFieldsKey)
            continue;
        m_configMap.insert(it.key(), it.value());
    }

    for (DeviceParamSpec *field : m_creationInputFields) {
        if (m_configMap.contains(field->key()))
            field->setValue(m_configMap.value(field->key()));
    }
}

QVariantList DeviceCommand::creationMinInputFields() const
{
	QVariantList result;
    for (DeviceParamSpec *field : m_creationInputFields) {
        if (!m_configMap.contains(field->key()))
            result.append(QVariant::fromValue(field));
    }
		
	return result;
}

QVariantList DeviceCommand::executionInputFields() const
{
    QVariantList result;
    result.reserve(m_executionInputFields.size());
    for (DeviceParamSpec *field : m_executionInputFields)
        result.append(QVariant::fromValue(field));
    return result;
}

void DeviceCommand::emitFieldChanged()
{
    emit fieldChanged(qobject_cast<DeviceParamSpec *>(sender()));
}

DeviceCommand_Http::DeviceCommand_Http(QObject *parent)
    : DeviceCommand_Http(DeviceProtocol::Http, QStringLiteral("HTTP指令"), QString(), parent)
{
}

DeviceCommand_Http::DeviceCommand_Http(const QString &protocol,
                                       const QString &name,
                                       const QString &commandType,
                                       QObject *parent)
    : DeviceCommand(protocol, name, commandType, parent)
{
    addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::Ip));
    addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::Port));
    addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::HttpMethod));
    addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::ApiPath));
    addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::HttpBody));
}

DeviceCommand_PC::DeviceCommand_PC(QObject *parent)
    : DeviceCommand_PC(QStringLiteral("PC指令"), QString(), parent)
{
}

DeviceCommand_PC::DeviceCommand_PC(const QString &name,
                                   const QString &commandType,
                                   QObject *parent)
    : DeviceCommand_Http(DeviceProtocol::Pc, name, commandType, parent)
{
    updateConfigMap({
        {DeviceKey::HttpMethod, QStringLiteral("GET")},
        {DeviceKey::HttpBody, QString()},
        {DeviceKey::Port, 11357}
    });
}
