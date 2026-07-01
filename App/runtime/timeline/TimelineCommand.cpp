#include "timeline/TimelineCommand.h"

#include "devices/DeviceCommand.h"

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

TimelineCommand *TimelineCommandModel::lastCommand() const
{
    return m_lastCommand;
}

TimelineCommand *TimelineCommandModel::addCommand(qint64 startTimeMs,
                                                  const QString &targetDeviceId,
                                                  const QString &commandName,
                                                  const QVariantMap &commandParams)
{
    return addCommand(startTimeMs, targetDeviceId, commandName, commandParams, nullptr);
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

    setLastCommand(command);
    return command;
}

void TimelineCommandModel::clearCommands()
{
    if (items().isEmpty()) {
        setLastCommand(nullptr);
        return;
    }

    clear();
}

void TimelineCommandModel::appendCommand(TimelineCommand *command)
{
    appendItem(command);
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

bool TimelineCommandModel::removeCommandById(const QString &commandId)
{
    TimelineCommand *command = commandById(commandId);
    return removeCommand(command);
}

bool TimelineCommandModel::removeCommand(TimelineCommand *command)
{
    const int row = indexOfCommand(command);
    if (row < 0)
        return false;

    removeCommandAt(row);
    return true;
}

void TimelineCommandModel::clear()
{
    if (items().isEmpty())
        return;

    const QList<TimelineCommand *> oldCommands = items();
    clearItems();
    setSelectedCommandId(QString());
    qDeleteAll(oldCommands);
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
}

void TimelineCommandModel::itemRemoved(TimelineCommand *command, int row)
{
    Q_UNUSED(row)
    emit commandAboutToBeRemoved(command);
    if (m_lastCommand == command)
        setLastCommand(nullptr);
    disconnectCommand(command);
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
}

void TimelineCommandModel::setLastCommand(TimelineCommand *command)
{
    if (m_lastCommand == command)
        return;

    m_lastCommand = command;
    emit lastCommandChanged();
}

