#pragma once

#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>

class QDataStream;
class QJsonObject;
class TimelineModel;


class DeviceCommand;
class DeviceParamSpec;
class DeviceTemplate;

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
    Q_PROPERTY(bool filteredOut READ filteredOut WRITE setFilteredOut NOTIFY filteredOutChanged FINAL)
    Q_PROPERTY(QString description READ description WRITE setDescription NOTIFY descriptionChanged FINAL)
    Q_PROPERTY(QVariantMap configValues READ configValues NOTIFY configValuesChanged FINAL)
    Q_PROPERTY(QVariantList params READ params NOTIFY paramsChanged FINAL)
    Q_PROPERTY(QVariantList commands READ commands NOTIFY commandsChanged FINAL)

public:
    explicit Device(DeviceTemplate *deviceTemplate, QObject *parent = nullptr);

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

    bool filteredOut() const;
    void setFilteredOut(bool filteredOut);

    QString description() const;
    void setDescription(const QString &description);

    QVariantMap configValues() const;

    QVariantList params() const;
    Q_INVOKABLE DeviceParamSpec *getParam(const QString &key) const;
    bool addParam(DeviceParamSpec *param);
    Q_INVOKABLE bool setParamValue(const QString &key, const QVariant &value);

    QVariantList commands() const;
    Q_INVOKABLE DeviceCommand *createCommandDraft(const QString &protocol = QString()) const;
    Q_INVOKABLE void deleteCommandDraft(DeviceCommand *command) const;
    Q_INVOKABLE DeviceCommand *createCommand(const QString &protocol = QString(),
                                                              const QString &name = QString());
    Q_INVOKABLE DeviceCommand *createCommandForType(const QString &commandType);
    DeviceCommand *createCommandFromJson(const QJsonObject &json,
                                         QObject *parent = nullptr,
                                         TimelineModel *timelineModel = nullptr) const;
    void appendCommand(DeviceCommand *command);
    Q_INVOKABLE bool removeCommandAt(int index);
    bool removeCommand(DeviceCommand *command);

    Q_INVOKABLE bool setFieldValue(const QString &field, const QVariant &value);
public:
	void writeToStream(QDataStream& stream) const;
	void readFromStream(QDataStream& stream, TimelineModel *timelineModel = nullptr);
signals:
    void deviceTypeChanged();
    void nameChanged();
    void supportedProtocolsChanged();
    void statusChanged();
    void filteredOutChanged();
    void descriptionChanged();
    void configValuesChanged();
    void paramsChanged();
    void paramChanged(const QString &key, const QVariant &value);
    void commandsChanged();

private:
    QString m_id;
    QString m_templateName;
    DeviceTemplate *m_deviceTemplate = nullptr;
    QString m_deviceType;
    QString m_name;
    QStringList m_supportedProtocols;
    QString m_status;
    bool m_filteredOut = false;
    QString m_description;
    QList<DeviceParamSpec *> m_params;
    QList<DeviceCommand *> m_commands;
};


Q_DECLARE_METATYPE(Device *)
