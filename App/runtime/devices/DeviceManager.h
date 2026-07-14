#pragma once

#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>

#include "devices/DeviceParamSpec.h"


class Device;
class DeviceExecutorManager;
class DeviceModel;
class DeviceTemplate;
class DeviceTemplateModel;

class DeviceManager final : public QObject
{
    Q_OBJECT

public:
    explicit DeviceManager(DeviceModel *deviceModel,
                           DeviceTemplateModel *deviceTemplateModel,
                           DeviceExecutorManager *deviceExecutorManager = nullptr,
                           QObject *parent = nullptr);

    Q_INVOKABLE QString validateDeviceCreation(const QString &deviceType,
                                               const QString &deviceName,
                                               const QString &templateName = QString()) const;
    Q_INVOKABLE bool createDeviceFromTemplate(const QString &templateName,
                                              const QVariantMap &configValues = QVariantMap(),
                                              const QString &deviceName = QString(),
                                              const QString &deviceType = QString());

private:
    void refreshDmx512AdapterOptions();
    Device *makeDeviceFromTemplate(const QString &templateName,
                                   const QString &deviceType,
                                   const QString &name,
                                   const QString &status,
                                   const QString &lastSeen,
                                   const QVariantMap &configValues);
    QVariantMap defaultConfigValues(const DeviceTemplate *deviceTemplate) const;

    DeviceModel *m_deviceModel = nullptr;
    DeviceTemplateModel *m_deviceTemplateModel = nullptr;
    DeviceExecutorManager *m_deviceExecutorManager = nullptr;
};


Q_DECLARE_METATYPE(DeviceManager *)
