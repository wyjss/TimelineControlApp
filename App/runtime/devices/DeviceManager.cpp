#include "devices/DeviceManager.h"

#include <QMetaType>
#include <QSize>

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

QVariantMap option(const QString &label, const QString &value)
{
    return QVariantMap{
        {QStringLiteral("label"), label},
        {QStringLiteral("value"), value}
    };
}

bool isTemplateOnlyDeviceType(const QString &deviceType)
{
    const QString normalizedDeviceType = deviceType.trimmed();
    return normalizedDeviceType.compare(TimelineControl::DeviceType::PC, Qt::CaseInsensitive) == 0
        || normalizedDeviceType.compare(TimelineControl::DeviceType::Dmx512Adapter, Qt::CaseInsensitive) == 0;
}

} // namespace

namespace TimelineControl {

DeviceManager::DeviceManager(QObject *parent)
    : QObject(parent)
{
    qRegisterMetaType<TimelineControl::Device *>("TimelineControl::Device*");
    qRegisterMetaType<TimelineControl::DeviceParamSpec *>("TimelineControl::DeviceParamSpec*");
    qRegisterMetaType<TimelineControl::DeviceTemplate *>("TimelineControl::DeviceTemplate*");

	m_deviceTypes = QStringList{
		DeviceType::PC,
	   DeviceType::Dmx512Adapter,
	   DeviceType::Projector,
	   DeviceType::Light,
	   DeviceType::Sound
	};

    m_deviceTemplates.push_back(createDefaultDeviceTemplatePc());
    m_deviceTemplates.push_back(createDefaultDeviceTemplateDmx512Adapter());
    m_deviceTemplates.push_back(createDefaultDeviceTemplateDmx512());
    m_deviceTemplates.push_back(createDefaultDeviceTemplateHttp());
    m_deviceTemplates.push_back(createDefaultDeviceTemplateSerial());
    m_deviceTemplates.push_back(createDefaultDeviceTemplateOsc());

    QVariantMap pc1x1Config;
    pc1x1Config.insert(DeviceKey::Ip, QStringLiteral("127.0.0.1"));
    pc1x1Config.insert(DeviceKey::ScreenSize, QSize(1920, 1080));
    pc1x1Config.insert(DeviceKey::ScreenLayout, QSize(1, 1));
    m_devices.push_back(makeDeviceFromTemplate(QStringLiteral("test-pc-1x1"),
                                               tr("电脑"),
                                               DeviceType::PC,
                                               tr("测试PC 1x1"),
                                               QStringLiteral("127.0.0.1"),
                                               tr("Online"),
                                               tr("Local test"),
                                               pc1x1Config));

    QVariantMap pc2x2Config;
    pc2x2Config.insert(DeviceKey::Ip, QStringLiteral("127.0.0.1"));
    pc2x2Config.insert(DeviceKey::ScreenSize, QSize(1920, 1080));
    pc2x2Config.insert(DeviceKey::ScreenLayout, QSize(2, 2));
    m_devices.push_back(makeDeviceFromTemplate(QStringLiteral("test-pc-2x2"),
                                               tr("电脑"),
                                               DeviceType::PC,
                                               tr("测试PC 2x2"),
                                               QStringLiteral("127.0.0.1"),
                                               tr("Online"),
                                               tr("Local test"),
                                               pc2x2Config));
    m_currentDeviceId = QStringLiteral("test-pc-1x1");

    refreshDmx512AdapterOptions();

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
		spec->setRequired(true);
        spec->setPlaceholderText(QStringLiteral("192.168.1.10"));
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

    auto pc = new DeviceTemplate(tr("电脑"),
                                 DeviceType::PC,
                                 DeviceProtocol::Pc,
                                 tr("电脑设备"),
                                 specs);
    return pc;
}

DeviceTemplate* DeviceManager::createDefaultDeviceTemplateDmx512Adapter() const
{
	QList<DeviceParamSpec*> specs;
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
		spec->setRequired(true);
		spec->setOptions(opts);
		specs.push_back(spec);
	}

	auto dt = new DeviceTemplate(tr("Dmx512适配器"),
                                 DeviceType::Dmx512Adapter,
								 DeviceProtocol::Dmx512,
								 tr("Dmx512适配器"),
								 specs);
	return dt;
}

