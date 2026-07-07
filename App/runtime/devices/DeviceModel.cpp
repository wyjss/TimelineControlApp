#include "devices/DeviceModel.h"
#include "devices/DeviceConstants.h"
#include <QDataStream>
#include <QVariantMap>

namespace {

QVariantMap option(const QString &label, const QString &value)
{
    return QVariantMap{
        {QStringLiteral("label"), label},
        {QStringLiteral("value"), value}
    };
}

} // namespace

using namespace TimelineControl;

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

bool DeviceModel::deviceMatchesDeviceType(const Device *device, const QString &deviceType) const
{
    if (!device)
        return false;

    return device->deviceType().trimmed() == deviceType.trimmed();
}

bool DeviceModel::hasDeviceName(const QString &deviceType, const QString &deviceName) const
{
    const QString normalizedDeviceType = deviceType.trimmed();
    const QString normalizedDeviceName = deviceName.trimmed();
    if (normalizedDeviceType.isEmpty() || normalizedDeviceName.isEmpty())
        return false;

    const QList<Device *> currentItems = items();
    for (Device *device : currentItems) {
        if (!deviceMatchesDeviceType(device, normalizedDeviceType))
            continue;

        if (device->name().trimmed().compare(normalizedDeviceName, Qt::CaseInsensitive) == 0)
            return true;
    }

    return false;
}

QStringList DeviceModel::deviceTypes(bool manual) const
{
    QStringList types;

    if (!manual)
        types << DeviceType::PC << DeviceType::Dmx512Adapter;

    types << DeviceType::Projector << DeviceType::Light << DeviceType::Sound;
    
    for (Device *device : items()) {
        if (!device)
            continue;

        const QString deviceType = device->deviceType();
        if (manual && (deviceType == DeviceType::PC || deviceType == DeviceType::Dmx512Adapter))
            continue;

        if (!types.contains(deviceType))
            types << deviceType;
    }
    return types;
}

QVariantList DeviceModel::deviceOptionsForDeviceType(const QString &deviceType) const
{
    QVariantList result;

    const QList<Device *> currentItems = items();
    for (Device *device : currentItems) {
        if (!deviceMatchesDeviceType(device, deviceType))
            continue;

        QString label = device->name().trimmed();
        if (label.isEmpty())
            label = device->id();

        const QVariantMap configValues = device->configValues();
        const QString ip = configValues.value(DeviceKey::Ip).toString().trimmed();
        QString port = configValues.value(DeviceKey::IpPort).toString().trimmed();
        if (port.isEmpty())
            port = configValues.value(DeviceKey::Port).toString().trimmed();
        QString address = !ip.isEmpty() && !port.isEmpty()
            ? QStringLiteral("%1:%2").arg(ip, port)
            : ip;
        if (address.isEmpty())
            address = configValues.value(DeviceKey::SerialPort).toString().trimmed();

        if (!address.isEmpty())
            label = QStringLiteral("%1 (%2)").arg(label, address);

        result.append(option(label, device->id()));
    }

    return result;
}

void DeviceModel::selectDevice(const QString &deviceId)
{
    setCurrentDeviceId(deviceId);
}

void DeviceModel::appendDevice(Device *device)
{
    if (!device || indexOfDevice(device) >= 0)
        return;
    
    const QStringList previousDeviceTypes = deviceTypes();

    if (device->parent() != this)
        device->setParent(this);

    if (appendItem(device)) {
        emit devicesChanged();
        emit deviceAdded(device);
    }

    if (previousDeviceTypes != deviceTypes())
        emit deviceTypesChanged();
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

    const QStringList previousDeviceTypes = deviceTypes();
    const QString removedDeviceId = device->id();
    const bool removedCurrentDevice = device->id() == m_currentDeviceId;
    emit deviceAboutToBeRemoved(device, removedDeviceId);
    if (!removeItemAt(row))
        return nullptr;

    if (device->parent() == this)
        device->setParent(nullptr);

    emit devicesChanged();
    if (previousDeviceTypes != deviceTypes())
        emit deviceTypesChanged();

    if (removedCurrentDevice) {
        Device *nextDevice = deviceAt(0);
        setCurrentDeviceId(nextDevice ? nextDevice->id() : QString());
    }
    emit deviceRemoved(removedDeviceId);

    return device;
}

void DeviceModel::writeToStream(QDataStream &stream) const
{
    const QList<Device *> currentItems = items();
    stream << currentItems.size();

    for (Device *device : currentItems)
        device->writeToStream(stream);

    stream << m_currentDeviceId;
}

void DeviceModel::readFromStream(QDataStream &stream)
{
    int deviceCount = 0;
    stream >> deviceCount;
    if (stream.status() != QDataStream::Ok || deviceCount < 0)
        return;

    QList<Device *> devices;
    devices.reserve(deviceCount);
    for (int index = 0; index < deviceCount; ++index) {
        auto *device = new Device(QString(), this);
        device->readFromStream(stream);
        if (stream.status() != QDataStream::Ok) {
            delete device;
            break;
        }
        devices.append(device);
    }

    QString currentDeviceId;
    if (stream.status() == QDataStream::Ok)
        stream >> currentDeviceId;

    if (stream.status() != QDataStream::Ok || devices.size() != deviceCount) {
        qDeleteAll(devices);
        return;
    }

    const QList<Device *> oldDevices = items();
    if (!resetItems(devices)) {
        qDeleteAll(devices);
        return;
    }

    qDeleteAll(oldDevices);
    emit devicesChanged();
    emit deviceTypesChanged();
    for (Device *device : devices)
        emit deviceAdded(device);

    const QString restoredCurrentDeviceId = deviceById(currentDeviceId) ? currentDeviceId : QString();
    if (m_currentDeviceId == restoredCurrentDeviceId)
        emit currentDeviceChanged();
    else
        setCurrentDeviceId(restoredCurrentDeviceId);
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

    connect(device, &Device::deviceTypeChanged, this, [this, device]() {
        emitDeviceChanged(device);
        emit deviceTypesChanged();
    });
    connect(device, &Device::nameChanged, this, notifyChanged);
    connect(device, &Device::supportedProtocolsChanged, this, notifyChanged);
    connect(device, &Device::statusChanged, this, notifyChanged);
    connect(device, &Device::lastSeenChanged, this, notifyChanged);
    connect(device, &Device::descriptionChanged, this, notifyChanged);
    connect(device, &Device::configValuesChanged, this, notifyChanged);
    connect(device, &Device::commandsChanged, this, notifyChanged);
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

