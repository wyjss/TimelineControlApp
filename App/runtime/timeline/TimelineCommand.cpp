#include "timeline/TimelineCommand.h"
#include "timeline/Timeline.h"

#include "devices/Device.h"
#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"
#include "utils.h"

#define LC "[TimelineCommand] "
#include "LogMacros.h"

#include <QtAlgorithms>
#include <QDataStream>
#include <QFileInfo>
#include <QJsonObject>
#include <QMap>
#include <QUuid>

namespace {

const char *kExecutionInputValuesKey = "__executionInputValues";

} // namespace


TimelineCommand::TimelineCommand(qint64 startTimeMs,
                                 const QString &targetDeviceId,
                                 const QString &commandName,
                                 const QVariantMap &executionInputValues,
                                 DeviceCommand *targetCommand,
                                 const QString &alias,
                                 QObject *parent)
    : QObject(parent)
    , m_id(QStringLiteral("timeline-command-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces)))
    , m_startTimeMs(qMax<qint64>(0, startTimeMs))
    , m_targetDeviceId(targetDeviceId.trimmed())
    , m_commandName(commandName)
    , m_alias(alias.isEmpty() ? commandName : alias)
{
    setExecutionInputValues(executionInputValues);
    setTargetCommand(targetCommand);
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

QString TimelineCommand::alias() const
{
    return m_alias;
}

void TimelineCommand::setAlias(const QString &alias)
{
    const QString &value = alias.isEmpty() ? m_commandName : alias;
    if (m_alias == value)
        return;

    m_alias = value;
    emit aliasChanged();
}

QVariantMap TimelineCommand::executionInputValues() const
{
    return m_executionInputValues;
}

void TimelineCommand::setExecutionInputValues(const QVariantMap &executionInputValues)
{
    if (m_executionInputValues == executionInputValues)
        return;

    m_executionInputValues = executionInputValues;
    if (m_executionInputValues.contains(DeviceKey::Rect)) {
        LOG_WARN("存在废弃兼容字段Rect");
        QRect rect;
        if (Utils::rectFromString(m_executionInputValues[DeviceKey::Rect].toString(), rect)) {
            m_executionInputValues[DeviceKey::VideoWindowX] = rect.x();
            m_executionInputValues[DeviceKey::VideoWindowY] = rect.y();
            m_executionInputValues[DeviceKey::VideoWindowW] = rect.width();
            m_executionInputValues[DeviceKey::VideoWindowH] = rect.height();
        }
        m_executionInputValues.remove(DeviceKey::Rect);
    }
    emit executionInputValuesChanged();
    emit parametersChanged();
}

DeviceCommand *TimelineCommand::targetCommand() const
{
    return m_targetCommand.data();
}

void TimelineCommand::setTargetCommand(DeviceCommand *targetCommand)
{
    if (m_targetCommand == targetCommand)
        return;

    if (m_targetCommand)
        disconnect(m_targetCommand.data(), nullptr, this, nullptr);

    m_targetCommand = targetCommand;
    if (m_targetCommand) {
        connect(m_targetCommand, &DeviceCommand::fieldChanged,
                this, &TimelineCommand::parametersChanged);
        connect(m_targetCommand, &QObject::destroyed, this, [this]() {
            m_targetCommand.clear();
            emit targetCommandChanged();
            emit parametersChanged();
            emit targetCommandDestroyed();
        });
    }

    emit targetCommandChanged();
    emit parametersChanged();
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
    case Skipped:
        return tr("已跳过");
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
    case Skipped:
        return QStringLiteral("#64748b");
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
    const QVariantMap storedValues{
        {QString::fromLatin1(kExecutionInputValuesKey), m_executionInputValues}
    };
    stream << m_id
           << m_startTimeMs
           << m_targetDeviceId
           << m_commandName
           << m_alias
           << storedValues;
}

void TimelineCommand::readFromStream(QDataStream &stream)
{
    QString id;
    qint64 startTimeMs = 0;
    QString targetDeviceId;
    QString commandName;
    QString alias;
    QVariantMap storedValues;

    stream >> id
           >> startTimeMs
           >> targetDeviceId
           >> commandName
           >> alias
           >> storedValues;

    if (stream.status() != QDataStream::Ok)
        return;

    m_id = id;
    m_targetDeviceId = targetDeviceId.trimmed();
    m_commandName = commandName;
    setAlias(alias);
    setTargetCommand(nullptr);
    m_state = Idle;
    m_errorMessage.clear();
    setStartTimeMs(startTimeMs);
    setExecutionInputValues(storedValues.contains(QString::fromLatin1(kExecutionInputValuesKey))
                                ? storedValues.value(QString::fromLatin1(kExecutionInputValuesKey)).toMap()
                                : storedValues.value(QStringLiteral("executionInputFields")).toMap());
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

qint64 TimelineCommandModel::realDurationMs()
{
    if (m_realDurationNeedUpdate) {
        m_realDurationNeedUpdate = false;

        //LOG_DEBUG("updateRealDuration");
        qint64 realDurationMs = 0;
        for (TimelineCommand* command : items()) {
            if (command)
                realDurationMs = qMax(realDurationMs,
                                      command->startTimeMs());
        }

        m_realDurationMs = realDurationMs;
    }

    return m_realDurationMs;
}

void TimelineCommandModel::makeRealTimeChanged()
{
    if (!m_realDurationNeedUpdate) {
        m_realDurationNeedUpdate = true;
        emit realDurationMsChanged();
    }
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
    qSort(sortedCommands.begin(), sortedCommands.end(), [](TimelineCommand *left, TimelineCommand *right) {
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

        DeviceCommand *targetCommand = command->targetCommand();
        if (!targetCommand)
            continue;

        const QString commandType = targetCommand->commandType();
        const bool openVideo = commandType == QStringLiteral("openVideo");
        const bool playVideo = commandType == QStringLiteral("playVideo");
        const bool pauseVideo = commandType == QStringLiteral("pauseVideo");
        const bool closeVideo = commandType == QStringLiteral("closeVideo");
        const bool closePlayer = commandType == QStringLiteral("closePlayer");
        if (!openVideo && !playVideo && !pauseVideo && !closeVideo && !closePlayer)
            continue;

        const QVariantMap input = command->executionInputValues();
        QString source = Utils::getVideoRealSource(input.value(DeviceKey::VideoFile).toString());

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
                                                        const QVariantMap &executionInputValues,
                                                        const QString &alias)
{
    if (!targetCommand)
        return nullptr;

    return addCommand(startTimeMs,
                      targetDeviceId,
                      targetCommand->name(),
                      executionInputValues,
                      targetCommand,
                      alias);
}

bool TimelineCommandModel::updateCommand(TimelineCommand *command,
                                         qint64 startTimeMs,
                                         const QVariantMap &executionInputValues)
{
    if (indexOfCommand(command) < 0)
        return false;

    const auto *timeline = qobject_cast<Timeline *>(parent());
    const bool timelineStarted = timeline
        && (timeline->state() == Timeline::Running || timeline->state() == Timeline::Completed);
    const bool timeChanged = command->startTimeMs() != qMax<qint64>(0, startTimeMs);
    const bool preserveResult = timelineStarted && command->state() != TimelineCommand::Idle;
    if (preserveResult && !timeChanged
        && command->executionInputValues() == executionInputValues)
        return true;

    command->setStartTimeMs(startTimeMs);
    command->setExecutionInputValues(executionInputValues);
    if (!preserveResult || timeChanged) {
        command->setErrorMessage(QString());
        command->setState(timeChanged && timelineStarted && command->startTimeMs() < timeline->currentTimeMs()
                              ? TimelineCommand::Skipped : TimelineCommand::Idle);
    } else if (command->state() == TimelineCommand::Running) {
        command->setErrorMessage(tr("指令已修改，原执行结果已作废"));
        command->setState(TimelineCommand::Failed);
    }
    emit commandScheduleChanged(timeChanged ? command : nullptr);
    return true;
}

TimelineCommand *TimelineCommandModel::addCommand(qint64 startTimeMs,
                                                  const QString &targetDeviceId,
                                                  const QString &commandName,
                                                  const QVariantMap &executionInputValues,
                                                  DeviceCommand *targetCommand,
                                                  const QString &alias)
{
    auto *command = new TimelineCommand(startTimeMs,
                                        targetDeviceId,
                                        commandName,
                                        executionInputValues,
                                        targetCommand,
                                        alias);

    auto cmds = this->items();
    int targetIndex = cmds.size();
    for (int i = 0; i < cmds.size(); ++i) {
        if (cmds[i]->startTimeMs() > startTimeMs) {
            targetIndex = i;
            break;
        }
    }
    if (!insertItem(targetIndex, command)) {
        command->deleteLater();
        return nullptr;
    }

    emit commandScheduleChanged();
    return command;
}

void TimelineCommandModel::resetCommands(const QList<TimelineCommand *> &commands)
{
    const QList<TimelineCommand *> oldCommands = items();
    if (resetItems(commands)) {
        qDeleteAll(oldCommands);
        if (!m_selectedCommandId.isEmpty() && !commandById(m_selectedCommandId))
            setSelectedCommandId(QString());
        makeRealTimeChanged();
        emit commandsChanged();
        emit commandScheduleChanged();
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
        makeRealTimeChanged();
        emit commandsChanged();
        emit commandScheduleChanged();
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
        auto *command = new TimelineCommand(0, QString(), QString(), QVariantMap(), nullptr, QString(), this);
        command->readFromStream(stream);
        if (stream.status() != QDataStream::Ok) {
            delete command;
            break;
        }
        commands.append(command);
    }

    qSort(commands.begin(), commands.end(), [](TimelineCommand* l, TimelineCommand* r)->bool {
        return l->startTimeMs() < r->startTimeMs();
    });

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
    makeRealTimeChanged();
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

    connect(command, &TimelineCommand::startTimeMsChanged, this,
            [this, command]() {

                // 重排检测
                const int from = indexOfCommand(command);
                int to = from;
                while (to > 0 && commandAt(to - 1)->startTimeMs() > command->startTimeMs()) {
                    to--;
                }
                while (to < items().size() - 1 && commandAt(to + 1)->startTimeMs() < command->startTimeMs()) {
                    to++;
                }

                if (to != from) {
                    moveItem(from, to);
                }
                makeRealTimeChanged();
                emitCommandChanged(command);
            });

    connect(command, &TimelineCommand::aliasChanged, this, notifyChanged);
    connect(command, &TimelineCommand::parametersChanged, this, notifyChanged);
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

