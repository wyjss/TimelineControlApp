#include "devices/DeviceManager.h"

#include <QMetaType>

#include "devices/Device.h"
#include "devices/DeviceCommandTemplate.h"
#include "devices/DeviceParamSpec.h"
#include "devices/DeviceTemplate.h"

namespace {

TimelineControl::DeviceParamSpec *makeParamSpec(const QString &key,
                                                const QString &label,
                                                TimelineControl::DeviceParamSpec::ValueType valueType,
                                                const QVariant &defaultValue,
                                                const QVariantMap &constraints = QVariantMap())
{
    return new TimelineControl::DeviceParamSpec(key, label, valueType, defaultValue, false, constraints);
}

TimelineControl::DeviceParamSpec *makeConfigSpec(const QString &key,
                                                 const QString &label,
                                                 TimelineControl::DeviceParamSpec::ValueType valueType,
                                                 const QVariant &defaultValue,
                                                 bool required = false,
                                                 const QVariantMap &constraints = QVariantMap())
{
    return new TimelineControl::DeviceParamSpec(key, label, valueType, defaultValue, required, constraints);
}

TimelineControl::DeviceCommandTemplate *makeCommandTemplate(const QString &id,
                                                            const QString &name,
                                                            const QString &action,
                                                            const QList<TimelineControl::DeviceParamSpec *> &params = QList<TimelineControl::DeviceParamSpec *>())
{
    return new TimelineControl::DeviceCommandTemplate(id, name, action, params);
}

TimelineControl::DeviceParamSpec* createSerialPortSpec()
{
	TimelineControl::DeviceParamSpec* param = new TimelineControl::DeviceParamSpec;
	param->setKey("serialPort");
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
	param->setKey("ip");
	param->setLabel("ip地址");
	param->setSuffix("自身或接入PC");
	param->setValueType(TimelineControl::DeviceParamSpec::StringType);
	param->setPattern(R"(^(?:$|\\\\(?:localhost|\d{1,3}(?:\.\d{1,3}){3})(?:\\|$)))");
	return param;
}

TimelineControl::DeviceParamSpec* makeIpSpec()
{
    TimelineControl::DeviceParamSpec* param = new TimelineControl::DeviceParamSpec;
    param->setKey("ip");
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
    qRegisterMetaType<TimelineControl::DeviceCommandTemplate *>("TimelineControl::DeviceCommandTemplate*");
    qRegisterMetaType<TimelineControl::DeviceParamSpec *>("TimelineControl::DeviceParamSpec*");
    qRegisterMetaType<TimelineControl::DeviceTemplate *>("TimelineControl::DeviceTemplate*");

    {
        
    }
    {
        auto projector = new DeviceTemplate("串口投影机",
                                            "投影机",
                                            "ser",
                                            "",
                                            {makeParamSpec("k", "l", DeviceParamSpec::StringType, "1234")}, {});
        m_deviceTemplates.push_back(projector);
    }

    m_deviceTemplates += QList<DeviceTemplate *>{
        makeDeviceTemplate(QStringLiteral("dmx-light-group"),
                           tr("DMX Light Group"),
                           QStringLiteral("DMX"),
                           tr("Dimmer, color, strobe"),
                           QList<DeviceParamSpec *>{},
                           QList<DeviceCommandTemplate *>{
                               makeCommandTemplate(QStringLiteral("set-intensity"),
                                                   tr("Set Intensity"),
                                                   QStringLiteral("dmx.setIntensity"),
                                                   QList<DeviceParamSpec *>{
                                                       makeParamSpec(QStringLiteral("intensity"),
                                                                     tr("Intensity"),
                                                                     DeviceParamSpec::IntType,
                                                                     80,
                                                                     QVariantMap{
                                                                         {QStringLiteral("min"), 0},
                                                                         {QStringLiteral("max"), 100},
                                                                         {QStringLiteral("unit"), QStringLiteral("%")}
                                                                     }),
                                                       makeParamSpec(QStringLiteral("fadeMs"),
                                                                     tr("Fade"),
                                                                     DeviceParamSpec::IntType,
                                                                     500,
                                                                     QVariantMap{
                                                                         {QStringLiteral("min"), 0},
                                                                         {QStringLiteral("max"), 10000},
                                                                         {QStringLiteral("unit"), QStringLiteral("ms")}
                                                                     })
                                                   }),
                               makeCommandTemplate(QStringLiteral("set-color"),
                                                   tr("Set Color"),
                                                   QStringLiteral("dmx.setColor"),
                                                   QList<DeviceParamSpec *>{
                                                       makeParamSpec(QStringLiteral("red"), tr("Red"), DeviceParamSpec::IntType, 255),
                                                       makeParamSpec(QStringLiteral("green"), tr("Green"), DeviceParamSpec::IntType, 255),
                                                       makeParamSpec(QStringLiteral("blue"), tr("Blue"), DeviceParamSpec::IntType, 255)
                                                   }),
                               makeCommandTemplate(QStringLiteral("strobe"),
                                                   tr("Strobe"),
                                                   QStringLiteral("dmx.strobe"),
                                                   QList<DeviceParamSpec *>{
                                                       makeParamSpec(QStringLiteral("rate"), tr("Rate"), DeviceParamSpec::IntType, 8),
                                                       makeParamSpec(QStringLiteral("durationMs"), tr("Duration"), DeviceParamSpec::IntType, 1000)
                                                   })
                           }),
        makeDeviceTemplate(QStringLiteral("screen-device"),
                           tr("Screen Device"),
                           QStringLiteral("HTTP"),
                           tr("Content, brightness, blank"),
                           QList<DeviceParamSpec *>{
                               makeConfigSpec(QStringLiteral("address"),
                                              tr("Address"),
                                              DeviceParamSpec::StringType,
                                              QStringLiteral("192.168.10.60"),
                                              true),
                               makeConfigSpec(QStringLiteral("resolution"),
                                              tr("Resolution"),
                                              DeviceParamSpec::SelectType,
                                              QStringLiteral("1920x1080"),
                                              true,
                                              QVariantMap{
                                                  {QStringLiteral("options"),
                                                   QVariantList{
                                                       QVariantMap{{QStringLiteral("label"), QStringLiteral("1920x1080")}, {QStringLiteral("value"), QStringLiteral("1920x1080")}},
                                                       QVariantMap{{QStringLiteral("label"), QStringLiteral("3840x2160")}, {QStringLiteral("value"), QStringLiteral("3840x2160")}}
                                                   }}
                                              }),
                               makeConfigSpec(QStringLiteral("port"),
                                              tr("Port"),
                                              DeviceParamSpec::IntType,
                                              80,
                                              true,
                                              QVariantMap{
                                                  {QStringLiteral("min"), 1},
                                                  {QStringLiteral("max"), 65535}
                                              })
                           },
                           QList<DeviceCommandTemplate *>{
                               makeCommandTemplate(QStringLiteral("show-content"),
                                                   tr("Show Content"),
                                                   QStringLiteral("screen.showContent"),
                                                   QList<DeviceParamSpec *>{
                                                       makeParamSpec(QStringLiteral("source"), tr("Source"), DeviceParamSpec::StringType, tr("Main")),
                                                       makeParamSpec(QStringLiteral("durationMs"), tr("Duration"), DeviceParamSpec::IntType, 0)
                                                   }),
                               makeCommandTemplate(QStringLiteral("set-brightness"),
                                                   tr("Set Brightness"),
                                                   QStringLiteral("screen.setBrightness"),
                                                   QList<DeviceParamSpec *>{
                                                       makeParamSpec(QStringLiteral("brightness"),
                                                                     tr("Brightness"),
                                                                     DeviceParamSpec::IntType,
                                                                     80,
                                                                     QVariantMap{
                                                                         {QStringLiteral("min"), 0},
                                                                         {QStringLiteral("max"), 100},
                                                                         {QStringLiteral("unit"), QStringLiteral("%")}
                                                                     })
                                                   }),
                               makeCommandTemplate(QStringLiteral("blank"),
                                                   tr("Blank"),
                                                   QStringLiteral("screen.blank"))
                           }),
        makeDeviceTemplate(QStringLiteral("visca-ptz-camera"),
                           tr("VISCA PTZ Camera"),
                           QStringLiteral("VISCA"),
                           tr("Pan, tilt, zoom, preset"),
                           QList<DeviceParamSpec *>{
                               makeConfigSpec(QStringLiteral("address"),
                                              tr("Address"),
                                              DeviceParamSpec::StringType,
                                              QStringLiteral("192.168.10.41:52381"),
                                              true)
                           },
                           QList<DeviceCommandTemplate *>{
                               makeCommandTemplate(QStringLiteral("move-camera"),
                                                   tr("Move Camera"),
                                                   QStringLiteral("visca.move"),
                                                   QList<DeviceParamSpec *>{
                                                       makeParamSpec(QStringLiteral("pan"), tr("Pan"), DeviceParamSpec::DoubleType, 0.0),
                                                       makeParamSpec(QStringLiteral("tilt"), tr("Tilt"), DeviceParamSpec::DoubleType, 0.0),
                                                       makeParamSpec(QStringLiteral("zoom"), tr("Zoom"), DeviceParamSpec::DoubleType, 1.0),
                                                       makeParamSpec(QStringLiteral("speed"), tr("Speed"), DeviceParamSpec::IntType, 5)
                                                   }),
                               makeCommandTemplate(QStringLiteral("recall-preset"),
                                                   tr("Recall Preset"),
                                                   QStringLiteral("visca.recallPreset"),
                                                   QList<DeviceParamSpec *>{
                                                       makeParamSpec(QStringLiteral("preset"), tr("Preset"), DeviceParamSpec::IntType, 1)
                                                   }),
                               makeCommandTemplate(QStringLiteral("stop"),
                                                   tr("Stop"),
                                                   QStringLiteral("visca.stop"))
                           }),
        makeDeviceTemplate(QStringLiteral("osc-mixer"),
                           tr("OSC Mixer"),
                           QStringLiteral("OSC"),
                           tr("Mute, level, scene"),
                           QList<DeviceParamSpec *>{
                               makeConfigSpec(QStringLiteral("address"), tr("Address"), DeviceParamSpec::StringType, QStringLiteral("/mixer/main"), true)
                           },
                           QList<DeviceCommandTemplate *>{
                               makeCommandTemplate(QStringLiteral("set-level"),
                                                   tr("Set Level"),
                                                   QStringLiteral("osc.setLevel"),
                                                   QList<DeviceParamSpec *>{
                                                       makeParamSpec(QStringLiteral("channel"), tr("Channel"), DeviceParamSpec::IntType, 1),
                                                       makeParamSpec(QStringLiteral("level"), tr("Level"), DeviceParamSpec::DoubleType, 0.75)
                                                   }),
                               makeCommandTemplate(QStringLiteral("mute-channel"),
                                                   tr("Mute Channel"),
                                                   QStringLiteral("osc.mute"),
                                                   QList<DeviceParamSpec *>{
                                                       makeParamSpec(QStringLiteral("channel"), tr("Channel"), DeviceParamSpec::IntType, 1),
                                                       makeParamSpec(QStringLiteral("muted"), tr("Muted"), DeviceParamSpec::BoolType, true)
                                                   }),
                               makeCommandTemplate(QStringLiteral("load-scene"),
                                                   tr("Load Scene"),
                                                   QStringLiteral("osc.loadScene"),
                                                   QList<DeviceParamSpec *>{
                                                       makeParamSpec(QStringLiteral("sceneName"), tr("Scene"), DeviceParamSpec::StringType, tr("Main"))
                                                   })
                           }),
        makeDeviceTemplate(QStringLiteral("modbus-relay-rack"),
                           tr("Modbus Relay Rack"),
                           QStringLiteral("Modbus"),
                           tr("Switch relay, pulse"),
                           QList<DeviceParamSpec *>{
                               makeConfigSpec(QStringLiteral("address"), tr("Address"), DeviceParamSpec::StringType, tr("Unit 4"), true)
                           },
                           QList<DeviceCommandTemplate *>{
                               makeCommandTemplate(QStringLiteral("switch-relay"),
                                                   tr("Switch Relay"),
                                                   QStringLiteral("modbus.switchRelay"),
                                                   QList<DeviceParamSpec *>{
                                                       makeParamSpec(QStringLiteral("relay"), tr("Relay"), DeviceParamSpec::IntType, 1),
                                                       makeParamSpec(QStringLiteral("enabled"), tr("Enabled"), DeviceParamSpec::BoolType, true)
                                                   }),
                               makeCommandTemplate(QStringLiteral("pulse"),
                                                   tr("Pulse"),
                                                   QStringLiteral("modbus.pulse"),
                                                   QList<DeviceParamSpec *>{
                                                       makeParamSpec(QStringLiteral("relay"), tr("Relay"), DeviceParamSpec::IntType, 1),
                                                       makeParamSpec(QStringLiteral("durationMs"), tr("Duration"), DeviceParamSpec::IntType, 250)
                                                   })
                           })
    };

    m_devices = QList<Device *>{
        makeDeviceFromTemplate(QStringLiteral("lighting-group"),
                               QStringLiteral("dmx-light-group"),
                               tr("Lighting Group"),
                               tr("Universe 1 / Channel 001"),
                               tr("Online"),
                               tr("2s ago")),
        makeDeviceFromTemplate(QStringLiteral("ptz-01"),
                               QStringLiteral("visca-ptz-camera"),
                               tr("PTZ-01"),
                               QStringLiteral("192.168.10.41:52381"),
                               tr("Online"),
                               tr("8s ago")),
        makeDeviceFromTemplate(QStringLiteral("mixer"),
                               QStringLiteral("osc-mixer"),
                               tr("Mixer"),
                               QStringLiteral("/mixer/main"),
                               tr("Standby"),
                               tr("1m ago")),
        makeDeviceFromTemplate(QStringLiteral("relay-rack"),
                               QStringLiteral("modbus-relay-rack"),
                               tr("Relay Rack"),
                               tr("Unit 4 / Coil 12"),
                               tr("Offline"),
                               tr("18m ago"))
    };

    m_currentDeviceId = QStringLiteral("lighting-group");
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
    createDeviceFromTemplate(QStringLiteral("dmx-light-group"));
}

void DeviceManager::createDeviceFromTemplate(const QString &templateId)
{
    DeviceTemplate *selectedTemplate = deviceTemplate(templateId);
    if (!selectedTemplate)
        return;

    const QString id = QStringLiteral("device-%1").arg(m_nextDeviceNumber++);
    const QVariantMap configValues = defaultConfigValues(selectedTemplate);
    const QString address = configValues.value(QStringLiteral("address"), tr("Unassigned")).toString();

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
                                                  const QList<DeviceParamSpec *> &configSpecs,
                                                  const QList<DeviceCommandTemplate *> &commandTemplates)
{
    return new DeviceTemplate(id, name, protocol, description, configSpecs, commandTemplates, this);
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
        configValues.insert(QStringLiteral("address"), address);

    device->setConfigValues(configValues);
    device->setCommandTemplates(cloneCommandTemplates(device, sourceTemplate));
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

QList<DeviceCommandTemplate *> DeviceManager::cloneCommandTemplates(Device *device, const DeviceTemplate *deviceTemplate) const
{
    QList<DeviceCommandTemplate *> result;

    for (DeviceCommandTemplate *commandTemplate : deviceTemplate->commandTemplateObjects()) {
        result.append(new DeviceCommandTemplate(commandTemplate->id(),
                                                commandTemplate->name(),
                                                commandTemplate->action(),
                                                commandTemplate->paramSpecs(),
                                                device));
    }

    return result;
}

} // namespace TimelineControl
