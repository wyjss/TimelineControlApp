#include "devices/Device.h"

#include "devices/DeviceCommand.h"
#include "devices/DeviceCommandFactory.h"
#include "devices/DeviceConstants.h"

#include <QDataStream>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMetaProperty>
#include <QUuid>


namespace {

const char *kSupportedProtocolsConfigKey = "__supportedProtocols";
const char *kStatusConfigKey = "__status";
const char *kLastSeenConfigKey = "__lastSeen";

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

QStringList Device::supportedProtocols() const
{
    return m_supportedProtocols;
}

void Device::setSupportedProtocols(const QStringList &supportedProtocols)
{
    QStringList nextSupportedProtocols;
    for (const QString &protocol : supportedProtocols) {
        const QString protocolValue = protocol.trimmed();
        if (!protocolValue.isEmpty() && !nextSupportedProtocols.contains(protocolValue))
            nextSupportedProtocols.append(protocolValue);
    }

    if (m_supportedProtocols == nextSupportedProtocols)
        return;

    m_supportedProtocols = nextSupportedProtocols;
    emit supportedProtocolsChanged();
}

bool Device::supportsProtocol(const QString &protocol) const
{
    const QString protocolValue = protocol.trimmed();
    return !protocolValue.isEmpty() && supportedProtocols().contains(protocolValue);
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

DeviceCommand *Device::createCommandDraft(const QString &protocol) const
{
    const QString commandProtocol = protocol.trimmed().isEmpty() && !m_supportedProtocols.isEmpty()
        ? m_supportedProtocols.first()
        : protocol.trimmed();
    if (!supportsProtocol(commandProtocol))
        return nullptr;

    DeviceCommand *command = DeviceCommandFactory::createForProtocol(commandProtocol, const_cast<Device *>(this));
    if (command)
        command->updateConfigMap(m_configValues);
    return command;
}

void Device::deleteCommandDraft(DeviceCommand *command) const
{
    if (!command || m_commands.contains(command))
        return;

    command->deleteLater();
}

DeviceCommand *Device::createCommand(const QString &protocol, const QString &name)
{
    for (const QChar character : name) {
        if (character.isSpace())
            return nullptr;
    }

    DeviceCommand *command = createCommandDraft(protocol);
    if (!command)
        return nullptr;

    const QString trimmedName = name.trimmed();
    if (!trimmedName.isEmpty())
        command->setName(trimmedName);

    appendCommand(command);
    return command;
}

DeviceCommand *Device::createCommandForType(const QString &commandType)
{
    for (const QString &protocol : m_supportedProtocols) {
        DeviceCommand *command = DeviceCommandFactory::create(protocol, commandType, this);
        if (!command)
            continue;

        command->updateConfigMap(m_configValues);
        appendCommand(command);
        return command;
    }

    return nullptr;
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

    command->onInstall(this);

    emit commandsChanged();
}

bool Device::removeCommandAt(int index)
{
    if (index < 0 || index >= m_commands.size())
        return false;

    DeviceCommand *command = m_commands.at(index);
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
    QVariantMap streamConfigValues = m_configValues;
    if (!supportedProtocols().isEmpty())
        streamConfigValues.insert(QString::fromLatin1(kSupportedProtocolsConfigKey), supportedProtocols());
    streamConfigValues.insert(QString::fromLatin1(kStatusConfigKey), status());
    streamConfigValues.insert(QString::fromLatin1(kLastSeenConfigKey), lastSeen());

    stream << m_id
           << m_templateName
           << m_deviceType
           << m_name
           << m_description
           << streamConfigValues
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
    QString description;
    QVariantMap configValues;
    int commandCount = 0;

    stream >> id
           >> templateName
           >> deviceType
           >> name
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
            ? DeviceCommandFactory::createFromJson(document.object(), this)
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
    setDescription(description);
    const QStringList restoredSupportedProtocols = configValues.take(QString::fromLatin1(kSupportedProtocolsConfigKey)).toStringList();
    const QString restoredStatus = configValues.take(QString::fromLatin1(kStatusConfigKey)).toString();
    const QString restoredLastSeen = configValues.take(QString::fromLatin1(kLastSeenConfigKey)).toString();
    setConfigValues(configValues);
    if (!restoredSupportedProtocols.isEmpty())
        setSupportedProtocols(restoredSupportedProtocols);
    setStatus(restoredStatus);
    setLastSeen(restoredLastSeen);

    for (DeviceCommand *command : m_commands)
        delete command;

    for (DeviceCommand *command : commands) {
        appendCommand(command);
    }
    emit commandsChanged();
}
