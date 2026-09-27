#pragma once

#include <QAbstractItemModel>
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
class DeviceFilterModel;
class TimelineCommandFilterModel;

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
    Q_PROPERTY(QStringList filterDeviceIds READ filterDeviceIds WRITE setFilterDeviceIds NOTIFY filterDeviceIdsChanged FINAL)
    Q_PROPERTY(QStringList filterGroupNames READ filterGroupNames WRITE setFilterGroupNames NOTIFY filterGroupNamesChanged FINAL)
    Q_PROPERTY(bool executionFilterEnabled READ executionFilterEnabled WRITE setExecutionFilterEnabled NOTIFY executionFilterEnabledChanged FINAL)
    Q_PROPERTY(bool showFilteredOut READ showFilteredOut WRITE setShowFilteredOut NOTIFY showFilteredOutChanged FINAL)
    Q_PROPERTY(QAbstractItemModel *filteredDeviceModel READ filteredDeviceModel CONSTANT FINAL)
    Q_PROPERTY(QAbstractItemModel *filteredCommandModel READ filteredCommandModel CONSTANT FINAL)

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
    Q_INVOKABLE bool seekTimeline(const QString &id, qint64 timeMs);
    Q_INVOKABLE void stopPlayback(bool notifyDevices = true);

    // 过滤设置；设备和组条件为空时不限制
    // 满足任一过滤条件都通过
    // 
    // 设备id过滤，空表示不过滤
    QStringList filterDeviceIds() const;
    void setFilterDeviceIds(const QStringList &deviceIds);
    // 设备组过滤，空表示不过滤
    QStringList filterGroupNames() const;
    void setFilterGroupNames(const QStringList &groupNames);
    // 是否仅执行筛选范围内的播放指令
    bool executionFilterEnabled() const;
    void setExecutionFilterEnabled(bool enabled);
    // 被过滤设备和指令是否显示
    bool showFilteredOut() const;
    void setShowFilteredOut(bool show);
    // 过滤后的代理模型
    QAbstractItemModel *filteredDeviceModel() const;
    QAbstractItemModel *filteredCommandModel() const;
    // 判断设备是否过滤通过
    bool matchesDeviceFilter(const QString &deviceId) const;

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
    void filterDeviceIdsChanged();
    void filterGroupNamesChanged();
    void executionFilterEnabledChanged();
    void showFilteredOutChanged();
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
    QStringList m_filterDeviceIds;
    QStringList m_filterGroupNames;
    bool m_executionFilterEnabled = false;
    bool m_showFilteredOut = true;
    DeviceFilterModel *m_filteredDeviceModel = nullptr;
    TimelineCommandFilterModel *m_filteredCommandModel = nullptr;
};


Q_DECLARE_METATYPE(TimelineManager *)