DeviceTemplate* DeviceManager::createDefaultDeviceTemplateDmx512() const
{
	QList<DeviceParamSpec*> specs;
    {
        auto spec = new DeviceParamSpec(
            DeviceKey::Dmx512AdapterDeviceId,
            "目标Dmx512适配器",
            "",
            DeviceParamSpec::SelectType,
            DeviceParamSpec::SelectEditor
        );
        spec->setRequired(true);
        specs.push_back(spec);
    }
// 	{// ip
// 		auto spec = new DeviceParamSpec(
// 			DeviceKey::Ip,
// 			"ip",
// 			"",
// 			DeviceParamSpec::StringType
// 		);
// 		spec->setPattern(DevicePattern::Ip);
// 		spec->setRequired(true);
//         spec->setPlaceholderText(QStringLiteral("192.168.1.10"));
// 		specs.push_back(spec);
// 	}
// 	
// 	{// 端口
//         QVariantList opts;
//         for (int i = 0; i < 10; ++i) {
//             opts.push_back(QString("COM%1").arg(i));
//         }
// 		auto spec = new DeviceParamSpec(
// 			DeviceKey::SerialPort,
// 			"适配器串口",
// 			"COM0",
// 			DeviceParamSpec::SelectType,
// 			DeviceParamSpec::SelectEditor
// 		);
//         spec->setRequired(true);
//         spec->setOptions(opts);
// 		specs.push_back(spec);
// 	}

    auto dt = new DeviceTemplate(tr("Dmx512协议"),
                                 "",
                                 DeviceProtocol::Dmx512,
                                 tr("Dmx512协议设备"),
                                 specs);
	return dt;
}

DeviceTemplate* DeviceManager::createDefaultDeviceTemplateHttp() const
{
    QList<DeviceParamSpec*> specs;
    {
        auto spec = new DeviceParamSpec(
            DeviceKey::Address,
            "HTTP地址",
            "",
            DeviceParamSpec::StringType,
            DeviceParamSpec::TextEditor
        );
        spec->setPattern(DevicePattern::HttpAddress);
        spec->setRequired(true);
        spec->setPlaceholderText(QStringLiteral("http://192.168.1.10:8080"));
        specs.push_back(spec);
    }

    auto dt = new DeviceTemplate(tr("HTTP协议"),
                                 QString(),
                                 DeviceProtocol::Http,
                                 tr("HTTP协议设备"),
                                 specs);
    return dt;
}

DeviceTemplate* DeviceManager::createDefaultDeviceTemplateSerial() const
{
    QList<DeviceParamSpec*> specs;
    {
        QVariantList opts;
        for (int i = 0; i < 10; ++i) {
            opts.push_back(QString("COM%1").arg(i));
        }
        auto spec = new DeviceParamSpec(
            DeviceKey::SerialPort,
            "串口",
            "COM0",
            DeviceParamSpec::SelectType,
            DeviceParamSpec::SelectEditor
        );
        spec->setRequired(true);
        spec->setOptions(opts);
        specs.push_back(spec);
    }

    {
        auto spec = new DeviceParamSpec(
            DeviceKey::BaudRate,
            "波特率",
            9600,
            DeviceParamSpec::IntType,
            DeviceParamSpec::SelectEditor
        );
        spec->setRequired(true);
        spec->setOptions(QVariantList{9600, 19200, 38400, 57600, 115200});
        specs.push_back(spec);
    }

    auto dt = new DeviceTemplate(tr("串口协议"),
                                 QString(),
                                 DeviceProtocol::Serial,
                                 tr("串口协议设备"),
                                 specs);
    return dt;
}

