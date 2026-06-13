#include "devices/Device.h"

#include <QVariant>

#include "devices/DeviceCommandTemplate.h"

namespace {

bool commandTemplateListsEqual(const QList<TimelineControl::DeviceCommandTemplate *> &left,
                               const QList<TimelineControl::DeviceCommandTemplate *> &right)
{
    if (left.size() != right.size())
        return false;

    for (int index = 0; index < left.size(); ++index) {
        if (left.at(index) != right.at(index))
            return false;
    }

    return true;
}

} // namespace

namespace TimelineControl {

Device::Device(const QString &id, QObject *parent)
    : QObject(parent)
    , m_id(id)
{
}

QString Device::id() const
{
    return m_id;
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

QVariantList Device::commandTemplates() const
{
    QVariantList result;
    result.reserve(m_commandTemplates.size());

    for (DeviceCommandTemplate *commandTemplate : m_commandTemplates)
        result.append(QVariant::fromValue(commandTemplate));

    return result;
}

void Device::setCommandTemplates(const QList<DeviceCommandTemplate *> &commandTemplates)
{
    if (commandTemplateListsEqual(m_commandTemplates, commandTemplates))
        return;

    for (DeviceCommandTemplate *commandTemplate : commandTemplates) {
        if (commandTemplate && commandTemplate->parent() != this)
            commandTemplate->setParent(this);
    }

    m_commandTemplates = commandTemplates;
    emit commandTemplatesChanged();
}

} // namespace TimelineControl
