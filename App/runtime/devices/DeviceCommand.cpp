#include "devices/DeviceCommand.h"

#include "devices/Device.h"
#include "devices/DeviceConstants.h"
#include "runtime/TimelineRuntime.h"
#include "timeline/TimelineManager.h"

#define LC "[DeviceCommand] "
#include "LogMacros.h"

#include <QJsonArray>
#include <QVariant>
#include <QUrl>
#include <QUrlQuery>

namespace {

const char *kProtocolKey = "protocol";
const char *kCreationInputValuesKey = "creationInputValues";
const char *kExecutionInputFieldsKey = "executionInputFields";
const char *kCreationInputFieldSpecsKey = "creationInputFieldSpecs";
const char *kExecutionInputFieldSpecsKey = "executionInputFieldSpecs";
const char *kStringTemplateKey = "stringTemplateKey";

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
    json.insert(QStringLiteral("readOnly"), field->key() == DeviceKey::Name ? false : field->readOnly());
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

bool applyFieldSpec(DeviceParamSpec *field, const QJsonObject &json)
{
    const QVariant defaultValue = json.value(QStringLiteral("defaultValue")).toVariant();
    field->setLabel(json.value(QStringLiteral("label")).toString());
    field->setSubtitle(json.value(QStringLiteral("subtitle")).toString());
    field->setValueType(static_cast<DeviceParamSpec::ValueType>(
        json.value(QStringLiteral("valueType")).toInt(DeviceParamSpec::VariantType)));
    field->setEditorHint(static_cast<DeviceParamSpec::EditorHint>(
        json.value(QStringLiteral("editorHint")).toInt(DeviceParamSpec::AutoEditor)));
    field->setDefaultValue(defaultValue);
    field->setValue(defaultValue);
    field->setRequired(json.value(QStringLiteral("required")).toBool());
    field->setReadOnly(field->key() != DeviceKey::Name
                       && json.value(QStringLiteral("readOnly")).toBool());
    field->setPlaceholderText(json.value(QStringLiteral("placeholderText")).toString());
    field->setPattern(json.value(QStringLiteral("pattern")).toString());
    field->setMinimum(json.value(QStringLiteral("minimum")).toDouble());
    field->setMaximum(json.value(QStringLiteral("maximum")).toDouble());
    field->setStepSize(json.value(QStringLiteral("stepSize")).toDouble());
    field->setSuffix(json.value(QStringLiteral("suffix")).toString());

    const QString optionSource = json.value(QStringLiteral("optionSource")).toString().trimmed();
    if (optionSource.isEmpty())
        field->setOptions(json.value(QStringLiteral("options")).toArray().toVariantList());
    else if (optionSource != QStringLiteral("timelines"))
        return false;
    return true;
}

DeviceParamSpec *fieldFromJson(const QJsonObject &json,
                               TimelineModel *timelineModel,
                               QObject *parent)
{
    const QString key = json.value(QStringLiteral("key")).toString().trimmed();
    if (key.isEmpty())
        return nullptr;

    const QString optionSource = json.value(QStringLiteral("optionSource")).toString().trimmed();
    DeviceParamSpec *field = optionSource == QStringLiteral("timelines")
        ? DeviceParamSpec::createForKey(DeviceKey::Timeline, timelineModel)
        : (optionSource.isEmpty() ? new DeviceParamSpec(parent) : nullptr);
    if (!field)
        return nullptr;
    if (field->parent() != parent)
        field->setParent(parent);
    field->setKey(key);
    if (!applyFieldSpec(field, json)) {
        delete field;
        return nullptr;
    }
    return field;
}

class SerialCommand final : public DeviceCommand
{
public:
    explicit SerialCommand(QObject *parent)
        : DeviceCommand(DeviceProtocol::Serial, QStringLiteral("串口指令"), parent)
    {
        addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::SerialPort));
        addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::BaudRate));
        addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::SerialPayload));
    }
};

