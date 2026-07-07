#include "timeline/TimelineCommand.h"

#include "devices/DeviceCommand.h"

#include <QDataStream>
#include <QJsonObject>
#include <QUuid>

namespace {

const char *kDurationMsKey = "durationMs";

QString createTimelineCommandId()
{
    return QStringLiteral("timeline-command-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
}

qint64 variantInt64(const QVariantMap &map, const QString &key, qint64 fallback)
{
    bool ok = false;
    const qint64 value = map.value(key).toLongLong(&ok);
    return ok ? value : fallback;
}

} // namespace

using namespace TimelineControl;

TimelineCommand::TimelineCommand(qint64 startTimeMs,
                                 const QString &targetDeviceId,
                                 const QString &commandName,
                                 const QVariantMap &commandParams,
                                 DeviceCommand *targetCommand,
                                 QObject *parent)
    : QObject(parent)
    , m_id(createTimelineCommandId())
    , m_startTimeMs(qMax<qint64>(0, startTimeMs))
    , m_targetDeviceId(targetDeviceId.trimmed())
    , m_commandName(commandName)
    , m_commandParams(commandParams)
    , m_targetCommand(targetCommand)
{
    if (targetCommand) {
        connect(targetCommand, &QObject::destroyed, this, [this]() {
            m_targetCommand.clear();
            emit targetCommandDestroyed();
        });
    }
}

QString TimelineCommand::id() const
{
    return m_id;
}

qint64 TimelineCommand::startTimeMs() const
{
    return m_startTimeMs;
}

void TimelineCommand::setStartTimeMs(qint64 startTimeMs)
{
    const qint64 normalizedStartTimeMs = qMax<qint64>(0, startTimeMs);
    if (m_startTimeMs == normalizedStartTimeMs)
        return;

    m_startTimeMs = normalizedStartTimeMs;
    emit startTimeMsChanged();
}

QString TimelineCommand::targetDeviceId() const
{
    return m_targetDeviceId;
}

QString TimelineCommand::commandName() const
{
    return m_commandName;
}

QVariantMap TimelineCommand::commandParams() const
{
    return m_commandParams;
}

void TimelineCommand::setCommandParams(const QVariantMap &commandParams)
{
    if (m_commandParams == commandParams)
        return;

    m_commandParams = commandParams;
    emit commandParamsChanged();
}

DeviceCommand *TimelineCommand::targetCommand() const
{
    return m_targetCommand.data();
}

qint64 TimelineCommand::durationMs() const
{
    return qMax<qint64>(0, variantInt64(m_commandParams, QString::fromLatin1(kDurationMsKey), 0));
}

TimelineCommand::State TimelineCommand::state() const
{
    return m_state;
}

void TimelineCommand::setState(State state)
{
    if (m_state == state)
        return;

    m_state = state;
    emit stateChanged();
}

QString TimelineCommand::stateText() const
{
    switch (m_state) {
    case Running:
        return tr("运行中");
    case Succeeded:
        return tr("已成功");
    case Failed:
        return m_errorMessage.isEmpty() ? tr("已失败") : tr("失败：%1").arg(m_errorMessage);
    case Idle:
        break;
    }

    return tr("待执行");
}

QString TimelineCommand::stateColor() const
{
    switch (m_state) {
    case Running:
        return QStringLiteral("#f59e0b");
    case Succeeded:
        return QStringLiteral("#22c55e");
    case Failed:
        return QStringLiteral("#ef4444");
    case Idle:
        break;
    }

    return QStringLiteral("#334155");
}

QString TimelineCommand::errorMessage() const
{
    return m_errorMessage;
}

void TimelineCommand::setErrorMessage(const QString &errorMessage)
{
    if (m_errorMessage == errorMessage)
        return;

    m_errorMessage = errorMessage;
    emit errorMessageChanged();
}

void TimelineCommand::writeToStream(QDataStream &stream) const
{
    stream << m_id
           << m_startTimeMs
           << m_targetDeviceId
           << m_commandName
           << m_commandParams;
}

void TimelineCommand::readFromStream(QDataStream &stream)
{
    QString id;
    qint64 startTimeMs = 0;
    QString targetDeviceId;
    QString commandName;
    QVariantMap commandParams;

    stream >> id
           >> startTimeMs
           >> targetDeviceId
           >> commandName
           >> commandParams;

    if (stream.status() != QDataStream::Ok)
        return;

    if (m_targetCommand)
        disconnect(m_targetCommand.data(), nullptr, this, nullptr);

    m_id = id;
    m_targetDeviceId = targetDeviceId.trimmed();
    m_commandName = commandName;
    m_targetCommand.clear();
    m_state = Idle;
    m_errorMessage.clear();
    setStartTimeMs(startTimeMs);
    setCommandParams(commandParams);
}

TimelineCommandModel::TimelineCommandModel(QObject *parent)
    : TypedListModel<TimelineCommand *>(QByteArrayLiteral("command"), parent)
{
}

TimelineCommandModel::~TimelineCommandModel()
{
    qDeleteAll(items());
}

QList<TimelineCommand *> TimelineCommandModel::commands() const
{
    return items();
}

QVariantList TimelineCommandModel::commandVariants() const
{
    QVariantList result;
    result.reserve(items().size());

    for (TimelineCommand *command : items())
        result.append(QVariant::fromValue(command));

    return result;
}

TimelineCommand *TimelineCommandModel::commandAt(int row) const
{
    return itemAt(row);
}

TimelineCommand *TimelineCommandModel::commandById(const QString &id) const
{
    const QString normalizedId = id.trimmed();
    for (TimelineCommand *command : items()) {
        if (command->id() == normalizedId)
            return command;
    }

    return nullptr;
}

int TimelineCommandModel::indexOfCommand(TimelineCommand *command) const
{
    return command ? indexOfItem(command) : -1;
}

QString TimelineCommandModel::selectedCommandId() const
{
    return m_selectedCommandId;
}

void TimelineCommandModel::setSelectedCommandId(const QString &selectedCommandId)
{
    const QString normalizedSelectedCommandId = selectedCommandId.trimmed();
    if (m_selectedCommandId == normalizedSelectedCommandId)
        return;

    m_selectedCommandId = normalizedSelectedCommandId;
    emit selectedCommandIdChanged();
}

TimelineCommand *TimelineCommandModel::addDeviceCommand(qint64 startTimeMs,
                                                        const QString &targetDeviceId,
                                                        DeviceCommand *targetCommand,
                                                        const QVariantMap &extraParams)
{
    if (!targetCommand)
        return nullptr;

    QVariantMap commandParams = targetCommand->toJson().toVariantMap();
    for (auto it = extraParams.cbegin(); it != extraParams.cend(); ++it) {
        if (!it.key().trimmed().isEmpty())
            commandParams.insert(it.key(), it.value());
    }

    return addCommand(startTimeMs, targetDeviceId, targetCommand->name(), commandParams, targetCommand);
}

TimelineCommand *TimelineCommandModel::addCommand(qint64 startTimeMs,
                                                  const QString &targetDeviceId,
                                                  const QString &commandName,
                                                  const QVariantMap &commandParams,
                                                  DeviceCommand *targetCommand)
{
    auto *command = new TimelineCommand(startTimeMs,
                                        targetDeviceId,
                                        commandName,
                                        commandParams,
                                        targetCommand);
    if (!appendItem(command)) {
        command->deleteLater();
        return nullptr;
    }

    return command;
}

void TimelineCommandModel::resetCommands(const QList<TimelineCommand *> &commands)
{
    const QList<TimelineCommand *> oldCommands = items();
    if (resetItems(commands)) {
        qDeleteAll(oldCommands);
        if (!m_selectedCommandId.isEmpty() && !commandById(m_selectedCommandId))
            setSelectedCommandId(QString());
    }
}

void TimelineCommandModel::removeCommandAt(int row)
{
    TimelineCommand *command = commandAt(row);
    if (!command)
        return;

    const bool removesSelectedCommand = command->id() == m_selectedCommandId;
    if (removeItemAt(row)) {
        if (removesSelectedCommand) {
            TimelineCommand *nextCommand = commandAt(qMin(row, rowCount() - 1));
            setSelectedCommandId(nextCommand ? nextCommand->id() : QString());
        }
        command->deleteLater();
    }
}

bool TimelineCommandModel::removeCommand(TimelineCommand *command)
{
    const int row = indexOfCommand(command);
    if (row < 0)
        return false;

    removeCommandAt(row);
    return true;
}

void TimelineCommandModel::writeToStream(QDataStream &stream) const
{
    const QList<TimelineCommand *> currentItems = items();
    stream << currentItems.size();

    for (TimelineCommand *command : currentItems)
        command->writeToStream(stream);

    stream << m_selectedCommandId;
}

void TimelineCommandModel::readFromStream(QDataStream &stream)
{
    int commandCount = 0;
    stream >> commandCount;
    if (stream.status() != QDataStream::Ok || commandCount < 0)
        return;

    QList<TimelineCommand *> commands;
    commands.reserve(commandCount);
    for (int index = 0; index < commandCount; ++index) {
        auto *command = new TimelineCommand(0, QString(), QString(), QVariantMap(), nullptr, this);
        command->readFromStream(stream);
        if (stream.status() != QDataStream::Ok) {
            delete command;
            break;
        }
        commands.append(command);
    }

    QString selectedCommandId;
    if (stream.status() == QDataStream::Ok)
        stream >> selectedCommandId;

    if (stream.status() != QDataStream::Ok || commands.size() != commandCount) {
        qDeleteAll(commands);
        return;
    }

    resetCommands(commands);
    setSelectedCommandId(commandById(selectedCommandId) ? selectedCommandId : QString());
}

void TimelineCommandModel::removeCommandsForDevice(const QString &deviceId)
{
    const QString normalizedDeviceId = deviceId.trimmed();
    if (normalizedDeviceId.isEmpty())
        return;

    for (int row = rowCount() - 1; row >= 0; --row) {
        TimelineCommand *command = commandAt(row);
        if (command && command->targetDeviceId() == normalizedDeviceId)
            removeCommandAt(row);
    }
}

bool TimelineCommandModel::acceptsItem(TimelineCommand *command) const
{
    return command != nullptr;
}

void TimelineCommandModel::itemInserted(TimelineCommand *command, int row)
{
    Q_UNUSED(row)
    prepareCommand(command);
    emit commandsChanged();
}

void TimelineCommandModel::itemRemoved(TimelineCommand *command, int row)
{
    Q_UNUSED(row)
    disconnectCommand(command);
    emit commandsChanged();
}

void TimelineCommandModel::prepareCommand(TimelineCommand *command)
{
    if (!command)
        return;

    disconnectCommand(command);
    command->setParent(this);

    const auto notifyChanged = [this, command]() {
        emitCommandChanged(command);
    };

    connect(command, &TimelineCommand::startTimeMsChanged, this, notifyChanged);
    connect(command, &TimelineCommand::commandParamsChanged, this, notifyChanged);
    connect(command, &TimelineCommand::targetCommandDestroyed, this, [this, command]() {
        removeCommand(command);
    });
    connect(command, &TimelineCommand::stateChanged, this, notifyChanged);
    connect(command, &TimelineCommand::errorMessageChanged, this, notifyChanged);
}

void TimelineCommandModel::disconnectCommand(TimelineCommand *command)
{
    if (!command)
        return;

    disconnect(command, nullptr, this, nullptr);
    if (command->parent() == this)
        command->setParent(nullptr);
}

void TimelineCommandModel::emitCommandChanged(TimelineCommand *command)
{
    const int row = indexOfCommand(command);
    if (row < 0)
        return;

    notifyItemChanged(row);
    emit commandsChanged();
}

