#pragma once

#include <QObject>
#include <QString>
#include <QStringList>


class QDataStream;
class Timeline;
class TimelineCommand;
class TimelineClock;
class TimelineModel;
class Device;
class DeviceCommand;
class DeviceModel;

// 时间线管理器
//! 实例由 TimelineRuntime 创建并管理。
class TimelineManager final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(TimelineModel *timelineModel READ timelineModel CONSTANT FINAL)
    Q_PROPERTY(Timeline *currentTimeline READ currentTimeline NOTIFY currentTimelineChanged FINAL)
    Q_PROPERTY(Timeline *playbackTimeline READ playbackTimeline NOTIFY playbackChanged FINAL)
    Q_PROPERTY(bool queuePlayback READ queuePlayback NOTIFY playbackChanged FINAL)
    Q_PROPERTY(PlaybackState playbackState READ playbackState NOTIFY playbackStateChanged FINAL)
    Q_PROPERTY(qint64 currentTimeMs READ currentTimeMs NOTIFY currentTimeMsChanged FINAL)
    Q_PROPERTY(QStringList playQueue READ playQueue NOTIFY playQueueChanged FINAL)
    Q_PROPERTY(int playQueueIndex READ playQueueIndex NOTIFY playQueueIndexChanged FINAL)
    Q_PROPERTY(QStringList playbackDevices READ getPlaybackDevices WRITE setPlaybackDevices NOTIFY playbackDevicesChanged FINAL)

public:
    enum PlaybackState
    {
        Stopped,
        Running,
        Paused,
        Completed
    };
    Q_ENUM(PlaybackState)

    explicit TimelineManager(DeviceModel *deviceModel, QObject *parent = nullptr);
    // 查询
    TimelineModel *timelineModel() const;
    Timeline *currentTimeline() const;
    Timeline *playbackTimeline() const;
    bool queuePlayback() const;
    PlaybackState playbackState() const;
    qint64 currentTimeMs() const;
    Timeline *timelineById(const QString &id) const;
    QStringList playQueue() const;
    int playQueueIndex() const;

    // timeline 控制
    Q_INVOKABLE Timeline *createTimeline(const QString &name);
    Q_INVOKABLE Timeline *cloneTimeline(const QString &id, const QString &name);
    Timeline *addTimeline(const QString &id, const QString &name);
    Q_INVOKABLE bool removeTimeline(const QString &id);
    Q_INVOKABLE bool moveTimeline(int fromIndex, int toIndex);
    Q_INVOKABLE bool setCurrentTimelineId(const QString &id);

    // 播控
    Q_INVOKABLE bool waitForTrigger(const QString &id);
    Q_INVOKABLE bool triggerTimeline(const QString &id);
    Q_INVOKABLE bool setPlayQueue(const QStringList &timelineIds);
    Q_INVOKABLE bool startCurrentPlayback(qint64 startTimeMs = 0);
    Q_INVOKABLE bool startPlayback(const QStringList &timelineIds, qint64 startTimeMs = 0);
    Q_INVOKABLE void pausePlayback();
    Q_INVOKABLE void resumePlayback();
    Q_INVOKABLE void stopPlayback(bool notifyDevices = true);

    // 播控-过滤
    void setPlaybackDevices(const QStringList& ids);
    QStringList getPlaybackDevices() const;

    void writeToStream(QDataStream &stream) const;
    bool readFromStream(QDataStream &stream);
signals:
    void currentTimelineChanged(Timeline *timeline);
    void playbackChanged();
    void playbackStateChanged(PlaybackState state);
    void currentTimeMsChanged(qint64 currentTimeMs);
    void playQueueChanged();
    void playQueueIndexChanged(int index);
    void commandTriggered(Timeline *timeline, TimelineCommand *command);
    void deviceCommandTriggered(DeviceCommand *command);
    void playbackDevicesChanged(QStringList);
private:
    bool startTimeline(const QString &id, qint64 startTimeMs = 0);
    void updateTimeline(Timeline *timeline, qint64 clockTimeMs);
    void handleTimelineCompleted(Timeline *timeline);
    bool hasRunningTimeline() const;
    void bindCommandsForDevice(Device *device);
    void triggerSystemCommand(const QString &commandName);

    TimelineClock *m_clock = nullptr;
    TimelineModel *m_timelineModel = nullptr;
    DeviceModel *m_deviceModel = nullptr;
    Timeline *m_playbackTimeline = nullptr;
    bool m_queuePlayback = false;
    QStringList m_playQueue;
    int m_playQueueIndex = -1;
    QStringList m_playbackDevices;
};


Q_DECLARE_METATYPE(TimelineManager *)
