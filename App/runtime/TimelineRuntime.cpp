#include "TimelineRuntime.h"

#include <QMetaType>

#include "devices/DeviceCommand.h"
#include "devices/DeviceCommand_Dmx512.h"
#include "devices/DeviceCommand_Http.h"
#include "devices/DeviceCommand_PC.h"
#include "devices/DeviceCommand_Serial.h"
#include "devices/DeviceInspectorFormProvider.h"
#include "devices/DeviceManager.h"
#include "devices/DeviceModel.h"
#include "devices/Device.h"
#include "devices/DeviceTemplate.h"
#include "devices/DeviceTemplateModel.h"
#include "projection/VideoProjectionPlanController.h"
#include "timeline/TimelineCommand.h"
#include "runtime/task/TaskManager.h"
#include "runtime/form/AppForm.h"

using namespace TimelineControl;

TimelineRuntime::TimelineRuntime(QObject *parent)
    : BaseRuntime(parent)
    , m_taskManager(new TaskManager(this))
    , m_deviceModel(new DeviceModel(this))
    , m_deviceTemplateModel(new DeviceTemplateModel(this))
    , m_deviceManager(new DeviceManager(m_deviceModel, m_deviceTemplateModel, this))
    , m_deviceInspectorFormProvider(new DeviceInspectorFormProvider(m_deviceModel,
                                                                    m_deviceTemplateModel,
                                                                    this))
    , m_videoProjectionPlanController(new VideoProjectionPlanController(this))
    , m_timelineCommandModel(new TimelineCommandModel(this))
{
    qRegisterMetaType<TimelineControl::DeviceCommand *>("TimelineControl::DeviceCommand*");
    qRegisterMetaType<TimelineControl::DeviceCommand_Dmx512 *>("TimelineControl::DeviceCommand_Dmx512*");
    qRegisterMetaType<TimelineControl::DeviceCommand_Http *>("TimelineControl::DeviceCommand_Http*");
    qRegisterMetaType<TimelineControl::DeviceCommand_PC *>("TimelineControl::DeviceCommand_PC*");
    qRegisterMetaType<TimelineControl::DeviceCommand_Serial *>("TimelineControl::DeviceCommand_Serial*");
    qRegisterMetaType<TimelineControl::Device *>("TimelineControl::Device*");
    qRegisterMetaType<TimelineControl::DeviceTemplate *>("TimelineControl::DeviceTemplate*");
    qRegisterMetaType<TimelineControl::DeviceInspectorFormProvider *>("TimelineControl::DeviceInspectorFormProvider*");
    qRegisterMetaType<EarthUI::AppForm *>("EarthUI::AppForm*");
    qRegisterMetaType<TaskManager *>("TaskManager*");
    qRegisterMetaType<TimelineControl::DeviceManager *>("TimelineControl::DeviceManager*");
    qRegisterMetaType<TimelineControl::DeviceModel *>("TimelineControl::DeviceModel*");
    qRegisterMetaType<TimelineControl::DeviceTemplateModel *>("TimelineControl::DeviceTemplateModel*");
    qRegisterMetaType<TimelineControl::VideoProjectionPlanController *>("TimelineControl::VideoProjectionPlanController*");
    qRegisterMetaType<TimelineControl::TimelineCommand *>("TimelineControl::TimelineCommand*");
    qRegisterMetaType<TimelineControl::TimelineCommandModel *>("TimelineControl::TimelineCommandModel*");

    connect(m_deviceModel, &DeviceModel::deviceRemoved,
            m_timelineCommandModel, &TimelineCommandModel::removeCommandsForDevice);
}

TaskManager *TimelineRuntime::taskManager() const
{
    return m_taskManager;
}

DeviceManager *TimelineRuntime::deviceManager() const
{
    return m_deviceManager;
}

DeviceModel *TimelineRuntime::deviceModel() const
{
    return m_deviceModel;
}

DeviceTemplateModel *TimelineRuntime::deviceTemplateModel() const
{
    return m_deviceTemplateModel;
}

DeviceInspectorFormProvider *TimelineRuntime::deviceInspectorFormProvider() const
{
    return m_deviceInspectorFormProvider;
}

VideoProjectionPlanController *TimelineRuntime::videoProjectionPlanController() const
{
    return m_videoProjectionPlanController;
}

TimelineCommandModel *TimelineRuntime::timelineCommandModel() const
{
    return m_timelineCommandModel;
}

