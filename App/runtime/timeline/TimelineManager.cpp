#include "timeline/TimelineManager.h"

#include "timeline/Timeline.h"
#include "timeline/TimelineClock.h"
#include "timeline/TimelineModel.h"
#include "timeline/TimelineCommandFilterModel.h"
#include "devices/CrossCondition.h"
#include "devices/CrossConditionModel.h"
#include "devices/Device.h"
#include "devices/DeviceModel.h"
#include "devices/DeviceCommand.h"
#include "devices/DeviceFilterModel.h"
#include "devices/DeviceConstants.h"

#include "LogMacros.h"

#include <QDataStream>
#include <QUuid>
#include <QtAlgorithms>

namespace {

constexpr quint32 kTimelineManagerMagic = 0x544C4D47;
constexpr qint32 kTimelineManagerVersion = 3;
} // namespace

TimelineManager::TimelineManager(DeviceModel *deviceModel, QObject *parent)
    : QObject(parent)
    , m_clock(new TimelineClock(this))
    , m_timelineModel(new TimelineModel(this))
    , m_deviceModel(deviceModel)
{
    m_filteredDeviceModel = new DeviceFilterModel(m_deviceModel, this);
    m_filteredCommandModel = new TimelineCommandFilterModel(m_deviceModel, this);

    connect(m_timelineModel, &TimelineModel::selectedItemChanged, this, [this]() {
        emit currentTimelineChanged(currentTimeline());
    });
    connect(m_clock, &TimelineClock::stateChanged, this, [this]() {
        emit playbackStateChanged(playbackState());
    });
    connect(m_clock, &TimelineClock::currentTimeMsChanged,
            this, [this]() {
        const qint64 clockTimeMs = m_clock->currentTimeMs();
        const QList<Timeline *> timelines = m_timelineModel->items();
        for (Timeline *timeline : timelines)
            updateTimeline(timeline, clockTimeMs);
        emit currentTimeMsChanged(clockTimeMs);
    });
    if (m_deviceModel) {
        connect(m_deviceModel, &DeviceModel::deviceAdded, this, [this](Device *device) {
            if (!device)
                return;

            connect(device, &Device::commandsChanged, this, [this, device]() {
                bindCommandsForDevice(device);
            });
            bindCommandsForDevice(device);
        });
    }
}

TimelineModel *TimelineManager::timelineModel() const
{
    return m_timelineModel;
}

Timeline *TimelineManager::currentTimeline() const
{
    return m_timelineModel->itemAt(m_timelineModel->selectedIndex());
}

Timeline *TimelineManager::playbackTimeline() const
{
    return m_playbackTimeline;
}

bool TimelineManager::queuePlayback() const
{
    return m_queuePlayback;
}

TimelineManager::PlaybackState TimelineManager::playbackState() const
{
    switch (m_clock->state()) {
    case TimelineClock::Running:
        return Running;
    case TimelineClock::Paused:
        return Paused;
    case TimelineClock::Completed:
        return Completed;
    default:
        return Stopped;
    }
}

qint64 TimelineManager::currentTimeMs() const
{
    return m_clock->currentTimeMs();
}

Timeline *TimelineManager::timelineById(const QString &id) const
{
    return m_timelineModel->timelineById(id);
}

QStringList TimelineManager::playQueue() const
{
    return m_playQueue;
}

int TimelineManager::playQueueIndex() const
{
    return m_playQueueIndex;
}

Timeline *TimelineManager::createTimeline(const QString &name)
{
    Timeline *timeline = addTimeline(QStringLiteral("timeline-%1")
                                         .arg(QUuid::createUuid().toString(QUuid::WithoutBraces)),
                                     name);
    if (timeline)
        setCurrentTimelineId(timeline->id());
    return timeline;
}

