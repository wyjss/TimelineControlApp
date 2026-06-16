#include "devices/DeviceManager.h"

#include <QMetaType>

#include "devices/DeviceConstants.h"
#include "devices/Device.h"
#include "devices/DeviceParamSpec.h"
#include "devices/DeviceTemplate.h"

namespace {

TimelineControl::DeviceParamSpec *makeConfigSpec(const QString &key,
                                                 const QString &label,
                                                 const QVariant &value,
                                                 TimelineControl::DeviceParamSpec::ValueType valueType = TimelineControl::DeviceParamSpec::VariantType,
                                                 bool required = false,
                                                 TimelineControl::DeviceParamSpec::EditorHint editorHint = TimelineControl::DeviceParamSpec::AutoEditor)
{
    auto *param = new TimelineControl::DeviceParamSpec(key, label, value, valueType, editorHint);
    param->setRequired(required);
    return param;
}

TimelineControl::DeviceParamSpec *withRange(TimelineControl::DeviceParamSpec *param, double minimum, double maximum)
{
    if (!param)
        return nullptr;

    param->setMinimum(minimum);
    param->setMaximum(maximum);
    return param;
}

TimelineControl::DeviceParamSpec *withOptions(TimelineControl::DeviceParamSpec *param, const QVariantList &options)
{
    if (param)
        param->setOptions(options);
    return param;
}

TimelineControl::DeviceParamSpec* createSerialPortSpec()
{
	TimelineControl::DeviceParamSpec* param = new TimelineControl::DeviceParamSpec;
    param->setKey(TimelineControl::DeviceKey::SerialPort);
	param->setLabel("串口");
	param->setValueType(TimelineControl::DeviceParamSpec::StringType);
    QVariantList opts;
    for (int i = 0; i < 9; ++i) {
        opts << QString("COM%1").arg(i);
    }
    param->setOptions(opts);
    param->setDefaultValue(opts[0]);
	return param;
}

TimelineControl::DeviceParamSpec* createSerialPortAddressSpec(const QString& key, const QString& label)
{
	TimelineControl::DeviceParamSpec* param = new TimelineControl::DeviceParamSpec;
    param->setKey(TimelineControl::DeviceKey::Ip);
	param->setLabel("ip地址");
	param->setSuffix("自身或接入PC");
	param->setValueType(TimelineControl::DeviceParamSpec::StringType);
	param->setPattern(R"(^(?:$|\\\\(?:localhost|\d{1,3}(?:\.\d{1,3}){3})(?:\\|$)))");
	return param;
}

TimelineControl::DeviceParamSpec* makeIpSpec()
{
    TimelineControl::DeviceParamSpec* param = new TimelineControl::DeviceParamSpec;
    param->setKey(TimelineControl::DeviceKey::Ip);
    param->setLabel("ip地址");
    param->setSuffix("自身或接入PC");
    param->setValueType(TimelineControl::DeviceParamSpec::StringType);
    param->setPattern(R"(^(?:$|\\\\(?:localhost|\d{1,3}(?:\.\d{1,3}){3})(?:\\|$)))");
    return param;
}

} // namespace

