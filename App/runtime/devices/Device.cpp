#include "devices/Device.h"

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"
#include "devices/DeviceParamSpec.h"
#include "devices/DeviceTemplate.h"

#include "LogMacros.h"
#include <QDataStream>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMetaProperty>
#include <QSet>
#include <QUuid>


namespace {

const char *kSupportedProtocolsConfigKey = "__supportedProtocols";
const char *kOnlineConfigKey = "__online";
const char *kStatusConfigKey = "__status";

} // namespace

Device::Device(DeviceTemplate *deviceTemplate, QObject *parent)
    : QObject(parent)
    , m_id(QStringLiteral("device-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces)))
    , m_templateName(deviceTemplate ? deviceTemplate->name() : QString())
    , m_deviceTemplate(deviceTemplate)
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

bool Device::isOnline() const
{
    return m_online;
}

void Device::setOnline(bool online)
{
    if (m_online == online)
        return;

    m_online = online;
    emit onlineChanged();
}

bool Device::filteredOut() const
{
    return m_filteredOut;
}

void Device::setFilteredOut(bool filteredOut)
{
    if (m_filteredOut == filteredOut)
        return;

    m_filteredOut = filteredOut;
    emit filteredOutChanged();
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
    QVariantMap values;
    for (DeviceParamSpec *param : m_params)
        values.insert(param->key(), param->value());
    return values;
}

QVariantList Device::params() const
{
    QVariantList result;
    result.reserve(m_params.size());
    for (DeviceParamSpec *param : m_params)
        result.append(QVariant::fromValue(param));
    return result;
}

DeviceParamSpec *Device::getParam(const QString &key) const
{
    for (DeviceParamSpec *param : m_params) {
        if (param->key() == key)
            return param;
    }
    return nullptr;
}

bool Device::addParam(DeviceParamSpec *param)
{
    if (!param || param->key().isEmpty() || getParam(param->key()))
        return false;
    if (param->parent() && param->parent() != this)
        return false;

    if (param->parent() != this)
        param->setParent(this);

    connect(param, &DeviceParamSpec::valueChanged, this, [this, param]() {
        emit configValuesChanged();
        emit paramChanged(param->key(), param->value());
    });

    m_params.append(param);
    emit configValuesChanged();
    emit paramsChanged();
    return true;
}

bool Device::setParamValue(const QString &key, const QVariant &value)
{
    DeviceParamSpec *param = getParam(key);
    if (!param)
        return false;

    param->setValue(value);
    return true;
}

QVariantList Device::commands() const
{
    QVariantList result;
    result.reserve(m_commands.size());
    for (DeviceCommand *command : m_commands)
        result.append(QVariant::fromValue(command));
    return result;
}

DeviceCommand *Device::commandByName(const QString &name) const
{
    const QString commandName = name.trimmed();
    for (DeviceCommand *command : m_commands) {
        if (command && command->name() == commandName)
            return command;
    }
    return nullptr;
}

QString Device::commandInvalidReason(DeviceCommand *command,
                                     DeviceCommand *excludedCommand) const
{
    if (!command)
        return tr("指令不存在");

    const QString reason = command->invalidReason();
    if (!reason.isEmpty())
        return reason;

    DeviceCommand *existingCommand = commandByName(command->name());
    return existingCommand && existingCommand != command && existingCommand != excludedCommand
        ? tr("指令名称已存在")
        : QString();
}

DeviceCommand *Device::createCommandDraft(const QString &protocol) const
{
    QString commandProtocol = protocol.trimmed();
    if (commandProtocol.isEmpty() && !m_supportedProtocols.isEmpty())
        commandProtocol = m_supportedProtocols.first();
    if (!supportsProtocol(commandProtocol))
        return nullptr;

    DeviceCommand *command = DeviceCommand::createForProtocol(commandProtocol, const_cast<Device *>(this));
    if (command)
        command->setDevice(const_cast<Device *>(this));
    return command;
}

void Device::deleteCommandDraft(DeviceCommand *command) const
{
    if (!command || m_commands.contains(command))
        return;

    command->deleteLater();
}

bool Device::commitCommandDraft(DeviceCommand *command)
{
    if (!command
        || command->parent() != this
        || m_commands.contains(command)
        || !supportsProtocol(command->protocol())
        || !commandInvalidReason(command).isEmpty()) {
        return false;
    }

    return appendCommand(command);
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

    if (!name.isEmpty())
        command->setName(name);

    if (!commitCommandDraft(command)) {
        LOG_ERROR("commitCommandDraft !!!!!!!!!!!!!!!!! ERRRRRRRRRRRRRRR");
        deleteCommandDraft(command);
        return nullptr;
    }
    return command;
}

DeviceCommand *Device::createCommandFromJson(const QJsonObject &json,
                                             QObject *parent,
                                             TimelineModel *timelineModel) const
{
    const QString commandType = json.value(DeviceKey::CommandType).toString().trimmed();
    DeviceCommand *command = commandType.isEmpty()
        ? DeviceCommand::createFromJson(json, parent, timelineModel)
        : (m_deviceTemplate ? m_deviceTemplate->createCommand(commandType, parent) : nullptr);
    if (!command)
        return nullptr;
    if (!commandType.isEmpty() && !command->loadFromJson(json)) {
        delete command;
        return nullptr;
    }
    command->setDevice(const_cast<Device *>(this));
    return command;
}

bool Device::appendCommand(DeviceCommand *command)
{
    if (!command || m_commands.contains(command))
        return false;

    if (command->parent() && command->parent() != this)
        return false;

    command->setDevice(this);
    if (command->name().trimmed().isEmpty() || commandByName(command->name()))
        return false;

    if (command->parent() != this)
        command->setParent(this);

    command->getField(DeviceKey::Name)->setReadOnly(true);
    connect(command, &DeviceCommand::fieldChanged, this, [this]() {
        emit commandsChanged();
    });
    m_commands.append(command);

    emit commandsChanged();
    return true;
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
    const QByteArray propertyName = field.toUtf8();
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
    QVariantMap streamConfigValues = configValues();
    if (!supportedProtocols().isEmpty())
        streamConfigValues.insert(QString::fromLatin1(kSupportedProtocolsConfigKey), supportedProtocols());
    streamConfigValues.insert(QString::fromLatin1(kOnlineConfigKey), isOnline());

    stream << m_id
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

void Device::readFromStream(QDataStream& stream, TimelineModel *timelineModel)
{
    QString id;
    QString deviceType;
    QString name;
    QString description;
    QVariantMap configValues;
    int commandCount = 0;

    stream >> id
           >> deviceType
           >> name
           >> description
           >> configValues
           >> commandCount;

    if (stream.status() != QDataStream::Ok || commandCount < 0)
        return;

    QList<QJsonObject> commandObjects;
    QSet<QString> commandNames;
    for (int index = 0; index < commandCount; ++index) {
        QByteArray commandData;
        stream >> commandData;
      
        if (stream.status() != QDataStream::Ok)
            break;

        const QJsonDocument document = QJsonDocument::fromJson(commandData);
        if (!document.isObject()) {
            stream.setStatus(QDataStream::ReadCorruptData);
            break;
        }

        const QJsonObject commandObject = document.object();
        const QJsonObject values = commandObject.value(QStringLiteral("creationInputValues")).toObject();
        const QString commandName = (values.contains(DeviceKey::Name)
                                         ? values.value(DeviceKey::Name)
                                         : commandObject.value(DeviceKey::Name)).toString().trimmed();
        if (commandName.isEmpty() || commandNames.contains(commandName)) {
            stream.setStatus(QDataStream::ReadCorruptData);
            break;
        }
        commandNames.insert(commandName);
        commandObjects.append(commandObject);
    }

    if (stream.status() != QDataStream::Ok)
        return;

    m_id = id;
    setDeviceType(deviceType);
    setName(name);
    setDescription(description);
    const QStringList restoredSupportedProtocols = configValues.take(QString::fromLatin1(kSupportedProtocolsConfigKey)).toStringList();
    const QVariant restoredOnline = configValues.take(QString::fromLatin1(kOnlineConfigKey));
    const QString restoredStatus = configValues.take(QString::fromLatin1(kStatusConfigKey)).toString();
    for (auto it = configValues.cbegin(); it != configValues.cend(); ++it)
        setParamValue(it.key(), it.value());
    if (!restoredSupportedProtocols.isEmpty())
        setSupportedProtocols(restoredSupportedProtocols);
    setOnline(restoredOnline.isValid()
                  ? restoredOnline.toBool()
                  : restoredStatus == QStringLiteral("在线"));

    QList<DeviceCommand *> commands;
    QList<DeviceCommand *> createdCommands;
    for (const QJsonObject &commandObject : commandObjects) {
        DeviceCommand *loadedCommand = createCommandFromJson(commandObject, this, timelineModel);
        if (!loadedCommand) {
            delete loadedCommand;
            stream.setStatus(QDataStream::ReadCorruptData);
            break;
        }

        DeviceCommand *command = commandByName(loadedCommand->name());
        if (command) {
            if (command->protocol() != loadedCommand->protocol()
                || command->commandType() != loadedCommand->commandType()
                || !command->loadFromJson(commandObject)) {
                delete loadedCommand;
                stream.setStatus(QDataStream::ReadCorruptData);
                break;
            }
            delete loadedCommand;
        } else {
            command = loadedCommand;
            createdCommands.append(command);
        }
        commands.append(command);
    }

    if (stream.status() != QDataStream::Ok) {
        qDeleteAll(createdCommands);
        return;
    }

    const QList<DeviceCommand *> oldCommands = m_commands;
    for (DeviceCommand *command : oldCommands)
        disconnect(command, &DeviceCommand::fieldChanged, this, nullptr);

    m_commands = commands;
    for (DeviceCommand *command : m_commands) {
        command->setParent(this);
        command->setDevice(this);
        command->getField(DeviceKey::Name)->setReadOnly(true);
        connect(command, &DeviceCommand::fieldChanged, this, [this]() {
            emit commandsChanged();
        });
    }

    for (DeviceCommand *command : oldCommands) {
        if (!m_commands.contains(command))
            delete command;
    }
    emit commandsChanged();
}
