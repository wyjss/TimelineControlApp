#pragma once

#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>

#include "devices/DeviceParamSpec.h"

namespace TimelineControl {

class Device;
class DeviceCommandTemplate;
class DeviceTemplate;

class DeviceManager final : public QObject
{
    Q_OBJECT

    //! 设备对象列表，先以内存数据驱动 DevicesPage。
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged FINAL)
    //! 可用设备模板列表，供创建设备时选择。
    Q_PROPERTY(QVariantList deviceTemplates READ deviceTemplates NOTIFY deviceTemplatesChanged FINAL)
    //! 当前选中设备 id。
    Q_PROPERTY(QString currentDeviceId READ currentDeviceId WRITE setCurrentDeviceId NOTIFY currentDeviceIdChanged FINAL)
    //! 当前选中设备对象。
    Q_PROPERTY(TimelineControl::Device *currentDevice READ currentDevice NOTIFY currentDeviceChanged FINAL)

public:
    explicit DeviceManager(QObject *parent = nullptr);

    QVariantList devices() const;
    QVariantList deviceTemplates() const;

    QString currentDeviceId() const;
    void setCurrentDeviceId(const QString &deviceId);

    Device *currentDevice() const;

    Q_INVOKABLE void selectDevice(const QString &deviceId);
    Q_INVOKABLE void createDevice();
    Q_INVOKABLE void createDeviceFromTemplate(const QString &templateId);
    Q_INVOKABLE void updateCurrentDeviceField(const QString &field, const QVariant &value);

signals:
    void devicesChanged();
    void deviceTemplatesChanged();
    void currentDeviceIdChanged();
    void currentDeviceChanged();

private:
    Device *device(const QString &deviceId) const;
    DeviceTemplate *deviceTemplate(const QString &templateId) const;
    DeviceTemplate *makeDeviceTemplate(const QString &id,
                                       const QString &name,
                                       const QString &protocol,
                                       const QString &description,
                                       const QList<DeviceParamSpec> &configSpecs,
                                       const QList<DeviceCommandTemplate *> &commandTemplates);
    Device *makeDeviceFromTemplate(const QString &id,
                                   const QString &templateId,
                                   const QString &name,
                                   const QString &address,
                                   const QString &status,
                                   const QString &lastSeen);
    QVariantMap defaultConfigValues(const DeviceTemplate *deviceTemplate) const;
    QList<DeviceCommandTemplate *> cloneCommandTemplates(Device *device, const DeviceTemplate *deviceTemplate) const;

    QList<DeviceTemplate *> m_deviceTemplates;
    QList<Device *> m_devices;
    QString m_currentDeviceId;
    int m_nextDeviceNumber = 5;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceManager *)
