#include "devices/DeviceTemplate.h"
#include "devices/Device.h"
#include "devices/DeviceCommand.h"
#include <QVariant>


DeviceTemplate::DeviceTemplate(const QString &name,
                               const QString &deviceType,
                               const QStringList &supportedProtocols,
                               const QString &description,
                               QList<DeviceParamSpec*> configSpecs,
                               QList<DeviceCommand*> commands,
                               QObject *parent)
    : QObject(parent)
    , m_name(name)
    , m_deviceType(deviceType)
    , m_supportedProtocols(supportedProtocols)
    , m_description(description)
    , m_configSpecs(configSpecs)
    , m_commands(commands)
{
    m_configSpecs.prepend(DeviceParamSpec::createForKey(DeviceKey::Ip));

	for (auto spec : m_configSpecs) {
		spec->setParent(this);
	}
	for (auto cmd : m_commands) {
        cmd->setParent(this);
	}
}

QString DeviceTemplate::name() const
{
    return m_name;
}

QString DeviceTemplate::deviceType() const
{
    return m_deviceType;
}

QStringList DeviceTemplate::supportedProtocols() const
{
    return m_supportedProtocols;
}

QString DeviceTemplate::description() const
{
    return m_description;
}

QVariantList DeviceTemplate::configSpecs() const
{
    QVariantList result;
    result.reserve(m_configSpecs.size());

    for (DeviceParamSpec *configSpec : m_configSpecs)
        result.append(QVariant::fromValue(configSpec));

    return result;
}

QList<DeviceParamSpec *> DeviceTemplate::configSpecObjects() const
{
    return m_configSpecs;
}

Device *DeviceTemplate::createDevice(QObject *parent, const QVariantMap &configValues)
{
    auto *device = new Device(name(), parent);
	device->setDeviceType(deviceType());
    device->setSupportedProtocols(supportedProtocols());
	device->setDescription(description());
    device->setConfigValues(configValues);

    for (auto cmd : m_commands) {
        auto newCmd = cmd->clone(device);
        Q_ASSERT(newCmd);
        device->appendCommand(newCmd);
    }

	return device;
}

SerialPowerDeviceTemplate::SerialPowerDeviceTemplate(QObject* parent /* = nullptr */)
    : DeviceTemplate("串口开关设备",
                     /*DeviceType::Projector*/"",
                     {DeviceProtocol::Serial},
                     "串口开关设备",
                     {DeviceParamSpec::createForKey(DeviceKey::SerialPort),
                     DeviceParamSpec::createForKey(DeviceKey::BaudRate)},
                     {},
                     parent
    )
{
	auto openPayload = DeviceParamSpec::createForKey(DeviceKey::SerialPayload);
	openPayload->setKey("open");
	openPayload->setLabel("开机码");
    openPayload->setParent(this);
    m_configSpecs << openPayload;

	auto closePayload = DeviceParamSpec::createForKey(DeviceKey::SerialPayload);
    closePayload->setKey("close");
    closePayload->setLabel("关机码");
    closePayload->setParent(this);
    m_configSpecs << closePayload;
}

Device * SerialPowerDeviceTemplate::createDevice(QObject *parent, const QVariantMap &configValues)
{
    Device *device = DeviceTemplate::createDevice(parent, configValues);

    {
        DeviceCommand* command = device->createCommand(DeviceProtocol::Serial, QStringLiteral("开机"));
        DeviceParamSpec* payload = command->getField(DeviceKey::SerialPayload);
        payload->setValue(configValues.value(QStringLiteral("open")));
    }
   
    {
		DeviceCommand* command = device->createCommand(DeviceProtocol::Serial, QStringLiteral("关机"));
		DeviceParamSpec* payload = command->getField(DeviceKey::SerialPayload);
		payload->setValue(configValues.value(QStringLiteral("close")));
    }

    return device;
}