Timeline *TimelineManager::cloneTimeline(const QString &id, const QString &name)
{
    Timeline *source = timelineById(id);
    const QString normalizedName = name.trimmed();
    if (!source || normalizedName.isEmpty() || playbackState() != Stopped)
        return nullptr;

    Timeline *timeline = addTimeline(
        QStringLiteral("timeline-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces)),
        normalizedName);
    if (!timeline)
        return nullptr;

    for (TimelineCommand *command : source->commandModel()->commands()) {
        if (!timeline->commandModel()->addCommand(command->startTimeMs(),
                                                   command->targetDeviceId(),
                                                   command->commandName(),
                                                   command->executionInputValues(),
                                                   command->targetCommand(),
                                                   command->alias())) {
            removeTimeline(timeline->id());
            return nullptr;
        }
    }

    CrossConditionModel *sourceConditions = source->crossConditionModel();
    for (int index = 0; index < sourceConditions->count(); ++index) {
        CrossCondition *condition = sourceConditions->conditionAt(index);
        CrossCondition *copy = timeline->crossConditionModel()->addCondition(
            condition->locator(),
            condition->fence(),
            condition->heading(),
            condition->timeline());
        if (!copy) {
            removeTimeline(timeline->id());
            return nullptr;
        }
        copy->setEnabled(condition->isEnabled());
    }

    setCurrentTimelineId(timeline->id());
    return timeline;
}

Timeline *TimelineManager::addTimeline(const QString &id, const QString &name)
{
    const QString normalizedId = id.trimmed();
    const QString normalizedName = name.trimmed();
    if (normalizedId.isEmpty()
        || normalizedName.isEmpty()
        || timelineById(normalizedId))
        return nullptr;

    auto *timeline = new Timeline(normalizedId, normalizedName, this);
    if (!m_timelineModel->appendTimeline(timeline)) {
        delete timeline;
        return nullptr;
    }
    if (m_timelineModel->selectedIndex() < 0)
        m_timelineModel->setSelectedIndex(m_timelineModel->rowCount() - 1);
    return timeline;
}

bool TimelineManager::removeTimeline(const QString &id)
{
    Timeline *timeline = timelineById(id);
    const int index = m_timelineModel->indexOfItem(timeline);
    if (index < 0)
        return false;

    if (timeline == m_playbackTimeline || m_playQueue.contains(timeline->id()))
        stopPlayback();
    if (m_playQueue.contains(timeline->id())) {
        m_playQueue.removeAll(timeline->id());
        emit playQueueChanged();
    }
    if (timeline == currentTimeline() && m_timelineModel->rowCount() > 1) {
        m_timelineModel->setSelectedIndex(index == m_timelineModel->rowCount() - 1
            ? index - 1
            : index + 1);
    }
    timeline->stop();
    m_timelineModel->removeTimelineAt(index);
    timeline->deleteLater();
    return true;
}

bool TimelineManager::moveTimeline(int fromIndex, int toIndex)
{
    return m_timelineModel->moveTimeline(fromIndex, toIndex);
}

bool TimelineManager::setCurrentTimelineId(const QString &id)
{
    Timeline *timeline = timelineById(id);
    if (!timeline || currentTimeline() == timeline)
        return timeline;

    m_timelineModel->setSelectedIndex(m_timelineModel->indexOfItem(timeline));
    return true;
}

int TimelineManager::copiedDeviceCommandCount() const
{
    return m_copiedDeviceCommands.size();
}

QString TimelineManager::copyCommandsForDevice(const QString &deviceId)
{
    Timeline *timeline = currentTimeline();
    Device *device = m_deviceModel ? m_deviceModel->deviceById(deviceId) : nullptr;
    if (!timeline || !device)
        return tr("时间线或设备不存在");

    QVariantList commands;
    for (TimelineCommand *command : timeline->commandModel()->commands()) {
        if (command->targetDeviceId() != device->id())
            continue;
        DeviceCommand *targetCommand = command->targetCommand();
        if (!targetCommand)
            return tr("指令“%1”未关联设备指令，无法拷贝").arg(command->alias());
        commands.append(QVariantMap{
            {QStringLiteral("startTimeMs"), command->startTimeMs()},
            {QStringLiteral("commandName"), targetCommand->name()},
            {QStringLiteral("protocol"), targetCommand->protocol()},
            {QStringLiteral("commandType"), targetCommand->commandType()},
            {QStringLiteral("executionInputValues"), command->executionInputValues()},
            {QStringLiteral("alias"), command->alias()}
        });
    }
    if (commands.isEmpty())
        return tr("此设备在当前时间线中没有指令");

    m_copiedDeviceType = device->deviceType();
    m_copiedDeviceProtocols = device->supportedProtocols();
    m_copiedDeviceProtocols.sort();
    m_copiedDeviceCommands = commands;
    emit copiedDeviceCommandsChanged();
    return QString();
}

QString TimelineManager::pasteCommandsForDevice(const QString &deviceId)
{
    if (playbackState() != Stopped && playbackState() != Paused)
        return tr("请先停止或暂停播放，再粘贴指令");
    Timeline *timeline = currentTimeline();
    Device *device = m_deviceModel ? m_deviceModel->deviceById(deviceId) : nullptr;
    if (!timeline || !device)
        return tr("时间线或设备不存在");
    if (m_copiedDeviceCommands.isEmpty())
        return tr("请先拷贝设备的时间线指令");
    if (device->deviceType() != m_copiedDeviceType)
        return tr("设备类型不一致，无法粘贴");
    QStringList protocols = device->supportedProtocols();
    protocols.sort();
    if (protocols != m_copiedDeviceProtocols)
        return tr("设备协议不一致，无法粘贴");

    // 整批检查通过后再添加，全部绑定目标设备自己的指令。
    QList<DeviceCommand *> targetCommands;
    for (const QVariant &value : m_copiedDeviceCommands) {
        const QVariantMap command = value.toMap();
        const QString name = command.value(QStringLiteral("commandName")).toString();
        DeviceCommand *targetCommand = device->commandByName(name);
        if (!targetCommand)
            return tr("目标设备缺少指令“%1”，无法粘贴").arg(name);
        if (targetCommand->protocol() != command.value(QStringLiteral("protocol")).toString()
            || targetCommand->commandType() != command.value(QStringLiteral("commandType")).toString()
            || !device->supportsProtocol(targetCommand->protocol()))
            return tr("目标设备的指令“%1”协议或类型不一致，无法粘贴").arg(name);
        targetCommands.append(targetCommand);
    }

    for (int index = 0; index < m_copiedDeviceCommands.size(); ++index) {
        const QVariantMap command = m_copiedDeviceCommands.at(index).toMap();
        timeline->commandModel()->addDeviceCommand(
            command.value(QStringLiteral("startTimeMs")).toLongLong(),
            device->id(), targetCommands.at(index),
            command.value(QStringLiteral("executionInputValues")).toMap(),
            command.value(QStringLiteral("alias")).toString());
    }
    return QString();
}

bool TimelineManager::waitForTrigger(const QString &id)
{
    Timeline *timeline = timelineById(id);
    if (!timeline)
        return false;

    timeline->waitForTrigger();
    return true;
}

bool TimelineManager::triggerTimeline(const QString &id)
{
    Timeline *timeline = timelineById(id);

   // if (!timeline || timeline->state() != Timeline::Waiting)
    if (!timeline || timeline->state() == Timeline::Running)
        return false;

    return startTimeline(id);
}

bool TimelineManager::stopTimeline(const QString &id)
{
    Timeline *timeline = timelineById(id);
    if (!timeline || timeline->state() != Timeline::Running)
        return false;

    timeline->stop();
    const bool running = hasRunningTimeline();
    if (m_playbackTimeline == timeline || !running) {
        if (m_playQueueIndex != -1) {
            m_playQueueIndex = -1;
            emit playQueueIndexChanged(m_playQueueIndex);
        }
        m_playbackTimeline = nullptr;
        m_queuePlayback = false;
        emit playbackChanged();
    }
    if (!running)
        m_clock->stop();
    return true;
}

bool TimelineManager::startTimeline(const QString &id, qint64 startTimeMs)
{
    Timeline *timeline = timelineById(id);
    if (!timeline)
        return false;

    if (m_clock->state() != TimelineClock::Running)
        m_clock->start();
    const qint64 clockTimeMs = m_clock->currentTimeMs();
    timeline->start(clockTimeMs, startTimeMs);
    timeline->crossConditionModel()->activate();
    updateTimeline(timeline, clockTimeMs);
    return true;
}

bool TimelineManager::setPlayQueue(const QStringList &timelineIds)
{
    if (playbackState() != Stopped)
        return false;

    QStringList playQueue;
    playQueue.reserve(timelineIds.size());
    for (const QString &id : timelineIds) {
        const QString normalizedId = id.trimmed();
        if (normalizedId.isEmpty()
            || playQueue.contains(normalizedId)
            || !timelineById(normalizedId))
            return false;
        playQueue.append(normalizedId);
    }
    if (m_playQueue == playQueue)
        return true;

    m_playQueue = playQueue;
    emit playQueueChanged();
    return true;
}

bool TimelineManager::startCurrentPlayback(qint64 startTimeMs)
{
    Timeline *timeline = currentTimeline();
    if (!timeline)
        return false;

    stopPlayback();
    m_playbackTimeline = timeline;
    emit playbackChanged();
    return startTimeline(timeline->id(), startTimeMs);
}

bool TimelineManager::startPlayback(const QStringList &timelineIds, qint64 startTimeMs)
{
    QStringList playQueue;
    playQueue.reserve(timelineIds.size());
    for (const QString &id : timelineIds) {
        const QString normalizedId = id.trimmed();
        if (normalizedId.isEmpty()
            || playQueue.contains(normalizedId)
            || !timelineById(normalizedId))
            return false;
        playQueue.append(normalizedId);
    }
    if (playQueue.isEmpty())
        return false;

    stopPlayback();
    if (m_playQueue != playQueue) {
        m_playQueue = playQueue;
        emit playQueueChanged();
    }
    m_playQueueIndex = 0;
    emit playQueueIndexChanged(m_playQueueIndex);
    m_queuePlayback = true;
    m_playbackTimeline = timelineById(m_playQueue.constFirst());
    emit playbackChanged();
    for (const QString &id : m_playQueue) {
        Timeline *timeline = timelineById(id);
        timeline->stop();
        timeline->waitForTrigger();
    }
    return startTimeline(m_playQueue.constFirst(), startTimeMs);
}

void TimelineManager::pausePlayback()
{
    LOG_INFO("pausePlayback");
    if (m_clock->state() != TimelineClock::Running)
        return;

    // 暂停先执行时钟
    m_clock->pause();
    triggerSystemCommand(DeviceKey::SystemPause);
}

void TimelineManager::resumePlayback()
{
    LOG_INFO("resumePlayback");
    if (m_clock->state() != TimelineClock::Paused)
        return;

    triggerSystemCommand(DeviceKey::SystemResume);
    m_clock->start();
}

bool TimelineManager::seekTimeline(const QString &id, qint64 timeMs)
{
    Timeline *timeline = timelineById(id);
    if (playbackState() != Paused || !timeline || timeline->state() != Timeline::Running)
        return false;

    const qint64 targetTimeMs = qBound<qint64>(0, timeMs, timeline->commandModel()->realDurationMs());
    if (targetTimeMs != timeline->currentTimeMs())
        timeline->seek(m_clock->currentTimeMs(), targetTimeMs);
    return true;
}

void TimelineManager::stopPlayback(bool notifyDevices)
{
    LOG_INFO("stopPlayback");
    notifyDevices = notifyDevices && m_clock->state() != TimelineClock::Stopped;
    if (notifyDevices)
        triggerSystemCommand(DeviceKey::SystemStop);

    for (Timeline *timeline : m_timelineModel->items())
        timeline->stop();
    if (m_playQueueIndex != -1) {
        m_playQueueIndex = -1;
        emit playQueueIndexChanged(m_playQueueIndex);
    }
    m_clock->stop();
    if (m_playbackTimeline || m_queuePlayback) {
        m_playbackTimeline = nullptr;
        m_queuePlayback = false;
        emit playbackChanged();
    }

   
}

void TimelineManager::triggerSystemCommand(const QString &commandName)
{
    if (!m_deviceModel)
        return;

    // 查找所有存在指令的设备
    QSet<QString> devIdSet;
    for (auto timeline : m_timelineModel->items()) {
        // 过滤未启动的
        if (timeline->state() == Timeline::Stopped ||
            timeline->state() ==  Timeline::Waiting) {
            continue;
        }

        //
        for (auto cmd : timeline->commandModel()->items()) {
            devIdSet.insert(cmd->targetDeviceId());
        }
        
    }

    for (Device *device : m_deviceModel->items()) {
        // 被过滤的
        if (m_executionFilterEnabled && !matchesDeviceFilter(device->id())) {
            continue;
        }
        
        // 无调用指令的
        if (devIdSet.contains(device->id()) == false) {
            continue;
        }

        // 无对应系统指令的
        DeviceCommand *command = device->commandByName(commandName);
        if (!command)
            continue;

        // do
        emit deviceCommandTriggered(command);
    }
}

QStringList TimelineManager::filterDeviceIds() const
{
    return m_filterDeviceIds;
}

void TimelineManager::setFilterDeviceIds(const QStringList &deviceIds)
{
    if (m_executionFilterEnabled && playbackState() != Stopped)
        return;

    if (m_filterDeviceIds == deviceIds)
        return;

    m_filterDeviceIds = deviceIds;
    emit filterDeviceIdsChanged();
}

QStringList TimelineManager::filterGroupNames() const
{
    return m_filterGroupNames;
}

void TimelineManager::setFilterGroupNames(const QStringList &groupNames)
{
    if (m_executionFilterEnabled && playbackState() != Stopped)
        return;

    if (m_filterGroupNames == groupNames)
        return;

    m_filterGroupNames = groupNames;
    emit filterGroupNamesChanged();
}

bool TimelineManager::executionFilterEnabled() const
{
    return m_executionFilterEnabled;
}

void TimelineManager::setExecutionFilterEnabled(bool enabled)
{
    if (playbackState() != Stopped)
        return;

    if (m_executionFilterEnabled == enabled)
        return;

    m_executionFilterEnabled = enabled;
    emit executionFilterEnabledChanged();
}

bool TimelineManager::showFilteredOut() const
{
    return m_showFilteredOut;
}

void TimelineManager::setShowFilteredOut(bool show)
{
    if (m_showFilteredOut == show)
        return;

    m_showFilteredOut = show;
    emit showFilteredOutChanged();
}

QAbstractItemModel *TimelineManager::filteredDeviceModel() const
{
    return m_filteredDeviceModel;
}

QAbstractItemModel *TimelineManager::filteredCommandModel() const
{
    return m_filteredCommandModel;
}

bool TimelineManager::matchesDeviceFilter(const QString &deviceId) const
{
    // 无过滤
    if (m_filterDeviceIds.isEmpty() && m_filterGroupNames.isEmpty()) {
		return true;
    }

	// id匹配
	if (m_filterDeviceIds.contains(deviceId)) {
		return true;
	}
   
    // 组匹配
	Device* device = m_deviceModel ? m_deviceModel->deviceById(deviceId) : nullptr;
    if (!device) {
		return false;
    }
	for (const QString& groupName : device->groupNames()) {
        if (m_filterGroupNames.contains(groupName)) {
			return true;
        }
	}

    return false;
}


void TimelineManager::writeToStream(QDataStream &stream) const
{
    const QList<Timeline *> timelines = m_timelineModel->items();
    stream << kTimelineManagerMagic
           << kTimelineManagerVersion
           << (currentTimeline() ? currentTimeline()->id() : QString())
           << timelines.size();
    for (Timeline *timeline : timelines)
        timeline->writeToStream(stream);
    stream << m_playQueue;
}

bool TimelineManager::readFromStream(QDataStream &stream)
{
    quint32 magic = 0;
    qint32 version = 0;
    QString currentTimelineId;
    int timelineCount = 0;
    stream >> magic
           >> version
           >> currentTimelineId
           >> timelineCount;
    if (stream.status() != QDataStream::Ok
        || magic != kTimelineManagerMagic
        || version < 1
        || version > kTimelineManagerVersion
        || timelineCount < 0) {
        stream.setStatus(QDataStream::ReadCorruptData);
        return false;
    }

    QList<Timeline *> timelines;
    QStringList timelineIds;
    timelines.reserve(timelineCount);
    timelineIds.reserve(timelineCount);
    for (int index = 0; index < timelineCount; ++index) {
        Timeline *timeline = Timeline::readFromStream(stream,
                                                      version,
                                                      this);
        if (!timeline || timelineIds.contains(timeline->id())) {
            delete timeline;
            qDeleteAll(timelines);
            stream.setStatus(QDataStream::ReadCorruptData);
            return false;
        }
        timelines.append(timeline);
        timelineIds.append(timeline->id());
    }

    QStringList playQueue;
    if (version >= 3)
        stream >> playQueue;
    for (const QString &id : playQueue) {
        if (!timelineIds.contains(id) || playQueue.count(id) > 1)
            stream.setStatus(QDataStream::ReadCorruptData);
    }
    if (stream.status() != QDataStream::Ok) {
        qDeleteAll(timelines);
        return false;
    }

    int currentTimelineIndex = -1;
    for (int index = 0; index < timelines.size(); ++index) {
        if (timelines.at(index)->id() == currentTimelineId) {
            currentTimelineIndex = index;
            break;
        }
    }
    if (!currentTimelineId.isEmpty() && currentTimelineIndex < 0) {
        qDeleteAll(timelines);
        stream.setStatus(QDataStream::ReadCorruptData);
        return false;
    }

    stopPlayback(false);
    setFilterDeviceIds({});
    setFilterGroupNames({});
    setExecutionFilterEnabled(false);
    const QList<Timeline *> oldTimelines = m_timelineModel->items();
    if (!m_timelineModel->resetTimelines(timelines)) {
        qDeleteAll(timelines);
        stream.setStatus(QDataStream::ReadCorruptData);
        return false;
    }
    qDeleteAll(oldTimelines);
    m_timelineModel->setSelectedIndex(currentTimelineIndex);
    if (m_playQueue != playQueue) {
        m_playQueue = playQueue;
        emit playQueueChanged();
    }
    if (m_deviceModel) {
        for (Device *device : m_deviceModel->items())
            bindCommandsForDevice(device);
    }
    return true;
}

void TimelineManager::bindCommandsForDevice(Device *device)
{
    if (!device)
        return;

    for (Timeline *timeline : m_timelineModel->items()) {
        for (TimelineCommand *command : timeline->commandModel()->commands()) {
            if (!command || command->targetDeviceId() != device->id())
                continue;

            DeviceCommand *targetCommand = device->commandByName(command->commandName());
            if (targetCommand || !command->targetCommand())
                command->setTargetCommand(targetCommand);
        }
    }
}

void TimelineManager::updateTimeline(Timeline *timeline, qint64 clockTimeMs)
{
    if (!timeline)
        return;

    const Timeline::State previousState = timeline->state();
    const QList<TimelineCommand *> commands = timeline->updateTime(clockTimeMs);
    for (TimelineCommand* command : commands) {
        if (!m_executionFilterEnabled || matchesDeviceFilter(command->targetDeviceId())) {
            emit commandTriggered(timeline, command);
        } else {
            command->setState(TimelineCommand::Skipped);
        }
    }
    if (previousState == Timeline::Running
        && timeline->state() == Timeline::Completed)
        handleTimelineCompleted(timeline);
}

void TimelineManager::handleTimelineCompleted(Timeline *timeline)
{
    if (m_playQueueIndex >= 0
        && m_playQueueIndex < m_playQueue.size()
        && m_playQueue.at(m_playQueueIndex) == timeline->id()) {
        ++m_playQueueIndex;
        if (m_playQueueIndex < m_playQueue.size()) {
            emit playQueueIndexChanged(m_playQueueIndex);
            m_playbackTimeline = timelineById(m_playQueue.at(m_playQueueIndex));
            emit playbackChanged();
            startTimeline(m_playQueue.at(m_playQueueIndex));
            return;
        }

        m_playQueueIndex = -1;
        emit playQueueIndexChanged(m_playQueueIndex);
        m_playbackTimeline = nullptr;
        emit playbackChanged();
    }
    if (!hasRunningTimeline())
        m_clock->setState(TimelineClock::Completed);
}

bool TimelineManager::hasRunningTimeline() const
{
    for (Timeline *timeline : m_timelineModel->items()) {
        if (timeline->state() == Timeline::Running)
            return true;
    }
    return false;
}
