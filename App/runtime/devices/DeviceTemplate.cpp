#include "devices/DeviceTemplate.h"
#include "devices/Device.h"
#include "devices/DeviceCommand.h"
#include <QVariant>

using namespace TimelineControl;

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

Device* DeviceTemplate::createDevice(QObject* parent)
{
    Device* device = new Device(name(), parent);
	device->setDeviceType(deviceType());
    device->setSupportedProtocols(supportedProtocols());
	device->setDescription(description());

    QVariantMap configValues;
    for (auto spec : m_configSpecs) {
        configValues[spec->key()] = spec->value();
    }
    device->setConfigValues(configValues);
    
    for (auto cmd : m_commands) {
        auto newCmd = cmd->clone(device);
        Q_ASSERT(newCmd);
        device->appendCommand(newCmd);
    }

	return device;
}

