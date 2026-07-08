#pragma once

#include <QList>
#include <QJsonObject>
#include <QMap>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

#include "devices/DeviceParamSpec.h"
#include "devices/DeviceConstants.h"

namespace TimelineControl {

//! 设备指令实例基类，保存设备指令通用信息，不绑定时间线调度。
class DeviceCommand : public QObject
{
    Q_OBJECT

    //! 指令显示名称。
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged FINAL)
    //! 协议标识，例如 serial、dmx512、http。
    Q_PROPERTY(QString protocol READ protocol CONSTANT)
    //! 创建指令时需要输入的字段描述。
    Q_PROPERTY(QVariantList creationInputFields READ creationInputFields CONSTANT FINAL)
    //! 添加到执行队列时需要输入的字段描述。
    Q_PROPERTY(QVariantList executionInputFields READ executionInputFields CONSTANT FINAL)

public:
    explicit DeviceCommand(QObject *parent = nullptr);
    DeviceCommand(const QString &protocol, const QString &name, QObject *parent = nullptr);

    QString name() const;
    void setName(const QString &name);

    QString protocol() const;

    DeviceParamSpec* getField(const QString& key) const;

    QJsonObject toJson() const;
    bool loadFromJson(const QJsonObject &json);
    QVariantMap resolvedParams(const QVariantMap &executionInputValues = QVariantMap());
    void setExecutionParamUpdaterName(const QString &name);

    void addCreationInputField(DeviceParamSpec *field);
    void addExecutionInputField(DeviceParamSpec *field);

    void updateConfigMap(const QVariantMap &configMap);
    Q_INVOKABLE QVariantList creationInputFields() const;
    Q_INVOKABLE QVariantList creationMinInputFields() const;
    Q_INVOKABLE QVariantList executionInputFields() const;

    DeviceCommand *clone(QObject *parent = nullptr) const;

signals:
    void nameChanged();
    void fieldChanged(DeviceParamSpec *field);

private:
    void updateExecutionParams(const QVariantMap &params);
    void emitFieldChanged();

    QMap<QString, DeviceParamSpec *> m_creationInputFieldMap;
    QList<DeviceParamSpec *> m_creationInputFields;
    QList<DeviceParamSpec *> m_executionInputFields;
    QVariantMap m_configMap;
    QString m_protocol;
    QString m_executionParamUpdaterName;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceCommand *)
