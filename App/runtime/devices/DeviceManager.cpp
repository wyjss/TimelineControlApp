#include "devices/DeviceManager.h"

#include <QMetaType>
#include <QSize>
#include <QDebug>
#include <QDataStream>

#include "devices/DeviceConstants.h"
#include "devices/Device.h"
#include "devices/DeviceModel.h"
#include "devices/DeviceParamSpec.h"
#include "devices/DeviceTemplate.h"
#include "devices/DeviceTemplateModel.h"

namespace {

bool isTemplateOnlyDeviceType(const QString &deviceType)
{
    const QString normalizedDeviceType = deviceType.trimmed();
    return normalizedDeviceType.compare(TimelineControl::DeviceType::PC, Qt::CaseInsensitive) == 0
        || normalizedDeviceType.compare(TimelineControl::DeviceType::Dmx512Adapter, Qt::CaseInsensitive) == 0;
}

} // namespace

using namespace TimelineControl;

DeviceManager::DeviceManager(DeviceModel *deviceModel,
                             DeviceTemplateModel *deviceTemplateModel,
                             QObject *parent)
    : QObject(parent)
    , m_deviceModel(deviceModel)
    , m_deviceTemplateModel(deviceTemplateModel)
{
    qRegisterMetaType<TimelineControl::Device *>("TimelineControl::Device*");
    qRegisterMetaType<TimelineControl::DeviceParamSpec *>("TimelineControl::DeviceParamSpec*");
    qRegisterMetaType<TimelineControl::DeviceTemplate *>("TimelineControl::DeviceTemplate*");

    m_deviceTemplateModel->loadDefaultTemplates();

    QVariantMap pc1x1Config;
    pc1x1Config.insert(DeviceKey::Ip, QStringLiteral("127.0.0.1"));
    pc1x1Config.insert(DeviceKey::ScreenSize, QSize(1920, 1080));
    pc1x1Config.insert(DeviceKey::ScreenLayout, QSize(1, 1));
    Device *defaultDevice = makeDeviceFromTemplate(
                                               tr("电脑"),
                                               DeviceType::PC,
                                               tr("测试PC 1x1"),
                                               QStringLiteral("127.0.0.1"),
                                               tr("Online"),
                                               tr("Local test"),
                                                   pc1x1Config);
    m_deviceModel->appendDevice(defaultDevice);

    QVariantMap pc2x2Config;
    pc2x2Config.insert(DeviceKey::Ip, QStringLiteral("127.0.0.1"));
    pc2x2Config.insert(DeviceKey::ScreenSize, QSize(1920, 1080));
    pc2x2Config.insert(DeviceKey::ScreenLayout, QSize(2, 2));
    m_deviceModel->appendDevice(makeDeviceFromTemplate(
                                               tr("电脑"),
                                               DeviceType::PC,
                                               tr("测试PC 2x2"),
                                               QStringLiteral("127.0.0.1"),
                                               tr("Online"),
                                               tr("Local test"),
                                               pc2x2Config));
    QVariantMap pc3x1Config;
    pc3x1Config.insert(DeviceKey::Ip, QStringLiteral("127.0.0.1"));
    pc3x1Config.insert(DeviceKey::ScreenSize, QSize(1920, 1080));
    pc3x1Config.insert(DeviceKey::ScreenLayout, QSize(3, 1));
    m_deviceModel->appendDevice(makeDeviceFromTemplate(
                                               DeviceType::PC,
                                               DeviceType::PC,
                                               tr("Test PC 3x1"),
                                               QStringLiteral("127.0.0.1"),
                                               tr("Online"),
                                               tr("Move preview"),
                                               pc3x1Config));

    QVariantMap pc1x2Config;
    pc1x2Config.insert(DeviceKey::Ip, QStringLiteral("127.0.0.1"));
    pc1x2Config.insert(DeviceKey::ScreenSize, QSize(1920, 1080));
    pc1x2Config.insert(DeviceKey::ScreenLayout, QSize(1, 2));
    m_deviceModel->appendDevice(makeDeviceFromTemplate(
                                               DeviceType::PC,
                                               DeviceType::PC,
                                               tr("Test PC 1x2"),
                                               QStringLiteral("127.0.0.1"),
                                               tr("Online"),
                                               tr("Move preview"),
                                               pc1x2Config));

    QVariantMap pcWideConfig;
    pcWideConfig.insert(DeviceKey::Ip, QStringLiteral("127.0.0.1"));
    pcWideConfig.insert(DeviceKey::ScreenSize, QSize(2560, 1440));
    pcWideConfig.insert(DeviceKey::ScreenLayout, QSize(2, 1));
    m_deviceModel->appendDevice(makeDeviceFromTemplate(
                                               DeviceType::PC,
                                               DeviceType::PC,
                                               tr("Test PC Wide"),
                                               QStringLiteral("127.0.0.1"),
                                               tr("Standby"),
                                               tr("Move preview"),
                                               pcWideConfig));

    QVariantMap pcWallConfig;
    pcWallConfig.insert(DeviceKey::Ip, QStringLiteral("127.0.0.1"));
    pcWallConfig.insert(DeviceKey::ScreenSize, QSize(1280, 720));
    pcWallConfig.insert(DeviceKey::ScreenLayout, QSize(4, 1));
    m_deviceModel->appendDevice(makeDeviceFromTemplate(
                                               DeviceType::PC,
                                               DeviceType::PC,
                                               tr("Test PC Wall"),
                                               QStringLiteral("127.0.0.1"),
                                               tr("Offline"),
                                               tr("Move preview"),
                                               pcWallConfig));

    QVariantMap otherConfig;
    otherConfig.insert(DeviceKey::Address, QStringLiteral("http://127.0.0.1:8080"));
    m_deviceModel->appendDevice(makeDeviceFromTemplate(
                                               tr("HTTP协议"),
                                               tr("其他"),
                                               tr("测试其他设备"),
                                               QStringLiteral("http://127.0.0.1:8080"),
                                               tr("Online"),
                                               tr("Local test"),
                                               otherConfig));

    if (m_deviceModel && defaultDevice)
        m_deviceModel->setCurrentDeviceId(defaultDevice->id());

    if (m_deviceModel) {
        connect(m_deviceModel, &DeviceModel::deviceAdded,
                this, &DeviceManager::refreshDmx512AdapterOptions);
        connect(m_deviceModel, &DeviceModel::deviceRemoved,
                this, &DeviceManager::refreshDmx512AdapterOptions);
    }

    refreshDmx512AdapterOptions();

}

