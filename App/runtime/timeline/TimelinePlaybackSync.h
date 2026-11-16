#pragma once

#include "timeline/TimelinePlaybackState.h"

#include <QHash>
#include <QObject>
#include <QPointer>
#include <QTimer>

class DeviceExecutorManager;
class DeviceModel;
class Timeline;
class TimelineManager;

//! 合并暂停拖拽请求，并将各播放类型的状态差异提交给设备执行器。
class TimelinePlaybackSync final : public QObject
{
public:
    TimelinePlaybackSync(TimelineManager *timelineManager,
                         DeviceModel *deviceModel,
                         DeviceExecutorManager *executorManager,
                         QObject *parent = nullptr);

    //! 接收暂停拖拽的目标时间线位置，单位毫秒。
    void requestPreview(Timeline *timeline, qint64 timeMs);

private:
    void flushPreview();

    TimelineManager *m_timelineManager;
    DeviceModel *m_deviceModel;
    DeviceExecutorManager *m_executorManager;
    QTimer m_previewTimer;
    QPointer<Timeline> m_pendingTimeline;
    qint64 m_pendingTimeMs = 0;
    //! 每条时间线上每台设备最近提交的状态。
    QHash<QString, QHash<QString, TimelinePlaybackState::Snapshot>> m_states;
};
