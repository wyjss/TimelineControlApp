#pragma once

#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>

class QDataStream;


class DeviceCommand;

class Device final : public QObject
{
    Q_OBJECT

    //! 设备唯一标识，供时间线和页面选择引用。
    Q_PROPERTY(QString id READ id CONSTANT FINAL)
    //! 设备来源模板名称，用于回查固定配置。
    Q_PROPERTY(QString templateName READ templateName CONSTANT FINAL)
    Q_PROPERTY(QString deviceType READ deviceType WRITE setDeviceType NOTIFY deviceTypeChanged FINAL)
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged FINAL)
    Q_PROPERTY(QStringList supportedProtocols READ supportedProtocols WRITE setSupportedProtocols NOTIFY supportedProtocolsChanged FINAL)
    Q_PROPERTY(QString status READ status WRITE setStatus NOTIFY statusChanged FINAL)
    Q_PROPERTY(QString lastSeen READ lastSeen WRITE setLastSeen NOTIFY lastSeenChanged FINAL)
    Q_PROPERTY(QString description READ description WRITE setDescription NOTIFY descriptionChanged FINAL)
    Q_PROPERTY(QVariantMap configValues READ configValues WRITE setConfigValues NOTIFY configValuesChanged FINAL)
    Q_PROPERTY(QVariantList commands READ commands NOTIFY commandsChanged FINAL)

public:
    explicit Device(const QString &templateName, QObject *parent = nullptr);

    QString id() const;
    QString templateName() const;

    QString deviceType() const;
    void setDeviceType(const QString &deviceType);

    QString name() const;
    void setName(const QString &name);

    QStringList supportedProtocols() const;
    void setSupportedProtocols(const QStringList &supportedProtocols);
    Q_INVOKABLE bool supportsProtocol(const QString &protocol) const;

    QString status() const;
    void setStatus(const QString &status);

    QString lastSeen() const;
    void setLastSeen(const QString &lastSeen);

    QString description() const;
    void setDescription(const QString &description);

    QVariantMap configValues() const;
    void setConfigValues(const QVariantMap &configValues);

    QVariantList commands() const;
    Q_INVOKABLE DeviceCommand *createCommandDraft(const QString &protocol = QString()) const;
    Q_INVOKABLE void deleteCommandDraft(DeviceCommand *command) const;
    Q_INVOKABLE DeviceCommand *createCommand(const QString &protocol = QString(),
                                                              const QString &name = QString());
    Q_INVOKABLE DeviceCommand *createCommandForType(const QString &commandType);
    void appendCommand(DeviceCommand *command);
    Q_INVOKABLE bool removeCommandAt(int index);
    bool removeCommand(DeviceCommand *command);

    Q_INVOKABLE bool setFieldValue(const QString &field, const QVariant &value);
public:
	void writeToStream(QDataStream& stream) const;
	void readFromStream(QDataStream& stream);
signals:
    void deviceTypeChanged();
    void nameChanged();
    void supportedProtocolsChanged();
    void statusChanged();
    void lastSeenChanged();
    void descriptionChanged();
    void configValuesChanged();
    void commandsChanged();

private:
    QString m_id;
    QString m_templateName;
    QString m_deviceType;
    QString m_name;
    QStringList m_supportedProtocols;
    QString m_status;
    QString m_lastSeen;
    QString m_description;
    QVariantMap m_configValues;
    QList<DeviceCommand *> m_commands;
};


Q_DECLARE_METATYPE(Device *)