void DeviceManager::createDevice()
{
    createDeviceFromTemplate(tr("Dmx512协议"), QVariantMap(), QString(), DeviceType::Light);
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

    DeviceTemplate *sourceTemplate = m_deviceTemplateModel ? m_deviceTemplateModel->templateByName(templateName) : nullptr;
    if (sourceTemplate) {
        const QString templateDeviceType = sourceTemplate->deviceType().trimmed();
        if (templateDeviceType.isEmpty() && isTemplateOnlyDeviceType(normalizedDeviceType))
            return tr("This device type can only be created from its template");

        if (!templateDeviceType.isEmpty()
            && templateDeviceType.compare(normalizedDeviceType, Qt::CaseInsensitive) != 0) {
            return tr("Device type is fixed by template");
        }
    }

    if (m_deviceModel && m_deviceModel->hasDeviceName(normalizedDeviceType, normalizedDeviceName))
        return tr("Device name already exists in this type");

    return QString();
}

bool DeviceManager::createDeviceFromTemplate(const QString &templateName,
                                             const QVariantMap &configValues,
                                             const QString &deviceName,
                                             const QString &deviceType)
{
    DeviceTemplate *selectedTemplate = m_deviceTemplateModel ? m_deviceTemplateModel->templateByName(templateName) : nullptr;
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
        Device *adapter = m_deviceModel
            ? m_deviceModel->deviceById(resolvedConfigValues.value(DeviceKey::Dmx512AdapterDeviceId).toString())
            : nullptr;
        if (adapter) {
            address = adapter->address().trimmed();
            if (address.isEmpty())
                address = adapter->name().trimmed();
        }
    }
    if (address.isEmpty())
        address = tr("Unassigned");

    Device *newDevice = makeDeviceFromTemplate(selectedTemplate->name(),
                                               resolvedDeviceType,
                                               resolvedDeviceName,
                                               address,
                                               tr("Offline"),
                                               tr("Never"),
                                               resolvedConfigValues);
    if (!newDevice)
        return false;

    m_deviceModel->appendDevice(newDevice);
    if (m_deviceModel)
        m_deviceModel->setCurrentDeviceId(newDevice->id());
    return true;
}

void DeviceManager::refreshDmx512AdapterOptions()
{
    const QVariantList adapterOptions = m_deviceModel
        ? m_deviceModel->deviceOptionsForDeviceType(DeviceType::Dmx512Adapter)
        : QVariantList();

    const QList<DeviceTemplate *> currentTemplates = m_deviceTemplateModel ? m_deviceTemplateModel->items() : QList<DeviceTemplate *>();
    for (DeviceTemplate *deviceTemplate : currentTemplates) {
        if (!deviceTemplate)
            continue;

        for (DeviceParamSpec *configSpec : deviceTemplate->configSpecObjects()) {
            if (configSpec && configSpec->key() == DeviceKey::Dmx512AdapterDeviceId)
                configSpec->setOptions(adapterOptions);
        }
    }
}

Device *DeviceManager::makeDeviceFromTemplate(const QString &templateName,
                                              const QString &deviceType,
                                              const QString &name,
                                              const QString &address,
                                              const QString &status,
                                              const QString &lastSeen,
                                              const QVariantMap &configValues)
{
    DeviceTemplate *sourceTemplate = m_deviceTemplateModel ? m_deviceTemplateModel->templateByName(templateName) : nullptr;
    if (!sourceTemplate)
        return nullptr;

    auto *device = new Device(sourceTemplate->name(), m_deviceModel);
    device->setDeviceType(deviceType);
    device->setName(name);
    device->setProtocol(sourceTemplate->protocol());
    device->setAddress(address);
    device->setStatus(status);
    device->setLastSeen(lastSeen);
    device->setDescription(sourceTemplate->description());

    QVariantMap deviceConfigValues = configValues;
    if (!address.isEmpty())
        deviceConfigValues.insert(DeviceKey::Address, address);
//     qDebug() << deviceConfigValues;
//     QByteArray ba;
//     QDataStream ds(&ba, QIODevice::ReadWrite);
//     ds << deviceConfigValues;
//     deviceConfigValues.clear();
//     ds.device()->seek(0);
//     ds >> deviceConfigValues;
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
