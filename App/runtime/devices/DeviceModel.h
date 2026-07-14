#pragma once

#include "devices/Device.h"
#include "models/TypedListModel.h"

#include <QString>
#include <QStringList>
#include <QVariantList>

class QDataStream;


class DeviceModel final : public TypedListModel<Device *>
{
    Q_OBJECT
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged FINAL)
    Q_PROPERTY(QString currentDeviceId READ currentDeviceId WRITE setCurrentDeviceId NOTIFY currentDeviceIdChanged FINAL)
    Q_PROPERTY(Device *currentDevice READ currentDevice NOTIFY currentDeviceChanged FINAL)
    Q_PROPERTY(QStringList deviceTypes READ deviceTypes NOTIFY deviceTypesChanged FINAL)

public:
    explicit DeviceModel(QObject *parent = nullptr);
    ~DeviceModel() override;

    QVariantList devices() const;
    QString currentDeviceId() const;
    void setCurrentDeviceId(const QString &deviceId);
    Device *currentDevice() const;
    Device *deviceById(const QString &deviceId) const;
    bool hasDeviceName(const QString &deviceType, const QString &deviceName) const;

    QStringList deviceTypes(bool manual = false) const;

    QVariantList deviceOptionsForDeviceType(const QString &deviceType) const;
    Q_INVOKABLE void selectDevice(const QString &deviceId);
    Q_INVOKABLE bool removeDevice(const QString &deviceId);

    void appendDevice(Device *device);

    void writeToStream(QDataStream &stream) const;
    void readFromStream(QDataStream &stream);

signals:
    void devicesChanged();
    void deviceAdded(Device *device);
    void deviceAboutToBeRemoved(Device *device, const QString &deviceId);
    void deviceRemoved(const QString &deviceId);
    void deviceTypesChanged();
    void currentDeviceIdChanged();
    void currentDeviceChanged();

protected:
    bool acceptsItem(Device *device) const override;
    void itemInserted(Device *device, int row) override;
    void itemRemoved(Device *device, int row) override;

private:
    Device *deviceAt(int row) const;
    int indexOfDevice(Device *device) const;
    int indexOfDeviceId(const QString &deviceId) const;
    bool deviceMatchesDeviceType(const Device *device, const QString &deviceType) const;
    bool removeDeviceAt(int row);
    Device *takeDeviceAt(int row);
    void prepareDevice(Device *device);
    void disconnectDevice(Device *device);
    void emitDeviceChanged(Device *device);

    QString m_currentDeviceId;
};


Q_DECLARE_METATYPE(DeviceModel *)
