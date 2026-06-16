#include "TimelineRuntime.h"

#include <QMetaType>

#include "devices/DeviceCommand.h"
#include "devices/DeviceCommand_Dmx512.h"
#include "devices/DeviceCommand_Http.h"
#include "devices/DeviceCommand_PC.h"
#include "devices/DeviceCommand_Serial.h"
#include "devices/DeviceManager.h"
#include "runtime/task/TaskManager.h"

namespace TimelineControl {

TimelineRuntime::TimelineRuntime(QObject *parent)
    : BaseRuntime(parent)
    , m_taskManager(new TaskManager(this))
    , m_deviceManager(new DeviceManager(this))
{
    qRegisterMetaType<TimelineControl::DeviceCommand *>("TimelineControl::DeviceCommand*");
    qRegisterMetaType<TimelineControl::DeviceCommand_Dmx512 *>("TimelineControl::DeviceCommand_Dmx512*");
    qRegisterMetaType<TimelineControl::DeviceCommand_Http *>("TimelineControl::DeviceCommand_Http*");
    qRegisterMetaType<TimelineControl::DeviceCommand_PC *>("TimelineControl::DeviceCommand_PC*");
    qRegisterMetaType<TimelineControl::DeviceCommand_Serial *>("TimelineControl::DeviceCommand_Serial*");
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
