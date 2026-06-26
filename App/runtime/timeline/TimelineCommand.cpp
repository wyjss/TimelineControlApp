#include "timeline/TimelineCommand.h"

namespace {

const char *kDurationMsKey = "durationMs";

qint64 variantInt64(const QVariantMap &map, const QString &key, qint64 fallback)
{
    bool ok = false;
    const qint64 value = map.value(key).toLongLong(&ok);
    return ok ? value : fallback;
}

} // namespace

namespace TimelineControl {

TimelineCommand::TimelineCommand(const QString &id,
                                 qint64 startTimeMs,
                                 const QString &targetDeviceId,
                                 const QString &commandName,
                                 const QVariantMap &commandParams,
                                 QObject *parent)
    : QObject(parent)
    , m_id(id.trimmed())
    , m_startTimeMs(qMax<qint64>(0, startTimeMs))
    , m_targetDeviceId(targetDeviceId.trimmed())
    , m_commandName(commandName)
    , m_commandParams(commandParams)
{
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
    : QAbstractListModel(parent)
{
}

TimelineCommandModel::~TimelineCommandModel()
{
    qDeleteAll(m_commands);
}

int TimelineCommandModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_commands.size();
}

QVariant TimelineCommandModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_commands.size())
        return {};

    TimelineCommand *command = m_commands.at(index.row());
    if (role == CommandRole || role == Qt::DisplayRole)
        return QVariant::fromValue(command);

    return {};
}

QHash<int, QByteArray> TimelineCommandModel::roleNames() const
{
    return {
        {CommandRole, QByteArrayLiteral("command")}
    };
}

QList<TimelineCommand *> TimelineCommandModel::commands() const
{
    return m_commands;
}

TimelineCommand *TimelineCommandModel::commandAt(int row) const
{
    return row >= 0 && row < m_commands.size() ? m_commands.at(row) : nullptr;
}

TimelineCommand *TimelineCommandModel::commandById(const QString &id) const
{
    const QString normalizedId = id.trimmed();
    for (TimelineCommand *command : m_commands) {
        if (command->id() == normalizedId)
            return command;
    }

    return nullptr;
}

int TimelineCommandModel::indexOfCommand(TimelineCommand *command) const
{
    return m_commands.indexOf(command);
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

void TimelineCommandModel::appendCommand(TimelineCommand *command)
{
    if (!command)
        return;

    const int row = m_commands.size();
    beginInsertRows(QModelIndex(), row, row);
    prepareCommand(command);
    m_commands.append(command);
    endInsertRows();
}

void TimelineCommandModel::resetCommands(const QList<TimelineCommand *> &commands)
{
    beginResetModel();
    qDeleteAll(m_commands);
    m_commands.clear();

    for (TimelineCommand *command : commands) {
        prepareCommand(command);
        m_commands.append(command);
    }

    endResetModel();
}

void TimelineCommandModel::removeCommandAt(int row)
{
    if (row < 0 || row >= m_commands.size())
        return;

    beginRemoveRows(QModelIndex(), row, row);
    TimelineCommand *command = m_commands.takeAt(row);
    endRemoveRows();

    if (command) {
        command->setParent(nullptr);
        command->deleteLater();
    }
}

void TimelineCommandModel::clear()
{
    if (m_commands.isEmpty())
        return;

    beginResetModel();
    qDeleteAll(m_commands);
    m_commands.clear();
    endResetModel();
}

void TimelineCommandModel::prepareCommand(TimelineCommand *command)
{
    if (!command)
        return;

    command->setParent(this);

    const auto notifyChanged = [this, command]() {
        emitCommandChanged(command);
    };

    connect(command, &TimelineCommand::startTimeMsChanged, this, notifyChanged);
    connect(command, &TimelineCommand::commandParamsChanged, this, notifyChanged);
    connect(command, &TimelineCommand::stateChanged, this, notifyChanged);
    connect(command, &TimelineCommand::errorMessageChanged, this, notifyChanged);
}

void TimelineCommandModel::emitCommandChanged(TimelineCommand *command)
{
    const int row = indexOfCommand(command);
    if (row < 0)
        return;

    const QModelIndex changedIndex = index(row, 0);
    emit dataChanged(changedIndex, changedIndex);
}

} // namespace TimelineControl
