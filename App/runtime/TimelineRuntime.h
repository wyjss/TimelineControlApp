#pragma once

#include <UICore/Shell/BaseRuntime.h>
#include <UICore/Task/TaskManager.h>

#include <QString>
#include <QVariantMap>

class QDataStream;


class DeviceCommand;
class DeviceManager;
class DeviceModel;
class DeviceTemplateModel;
class DeviceExecutorManager;
class FenceManager;
class VideoProjectionPlanController;
class TimelineCommand;
class TimelineManager;


class TimelineRuntime final : public UICore::BaseRuntime
{
    Q_OBJECT
    Q_PROPERTY(UICore::TaskManager *taskManager READ taskManager CONSTANT FINAL)
    Q_PROPERTY(DeviceManager *deviceManager READ deviceManager CONSTANT FINAL)
    Q_PROPERTY(DeviceModel *deviceModel READ deviceModel CONSTANT FINAL)
    Q_PROPERTY(DeviceTemplateModel *deviceTemplateModel READ deviceTemplateModel CONSTANT FINAL)
    Q_PROPERTY(FenceManager *fenceManager READ fenceManager CONSTANT FINAL)
    Q_PROPERTY(TimelineManager *timelineManager READ timelineManager CONSTANT FINAL)
    Q_PROPERTY(QString currentPlanFilePath READ currentPlanFilePath NOTIFY currentPlanFilePathChanged FINAL)
    Q_PROPERTY(QString currentPlanName READ currentPlanName NOTIFY currentPlanFilePathChanged FINAL)

public:
    explicit TimelineRuntime(QObject *parent = nullptr);

    static TimelineRuntime* getInstance();

    UICore::TaskManager *taskManager() const;
    DeviceManager *deviceManager() const;
    DeviceModel *deviceModel() const;
    DeviceTemplateModel *deviceTemplateModel() const;
    FenceManager *fenceManager() const;
    TimelineManager *timelineManager() const;
    QString currentPlanFilePath() const;
    QString currentPlanName() const;

    void writePlanToStream(QDataStream &stream) const;
    void readPlanFromStream(QDataStream &stream);
    Q_INVOKABLE bool savePlanToFile(const QString &filePath);
    Q_INVOKABLE bool loadPlanFromFile(const QString &filePath);
    //! 独立测试设备指令，返回由 QML 持有的临时执行状态。
    Q_INVOKABLE TimelineCommand *testDeviceCommand(const QString &targetDeviceId,
                                                  DeviceCommand *deviceCommand,
                                                  const QVariantMap &executionInputValues);

signals:
    void currentPlanFilePathChanged();

private:
    void executeTimelineCommand(TimelineCommand *timelineCommand,
                                const QVariantMap &executionInputValues,
                                bool isTest);

    UICore::TaskManager *m_taskManager = nullptr;
    DeviceModel *m_deviceModel = nullptr;
    TimelineManager *m_timelineManager = nullptr;
    DeviceTemplateModel *m_deviceTemplateModel = nullptr;
    DeviceExecutorManager *m_deviceExecutorManager = nullptr;
    DeviceManager *m_deviceManager = nullptr;
    FenceManager *m_fenceManager = nullptr;
    VideoProjectionPlanController *m_videoProjectionPlanController = nullptr;
    QString m_currentPlanFilePath;
    int m_runId = 0;
};