class Dmx512Command final : public DeviceCommand
{
public:
    explicit Dmx512Command(QObject *parent)
        : DeviceCommand(DeviceProtocol::Dmx512, QStringLiteral("DMX指令"), parent)
    {
        addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::Dmx512BitOffset));

        addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::Dmx512BitCount));

        addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::Dmx512CommandBits));
    }
    QVariantMap resolvedParams(const QVariantMap& executionInputValues = QVariantMap()) const override
    {
        auto paramMap = DeviceCommand::resolvedParams(executionInputValues);
        auto bitsStr = paramMap[DeviceKey::Dmx512CommandBits].toString();
        int bitCount = paramMap[DeviceKey::Dmx512BitCount].toInt();
        auto bitStrs = bitsStr.split(",");
        // 补全默认值
        while (bitStrs.size() < bitCount) {
            if (bitStrs.isEmpty() == false) {
                bitStrs << ",";
            }
            bitStrs << "0";
        }
        //
        while (bitStrs.size() > bitCount) {
            bitStrs.takeLast();
        }

        paramMap[DeviceKey::Dmx512CommandBits] = bitStrs.join(",");

        return paramMap;
    }

    QString invalidReason() const override
    {
        const QString reason = DeviceCommand::invalidReason();
        if (!reason.isEmpty())
            return reason;

        const auto *countField = getField(DeviceKey::Dmx512BitCount);
        const auto *dataField = getField(DeviceKey::Dmx512CommandBits);
        if (!countField || !dataField)
            return QStringLiteral("DMX512 指令字段不完整");

        const QString data = dataField->value().toString().trimmed();
        const int actualCount = data.isEmpty()
            ? 0
            : data.split(',', Qt::KeepEmptyParts).size();
        const int expectedCount = countField->value().toInt();
        if (actualCount != expectedCount) {
            return QStringLiteral("指令数据数量应为 %1，当前为 %2")
                .arg(expectedCount)
                .arg(actualCount);
        }

        return QString();
    }

};

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

DeviceCommand* DeviceCommand::createForProtocol(const QString& protocol, QObject* parent)
{
	const QString value = protocol.trimmed();
	if (value == DeviceProtocol::Internal)
		return new DeviceCommand_Internal(parent);
	if (value == DeviceProtocol::Udp)
		return new DeviceCommand_Udp(parent);
	if (value == DeviceProtocol::Http)
		return new DeviceCommand_Http(parent);
	if (value == DeviceProtocol::Pc)
		return new DeviceCommand_PC(parent);
	if (value == DeviceProtocol::Serial)
		return new SerialCommand(parent);
	if (value == DeviceProtocol::Dmx512)
		return new Dmx512Command(parent);

    LOG_ERROR("不支持的指令类型 " << protocol);
	return nullptr;
}

DeviceCommand* DeviceCommand::createFromJson(const QJsonObject& json,
											 QObject* parent,
											 TimelineModel* timelineModel)
{
    if (json.contains(DeviceKey::CommandType)) {
        LOG_ERROR("无法从json创建commandType指令");
		return nullptr;
    }

	DeviceCommand* command = createForProtocol(
		json.value(QString::fromLatin1(kProtocolKey)).toString(), parent);
	if (!command)
		return nullptr;

	const auto loadFields = [command, timelineModel](const QJsonArray& fields,
															  bool executionFields) {
		for (const QJsonValue& value : fields) {
			const QJsonObject fieldJson = value.toObject();
			DeviceParamSpec* field = executionFields
				? nullptr
				: command->getField(fieldJson.value(QStringLiteral("key")).toString());

			if (field) {
				if (!applyFieldSpec(field, fieldJson))
					return false;
				continue;
			}

			field = fieldFromJson(fieldJson, timelineModel, command);
			if (!field)
				return false;

			if (executionFields)
				command->addExecutionInputField(field);
			else
				command->addCreationInputField(field);
		}
		return true;
	};

	if (!loadFields(json.value(QString::fromLatin1(kCreationInputFieldSpecsKey)).toArray(), false)
		|| !loadFields(json.value(QString::fromLatin1(kExecutionInputFieldSpecsKey)).toArray(), true)
		|| !command->loadFromJson(json)) {
		delete command;
		return nullptr;
	}
	return command;
}

QString DeviceCommand::name() const
{
    return getField(DeviceKey::Name)->stringValue();
}

void DeviceCommand::setName(const QString &name)
{
    DeviceParamSpec *field = getField(DeviceKey::Name);
    if (field && !field->readOnly())
        field->setValue(name.trimmed());
}

QString DeviceCommand::protocol() const
{
    return m_protocol;
}

QString DeviceCommand::commandType() const
{
    return m_commandType;
}

Device *DeviceCommand::device() const
{
    return m_device.data();
}

bool DeviceCommand::filteredOut() const
{
    return m_device && m_device->filteredOut();
}

