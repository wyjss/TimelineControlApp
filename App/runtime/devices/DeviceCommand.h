#pragma once

#include <QList>
#include <QJsonObject>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

#include "devices/DeviceParamSpec.h"
#include "devices/DeviceConstants.h"


class Device;
class TimelineModel;
//! 设备指令实例基类，保存设备指令通用信息，不绑定时间线调度。
class DeviceCommand : public QObject
{
    Q_OBJECT

    //! 指令显示名称。
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged FINAL)
    Q_PROPERTY(Device *device READ device NOTIFY deviceChanged FINAL)
    Q_PROPERTY(bool filteredOut READ filteredOut NOTIFY filteredOutChanged FINAL)
    //! 是否允许编辑指令的创建参数。
    Q_PROPERTY(bool editable READ editable NOTIFY editableChanged FINAL)
    //! 协议标识DeviceProtocol，例如 serial、dmx512、http。
    Q_PROPERTY(QString protocol READ protocol CONSTANT)
    //! 指令类型，仅内部定义指令使用
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

    // 创建基础协议指令
	static DeviceCommand* createForProtocol(const QString& protocol,
											QObject* parent = nullptr);
	static DeviceCommand* createFromJson(const QJsonObject& json,
										 QObject* parent = nullptr,
										 TimelineModel* timelineModel = nullptr);

    QString name() const;
    void setName(const QString &name);

    QString protocol() const;
    QString commandType() const;
    Device *device() const;
    bool filteredOut() const;
    bool editable() const;
    Q_INVOKABLE void setEditable(bool editable);

    DeviceParamSpec* getField(const QString& key) const;
    Q_INVOKABLE virtual QString invalidReason() const;

	QJsonObject toJson() const;
	bool loadFromJson(const QJsonObject& json);

	Q_INVOKABLE virtual QVariantMap resolvedParams(const QVariantMap& executionInputValues = QVariantMap()) const;

    void addCreationInputField(DeviceParamSpec *field);
    void addExecutionInputField(DeviceParamSpec *field);

    Q_INVOKABLE QVariantList creationInputFields() const;
    Q_INVOKABLE QVariantList creationMinInputFields() const;
    Q_INVOKABLE QVariantList executionInputFields() const;

    //! 将指定key参数作为模板，自动从其它参数拼接
    //! ${OtherParam}: 字符解析
    //! ${&OtherParam}: http参数解析
    void setStringTemplateKey(const QString& k) { m_stringTemplateKey = k; }

    DeviceCommand *clone(QObject *parent = nullptr) const;

signals:
    void nameChanged();
    void deviceChanged();
    void filteredOutChanged();
    void editableChanged();
    void fieldChanged(DeviceParamSpec *field);

private:
    friend class Device;

    void setDevice(Device *device);
    void emitFieldChanged();
    void updateParamFromDevice();

    // 创建时需要输入的参数
    QList<DeviceParamSpec *> m_creationInputFields;
    // 执行需要的参数，仅作为字段描述，实际值在TimelineCommand中
    QList<DeviceParamSpec *> m_executionInputFields;
    //
    QString m_protocol;
    QString m_commandType;
    QString m_stringTemplateKey;
    QPointer<Device> m_device;
    bool m_editable = false;
};

//! StringTemplate指令
//! 通过string进行url拼接的指令都接入
//! http/udp/serial
//class StringTemplateCommand : public DeviceCommand
//{
//protected:
//    StringTemplateCommand(const QString& protocol,
//					  const QString& name,
//					  const QString& commandType,
//					  QObject* parent);
//public:
//    QVariantMap resolvedParams(
//        const QVariantMap& executionInputValues = QVariantMap()) const override;
//};

class DeviceCommand_Internal : public DeviceCommand
{
public:
	explicit DeviceCommand_Internal(QObject* parent = nullptr);

protected:
    DeviceCommand_Internal(const QString& protocol,
					  const QString& name,
					  const QString& commandType,
					  QObject* parent);
};


class DeviceCommand_Udp : public DeviceCommand
{
public:
	explicit DeviceCommand_Udp(QObject* parent = nullptr);

protected:
    DeviceCommand_Udp(const QString& protocol,
					   const QString& name,
					   const QString& commandType,
					   QObject* parent);
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
