#pragma once

#include "runtime/app/BaseRuntime.h"

namespace TimelineControl {

class DeviceManager;
class DeviceModel;
class DeviceTemplateModel;
class DeviceInspectorFormProvider;
class VideoProjectionPlanController;
class TimelineCommandModel;
class TimelineManager;

} // namespace TimelineControl

class TaskManager;

namespace TimelineControl {

class TimelineRuntime final : public EarthUI::BaseRuntime
{
    Q_OBJECT
    Q_PROPERTY(TaskManager *taskManager READ taskManager CONSTANT FINAL)
    Q_PROPERTY(TimelineControl::DeviceManager *deviceManager READ deviceManager CONSTANT FINAL)
    Q_PROPERTY(TimelineControl::DeviceModel *deviceModel READ deviceModel CONSTANT FINAL)
    Q_PROPERTY(TimelineControl::DeviceTemplateModel *deviceTemplateModel READ deviceTemplateModel CONSTANT FINAL)
    Q_PROPERTY(TimelineControl::DeviceInspectorFormProvider *deviceInspectorFormProvider READ deviceInspectorFormProvider CONSTANT FINAL)
    Q_PROPERTY(TimelineControl::VideoProjectionPlanController *videoProjectionPlanController READ videoProjectionPlanController CONSTANT FINAL)
    Q_PROPERTY(TimelineControl::TimelineCommandModel *timelineCommandModel READ timelineCommandModel CONSTANT FINAL)
    Q_PROPERTY(TimelineControl::TimelineManager *timelineManager READ timelineManager CONSTANT FINAL)

public:
    explicit TimelineRuntime(QObject *parent = nullptr);

    TaskManager *taskManager() const;
    DeviceManager *deviceManager() const;
    DeviceModel *deviceModel() const;
    DeviceTemplateModel *deviceTemplateModel() const;
    DeviceInspectorFormProvider *deviceInspectorFormProvider() const;
    VideoProjectionPlanController *videoProjectionPlanController() const;
    TimelineCommandModel *timelineCommandModel() const;
    TimelineManager *timelineManager() const;

private:
    TaskManager *m_taskManager = nullptr;
    DeviceModel *m_deviceModel = nullptr;
    DeviceTemplateModel *m_deviceTemplateModel = nullptr;
    DeviceManager *m_deviceManager = nullptr;
    DeviceInspectorFormProvider *m_deviceInspectorFormProvider = nullptr;
    VideoProjectionPlanController *m_videoProjectionPlanController = nullptr;
    TimelineCommandModel *m_timelineCommandModel = nullptr;
    TimelineManager *m_timelineManager = nullptr;
};

} // namespace TimelineControl
