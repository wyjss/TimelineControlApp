#include "TimelineRuntime.h"

#include <QMetaType>

#include "devices/DeviceManager.h"
#include "runtime/task/TaskManager.h"

namespace TimelineControl {

TimelineRuntime::TimelineRuntime(QObject *parent)
    : BaseRuntime(parent)
    , m_taskManager(new TaskManager(this))
    , m_deviceManager(new DeviceManager(this))
{
    qRegisterMetaType<TaskManager *>("TaskManager*");
    qRegisterMetaType<TimelineControl::DeviceManager *>("TimelineControl::DeviceManager*");
}

TaskManager *TimelineRuntime::taskManager() const
{
    return m_taskManager;
}

DeviceManager *TimelineRuntime::deviceManager() const
{
    return m_deviceManager;
}

} // namespace TimelineControl
