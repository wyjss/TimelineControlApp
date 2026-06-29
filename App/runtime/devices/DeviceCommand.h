#pragma once

#include <QList>
#include <QJsonObject>
#include <QObject>
#include <QString>
#include <QVariantList>

#include "devices/DeviceParamSpec.h"

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
    DeviceCommand(const QString &name, QObject *parent = nullptr);

    QString name() const;
    void setName(const QString &name);

    virtual QString protocol() const = 0;

    static DeviceCommand *createForProtocol(const QString &protocol, QObject *parent = nullptr);
    static DeviceCommand *createFromJson(const QJsonObject &json, QObject *parent = nullptr);

    QJsonObject toJson() const;
    bool loadFromJson(const QJsonObject &json);
    Q_INVOKABLE QString validate() const;

    void addCreationInputField(DeviceParamSpec *field);
    void addExecutionInputField(DeviceParamSpec *field);

    Q_INVOKABLE QVariantList creationInputFields() const;
    Q_INVOKABLE QVariantList executionInputFields() const;
    Q_INVOKABLE DeviceParamSpec *creationInputField(const QString &key) const;
    Q_INVOKABLE DeviceParamSpec *executionInputField(const QString &key) const;
    Q_INVOKABLE DeviceParamSpec *fieldByKey(const QString &key) const;

    virtual DeviceCommand *clone(QObject *parent = nullptr) const;

signals:
    void nameChanged();

protected:
    virtual QJsonObject paramsToJson() const = 0;
    virtual bool loadParamsFromJson(const QJsonObject &params) = 0;
    virtual QString validateParams() const = 0;
    virtual QList<DeviceParamSpec *> createCreationInputFields(QObject *parent) const;
    virtual QList<DeviceParamSpec *> createExecutionInputFields(QObject *parent) const;

private:
    void ensureCreationInputFields() const;
    void ensureExecutionInputFields() const;

    QString m_name;
    mutable QList<DeviceParamSpec *> m_creationInputFields;
    mutable QList<DeviceParamSpec *> m_executionInputFields;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceCommand *)
