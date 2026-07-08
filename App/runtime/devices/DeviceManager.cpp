#include "devices/DeviceManager.h"

#include <QMetaType>
#include <QDebug>
#include <QDataStream>

#include "devices/DeviceConstants.h"
#include "devices/Device.h"
#include "devices/DeviceModel.h"
#include "devices/DeviceParamSpec.h"
#include "devices/DeviceTemplate.h"
#include "devices/DeviceTemplateModel.h"
#include "devices/executors/DeviceExecutorManager.h"

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
                             DeviceExecutorManager *deviceExecutorManager,
                             QObject *parent)
    : QObject(parent)
    , m_deviceModel(deviceModel)
    , m_deviceTemplateModel(deviceTemplateModel)
    , m_deviceExecutorManager(deviceExecutorManager)
{
    qRegisterMetaType<TimelineControl::Device *>("TimelineControl::Device*");
    qRegisterMetaType<TimelineControl::DeviceParamSpec *>("TimelineControl::DeviceParamSpec*");
    qRegisterMetaType<TimelineControl::DeviceTemplate *>("TimelineControl::DeviceTemplate*");

    m_deviceTemplateModel->loadDefaultTemplates();

    QVariantMap pc1x1Config;
    pc1x1Config.insert(DeviceKey::Ip, QStringLiteral("127.0.0.1"));
    pc1x1Config.insert(DeviceKey::ScreenWidth, 1920);
    pc1x1Config.insert(DeviceKey::ScreenHeight, 1080);
    pc1x1Config.insert(DeviceKey::ScreenColumns, 1);
    pc1x1Config.insert(DeviceKey::ScreenRows, 1);
    Device *defaultDevice = makeDeviceFromTemplate(
                                               tr("电脑"),
                                               DeviceType::PC,
                                               tr("测试PC 1x1"),
                                               tr("在线"),
                                               tr("本地测试"),
                                               pc1x1Config);
    m_deviceModel->appendDevice(defaultDevice);

    QVariantMap pc2x2Config;
    pc2x2Config.insert(DeviceKey::Ip, QStringLiteral("127.0.0.1"));
    pc2x2Config.insert(DeviceKey::ScreenWidth, 1920);
    pc2x2Config.insert(DeviceKey::ScreenHeight, 1080);
    pc2x2Config.insert(DeviceKey::ScreenColumns, 2);
    pc2x2Config.insert(DeviceKey::ScreenRows, 2);
    m_deviceModel->appendDevice(makeDeviceFromTemplate(
                                               tr("电脑"),
                                               DeviceType::PC,
                                               tr("测试PC 2x2"),
                                               tr("在线"),
                                               tr("本地测试"),
                                               pc2x2Config));
    QVariantMap pc3x1Config;
    pc3x1Config.insert(DeviceKey::Ip, QStringLiteral("127.0.0.1"));
    pc3x1Config.insert(DeviceKey::ScreenWidth, 1920);
    pc3x1Config.insert(DeviceKey::ScreenHeight, 1080);
    pc3x1Config.insert(DeviceKey::ScreenColumns, 3);
    pc3x1Config.insert(DeviceKey::ScreenRows, 1);
    m_deviceModel->appendDevice(makeDeviceFromTemplate(
                                               DeviceType::PC,
                                               DeviceType::PC,
                                               tr("测试PC 3x1"),
                                               tr("在线"),
                                               tr("移动预览"),
                                               pc3x1Config));

    QVariantMap pc1x2Config;
    pc1x2Config.insert(DeviceKey::Ip, QStringLiteral("127.0.0.1"));
    pc1x2Config.insert(DeviceKey::ScreenWidth, 1920);
    pc1x2Config.insert(DeviceKey::ScreenHeight, 1080);
    pc1x2Config.insert(DeviceKey::ScreenColumns, 1);
    pc1x2Config.insert(DeviceKey::ScreenRows, 2);
    m_deviceModel->appendDevice(makeDeviceFromTemplate(
                                               DeviceType::PC,
                                               DeviceType::PC,
                                               tr("测试PC 1x2"),
                                               tr("在线"),
                                               tr("移动预览"),
                                               pc1x2Config));

    QVariantMap pcWideConfig;
    pcWideConfig.insert(DeviceKey::Ip, QStringLiteral("127.0.0.1"));
    pcWideConfig.insert(DeviceKey::ScreenWidth, 2560);
    pcWideConfig.insert(DeviceKey::ScreenHeight, 1440);
    pcWideConfig.insert(DeviceKey::ScreenColumns, 2);
    pcWideConfig.insert(DeviceKey::ScreenRows, 1);
    m_deviceModel->appendDevice(makeDeviceFromTemplate(
                                               DeviceType::PC,
                                               DeviceType::PC,
                                               tr("测试PC 宽屏"),
                                               tr("离线"),
                                               tr("移动预览"),
                                               pcWideConfig));

    QVariantMap pcWallConfig;
    pcWallConfig.insert(DeviceKey::Ip, QStringLiteral("127.0.0.1"));
    pcWallConfig.insert(DeviceKey::ScreenWidth, 1280);
    pcWallConfig.insert(DeviceKey::ScreenHeight, 720);
    pcWallConfig.insert(DeviceKey::ScreenColumns, 4);
    pcWallConfig.insert(DeviceKey::ScreenRows, 1);
    m_deviceModel->appendDevice(makeDeviceFromTemplate(
                                               DeviceType::PC,
                                               DeviceType::PC,
                                               tr("测试PC 拼接墙"),
                                               tr("离线"),
                                               tr("移动预览"),
                                               pcWallConfig));

    QVariantMap otherConfig;
    otherConfig.insert(DeviceKey::Ip, QStringLiteral("127.0.0.1"));
    otherConfig.insert(DeviceKey::IpPort, 8080);
    m_deviceModel->appendDevice(makeDeviceFromTemplate(
                                               tr("HTTP协议"),
                                               tr("其他"),
                                               tr("测试其他设备"),
                                               tr("在线"),
                                               tr("本地测试"),
                                               otherConfig));

    if (m_deviceModel && defaultDevice)
        m_deviceModel->setCurrentDeviceId(defaultDevice->id());

    if (m_deviceModel) {
        connect(m_deviceModel, &DeviceModel::deviceAdded,
                this, [this](Device *device) {
                    refreshDmx512AdapterOptions();
                    connect(device, &Device::configValuesChanged, this, [this, device]() {
                        if (m_deviceExecutorManager)
                            m_deviceExecutorManager->bindDevice(device);
                    });
                    if (m_deviceExecutorManager)
                        m_deviceExecutorManager->bindDevice(device);
                });
        connect(m_deviceModel, &DeviceModel::deviceAboutToBeRemoved,
                this, [this](Device *device, const QString &) {
                    if (m_deviceExecutorManager)
                        m_deviceExecutorManager->unbindDevice(device);
                });
        connect(m_deviceModel, &DeviceModel::deviceRemoved,
                this, [this](const QString &deviceId) {
                    Q_UNUSED(deviceId)
                    refreshDmx512AdapterOptions();
                });
    }
    if (m_deviceExecutorManager) {
        if (m_deviceModel) {
            for (Device *device : m_deviceModel->items()) {
                connect(device, &Device::configValuesChanged, this, [this, device]() {
                    if (m_deviceExecutorManager)
                        m_deviceExecutorManager->bindDevice(device);
                });
                m_deviceExecutorManager->bindDevice(device);
            }
        }
    }

    refreshDmx512AdapterOptions();

}

