#pragma once

#include <QList>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

namespace TimelineControl {

class Device final : public QObject
{
    Q_OBJECT

    //! 设备唯一标识，供时间线和页面选择引用。
    Q_PROPERTY(QString id READ id CONSTANT FINAL)
    //! 设备来源模板，用于回查固定配置和指令定义。
    Q_PROPERTY(QString templateId READ templateId CONSTANT FINAL)
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged FINAL)
    Q_PROPERTY(QString protocol READ protocol WRITE setProtocol NOTIFY protocolChanged FINAL)
    Q_PROPERTY(QString address READ address WRITE setAddress NOTIFY addressChanged FINAL)
    Q_PROPERTY(QString status READ status WRITE setStatus NOTIFY statusChanged FINAL)
    Q_PROPERTY(QString lastSeen READ lastSeen WRITE setLastSeen NOTIFY lastSeenChanged FINAL)
    Q_PROPERTY(QString capabilities READ capabilities WRITE setCapabilities NOTIFY capabilitiesChanged FINAL)
    Q_PROPERTY(QVariantMap configValues READ configValues WRITE setConfigValues NOTIFY configValuesChanged FINAL)

public:
    Device(const QString &id, const QString &templateId, QObject *parent = nullptr);

    QString id() const;
    QString templateId() const;

    QString name() const;
    void setName(const QString &name);

    QString protocol() const;
    void setProtocol(const QString &protocol);

    QString address() const;
    void setAddress(const QString &address);

    QString status() const;
    void setStatus(const QString &status);

    QString lastSeen() const;
    void setLastSeen(const QString &lastSeen);

    QString capabilities() const;
    void setCapabilities(const QString &capabilities);

    QVariantMap configValues() const;
    void setConfigValues(const QVariantMap &configValues);

signals:
    void nameChanged();
    void protocolChanged();
    void addressChanged();
    void statusChanged();
    void lastSeenChanged();
    void capabilitiesChanged();
    void configValuesChanged();

private:
    QString m_id;
    QString m_templateId;
    QString m_name;
    QString m_protocol;
    QString m_address;
    QString m_status;
    QString m_lastSeen;
    QString m_capabilities;
    QVariantMap m_configValues;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::Device *)
