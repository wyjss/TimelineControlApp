#pragma once

#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>

namespace TimelineControl {

class Device;

class DeviceManager final : public QObject
{
    Q_OBJECT

    //! 设备对象列表，先以内存数据驱动 DevicesPage。
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged FINAL)
    //! 当前选中设备 id。
    Q_PROPERTY(QString currentDeviceId READ currentDeviceId WRITE setCurrentDeviceId NOTIFY currentDeviceIdChanged FINAL)
    //! 当前选中设备对象。
    Q_PROPERTY(TimelineControl::Device *currentDevice READ currentDevice NOTIFY currentDeviceChanged FINAL)

public:
    explicit DeviceManager(QObject *parent = nullptr);

    QVariantList devices() const;

    QString currentDeviceId() const;
    void setCurrentDeviceId(const QString &deviceId);

    Device *currentDevice() const;

    Q_INVOKABLE void selectDevice(const QString &deviceId);
    Q_INVOKABLE void createDevice();
    Q_INVOKABLE void updateCurrentDeviceField(const QString &field, const QVariant &value);

signals:
    void devicesChanged();
    void currentDeviceIdChanged();
    void currentDeviceChanged();

private:
    Device *device(const QString &deviceId) const;
    Device *makeDevice(const QString &id,
                       const QString &name,
                       const QString &protocol,
                       const QString &address,
                       const QString &status,
                       const QString &lastSeen,
                       const QString &capabilities,
                       const QVariantList &commandTemplateSpecs);

    QList<Device *> m_devices;
    QString m_currentDeviceId;
    int m_nextDeviceNumber = 5;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceManager *)
