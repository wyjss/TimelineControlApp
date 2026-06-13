#pragma once

#include "runtime/app/BaseRuntime.h"

namespace TimelineControl {

class DeviceManager;

} // namespace TimelineControl

class TaskManager;

namespace TimelineControl {

class TimelineRuntime final : public EarthUI::BaseRuntime
{
    Q_OBJECT
    Q_PROPERTY(TaskManager *taskManager READ taskManager CONSTANT FINAL)
    Q_PROPERTY(TimelineControl::DeviceManager *deviceManager READ deviceManager CONSTANT FINAL)

public:
    explicit TimelineRuntime(QObject *parent = nullptr);

    TaskManager *taskManager() const;
    DeviceManager *deviceManager() const;

private:
    TaskManager *m_taskManager = nullptr;
    DeviceManager *m_deviceManager = nullptr;
};

} // namespace TimelineControl
