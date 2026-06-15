#pragma once

#include <QList>
#include <QObject>
#include <QString>
#include <QVariantList>

#include "devices/DeviceParamSpec.h"

namespace TimelineControl {

class DeviceCommandTemplate;

class DeviceTemplate final : public QObject
{
    Q_OBJECT

    //! 设备模板唯一标识，用于按类型创建设备。
    Q_PROPERTY(QString id READ id CONSTANT FINAL)
    Q_PROPERTY(QString name READ name CONSTANT FINAL)
    Q_PROPERTY(QString protocol READ protocol CONSTANT FINAL)
    Q_PROPERTY(QString description READ description CONSTANT FINAL)
    Q_PROPERTY(QVariantList configSpecs READ configSpecs CONSTANT FINAL)
    Q_PROPERTY(QVariantList commandTemplates READ commandTemplates CONSTANT FINAL)

public:
    DeviceTemplate(const QString &id,
                   const QString &name,
                   const QString &protocol,
                   const QString &description,
                   const QList<DeviceParamSpec *> &configSpecs,
                   const QList<DeviceCommandTemplate *> &commandTemplates,
                   QObject *parent = nullptr);

    QString id() const;
    QString name() const;
    QString protocol() const;
    QString description() const;
    QVariantList configSpecs() const;
    QList<DeviceParamSpec *> configSpecObjects() const;
    QVariantList commandTemplates() const;
    QList<DeviceCommandTemplate *> commandTemplateObjects() const;

private:
    QString m_id;
    QString m_name;
    QString m_protocol;
    QString m_description;
    QList<DeviceParamSpec *> m_configSpecs;
    QList<DeviceCommandTemplate *> m_commandTemplates;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceTemplate *)
