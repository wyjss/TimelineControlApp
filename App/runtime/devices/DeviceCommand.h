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


    class Device;
//! 设备指令实例基类，保存设备指令通用信息，不绑定时间线调度。
class DeviceCommand : public QObject
{
    Q_OBJECT

    //! 指令显示名称。
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged FINAL)
    //! 协议标识，例如 serial、dmx512、http。
    Q_PROPERTY(QString protocol READ protocol CONSTANT)
    Q_PROPERTY(QString commandType READ commandType CONSTANT FINAL)
    //! 创建指令时需要输入的字段描述。
    Q_PROPERTY(QVariantList creationInputFields READ creationInputFields CONSTANT FINAL)
    //! 添加到执行队列时需要输入的字段描述。
    Q_PROPERTY(QVariantList executionInputFields READ executionInputFields CONSTANT FINAL)

public:
    explicit DeviceCommand(QObject *parent = nullptr);
    DeviceCommand(const QString &protocol, const QString &name, QObject *parent = nullptr);
    DeviceCommand(const QString &protocol,
                  const QString &name,
                  const QString &commandType,
                  QObject *parent = nullptr);

    QString name() const;
    void setName(const QString &name);

    QString protocol() const;
    QString commandType() const;

    DeviceParamSpec* getField(const QString& key) const;

	QJsonObject toJson() const;
	bool loadFromJson(const QJsonObject& json);
	virtual QVariantMap resolvedParams(const QVariantMap& executionInputValues = QVariantMap()) const;
	virtual void onInstall(Device*) {}

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
    void emitFieldChanged();

    QMap<QString, DeviceParamSpec *> m_creationInputFieldMap;
    QList<DeviceParamSpec *> m_creationInputFields;
    QList<DeviceParamSpec *> m_executionInputFields;
    QVariantMap m_configMap;
    QString m_protocol;
    QString m_commandType;
};

class DeviceCommand_Http : public DeviceCommand
{
public:
    explicit DeviceCommand_Http(QObject *parent = nullptr);

protected:
    DeviceCommand_Http(const QString &protocol,
                       const QString &name,
                       const QString &commandType,
                       QObject *parent);
};

class DeviceCommand_PC : public DeviceCommand_Http
{
public:
    explicit DeviceCommand_PC(QObject *parent = nullptr);

protected:
    DeviceCommand_PC(const QString &name, const QString &commandType, QObject *parent);
};


Q_DECLARE_METATYPE(DeviceCommand *)
