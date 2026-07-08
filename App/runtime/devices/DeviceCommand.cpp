#include "devices/DeviceCommand.h"

#include "devices/DeviceCommandExecutionParamUpdater.h"
#include "devices/DeviceCommandFactory.h"
#include "devices/DeviceConstants.h"

#include <QVariant>

namespace {

const char *kProtocolKey = "protocol";
const char *kExecutionInputFieldsKey = "executionInputFields";
const char *kExecutionParamUpdaterKey = "executionParamUpdater";

} // namespace

using namespace TimelineControl;

DeviceCommand::DeviceCommand(QObject *parent)
    : DeviceCommand(QString(), QString(), parent)
{
}

DeviceCommand::DeviceCommand(const QString &protocol, const QString &name, QObject *parent)
    : QObject(parent)
    , m_protocol(protocol.trimmed())
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

QString DeviceCommand::protocol() const
{
    return m_protocol;
}

DeviceParamSpec* DeviceCommand::getField(const QString& key) const
{
    return m_creationInputFieldMap.value(key, nullptr);
}

QJsonObject DeviceCommand::toJson() const
{
    QJsonObject json;

    json.insert(QString::fromLatin1(kProtocolKey), protocol());
    if (!m_executionParamUpdaterName.isEmpty())
        json.insert(QString::fromLatin1(kExecutionParamUpdaterKey), m_executionParamUpdaterName);

    for (DeviceParamSpec *field : m_creationInputFields)
        json.insert(field->key(), QJsonValue::fromVariant(field->value()));

    return json;
}

bool DeviceCommand::loadFromJson(const QJsonObject &json)
{
    const QString jsonProtocol = json.value(QString::fromLatin1(kProtocolKey)).toString();
    if (!jsonProtocol.isEmpty() && jsonProtocol != protocol())
        return false;

    setExecutionParamUpdaterName(json.value(QString::fromLatin1(kExecutionParamUpdaterKey)).toString());

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

QVariantMap DeviceCommand::resolvedParams(const QVariantMap &executionInputValues)
{
    updateExecutionParams(executionInputValues);

    QVariantMap params = m_configMap;
    params.remove(QString::fromLatin1(kExecutionInputFieldsKey));
    params.remove(QString::fromLatin1(kExecutionParamUpdaterKey));

    for (DeviceParamSpec *field : m_creationInputFields)
        params.insert(field->key(), field->value());

    return params;
}

void DeviceCommand::updateExecutionParams(const QVariantMap &params)
{
    DeviceCommandExecutionParamUpdater::update(m_executionParamUpdaterName, this, params);
}

void DeviceCommand::setExecutionParamUpdaterName(const QString &name)
{
    const QString updaterName = name.trimmed();
    if (m_executionParamUpdaterName == updaterName)
        return;

    m_executionParamUpdaterName = updaterName;
    DeviceCommandExecutionParamUpdater::install(m_executionParamUpdaterName, this);
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
    const QString executionParamUpdaterKey = QString::fromLatin1(kExecutionParamUpdaterKey);
    for (auto it = configMap.cbegin(); it != configMap.cend(); ++it) {
        if (it.key() == executionInputFieldsKey || it.key() == executionParamUpdaterKey)
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
