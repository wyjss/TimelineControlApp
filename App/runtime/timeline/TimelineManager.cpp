#include "timeline/TimelineManager.h"

#include "timeline/Timeline.h"
#include "timeline/TimelineClock.h"
#include "timeline/TimelineModel.h"
#include "devices/CrossCondition.h"
#include "devices/CrossConditionModel.h"
#include "devices/Device.h"
#include "devices/DeviceModel.h"
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

            device->setFilteredOut(!m_playbackDevices.isEmpty()
                                   && !m_playbackDevices.contains(device->id()));
            connect(device, &Device::commandsChanged, this, [this, device]() {
                bindCommandsForDevice(device);
            });
            bindCommandsForDevice(device);
        });
        connect(m_deviceModel, &DeviceModel::deviceRemoved, this, [this](const QString &deviceId) {
            QStringList playbackDevices = m_playbackDevices;
            if (playbackDevices.removeAll(deviceId) > 0)
                setPlaybackDevices(playbackDevices);
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
                                                   command->targetCommand())) {
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
    if (!timeline || timeline->state() != Timeline::Waiting)
        return false;

    return startTimeline(id);
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

    m_clock->pause();
    if (!m_deviceModel)
        return;

    for (auto dev : m_deviceModel->items()) {
        if (dev->filteredOut())
            continue;
        if (auto cmd = dev->commandByName(DeviceKey::SystemPause))
            emit deviceCommandTriggered(cmd);
    }
}

void TimelineManager::resumePlayback()
{
    LOG_INFO("resumePlayback");
    if (m_clock->state() != TimelineClock::Paused)
        return;

    m_clock->start();
    if (!m_deviceModel)
        return;

    for (auto dev : m_deviceModel->items()) {
        if (dev->filteredOut())
            continue;
        if (auto cmd = dev->commandByName(DeviceKey::SystemResume))
            emit deviceCommandTriggered(cmd);
    }
}

void TimelineManager::stopPlayback(bool notifyDevices)
{
    LOG_INFO("stopPlayback");
    notifyDevices = notifyDevices && m_clock->state() != TimelineClock::Stopped;
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

    if (!notifyDevices || !m_deviceModel)
        return;

    for (auto dev : m_deviceModel->items()) {
        if (dev->filteredOut())
            continue;
        if (auto cmd = dev->commandByName(DeviceKey::SystemStop))
            emit deviceCommandTriggered(cmd);
    }
}

void TimelineManager::setPlaybackDevices(const QStringList& ids)
{
    if (playbackState() != Stopped)
        return;

    QStringList playbackDevices;
    for (const QString &id : ids) {
        const QString deviceId = id.trimmed();
        if (!deviceId.isEmpty() && !playbackDevices.contains(deviceId)
            && (!m_deviceModel || m_deviceModel->deviceById(deviceId)))
            playbackDevices.append(deviceId);
    }
    if (playbackDevices == m_playbackDevices)
        return;

    m_playbackDevices = playbackDevices;
    if (m_deviceModel) {
        for (Device *device : m_deviceModel->items()) {
            if (device)
                device->setFilteredOut(!m_playbackDevices.isEmpty()
                                       && !m_playbackDevices.contains(device->id()));
        }
    }
    emit playbackDevicesChanged(m_playbackDevices);
}

QStringList TimelineManager::getPlaybackDevices() const
{
    return m_playbackDevices;
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
    setPlaybackDevices({});
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
        if (m_playbackDevices.isEmpty() || m_playbackDevices.contains(command->targetDeviceId())) {
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