DeviceTemplate* DeviceManager::createDefaultDeviceTemplateOsc() const
{
    QList<DeviceParamSpec*> specs;
    {
        auto spec = new DeviceParamSpec(
            DeviceKey::Ip,
            "ip",
            "",
            DeviceParamSpec::StringType,
            DeviceParamSpec::TextEditor
        );
        spec->setPattern(DevicePattern::Ip);
        spec->setRequired(true);
        spec->setPlaceholderText(QStringLiteral("192.168.1.10"));
        specs.push_back(spec);
    }

    {
        auto spec = new DeviceParamSpec(
            DeviceKey::Port,
            "端口",
            8000,
            DeviceParamSpec::IntType,
            DeviceParamSpec::TextEditor
        );
        spec->setRequired(true);
        spec->setMinimum(1);
        spec->setMaximum(65535);
        specs.push_back(spec);
    }

    auto dt = new DeviceTemplate(tr("OSC协议"),
                                 QString(),
                                 DeviceProtocol::Osc,
                                 tr("OSC协议设备"),
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

QStringList DeviceManager::deviceTypes() const
{
    return m_deviceTypes;
}

QStringList DeviceManager::manualDeviceTypes() const
{
    QStringList result;
    for (const QString &deviceType : m_deviceTypes) {
        if (!isTemplateOnlyDeviceType(deviceType))
            result.append(deviceType);
    }

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
    createDeviceFromTemplate(tr("Dmx512协议"), QVariantMap(), QString(), DeviceType::Light);
}

QVariantList DeviceManager::devicesForDeviceType(const QString &deviceType) const
{
    QVariantList result;

    for (Device *candidate : m_devices) {
        if (deviceMatchesDeviceType(candidate, deviceType))
            result.append(QVariant::fromValue(candidate));
    }

    return result;
}

QString DeviceManager::validateDeviceCreation(const QString &deviceType,
                                              const QString &deviceName,
                                              const QString &templateName) const
{
    const QString normalizedDeviceType = deviceType.trimmed();
    if (normalizedDeviceType.isEmpty())
        return tr("Device type is required");

    const QString normalizedDeviceName = deviceName.trimmed();
    if (normalizedDeviceName.isEmpty())
        return tr("Device name is required");

    DeviceTemplate *sourceTemplate = deviceTemplate(templateName);
    if (sourceTemplate) {
        const QString templateDeviceType = sourceTemplate->deviceType().trimmed();
        if (templateDeviceType.isEmpty() && isTemplateOnlyDeviceType(normalizedDeviceType))
            return tr("This device type can only be created from its template");

        if (!templateDeviceType.isEmpty()
            && templateDeviceType.compare(normalizedDeviceType, Qt::CaseInsensitive) != 0) {
            return tr("Device type is fixed by template");
        }
    }

    for (Device *candidate : m_devices) {
        if (!candidate)
            continue;

        if (candidate->deviceType().trimmed().compare(normalizedDeviceType, Qt::CaseInsensitive) != 0)
            continue;

        if (candidate->name().trimmed().compare(normalizedDeviceName, Qt::CaseInsensitive) == 0)
            return tr("Device name already exists in this type");
    }

    return QString();
}

bool DeviceManager::createDeviceFromTemplate(const QString &templateName,
                                             const QVariantMap &configValues,
                                             const QString &deviceName,
                                             const QString &deviceType)
{
    DeviceTemplate *selectedTemplate = deviceTemplate(templateName);
    if (!selectedTemplate)
        return false;

    const QString templateDeviceType = selectedTemplate->deviceType().trimmed();
    const QString resolvedDeviceType = templateDeviceType.isEmpty()
        ? deviceType.trimmed()
        : templateDeviceType;
    const QString resolvedDeviceName = deviceName.trimmed().isEmpty()
        ? tr("New %1").arg(selectedTemplate->name())
        : deviceName.trimmed();

    if (!validateDeviceCreation(resolvedDeviceType, resolvedDeviceName, selectedTemplate->name()).isEmpty())
        return false;

    const QString id = QStringLiteral("device-%1").arg(m_nextDeviceNumber++);
    QVariantMap resolvedConfigValues = defaultConfigValues(selectedTemplate);
    for (auto it = configValues.cbegin(); it != configValues.cend(); ++it) {
        if (!it.key().trimmed().isEmpty())
            resolvedConfigValues.insert(it.key(), it.value());
    }

    QString address = resolvedConfigValues.value(DeviceKey::Address).toString().trimmed();
    if (address.isEmpty()) {
        const QString ip = resolvedConfigValues.value(DeviceKey::Ip).toString().trimmed();
        const QString port = resolvedConfigValues.value(DeviceKey::Port).toString().trimmed();
        if (!ip.isEmpty() && !port.isEmpty())
            address = QStringLiteral("%1:%2").arg(ip, port);
        else
            address = ip;
    }
    if (address.isEmpty())
        address = resolvedConfigValues.value(DeviceKey::SerialPort).toString().trimmed();
    if (address.isEmpty()) {
        Device *adapter = device(resolvedConfigValues.value(DeviceKey::Dmx512AdapterDeviceId).toString());
        if (adapter) {
            address = adapter->address().trimmed();
            if (address.isEmpty())
                address = adapter->name().trimmed();
        }
    }
    if (address.isEmpty())
        address = tr("Unassigned");

    Device *newDevice = makeDeviceFromTemplate(id,
                                               selectedTemplate->name(),
                                               resolvedDeviceType,
                                               resolvedDeviceName,
                                               address,
                                               tr("Offline"),
                                               tr("Never"),
                                               resolvedConfigValues);
    if (!newDevice)
        return false;

    m_devices.append(newDevice);
    addDeviceType(resolvedDeviceType);
    refreshDmx512AdapterOptions();
    emit devicesChanged();
    setCurrentDeviceId(id);
    return true;
}

void DeviceManager::addDeviceType(const QString &deviceType)
{
    const QString normalizedDeviceType = deviceType.trimmed();
    if (normalizedDeviceType.isEmpty() || m_deviceTypes.contains(normalizedDeviceType))
        return;

    m_deviceTypes.append(normalizedDeviceType);
    emit deviceTypesChanged();
}

void DeviceManager::removeDeviceType(const QString &deviceType)
{
    const QString normalizedDeviceType = deviceType.trimmed();
    if (normalizedDeviceType.isEmpty() || !m_deviceTypes.contains(normalizedDeviceType))
        return;

    m_deviceTypes.removeAll(normalizedDeviceType);
    emit deviceTypesChanged();
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

bool DeviceManager::deviceMatchesDeviceType(const Device *device, const QString &deviceType) const
{
    if (!device)
        return false;

    return device->deviceType().trimmed() == deviceType.trimmed();
}

QVariantList DeviceManager::deviceOptionsForDeviceType(const QString &deviceType) const
{
    QVariantList result;

    for (Device *candidate : m_devices) {
        if (!deviceMatchesDeviceType(candidate, deviceType))
            continue;

        QString label = candidate->name().trimmed();
        if (label.isEmpty())
            label = candidate->id();

        const QString address = candidate->address().trimmed();
        if (!address.isEmpty())
            label = QStringLiteral("%1 (%2)").arg(label, address);

        result.append(option(label, candidate->id()));
    }

    return result;
}

DeviceTemplate *DeviceManager::deviceTemplate(const QString &templateName) const
{
    const QString normalizedTemplateName = templateName.trimmed();
    for (DeviceTemplate *deviceTemplate : m_deviceTemplates) {
        if (deviceTemplate && deviceTemplate->name() == normalizedTemplateName)
            return deviceTemplate;
    }

    return nullptr;
}

void DeviceManager::refreshDmx512AdapterOptions()
{
    const QVariantList adapterOptions = deviceOptionsForDeviceType(DeviceType::Dmx512Adapter);

    for (DeviceTemplate *deviceTemplate : m_deviceTemplates) {
        if (!deviceTemplate)
            continue;

        for (DeviceParamSpec *configSpec : deviceTemplate->configSpecObjects()) {
            if (configSpec && configSpec->key() == DeviceKey::Dmx512AdapterDeviceId)
                configSpec->setOptions(adapterOptions);
        }
    }
}

DeviceTemplate *DeviceManager::makeDeviceTemplate(const QString &name,
                                                  const QString &deviceType,
                                                  const QString &protocol,
                                                  const QString &description,
                                                  const QList<DeviceParamSpec *> &configSpecs)
{
    return new DeviceTemplate(name, deviceType, protocol, description, configSpecs, this);
}

Device *DeviceManager::makeDeviceFromTemplate(const QString &id,
                                              const QString &templateName,
                                              const QString &deviceType,
                                              const QString &name,
                                              const QString &address,
                                              const QString &status,
                                              const QString &lastSeen,
                                              const QVariantMap &configValues)
{
    DeviceTemplate *sourceTemplate = deviceTemplate(templateName);
    if (!sourceTemplate)
        return nullptr;

    auto *device = new Device(id, sourceTemplate->name(), this);
    device->setDeviceType(deviceType);
    device->setName(name);
    device->setProtocol(sourceTemplate->protocol());
    device->setAddress(address);
    device->setStatus(status);
    device->setLastSeen(lastSeen);
    device->setCapabilities(sourceTemplate->description());

    QVariantMap deviceConfigValues = configValues;
    if (!address.isEmpty())
        deviceConfigValues.insert(DeviceKey::Address, address);

    device->setConfigValues(deviceConfigValues);
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
