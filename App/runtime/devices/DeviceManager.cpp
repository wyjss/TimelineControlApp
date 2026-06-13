#include "devices/DeviceManager.h"

#include <QMetaType>

#include "devices/Device.h"
#include "devices/DeviceCommandTemplate.h"

namespace {

QVariantMap makeParamSpec(const QString &key,
                          const QString &label,
                          const QString &type,
                          const QVariant &defaultValue,
                          const QVariantMap &constraints = QVariantMap())
{
    return QVariantMap{
        {QStringLiteral("key"), key},
        {QStringLiteral("label"), label},
        {QStringLiteral("type"), type},
        {QStringLiteral("defaultValue"), defaultValue},
        {QStringLiteral("constraints"), constraints}
    };
}

QVariantMap makeCommandTemplateSpec(const QString &id,
                                    const QString &name,
                                    const QString &action,
                                    const QVariantList &params = QVariantList())
{
    return QVariantMap{
        {QStringLiteral("id"), id},
        {QStringLiteral("name"), name},
        {QStringLiteral("action"), action},
        {QStringLiteral("params"), params}
    };
}

} // namespace

namespace TimelineControl {

DeviceManager::DeviceManager(QObject *parent)
    : QObject(parent)
{
    qRegisterMetaType<TimelineControl::Device *>("TimelineControl::Device*");
    qRegisterMetaType<TimelineControl::DeviceCommandTemplate *>("TimelineControl::DeviceCommandTemplate*");

    m_devices = QList<Device *>{
        makeDevice(QStringLiteral("lighting-group"),
                   tr("Lighting Group"),
                   QStringLiteral("DMX"),
                   tr("Universe 1 / Channel 001"),
                   tr("Online"),
                   tr("2s ago"),
                   tr("Dimmer, color, strobe"),
                   QVariantList{
                       makeCommandTemplateSpec(QStringLiteral("set-intensity"),
                                               tr("Set Intensity"),
                                               QStringLiteral("dmx.setIntensity"),
                                               QVariantList{
                                                   makeParamSpec(QStringLiteral("intensity"),
                                                                 tr("Intensity"),
                                                                 QStringLiteral("number"),
                                                                 80,
                                                                 QVariantMap{
                                                                     {QStringLiteral("min"), 0},
                                                                     {QStringLiteral("max"), 100},
                                                                     {QStringLiteral("unit"), QStringLiteral("%")}
                                                                 }),
                                                   makeParamSpec(QStringLiteral("fadeMs"),
                                                                 tr("Fade"),
                                                                 QStringLiteral("number"),
                                                                 500,
                                                                 QVariantMap{
                                                                     {QStringLiteral("min"), 0},
                                                                     {QStringLiteral("max"), 10000},
                                                                     {QStringLiteral("unit"), QStringLiteral("ms")}
                                                                 })
                                               }),
                       makeCommandTemplateSpec(QStringLiteral("set-color"),
                                               tr("Set Color"),
                                               QStringLiteral("dmx.setColor"),
                                               QVariantList{
                                                   makeParamSpec(QStringLiteral("red"), tr("Red"), QStringLiteral("number"), 255),
                                                   makeParamSpec(QStringLiteral("green"), tr("Green"), QStringLiteral("number"), 255),
                                                   makeParamSpec(QStringLiteral("blue"), tr("Blue"), QStringLiteral("number"), 255)
                                               }),
                       makeCommandTemplateSpec(QStringLiteral("strobe"),
                                               tr("Strobe"),
                                               QStringLiteral("dmx.strobe"),
                                               QVariantList{
                                                   makeParamSpec(QStringLiteral("rate"), tr("Rate"), QStringLiteral("number"), 8),
                                                   makeParamSpec(QStringLiteral("durationMs"), tr("Duration"), QStringLiteral("number"), 1000)
                                               })
                   }),
        makeDevice(QStringLiteral("ptz-01"),
                   tr("PTZ-01"),
                   QStringLiteral("VISCA"),
                   QStringLiteral("192.168.10.41:52381"),
                   tr("Online"),
                   tr("8s ago"),
                   tr("Pan, tilt, zoom, preset"),
                   QVariantList{
                       makeCommandTemplateSpec(QStringLiteral("move-camera"),
                                               tr("Move Camera"),
                                               QStringLiteral("visca.move"),
                                               QVariantList{
                                                   makeParamSpec(QStringLiteral("pan"), tr("Pan"), QStringLiteral("number"), 0),
                                                   makeParamSpec(QStringLiteral("tilt"), tr("Tilt"), QStringLiteral("number"), 0),
                                                   makeParamSpec(QStringLiteral("zoom"), tr("Zoom"), QStringLiteral("number"), 1),
                                                   makeParamSpec(QStringLiteral("speed"), tr("Speed"), QStringLiteral("number"), 5)
                                               }),
                       makeCommandTemplateSpec(QStringLiteral("recall-preset"),
                                               tr("Recall Preset"),
                                               QStringLiteral("visca.recallPreset"),
                                               QVariantList{
                                                   makeParamSpec(QStringLiteral("preset"), tr("Preset"), QStringLiteral("number"), 1)
                                               }),
                       makeCommandTemplateSpec(QStringLiteral("stop"),
                                               tr("Stop"),
                                               QStringLiteral("visca.stop"))
                   }),
        makeDevice(QStringLiteral("mixer"),
                   tr("Mixer"),
                   QStringLiteral("OSC"),
                   QStringLiteral("/mixer/main"),
                   tr("Standby"),
                   tr("1m ago"),
                   tr("Mute, level, scene"),
                   QVariantList{
                       makeCommandTemplateSpec(QStringLiteral("set-level"),
                                               tr("Set Level"),
                                               QStringLiteral("osc.setLevel"),
                                               QVariantList{
                                                   makeParamSpec(QStringLiteral("channel"), tr("Channel"), QStringLiteral("number"), 1),
                                                   makeParamSpec(QStringLiteral("level"), tr("Level"), QStringLiteral("number"), 0.75)
                                               }),
                       makeCommandTemplateSpec(QStringLiteral("mute-channel"),
                                               tr("Mute Channel"),
                                               QStringLiteral("osc.mute"),
                                               QVariantList{
                                                   makeParamSpec(QStringLiteral("channel"), tr("Channel"), QStringLiteral("number"), 1),
                                                   makeParamSpec(QStringLiteral("muted"), tr("Muted"), QStringLiteral("bool"), true)
                                               }),
                       makeCommandTemplateSpec(QStringLiteral("load-scene"),
                                               tr("Load Scene"),
                                               QStringLiteral("osc.loadScene"),
                                               QVariantList{
                                                   makeParamSpec(QStringLiteral("sceneName"), tr("Scene"), QStringLiteral("text"), tr("Main"))
                                               })
                   }),
        makeDevice(QStringLiteral("relay-rack"),
                   tr("Relay Rack"),
                   QStringLiteral("Modbus"),
                   tr("Unit 4 / Coil 12"),
                   tr("Offline"),
                   tr("18m ago"),
                   tr("Switch relay, pulse"),
                   QVariantList{
                       makeCommandTemplateSpec(QStringLiteral("switch-relay"),
                                               tr("Switch Relay"),
                                               QStringLiteral("modbus.switchRelay"),
                                               QVariantList{
                                                   makeParamSpec(QStringLiteral("relay"), tr("Relay"), QStringLiteral("number"), 1),
                                                   makeParamSpec(QStringLiteral("enabled"), tr("Enabled"), QStringLiteral("bool"), true)
                                               }),
                       makeCommandTemplateSpec(QStringLiteral("pulse"),
                                               tr("Pulse"),
                                               QStringLiteral("modbus.pulse"),
                                               QVariantList{
                                                   makeParamSpec(QStringLiteral("relay"), tr("Relay"), QStringLiteral("number"), 1),
                                                   makeParamSpec(QStringLiteral("durationMs"), tr("Duration"), QStringLiteral("number"), 250)
                                               })
                   })
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
    const QString id = QStringLiteral("device-%1").arg(m_nextDeviceNumber++);
    m_devices.append(makeDevice(id,
                                tr("New Device"),
                                QStringLiteral("DMX"),
                                tr("Unassigned"),
                                tr("Offline"),
                                tr("Never"),
                                tr("No capabilities configured"),
                                QVariantList{
                                    makeCommandTemplateSpec(QStringLiteral("new-command"),
                                                            tr("New Command"),
                                                            QStringLiteral("device.newCommand"))
                                }));
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

Device *DeviceManager::makeDevice(const QString &id,
                                  const QString &name,
                                  const QString &protocol,
                                  const QString &address,
                                  const QString &status,
                                  const QString &lastSeen,
                                  const QString &capabilities,
                                  const QVariantList &commandTemplateSpecs)
{
    auto *device = new Device(id, this);
    device->setName(name);
    device->setProtocol(protocol);
    device->setAddress(address);
    device->setStatus(status);
    device->setLastSeen(lastSeen);
    device->setCapabilities(capabilities);

    QList<DeviceCommandTemplate *> commandTemplates;
    for (const QVariant &commandTemplateValue : commandTemplateSpecs) {
        const QVariantMap commandTemplateData = commandTemplateValue.toMap();
        commandTemplates.append(new DeviceCommandTemplate(commandTemplateData.value(QStringLiteral("id")).toString(),
                                                         commandTemplateData.value(QStringLiteral("name")).toString(),
                                                         commandTemplateData.value(QStringLiteral("action")).toString(),
                                                         commandTemplateData.value(QStringLiteral("params")).toList(),
                                                         device));
    }

    device->setCommandTemplates(commandTemplates);
    return device;
}

} // namespace TimelineControl