void DeviceCommand::setDevice(Device *device)
{
	if (m_device == device)
		return;

    const bool previousFilteredOut = filteredOut();

	if (m_device) {
		disconnect(m_device, &Device::paramChanged, this, nullptr);
		disconnect(m_device, &Device::filteredOutChanged, this, &DeviceCommand::filteredOutChanged);
	}

	m_device = device;

    if (m_device) {
		connect(m_device, &Device::paramChanged, this, &DeviceCommand::updateParamFromDevice);
		connect(m_device, &Device::filteredOutChanged, this, &DeviceCommand::filteredOutChanged);
		updateParamFromDevice();
    }

	emit deviceChanged();
    if (previousFilteredOut != filteredOut())
        emit filteredOutChanged();
}

DeviceParamSpec* DeviceCommand::getField(const QString& key) const
{
    for (DeviceParamSpec *field : m_creationInputFields) {
        if (field->key() == key)
            return field;
    }
    return nullptr;
}

QString DeviceCommand::invalidReason() const
{
    for (DeviceParamSpec *field : m_creationInputFields) {
        const QString reason = field->invalidReason();
        if (!reason.isEmpty())
            return reason;
    }

    return QString();
}

QJsonObject DeviceCommand::toJson() const
{
    QJsonObject json;

    json.insert(QString::fromLatin1(kProtocolKey), protocol());
    if (!commandType().isEmpty())
        json.insert(DeviceKey::CommandType, commandType());
    if (!m_stringTemplateKey.isEmpty())
        json.insert(QString::fromLatin1(kStringTemplateKey), m_stringTemplateKey);

    QJsonObject creationInputValues;
    const QVariantMap configValues = m_device ? m_device->configValues() : QVariantMap();
    for (DeviceParamSpec *field : m_creationInputFields) {
        if (!configValues.contains(field->key()))
            creationInputValues.insert(field->key(), QJsonValue::fromVariant(field->value()));
    }
    json.insert(QString::fromLatin1(kCreationInputValuesKey), creationInputValues);

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

    m_stringTemplateKey = json.value(QString::fromLatin1(kStringTemplateKey)).toString();

    const QJsonObject creationInputValues = json.value(
        QString::fromLatin1(kCreationInputValuesKey)).toObject();
    const QString jsonName = (creationInputValues.contains(DeviceKey::Name)
                                  ? creationInputValues.value(DeviceKey::Name)
                                  : json.value(DeviceKey::Name)).toString().trimmed();
    DeviceParamSpec *nameField = getField(DeviceKey::Name);
    if (nameField && nameField->readOnly() && jsonName != name())
        return false;

    for (DeviceParamSpec *field : m_creationInputFields) {
        if (field == nameField && field->readOnly())
            continue;
        if (creationInputValues.contains(field->key()))
            field->setValue(creationInputValues.value(field->key()).toVariant());
        else if (json.contains(field->key()))
            field->setValue(json.value(field->key()).toVariant());
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
	QVariantMap params;

	for (DeviceParamSpec* field : m_creationInputFields)
		params.insert(field->key(), field->value());

    // 将Device的、Command不适用的参数也放进入
	if (m_device) {
		const QVariantMap values = m_device->configValues();
		for (auto it = values.cbegin(); it != values.cend(); ++it)
			params.insert(it.key(), it.value());
	}

	for (DeviceParamSpec* field : m_executionInputFields)
		params.insert(field->key(), field->value());

	for (auto it = executionInputValues.cbegin();
		 it != executionInputValues.cend();
		 ++it) {
		params.insert(it.key(), it.value());
	}


    if (params.contains(m_stringTemplateKey)) {
        auto str = params[m_stringTemplateKey].toString();
		
		for (auto it = params.cbegin(); it != params.cend(); ++it) {
            QString k = QString("${%1}").arg(it.key());
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
    return createFromJson(toJson(), parent,
                          TimelineRuntime::getInstance()->timelineManager()->timelineModel());
}

void DeviceCommand::addCreationInputField(DeviceParamSpec *field)
{
    if (!field)
        return;

    if (getField(field->key())) {
        LOG_ERROR("重复添加创建字段 " << field->key());
		return;
    }

    if (field->parent() != this)
        field->setParent(this);

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

QVariantList DeviceCommand::creationMinInputFields() const
{
	QVariantList result;
    const QVariantMap configValues = m_device ? m_device->configValues() : QVariantMap();
    for (DeviceParamSpec *field : m_creationInputFields) {
        if (!configValues.contains(field->key()))
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

void DeviceCommand::updateParamFromDevice()
{
    if (!m_device) {
        return;
    }

	for (DeviceParamSpec* field : m_creationInputFields) {
		if (auto inField = m_device->getParam(field->key())) {
			field->setValue(inField->value());
		}
	}
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
    addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::Payload));
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
    getField(DeviceKey::Port)->setValue(11357);
	getField(DeviceKey::ApiPath)->setRequired(false);
}