namespace TimelineControl {

DeviceManager::DeviceManager(QObject *parent)
    : QObject(parent)
{
    qRegisterMetaType<TimelineControl::Device *>("TimelineControl::Device*");
    qRegisterMetaType<TimelineControl::DeviceParamSpec *>("TimelineControl::DeviceParamSpec*");
    qRegisterMetaType<TimelineControl::DeviceTemplate *>("TimelineControl::DeviceTemplate*");

    m_deviceTemplates.push_back(createDefaultDeviceTemplatePc());
    m_deviceTemplates.push_back(createDefaultDeviceTemplateDmx512());
	m_deviceTemplates += makeDeviceTemplate(DeviceTemplateId::Display,
											tr("显示设备"),
											DeviceProtocol::Null,
											tr(""),
											{});
	m_deviceTemplates += makeDeviceTemplate(DeviceTemplateId::Lighting,
											tr("灯光"),
											DeviceProtocol::Null,
											tr(""),
											{});
	m_deviceTemplates += makeDeviceTemplate(DeviceTemplateId::AudioMixer,
											tr("音响"),
											DeviceProtocol::Null,
											tr(""),
											{});
	m_deviceTemplates += makeDeviceTemplate(DeviceTemplateId::PtzCamera,
											tr("云台相机"),
											DeviceProtocol::Null,
											tr(""),
											{});
	m_deviceTemplates += makeDeviceTemplate(DeviceTemplateId::RelayController,
											tr("延迟控制器"),
											DeviceProtocol::Null,
											tr(""),
											{});

//     m_devices = QList<Device *>{
//         makeDeviceFromTemplate(QStringLiteral("lighting-group"),
//                                DeviceTemplateId::Lighting,
//                                tr("Lighting Group"),
//                                tr("Universe 1 / Channel 001"),
//                                tr("Online"),
//                                tr("2s ago")),
//         makeDeviceFromTemplate(QStringLiteral("ptz-01"),
//                                DeviceTemplateId::PtzCamera,
//                                tr("PTZ-01"),
//                                QStringLiteral("192.168.10.41:52381"),
//                                tr("Online"),
//                                tr("8s ago")),
//         makeDeviceFromTemplate(QStringLiteral("mixer"),
//                                DeviceTemplateId::AudioMixer,
//                                tr("Mixer"),
//                                QStringLiteral("/mixer/main"),
//                                tr("Standby"),
//                                tr("1m ago")),
//         makeDeviceFromTemplate(QStringLiteral("relay-rack"),
//                                DeviceTemplateId::RelayController,
//                                tr("Relay Rack"),
//                                tr("Unit 4 / Coil 12"),
//                                tr("Offline"),
//                                tr("18m ago"))
//     };

    m_currentDeviceId = QStringLiteral("lighting-group");
}

DeviceTemplate* DeviceManager::createDefaultDeviceTemplatePc() const
{
	QList<DeviceParamSpec*> specs;
	{// ip
		auto spec = new DeviceParamSpec(
			DeviceKey::Ip,
			"ip",
			"",
			DeviceParamSpec::StringType
		);
		spec->setPattern(DevicePattern::Ip);
		specs.push_back(spec);
	}
	{// 分辨率
		auto spec = new DeviceParamSpec(
			DeviceKey::ScreenSize,
			"单屏分辨率",
			QSize(),
			DeviceParamSpec::SizeType,
			DeviceParamSpec::SizeEditor
		);
		specs.push_back(spec);
	}
	{// 屏幕布局
		auto spec = new DeviceParamSpec(
			DeviceKey::ScreenLayout,
			"屏幕布局",
			QSize(1, 1),
			DeviceParamSpec::SizeType,
			DeviceParamSpec::SizeEditor
		);
		specs.push_back(spec);
	}

	auto pc = new DeviceTemplate(DeviceTemplateId::Pc,
								 tr("电脑"),
								 DeviceProtocol::Pc,
								 tr("电脑设备"),
								 specs);
    return pc;
}

DeviceTemplate* DeviceManager::createDefaultDeviceTemplateDmx512() const
{
	QList<DeviceParamSpec*> specs;
	{// ip
		auto spec = new DeviceParamSpec(
			DeviceKey::Ip,
			"ip",
			"",
			DeviceParamSpec::StringType
		);
		spec->setPattern(DevicePattern::Ip);
		specs.push_back(spec);
	}
	
	{// 端口
        QVariantList opts;
        for (int i = 0; i < 10; ++i) {
            opts.push_back(QString("COM%1").arg(i));
        }
		auto spec = new DeviceParamSpec(
			DeviceKey::SerialPort,
			"适配器串口",
			"COM0",
			DeviceParamSpec::SelectType,
			DeviceParamSpec::SelectEditor
		);
		specs.push_back(spec);
	}

	auto dt = new DeviceTemplate(DeviceTemplateId::Dmx512,
								 tr("Dmx512"),
								 DeviceProtocol::Dmx,
								 tr("Dmx512"),
								 specs);
	return dt;
}

QVariantList DeviceManager::devices() const
{
    QVariantList result;
    result.reserve(m_devices.size());

    for (Device *device : m_devices)
        result.append(QVariant::fromValue(device));

    return result;
}

QVariantList DeviceManager::deviceTemplates() const
{
    QVariantList result;
    result.reserve(m_deviceTemplates.size());

    for (DeviceTemplate *deviceTemplate : m_deviceTemplates)
        result.append(QVariant::fromValue(deviceTemplate));

    return result;
}

QString DeviceManager::currentDeviceId() const
{
    return m_currentDeviceId;
}

void DeviceManager::setCurrentDeviceId(const QString &deviceId)
{
    const QString normalizedDeviceId = deviceId.trimmed();
    if (normalizedDeviceId.isEmpty() || !device(normalizedDeviceId))
        return;

    if (m_currentDeviceId == normalizedDeviceId)
        return;

    m_currentDeviceId = normalizedDeviceId;
    emit currentDeviceIdChanged();
    emit currentDeviceChanged();
}

Device *DeviceManager::currentDevice() const
{
    return device(m_currentDeviceId);
}

void DeviceManager::selectDevice(const QString &deviceId)
{
    setCurrentDeviceId(deviceId);
}

void DeviceManager::createDevice()
{
    createDeviceFromTemplate(DeviceTemplateId::Dmx512);
}

void DeviceManager::createDeviceFromTemplate(const QString &templateId)
{
    DeviceTemplate *selectedTemplate = deviceTemplate(templateId);
    if (!selectedTemplate)
        return;

    const QString id = QStringLiteral("device-%1").arg(m_nextDeviceNumber++);
    const QVariantMap configValues = defaultConfigValues(selectedTemplate);
    const QString address = configValues.value(DeviceKey::Address, tr("Unassigned")).toString();

    Device *newDevice = makeDeviceFromTemplate(id,
                                               selectedTemplate->id(),
                                               tr("New %1").arg(selectedTemplate->name()),
                                               address,
                                               tr("Offline"),
                                               tr("Never"));
    m_devices.append(newDevice);
    emit devicesChanged();
    setCurrentDeviceId(id);
}

void DeviceManager::updateCurrentDeviceField(const QString &field, const QVariant &value)
{
    const QString normalizedField = field.trimmed();
    if (normalizedField.isEmpty())
        return;

    Device *current = currentDevice();
    if (!current)
        return;

    if (current->property(normalizedField.toUtf8().constData()) == value)
        return;

    current->setProperty(normalizedField.toUtf8().constData(), value);
}

Device *DeviceManager::device(const QString &deviceId) const
{
    const QString normalizedDeviceId = deviceId.trimmed();
    for (Device *device : m_devices) {
        if (device && device->id() == normalizedDeviceId)
            return device;
    }

    return nullptr;
}

DeviceTemplate *DeviceManager::deviceTemplate(const QString &templateId) const
{
    const QString normalizedTemplateId = templateId.trimmed();
    for (DeviceTemplate *deviceTemplate : m_deviceTemplates) {
        if (deviceTemplate && deviceTemplate->id() == normalizedTemplateId)
            return deviceTemplate;
    }

    return nullptr;
}

DeviceTemplate *DeviceManager::makeDeviceTemplate(const QString &id,
                                                  const QString &name,
                                                  const QString &protocol,
                                                  const QString &description,
                                                  const QList<DeviceParamSpec *> &configSpecs)
{
    return new DeviceTemplate(id, name, protocol, description, configSpecs, this);
}

Device *DeviceManager::makeDeviceFromTemplate(const QString &id,
                                              const QString &templateId,
                                              const QString &name,
                                              const QString &address,
                                              const QString &status,
                                              const QString &lastSeen)
{
    DeviceTemplate *sourceTemplate = deviceTemplate(templateId);

    auto *device = new Device(id, sourceTemplate->id(), this);
    device->setName(name);
    device->setProtocol(sourceTemplate->protocol());
    device->setAddress(address);
    device->setStatus(status);
    device->setLastSeen(lastSeen);
    device->setCapabilities(sourceTemplate->description());

    QVariantMap configValues = defaultConfigValues(sourceTemplate);
    if (!address.isEmpty())
        configValues.insert(DeviceKey::Address, address);

    device->setConfigValues(configValues);
    return device;
}

QVariantMap DeviceManager::defaultConfigValues(const DeviceTemplate *deviceTemplate) const
{
    QVariantMap result;

    for (DeviceParamSpec *configSpec : deviceTemplate->configSpecObjects()) {
        if (configSpec && !configSpec->key().isEmpty())
            result.insert(configSpec->key(), configSpec->defaultValue());
    }

    return result;
}

} // namespace TimelineControl
