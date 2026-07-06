#pragma once

#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>

#include "devices/DeviceParamSpec.h"

namespace TimelineControl {

    class DeviceCommand;
    class Device;
class DeviceTemplate final : public QObject
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

    Device* createDevice(QObject* parent);
private:
    QString m_name;
    QString m_deviceType;
    QStringList m_supportedProtocols;
    QString m_description;
    QList<DeviceParamSpec *> m_configSpecs;
    QList<DeviceCommand*> m_commands;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceTemplate *)
