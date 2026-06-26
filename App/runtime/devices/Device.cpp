#include "devices/Device.h"

#include <QMetaProperty>
#include <QUuid>

namespace TimelineControl {

namespace {

QString createDeviceId()
{
    return QStringLiteral("device-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
}

} // namespace

Device::Device(const QString &templateName, QObject *parent)
    : QObject(parent)
    , m_id(createDeviceId())
    , m_templateName(templateName)
{
}

QString Device::id() const
{
    return m_id;
}

QString Device::templateName() const
{
    return m_templateName;
}

QString Device::deviceType() const
{
    return m_deviceType;
}

void Device::setDeviceType(const QString &deviceType)
{
    if (m_deviceType == deviceType)
        return;

    m_deviceType = deviceType;
    emit deviceTypeChanged();
}

QString Device::name() const
{
    return m_name;
}

void Device::setName(const QString &name)
{
    if (m_name == name)
        return;

    m_name = name;
    emit nameChanged();
}

QString Device::protocol() const
{
    return m_protocol;
}

void Device::setProtocol(const QString &protocol)
{
    if (m_protocol == protocol)
        return;

    m_protocol = protocol;
    emit protocolChanged();
}

QString Device::address() const
{
    return m_address;
}

void Device::setAddress(const QString &address)
{
    if (m_address == address)
        return;

    m_address = address;
    emit addressChanged();
}

QString Device::status() const
{
    return m_status;
}

void Device::setStatus(const QString &status)
{
    if (m_status == status)
        return;

    m_status = status;
    emit statusChanged();
}

QString Device::lastSeen() const
{
    return m_lastSeen;
}

void Device::setLastSeen(const QString &lastSeen)
{
    if (m_lastSeen == lastSeen)
        return;

    m_lastSeen = lastSeen;
    emit lastSeenChanged();
}

QString Device::capabilities() const
{
    return m_capabilities;
}

void Device::setCapabilities(const QString &capabilities)
{
    if (m_capabilities == capabilities)
        return;

    m_capabilities = capabilities;
    emit capabilitiesChanged();
}

QVariantMap Device::configValues() const
{
    return m_configValues;
}

void Device::setConfigValues(const QVariantMap &configValues)
{
    if (m_configValues == configValues)
        return;

    m_configValues = configValues;
    emit configValuesChanged();
}

bool Device::setFieldValue(const QString &field, const QVariant &value)
{
    const QByteArray propertyName = field.trimmed().toUtf8();
    if (propertyName.isEmpty())
        return false;

    const int propertyIndex = metaObject()->indexOfProperty(propertyName.constData());
    if (propertyIndex < 0)
        return false;

    const QMetaProperty metaProperty = metaObject()->property(propertyIndex);
    if (!metaProperty.isWritable())
        return false;

    if (property(propertyName.constData()) == value)
        return true;

    return setProperty(propertyName.constData(), value);
}

} // namespace TimelineControl
