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
class DeviceModel;
class DeviceTemplate;
class DeviceTemplateModel;

class DeviceManager final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList deviceTypes READ deviceTypes NOTIFY deviceTypesChanged FINAL)
    Q_PROPERTY(QStringList manualDeviceTypes READ manualDeviceTypes NOTIFY deviceTypesChanged FINAL)

public:
    explicit DeviceManager(DeviceModel *deviceModel,
                           DeviceTemplateModel *deviceTemplateModel,
                           QObject *parent = nullptr);

    QStringList deviceTypes() const;
    QStringList manualDeviceTypes() const;

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

signals:
    void deviceTypesChanged();

private:
    bool deviceMatchesDeviceType(const Device *device, const QString &deviceType) const;
    QVariantList deviceOptionsForDeviceType(const QString &deviceType) const;
    void refreshDmx512AdapterOptions();
    Device *makeDeviceFromTemplate(const QString &templateName,
                                   const QString &deviceType,
                                   const QString &name,
                                   const QString &address,
                                   const QString &status,
                                   const QString &lastSeen,
                                   const QVariantMap &configValues);
    QVariantMap defaultConfigValues(const DeviceTemplate *deviceTemplate) const;

    DeviceModel *m_deviceModel = nullptr;
    DeviceTemplateModel *m_deviceTemplateModel = nullptr;
    QStringList m_deviceTypes;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceManager *)
