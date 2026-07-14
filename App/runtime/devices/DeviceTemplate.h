#pragma once

#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

#include "devices/DeviceParamSpec.h"


    class DeviceCommand;
    class Device;
class DeviceTemplate : public QObject
{
    Q_OBJECT

    //! 设备模板唯一名称，用于按类型创建设备。
    Q_PROPERTY(QString name READ name CONSTANT FINAL)
    Q_PROPERTY(QString deviceType READ deviceType CONSTANT FINAL)
    Q_PROPERTY(QStringList supportedProtocols READ supportedProtocols CONSTANT FINAL)
    Q_PROPERTY(QString description READ description CONSTANT FINAL)
    Q_PROPERTY(QVariantList configSpecs READ configSpecs CONSTANT FINAL)

public:
    DeviceTemplate(const QString &name,
                   const QString &deviceType,
                   const QStringList &supportedProtocols,
                   const QString &description,
                   QList<DeviceParamSpec*> configSpecs,
                   QList<DeviceCommand*> commands,
                   QObject *parent = nullptr);

    QString name() const;
    QString deviceType() const;
    QStringList supportedProtocols() const;
    QString description() const;
    QVariantList configSpecs() const;
    QList<DeviceParamSpec *> configSpecObjects() const;

    virtual Device *createDevice(QObject *parent, const QVariantMap &configValues);
protected:
    QString m_name;
    QString m_deviceType;
    QStringList m_supportedProtocols;
    QString m_description;
    QList<DeviceParamSpec *> m_configSpecs;
    QList<DeviceCommand*> m_commands;
};

class SerialPowerDeviceTemplate : public DeviceTemplate
{
public:
    SerialPowerDeviceTemplate(QObject* parent = nullptr);
    Device *createDevice(QObject *parent, const QVariantMap &configValues) override;
};

Q_DECLARE_METATYPE(DeviceTemplate *)
