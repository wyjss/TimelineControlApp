#include "devices/DeviceCommand.h"

#include "devices/DeviceCommandFactory.h"
#include "devices/DeviceConstants.h"

#include <QJsonArray>
#include <QVariant>
#include <QUrl>
#include <QUrlQuery>

namespace {

const char *kProtocolKey = "protocol";
const char *kExecutionInputFieldsKey = "executionInputFields";
const char *kCreationInputFieldSpecsKey = "creationInputFieldSpecs";
const char *kExecutionInputFieldSpecsKey = "executionInputFieldSpecs";

QJsonObject fieldSpecToJson(const DeviceParamSpec *field)
{
    QJsonObject json;
    json.insert(QStringLiteral("key"), field->key());
    json.insert(QStringLiteral("label"), field->label());
    json.insert(QStringLiteral("subtitle"), field->subtitle());
    json.insert(QStringLiteral("valueType"), static_cast<int>(field->valueType()));
    json.insert(QStringLiteral("editorHint"), static_cast<int>(field->editorHint()));
    json.insert(QStringLiteral("defaultValue"), QJsonValue::fromVariant(field->defaultValue()));
    json.insert(QStringLiteral("required"), field->required());
    json.insert(QStringLiteral("readOnly"), field->readOnly());
    json.insert(QStringLiteral("placeholderText"), field->placeholderText());
    json.insert(QStringLiteral("pattern"), field->pattern());
    json.insert(QStringLiteral("minimum"), field->minimum());
    json.insert(QStringLiteral("maximum"), field->maximum());
    json.insert(QStringLiteral("stepSize"), field->stepSize());
    json.insert(QStringLiteral("suffix"), field->suffix());
    if (field->key() == DeviceKey::Timeline)
        json.insert(QStringLiteral("optionSource"), QStringLiteral("timelines"));
    else
        json.insert(QStringLiteral("options"), QJsonArray::fromVariantList(field->options()));
    return json;
}

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

    if (commandType().isEmpty()) {
        QJsonArray creationInputFieldSpecs;
        for (DeviceParamSpec *field : m_creationInputFields)
            creationInputFieldSpecs.append(fieldSpecToJson(field));
        json.insert(QString::fromLatin1(kCreationInputFieldSpecsKey), creationInputFieldSpecs);

        QJsonArray executionInputFieldSpecs;
        for (DeviceParamSpec *field : m_executionInputFields)
            executionInputFieldSpecs.append(fieldSpecToJson(field));
        json.insert(QString::fromLatin1(kExecutionInputFieldSpecsKey), executionInputFieldSpecs);
    }

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

QVariantMap DeviceCommand::resolvedParams(const QVariantMap & executionInputValues) const
{
    QVariantMap params = m_configMap;
    params.remove(QString::fromLatin1(kExecutionInputFieldsKey));

    for (DeviceParamSpec *field : m_creationInputFields)
        params.insert(field->key(), field->value());

	for (auto it = executionInputValues.cbegin();
		 it != executionInputValues.cend();
		 ++it) {
        params.insert(it.key(), it.value());
	}

    if (params.contains(m_stringTemplateKey)) {
        auto str = params[m_stringTemplateKey].toString();
		
		for (auto it = params.cbegin(); it != params.cend(); ++it) {
            QString k = QString("{%1}").arg(it.key());
            // 普通替换
            if (str.contains(k)) {
                str = str.replace(k, it.value().toString());
            } 
            // http query插入
            else if (k.insert(1, "&"); str.contains(k)) {
                QUrl qurl(str);
                QUrlQuery query(qurl);
                query.addQueryItem(it.key(), it.value().toString());
                qurl.setQuery(query);
                str = qurl.toString();
            }
		}

        params[m_stringTemplateKey] = str;
    }

    return params;
}

DeviceCommand *DeviceCommand::clone(QObject *parent) const
{
    auto *command = DeviceCommandFactory::createFromJson(toJson(), parent);
    if (!command)
        return nullptr;

    for (DeviceParamSpec *field : command->m_executionInputFields)
        delete field;
    command->m_executionInputFields.clear();

    for (DeviceParamSpec *field : m_executionInputFields)
        command->addExecutionInputField(field->clone(command));

    command->m_stringTemplateKey = m_stringTemplateKey;
    return command;
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

//////////////////////////////////////////////////////////////////////////
DeviceCommand_Internal::DeviceCommand_Internal(QObject* parent)
	: DeviceCommand_Internal(DeviceProtocol::Internal, QStringLiteral("内部指令"), QString(), parent)
{

}

DeviceCommand_Internal::DeviceCommand_Internal(const QString& protocol,
									 const QString& name,
									 const QString& commandType,
									 QObject* parent)
	: DeviceCommand(protocol, name, commandType, parent)
{
	
}

//////////////////////////////////////////////////////////////////////////
DeviceCommand_Udp::DeviceCommand_Udp(QObject* parent)
	: DeviceCommand_Udp(DeviceProtocol::Udp, QStringLiteral("Udp指令"), QString(), parent)
{
	
}

DeviceCommand_Udp::DeviceCommand_Udp(const QString& protocol,
                  const QString& name,
                  const QString& commandType,
                  QObject* parent)
    : DeviceCommand(protocol, name, commandType, parent)
{
	addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::Ip));
	addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::Port));
    addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::ApiPath));
}

//////////////////////////////////////////////////////////////////////////
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

DeviceCommand_Osc::DeviceCommand_Osc(QObject *parent)
    : DeviceCommand(DeviceProtocol::Osc, QStringLiteral("OSC指令"), parent)
{
    addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::Ip));
    addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::Port));
    addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::OscTransProtocol));
    addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::OscMessage));
}
