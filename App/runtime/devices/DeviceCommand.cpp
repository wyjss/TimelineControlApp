#include "devices/DeviceCommand.h"

#include "devices/DeviceConstants.h"
#include "devices/DeviceCommand_Dmx512.h"
#include "devices/DeviceCommand_Http.h"
#include "devices/DeviceCommand_PC.h"
#include "devices/DeviceCommand_Serial.h"

#include <QVariant>

namespace {

const char *kProtocolKey = "protocol";
const char *kExecutionInputFieldsKey = "executionInputFields";

} // namespace

using namespace TimelineControl;

DeviceCommand::DeviceCommand(QObject *parent)
    : DeviceCommand("", parent)
{
}

DeviceCommand::DeviceCommand(const QString &name, QObject *parent)
    : QObject(parent)
{
	auto nameField = new DeviceParamSpec(
		DeviceKey::Name,
		"名称",
		name,
		DeviceParamSpec::StringType,
		DeviceParamSpec::TextEditor,
		this
	);
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

DeviceCommand *DeviceCommand::createForProtocol(const QString &protocol, QObject *parent)
{
    const QString protocolValue = protocol.trimmed();
    if (protocolValue == DeviceCommand_Dmx512::protocolName())
        return new DeviceCommand_Dmx512(parent);
    if (protocolValue == DeviceCommand_Http::protocolName())
        return new DeviceCommand_Http(parent);
    if (protocolValue == DeviceCommand_PC::protocolName())
        return new DeviceCommand_PC(parent);
    if (protocolValue == DeviceCommand_Serial::protocolName())
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

DeviceParamSpec* DeviceCommand::getField(const QString& key) const
{
    return m_creationInputFieldMap.value(key, nullptr);
}

QJsonObject DeviceCommand::toJson() const
{
    QJsonObject json;

    json.insert(QString::fromLatin1(kProtocolKey), protocol());
    for (DeviceParamSpec *field : m_creationInputFields)
        json.insert(field->key(), QJsonValue::fromVariant(field->value()));

    if (!m_executionInputFields.isEmpty()) {
        QJsonObject executionInputFields;
        for (DeviceParamSpec *field : m_executionInputFields)
            executionInputFields.insert(field->key(), QJsonValue::fromVariant(field->value()));
        json.insert(QString::fromLatin1(kExecutionInputFieldsKey), executionInputFields);
    }

    return json;
}

bool DeviceCommand::loadFromJson(const QJsonObject &json)
{
    const QString jsonProtocol = json.value(QString::fromLatin1(kProtocolKey)).toString();
    if (!jsonProtocol.isEmpty() && jsonProtocol != protocol())
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

QString DeviceCommand::validate() const
{
    for (DeviceParamSpec *field : m_creationInputFields) {
        const QString reason = field->invalidReason();
        if (!reason.isEmpty())
            return reason;
    }

    for (DeviceParamSpec *field : m_executionInputFields) {
        const QString reason = field->invalidReason();
        if (!reason.isEmpty())
            return reason;
    }

    return validateParams();
}

QString DeviceCommand::validateParams() const
{
    return QString();
}

void DeviceCommand::execute()
{
    emit executionFinished(false, tr("指令执行尚未实现"));
}

DeviceCommand *DeviceCommand::clone(QObject *parent) const
{
    return createFromJson(toJson(), parent);
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
    for (auto it = configMap.cbegin(); it != configMap.cend(); ++it)
        m_configMap.insert(it.key(), it.value());

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
