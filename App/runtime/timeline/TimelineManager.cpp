#include "timeline/TimelineManager.h"

#include "timeline/Timeline.h"
#include "timeline/TimelineClock.h"
#include "timeline/TimelineModel.h"

#include <QDataStream>
#include <QUuid>
#include <QtAlgorithms>

namespace {

constexpr quint32 kTimelineManagerMagic = 0x544C4D47;
constexpr qint32 kTimelineManagerVersion = 1;

} // namespace


TimelineManager::TimelineManager(QObject *parent)
    : QObject(parent)
    , m_clock(new TimelineClock(this))
    , m_timelineModel(new TimelineModel(this))
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
}

TimelineModel *TimelineManager::timelineModel() const
{
    return m_timelineModel;
}

Timeline *TimelineManager::currentTimeline() const
{
    return m_timelineModel->itemAt(m_timelineModel->selectedIndex());
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

    if (m_playQueue.contains(timeline->id())) {
        stopPlayback();
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

bool TimelineManager::startTimeline(const QString &id)
{
    Timeline *timeline = timelineById(id);
    if (!timeline)
        return false;

    if (m_clock->state() != TimelineClock::Running)
        m_clock->start();
    const qint64 clockTimeMs = m_clock->currentTimeMs();
    timeline->start(clockTimeMs);
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

bool TimelineManager::startPlayback(const QStringList &timelineIds)
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
    for (const QString &id : m_playQueue) {
        Timeline *timeline = timelineById(id);
        timeline->stop();
        timeline->waitForTrigger();
    }
    return startTimeline(m_playQueue.constFirst());
}

void TimelineManager::pausePlayback()
{
    if (m_clock->state() == TimelineClock::Running)
        m_clock->pause();
}

void TimelineManager::resumePlayback()
{
    if (m_clock->state() == TimelineClock::Paused)
        m_clock->start();
}

void TimelineManager::stopPlayback()
{
    for (Timeline *timeline : m_timelineModel->items())
        timeline->stop();
    if (m_playQueueIndex != -1) {
        m_playQueueIndex = -1;
        emit playQueueIndexChanged(m_playQueueIndex);
    }
    m_clock->stop();
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
        || version != kTimelineManagerVersion
        || timelineCount < 0) {
        stream.setStatus(QDataStream::ReadCorruptData);
        return false;
    }

    QList<Timeline *> timelines;
    QStringList timelineIds;
    timelines.reserve(timelineCount);
    timelineIds.reserve(timelineCount);
    for (int index = 0; index < timelineCount; ++index) {
        Timeline *timeline = Timeline::readFromStream(stream, this);
        if (!timeline || timelineIds.contains(timeline->id())) {
            delete timeline;
            qDeleteAll(timelines);
            stream.setStatus(QDataStream::ReadCorruptData);
            return false;
        }
        timelines.append(timeline);
        timelineIds.append(timeline->id());
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

    stopPlayback();
    if (!m_playQueue.isEmpty()) {
        m_playQueue.clear();
        emit playQueueChanged();
    }
    const QList<Timeline *> oldTimelines = m_timelineModel->items();
    if (!m_timelineModel->resetTimelines(timelines)) {
        qDeleteAll(timelines);
        stream.setStatus(QDataStream::ReadCorruptData);
        return false;
    }
    qDeleteAll(oldTimelines);
    m_timelineModel->setSelectedIndex(currentTimelineIndex);
    return true;
}

void TimelineManager::updateTimeline(Timeline *timeline, qint64 clockTimeMs)
{
    if (!timeline)
        return;

    const Timeline::State previousState = timeline->state();
    const QList<TimelineCommand *> commands = timeline->updateTime(clockTimeMs);
    for (TimelineCommand *command : commands)
        emit commandTriggered(timeline, command);
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
            startTimeline(m_playQueue.at(m_playQueueIndex));
            return;
        }

        m_playQueueIndex = -1;
        emit playQueueIndexChanged(m_playQueueIndex);
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