QString DeviceManager::validateDeviceCreation(const QString &deviceType,
                                              const QString &deviceName,
                                              const QString &templateName) const
{
    const QString normalizedDeviceType = deviceType.trimmed();
    if (normalizedDeviceType.isEmpty())
        return tr("设备类型必填");

    const QString normalizedDeviceName = deviceName.trimmed();
    if (normalizedDeviceName.isEmpty())
        return tr("设备名称必填");

    DeviceTemplate *sourceTemplate = m_deviceTemplateModel ? m_deviceTemplateModel->templateByName(templateName) : nullptr;
    if (sourceTemplate) {
        const QString templateDeviceType = sourceTemplate->deviceType().trimmed();
        if (templateDeviceType.isEmpty() && isTemplateOnlyDeviceType(normalizedDeviceType))
            return tr("该设备类型只能通过模板创建");

        if (!templateDeviceType.isEmpty()
            && templateDeviceType.compare(normalizedDeviceType, Qt::CaseInsensitive) != 0) {
            return tr("设备类型由模板固定");
        }
    }

    if (m_deviceModel && m_deviceModel->hasDeviceName(normalizedDeviceType, normalizedDeviceName))
        return tr("该类型中已存在同名设备");

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
        ? tr("新建 %1").arg(selectedTemplate->name())
        : deviceName.trimmed();

    if (!validateDeviceCreation(resolvedDeviceType, resolvedDeviceName, selectedTemplate->name()).isEmpty())
        return false;

    QVariantMap resolvedConfigValues = defaultConfigValues(selectedTemplate);
    for (auto it = configValues.cbegin(); it != configValues.cend(); ++it) {
        if (!it.key().trimmed().isEmpty())
            resolvedConfigValues.insert(it.key(), it.value());
    }

    Device *newDevice = makeDeviceFromTemplate(selectedTemplate->name(),
                                               resolvedDeviceType,
                                               resolvedDeviceName,
                                               tr("离线"),
                                               tr("从未"),
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
                                              const QString &status,
                                              const QString &lastSeen,
                                              const QVariantMap &configValues)
{
    DeviceTemplate *sourceTemplate = m_deviceTemplateModel ? m_deviceTemplateModel->templateByName(templateName) : nullptr;
    if (!sourceTemplate)
        return nullptr;

    auto *device = sourceTemplate->createDevice(m_deviceModel);
    device->setDeviceType(deviceType);
    device->setName(name);
    device->setSupportedProtocols(sourceTemplate->supportedProtocols());
    device->setStatus(status);
    device->setLastSeen(lastSeen);
    device->setDescription(sourceTemplate->description());

    QVariantMap deviceConfigValues = configValues;
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
