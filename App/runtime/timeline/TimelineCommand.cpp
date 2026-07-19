#include "timeline/TimelineCommand.h"

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"

#include <algorithm>
#include <QDataStream>
#include <QFileInfo>
#include <QJsonObject>
#include <QMap>
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

QVariantMap TimelineCommandModel::childTracksByParentId() const
{
    struct ChildTrackState
    {
        QString source;
        QString title;
        QVariantList segments;
        qint64 playingSinceMs = -1;
        bool opened = false;
    };
    struct ParentTrackState
    {
        QMap<QString, ChildTrackState> tracks;
        QStringList trackOrder;
    };

    QList<TimelineCommand *> sortedCommands = items();
    std::stable_sort(sortedCommands.begin(), sortedCommands.end(), [](TimelineCommand *left, TimelineCommand *right) {
        return left && right ? left->startTimeMs() < right->startTimeMs() : right != nullptr;
    });

    QMap<QString, ParentTrackState> parentStates;
    const auto closeSegment = [](ChildTrackState &state, qint64 endTimeMs) {
        if (state.playingSinceMs >= 0 && endTimeMs > state.playingSinceMs) {
            state.segments.append(QVariantMap{
                {QStringLiteral("startTimeMs"), state.playingSinceMs},
                {QStringLiteral("endTimeMs"), endTimeMs}
            });
        }
        state.playingSinceMs = -1;
    };

    for (TimelineCommand *command : sortedCommands) {
        if (!command || command->targetDeviceId().isEmpty())
            continue;

        const QVariantMap params = command->commandParams();
        const QString commandType = params.value(DeviceKey::CommandType).toString();
        const bool openVideo = commandType == QStringLiteral("openVideo");
        const bool playVideo = commandType == QStringLiteral("playVideo");
        const bool pauseVideo = commandType == QStringLiteral("pauseVideo");
        const bool closeVideo = commandType == QStringLiteral("closeVideo");
        const bool closePlayer = commandType == QStringLiteral("closePlayer");
        if (!openVideo && !playVideo && !pauseVideo && !closeVideo && !closePlayer)
            continue;

        const QVariantMap input = params.value(QStringLiteral("executionInputFields")).toMap();
        QString source = input.value(DeviceKey::VideoFile).toString().trimmed();
        if (source.startsWith(QLatin1Char('$')))
            source = DeviceConstants::LocalVideoPrefix + source.mid(1);

        ParentTrackState &parentState = parentStates[command->targetDeviceId()];
        const qint64 eventTimeMs = command->startTimeMs();
        if (openVideo) {
            if (source.isEmpty())
                continue;

            if (!parentState.tracks.contains(source)) {
                ChildTrackState state;
                state.source = source;
                state.title = QFileInfo(source).fileName();
                if (state.title.isEmpty())
                    state.title = source;
                parentState.tracks.insert(source, state);
                parentState.trackOrder.append(source);
            }

            ChildTrackState &state = parentState.tracks[source];
            closeSegment(state, eventTimeMs);
            state.opened = true;
            if (input.value(QStringLiteral("play"), true).toBool())
                state.playingSinceMs = eventTimeMs;
            continue;
        }

        QStringList targetSources;
        if (source.isEmpty())
            targetSources = parentState.trackOrder;
        else
            targetSources.append(source);

        for (const QString &targetSource : targetSources) {
            auto stateIt = parentState.tracks.find(targetSource);
            if (stateIt == parentState.tracks.end() || !stateIt->opened)
                continue;

            ChildTrackState &state = stateIt.value();
            if (playVideo) {
                if (state.playingSinceMs < 0)
                    state.playingSinceMs = eventTimeMs;
            } else if (pauseVideo) {
                closeSegment(state, eventTimeMs);
            } else if (closeVideo || closePlayer) {
                closeSegment(state, eventTimeMs);
                state.opened = false;
            }
        }
    }

    QVariantMap result;
    for (auto parentIt = parentStates.cbegin(); parentIt != parentStates.cend(); ++parentIt) {
        QVariantList childTracks;
        const ParentTrackState &parentState = parentIt.value();
        for (const QString &source : parentState.trackOrder) {
            const ChildTrackState &state = parentState.tracks[source];
            QVariantList segments = state.segments;
            if (state.playingSinceMs >= 0) {
                segments.append(QVariantMap{
                    {QStringLiteral("startTimeMs"), state.playingSinceMs},
                    {QStringLiteral("endTimeMs"), -1}
                });
            }

            childTracks.append(QVariantMap{
                {QStringLiteral("id"), QStringLiteral("video:%1:%2").arg(parentIt.key(), source)},
                {QStringLiteral("type"), QStringLiteral("video")},
                {QStringLiteral("title"), state.title},
                {QStringLiteral("detail"), state.source},
                {QStringLiteral("color"), QStringLiteral("#16a34a")},
                {QStringLiteral("segments"), segments}
            });
        }
        if (!childTracks.isEmpty())
            result.insert(parentIt.key(), childTracks);
    }
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

    const QVariantMap executionValues = extraParams.value(QStringLiteral("executionInputFields")).toMap();
    const QString commandName = targetCommand->resolvedParams(executionValues)
                                    .value(DeviceKey::Name, targetCommand->name()).toString();
    return addCommand(startTimeMs, targetDeviceId, commandName, commandParams, targetCommand);
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
        emit commandsChanged();
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
        emit commandsChanged();
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

