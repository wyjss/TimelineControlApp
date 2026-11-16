#include "timeline/TimelinePlaybackSync.h"

#include "devices/Device.h"
#include "devices/DeviceModel.h"
#include "devices/executors/DeviceExecutorManager.h"
#include "timeline/Timeline.h"
#include "timeline/TimelineCommand.h"
#include "timeline/TimelineManager.h"

#include <QUuid>

TimelinePlaybackSync::TimelinePlaybackSync(TimelineManager *timelineManager,
                                           DeviceModel *deviceModel,
                                           DeviceExecutorManager *executorManager,
                                           QObject *parent)
    : QObject(parent)
    , m_timelineManager(timelineManager)
    , m_deviceModel(deviceModel)
    , m_executorManager(executorManager)
{
    m_previewTimer.setInterval(200);
    m_previewTimer.setSingleShot(true);
    connect(&m_previewTimer, &QTimer::timeout, this, &TimelinePlaybackSync::flushPreview);
    connect(m_timelineManager, &TimelineManager::currentTimelineChanged, this, [this]() {
        // 取消待发送的请求，保留已提交的状态供切回时比较。
        m_previewTimer.stop();
        m_pendingTimeline.clear();
    });
    connect(m_timelineManager, &TimelineManager::playbackStateChanged, this,
            [this](TimelineManager::PlaybackState state) {
        if (state == TimelineManager::Paused)
            return;

        m_previewTimer.stop();
        m_pendingTimeline.clear();
        m_states.clear();
    });
}

void TimelinePlaybackSync::requestPreview(Timeline *timeline, qint64 timeMs)
{
    if (m_timelineManager->playbackState() != TimelineManager::Paused
        || !timeline || timeline->state() != Timeline::Running)
        return;

    // 首次拖动时记录原状态，避免松手提交时间后才计算比较基准。
    const QList<TimelineCommand *> commands = timeline->commandModel()->commands();
    auto &states = m_states[timeline->id()];
    for (Device *device : m_deviceModel->items()) {
        if ((m_timelineManager->executionFilterEnabled()
             && !m_timelineManager->matchesDeviceFilter(device->id()))
            || states.contains(device->id()))
            continue;

        states.insert(device->id(), TimelinePlaybackState::stateAt(
            commands, *device, timeline->currentTimeMs()));
    }

    m_pendingTimeline = timeline;
    m_pendingTimeMs = timeMs;
    // 窗口内只覆盖目标位置，不重启定时器，持续拖动时仍定期同步。
    if (!m_previewTimer.isActive())
        m_previewTimer.start();
}

void TimelinePlaybackSync::flushPreview()
{
    Timeline *timeline = m_pendingTimeline.data();
    const qint64 timeMs = m_pendingTimeMs;
    m_pendingTimeline.clear();
    if (m_timelineManager->playbackState() != TimelineManager::Paused
        || !timeline || timeline->state() != Timeline::Running)
        return;

    const QList<TimelineCommand *> commands = timeline->commandModel()->commands();
    auto &states = m_states[timeline->id()];
    for (auto state = states.begin(); state != states.end(); ++state) {
        Device *device = m_deviceModel->deviceById(state.key());
        if (!device || (m_timelineManager->executionFilterEnabled()
                        && !m_timelineManager->matchesDeviceFilter(device->id())))
            continue;

        const auto after = TimelinePlaybackState::stateAt(commands, *device, timeMs);
        const auto previewCommands = TimelinePlaybackState::previewCommands(*device, state.value(), after);
        // 缺少必要命令时保留原基准，供下次拖拽重试。
        if (!previewCommands)
            continue;

        for (const auto &command : *previewCommands) {
            m_executorManager->execute(QUuid::createUuid().toString(QUuid::WithoutBraces),
                                       command.target, command.input);
        }
        // 保存本轮已提交给执行器的目标，作为下一轮拖动的比较基准。
        state.value() = after;
    }
}
