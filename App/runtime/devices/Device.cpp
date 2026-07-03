#include "devices/Device.h"

#include "devices/DeviceCommand.h"

#include <QDataStream>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMetaProperty>
#include <QUuid>

using namespace TimelineControl;

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

QString Device::description() const
{
    return m_description;
}

void Device::setDescription(const QString &description)
{
    if (m_description == description)
        return;

    m_description = description;
    emit descriptionChanged();
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

QVariantList Device::commands() const
{
    QVariantList result;
    result.reserve(m_commands.size());
    for (DeviceCommand *command : m_commands)
        result.append(QVariant::fromValue(command));
    return result;
}

int Device::commandCount() const
{
    return m_commands.size();
}

DeviceCommand *Device::commandAt(int index) const
{
    return index >= 0 && index < m_commands.size() ? m_commands.at(index) : nullptr;
}

DeviceCommand *Device::createCommandDraft(const QString &protocol) const
{
    const QString commandProtocol = protocol.trimmed().isEmpty() ? m_protocol : protocol.trimmed();
    return DeviceCommand::createForProtocol(commandProtocol, const_cast<Device *>(this));
}

void Device::deleteCommandDraft(DeviceCommand *command) const
{
    if (!command || m_commands.contains(command))
        return;

    command->deleteLater();
}

DeviceCommand *Device::createCommand(const QString &protocol, const QString &name)
{
    const QString commandProtocol = protocol.trimmed().isEmpty() ? m_protocol : protocol.trimmed();
    DeviceCommand *command = DeviceCommand::createForProtocol(commandProtocol, this);
    if (!command)
        return nullptr;

    const QString trimmedName = name.trimmed();
    if (!trimmedName.isEmpty())
        command->setName(trimmedName);

    appendCommand(command);
    return command;
}

void Device::appendCommand(DeviceCommand *command)
{
    if (!command || m_commands.contains(command))
        return;

    if (command->parent() && command->parent() != this)
        return;

    if (command->parent() != this)
        command->setParent(this);

    m_commands.append(command);
    emit commandsChanged();
}

bool Device::removeCommandAt(int index)
{
    DeviceCommand *command = commandAt(index);
    if (!command)
        return false;

    m_commands.removeAt(index);
    if (command->parent() == this)
        command->setParent(nullptr);

    emit commandsChanged();
    command->deleteLater();
    return true;
}

bool Device::removeCommand(DeviceCommand *command)
{
    return removeCommandAt(m_commands.indexOf(command));
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

void Device::writeToStream(QDataStream& stream) const
{
    stream << m_id
           << m_templateName
           << m_deviceType
           << m_name
           << m_protocol
           << m_address
           << m_description
           << m_configValues
           << m_commands.size();

    for (DeviceCommand *command : m_commands) {
        const QByteArray commandData = command
            ? QJsonDocument(command->toJson()).toJson(QJsonDocument::Compact)
            : QByteArray();
        stream << commandData;
    }
}

void Device::readFromStream(QDataStream& stream)
{
    QString id;
    QString templateName;
    QString deviceType;
    QString name;
    QString protocol;
    QString address;
    QString description;
    QVariantMap configValues;
    int commandCount = 0;

    stream >> id
           >> templateName
           >> deviceType
           >> name
           >> protocol
           >> address
           >> description
           >> configValues
           >> commandCount;

    if (stream.status() != QDataStream::Ok || commandCount < 0)
        return;

    QList<DeviceCommand *> commands;
    for (int index = 0; index < commandCount; ++index) {
        QByteArray commandData;
        stream >> commandData;
        if (stream.status() != QDataStream::Ok)
            break;

        const QJsonDocument document = QJsonDocument::fromJson(commandData);
        DeviceCommand *command = document.isObject()
            ? DeviceCommand::createFromJson(document.object(), this)
            : nullptr;
        if (command)
            commands.append(command);
    }

    if (stream.status() != QDataStream::Ok) {
        for (DeviceCommand *command : commands)
            delete command;
        return;
    }

    m_id = id;
    m_templateName = templateName;
    setDeviceType(deviceType);
    setName(name);
    setProtocol(protocol);
    setAddress(address);
    setDescription(description);
    setConfigValues(configValues);

    for (DeviceCommand *command : m_commands)
        delete command;
    m_commands = commands;
    for (DeviceCommand *command : m_commands) {
        if (command->parent() != this)
            command->setParent(this);
    }
    emit commandsChanged();
}
