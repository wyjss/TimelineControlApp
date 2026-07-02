#pragma once

#include "runtime/app/BaseRuntime.h"

namespace TimelineControl {

class DeviceManager;
class DeviceModel;
class DeviceTemplateModel;
class DeviceInspectorFormProvider;
class VideoProjectionPlanController;
class TimelineController;
class TimelineCommandModel;

} // namespace TimelineControl

class TaskManager;

namespace TimelineControl {

class TimelineRuntime final : public EarthUI::BaseRuntime
{
    Q_OBJECT
    Q_PROPERTY(State state READ state WRITE setState NOTIFY stateChanged FINAL)
    Q_PROPERTY(TaskManager *taskManager READ taskManager CONSTANT FINAL)
    Q_PROPERTY(TimelineControl::DeviceManager *deviceManager READ deviceManager CONSTANT FINAL)
    Q_PROPERTY(TimelineControl::DeviceModel *deviceModel READ deviceModel CONSTANT FINAL)
    Q_PROPERTY(TimelineControl::DeviceTemplateModel *deviceTemplateModel READ deviceTemplateModel CONSTANT FINAL)
    Q_PROPERTY(TimelineControl::DeviceInspectorFormProvider *deviceInspectorFormProvider READ deviceInspectorFormProvider CONSTANT FINAL)
    Q_PROPERTY(TimelineControl::VideoProjectionPlanController *videoProjectionPlanController READ videoProjectionPlanController CONSTANT FINAL)
    Q_PROPERTY(TimelineControl::TimelineController *timelineController READ timelineController CONSTANT FINAL)
    Q_PROPERTY(TimelineControl::TimelineCommandModel *timelineCommandModel READ timelineCommandModel CONSTANT FINAL)

public:
    enum State
    {
        Stopped,
        Running,
        Paused
    };
    Q_ENUM(State)

    explicit TimelineRuntime(QObject *parent = nullptr);

    State state() const;
    void setState(State state);

    TaskManager *taskManager() const;
    DeviceManager *deviceManager() const;
    DeviceModel *deviceModel() const;
    DeviceTemplateModel *deviceTemplateModel() const;
    DeviceInspectorFormProvider *deviceInspectorFormProvider() const;
    VideoProjectionPlanController *videoProjectionPlanController() const;
    TimelineController *timelineController() const;
    TimelineCommandModel *timelineCommandModel() const;

signals:
    void stateChanged();

private:
    State m_state = Stopped;
    TaskManager *m_taskManager = nullptr;
    DeviceModel *m_deviceModel = nullptr;
    DeviceTemplateModel *m_deviceTemplateModel = nullptr;
    DeviceManager *m_deviceManager = nullptr;
    DeviceInspectorFormProvider *m_deviceInspectorFormProvider = nullptr;
    VideoProjectionPlanController *m_videoProjectionPlanController = nullptr;
    TimelineController *m_timelineController = nullptr;
    TimelineCommandModel *m_timelineCommandModel = nullptr;
};

} // namespace TimelineControl
