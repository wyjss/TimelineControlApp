#include "devices/DeviceModel.h"

namespace TimelineControl {

DeviceModel::DeviceModel(QObject *parent)
    : TypedListModel<Device *>(parent)
{
}

DeviceModel::~DeviceModel()
{
    for (Device *device : items())
        disconnectDevice(device);
}

QVariantList DeviceModel::devices() const
{
    QVariantList result;
    const QList<Device *> currentItems = items();
    result.reserve(currentItems.size());

    for (Device *device : currentItems)
        result.append(QVariant::fromValue(device));

    return result;
}

QString DeviceModel::currentDeviceId() const
{
    return m_currentDeviceId;
}

void DeviceModel::setCurrentDeviceId(const QString &deviceId)
{
    const QString normalizedDeviceId = deviceId.trimmed();
    if (!normalizedDeviceId.isEmpty() && !deviceById(normalizedDeviceId))
        return;

    if (m_currentDeviceId == normalizedDeviceId)
        return;

    m_currentDeviceId = normalizedDeviceId;
    emit currentDeviceIdChanged();
    emit currentDeviceChanged();
}

Device *DeviceModel::currentDevice() const
{
    return deviceById(m_currentDeviceId);
}

Device *DeviceModel::deviceAt(int row) const
{
    return itemAt(row);
}

Device *DeviceModel::deviceById(const QString &deviceId) const
{
    const int row = indexOfDeviceId(deviceId);
    return deviceAt(row);
}

int DeviceModel::indexOfDevice(Device *device) const
{
    return device ? indexOfItem(device) : -1;
}

int DeviceModel::indexOfDeviceId(const QString &deviceId) const
{
    const QString normalizedDeviceId = deviceId.trimmed();
    if (normalizedDeviceId.isEmpty())
        return -1;

    const QList<Device *> currentItems = items();
    for (int row = 0; row < currentItems.size(); ++row) {
        Device *device = currentItems.at(row);
        if (device && device->id() == normalizedDeviceId)
            return row;
    }

    return -1;
}

void DeviceModel::selectDevice(const QString &deviceId)
{
    setCurrentDeviceId(deviceId);
}

void DeviceModel::appendDevice(Device *device)
{
    if (!device || indexOfDevice(device) >= 0)
        return;

    if (device->parent() != this)
        device->setParent(this);

    if (appendItem(device)) {
        emit devicesChanged();
        emit deviceAdded(device);
    }
}

bool DeviceModel::removeDeviceAt(int row)
{
    Device *device = takeDeviceAt(row);
    if (!device)
        return false;

    device->deleteLater();
    return true;
}

bool DeviceModel::removeDevice(const QString &deviceId)
{
    return removeDeviceAt(indexOfDeviceId(deviceId));
}

Device *DeviceModel::takeDeviceAt(int row)
{
    Device *device = deviceAt(row);
    if (!device)
        return nullptr;

    const QString removedDeviceId = device->id();
    const bool removedCurrentDevice = device->id() == m_currentDeviceId;
    emit deviceAboutToBeRemoved(device, removedDeviceId);
    if (!removeItemAt(row))
        return nullptr;

    if (device->parent() == this)
        device->setParent(nullptr);

    emit devicesChanged();
    if (removedCurrentDevice) {
        Device *nextDevice = deviceAt(0);
        setCurrentDeviceId(nextDevice ? nextDevice->id() : QString());
    }
    emit deviceRemoved(removedDeviceId);

    return device;
}

Device *DeviceModel::takeDevice(const QString &deviceId)
{
    return takeDeviceAt(indexOfDeviceId(deviceId));
}

bool DeviceModel::acceptsItem(Device *device) const
{
    return device != nullptr;
}

void DeviceModel::itemInserted(Device *device, int row)
{
    Q_UNUSED(row)
    prepareDevice(device);
}

void DeviceModel::itemRemoved(Device *device, int row)
{
    Q_UNUSED(row)
    disconnectDevice(device);
}

void DeviceModel::prepareDevice(Device *device)
{
    if (!device)
        return;

    const auto notifyChanged = [this, device]() {
        emitDeviceChanged(device);
    };

    connect(device, &Device::deviceTypeChanged, this, notifyChanged);
    connect(device, &Device::nameChanged, this, notifyChanged);
    connect(device, &Device::protocolChanged, this, notifyChanged);
    connect(device, &Device::addressChanged, this, notifyChanged);
    connect(device, &Device::statusChanged, this, notifyChanged);
    connect(device, &Device::lastSeenChanged, this, notifyChanged);
    connect(device, &Device::capabilitiesChanged, this, notifyChanged);
    connect(device, &Device::configValuesChanged, this, notifyChanged);
}

void DeviceModel::disconnectDevice(Device *device)
{
    if (device)
        disconnect(device, nullptr, this, nullptr);
}

void DeviceModel::emitDeviceChanged(Device *device)
{
    const int row = indexOfDevice(device);
    if (row < 0)
        return;

    notifyItemChanged(row);
}

} // namespace TimelineControl
