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
class DeviceTemplate;

class DeviceManager final : public QObject
{
    Q_OBJECT

    //! 设备对象列表，先以内存数据驱动 DevicesPage。
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged FINAL)
    //! 可用设备模板列表，供创建设备时选择。
    Q_PROPERTY(QVariantList deviceTemplates READ deviceTemplates NOTIFY deviceTemplatesChanged FINAL)
    //! 可动态维护的设备类型列表。
    Q_PROPERTY(QStringList deviceTypes READ deviceTypes NOTIFY deviceTypesChanged FINAL)
    //! 协议模板创建设备时可手动选择的设备类型。
    Q_PROPERTY(QStringList manualDeviceTypes READ manualDeviceTypes NOTIFY deviceTypesChanged FINAL)
    //! 当前选中设备 id。
    Q_PROPERTY(QString currentDeviceId READ currentDeviceId WRITE setCurrentDeviceId NOTIFY currentDeviceIdChanged FINAL)
    //! 当前选中设备对象。
    Q_PROPERTY(TimelineControl::Device *currentDevice READ currentDevice NOTIFY currentDeviceChanged FINAL)

public:
    explicit DeviceManager(QObject *parent = nullptr);

    QVariantList devices() const;
    QVariantList deviceTemplates() const;
    QStringList deviceTypes() const;
    QStringList manualDeviceTypes() const;

    QString currentDeviceId() const;
    void setCurrentDeviceId(const QString &deviceId);

    Device *currentDevice() const;

    Q_INVOKABLE void selectDevice(const QString &deviceId);
    Q_INVOKABLE void createDevice();
    Q_INVOKABLE QVariantList devicesForDeviceType(const QString &deviceType) const;
    Q_INVOKABLE QString validateDeviceCreation(const QString &deviceType,
                                               const QString &deviceName,
                                               const QString &templateName = QString()) const;
    Q_INVOKABLE bool createDeviceFromTemplate(const QString &templateName,
                                              const QVariantMap &configValues = QVariantMap(),
                                              const QString &deviceName = QString(),
                                              const QString &deviceType = QString());
    Q_INVOKABLE void addDeviceType(const QString &deviceType);
    Q_INVOKABLE void removeDeviceType(const QString &deviceType);
    Q_INVOKABLE void updateCurrentDeviceField(const QString &field, const QVariant &value);

signals:
    void devicesChanged();
    void deviceTemplatesChanged();
    void deviceTypesChanged();
    void currentDeviceIdChanged();
    void currentDeviceChanged();

private:
    DeviceTemplate* createDefaultDeviceTemplatePc() const;
    DeviceTemplate* createDefaultDeviceTemplateDmx512Adapter() const;
    DeviceTemplate* createDefaultDeviceTemplateDmx512() const;
    DeviceTemplate* createDefaultDeviceTemplateHttp() const;
    DeviceTemplate* createDefaultDeviceTemplateSerial() const;
    DeviceTemplate* createDefaultDeviceTemplateOsc() const;
    
    Device *device(const QString &deviceId) const;
    bool deviceMatchesDeviceType(const Device *device, const QString &deviceType) const;
    QVariantList deviceOptionsForDeviceType(const QString &deviceType) const;
    DeviceTemplate *deviceTemplate(const QString &templateName) const;
    void refreshDmx512AdapterOptions();
    DeviceTemplate *makeDeviceTemplate(const QString &name,
                                       const QString &deviceType,
                                       const QString &protocol,
                                       const QString &description,
                                       const QList<DeviceParamSpec *> &configSpecs);
    Device *makeDeviceFromTemplate(const QString &id,
                                   const QString &templateName,
                                   const QString &deviceType,
                                   const QString &name,
                                   const QString &address,
                                   const QString &status,
                                   const QString &lastSeen,
                                   const QVariantMap &configValues);
    QVariantMap defaultConfigValues(const DeviceTemplate *deviceTemplate) const;

    QList<DeviceTemplate *> m_deviceTemplates;
    QList<Device *> m_devices;
    QStringList m_deviceTypes;
    QString m_currentDeviceId;
    int m_nextDeviceNumber = 5;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceManager *)
