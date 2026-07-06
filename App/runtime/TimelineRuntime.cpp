#include "TimelineRuntime.h"

#include <QMetaType>

#include "devices/DeviceCommand.h"
#include "devices/DeviceCommand_Dmx512.h"
#include "devices/DeviceCommand_Http.h"
#include "devices/DeviceCommand_PC.h"
#include "devices/DeviceCommand_Serial.h"
#include "devices/DeviceConstants.h"
#include "devices/DeviceInspectorFormProvider.h"
#include "devices/DeviceManager.h"
#include "devices/DeviceModel.h"
#include "devices/Device.h"
#include "devices/DeviceTemplate.h"
#include "devices/DeviceTemplateModel.h"
#include "devices/executors/DeviceExecutorManager.h"
#include "projection/VideoProjectionPlanController.h"
#include "timeline/TimelineController.h"
#include "timeline/TimelineCommand.h"
#include "runtime/task/TaskManager.h"
#include "runtime/form/AppForm.h"

#include <QCoreApplication>
#include <QDataStream>
#include <QFile>
#include <QFileInfo>
#include <QIODevice>
#include <QJsonObject>
#include <QPointer>
#include <QUrl>

using namespace TimelineControl;

TimelineRuntime::TimelineRuntime(QObject *parent)
    : BaseRuntime(parent)
    , m_taskManager(new TaskManager(this))
    , m_deviceModel(new DeviceModel(this))
    , m_deviceTemplateModel(new DeviceTemplateModel(this))
    , m_deviceExecutorManager(new DeviceExecutorManager(this))
    , m_deviceManager(new DeviceManager(m_deviceModel, m_deviceTemplateModel, m_deviceExecutorManager, this))
    , m_deviceInspectorFormProvider(new DeviceInspectorFormProvider(m_deviceModel,
                                                                    m_deviceTemplateModel,
                                                                    this))
    , m_videoProjectionPlanController(new VideoProjectionPlanController(this))
    , m_timelineController(new TimelineController(this))
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
    qRegisterMetaType<TimelineControl::TimelineController *>("TimelineControl::TimelineController*");
    qRegisterMetaType<TimelineControl::TimelineCommand *>("TimelineControl::TimelineCommand*");
    qRegisterMetaType<TimelineControl::TimelineCommandModel *>("TimelineControl::TimelineCommandModel*");

    connect(m_deviceModel, &DeviceModel::deviceRemoved,
            m_timelineCommandModel, &TimelineCommandModel::removeCommandsForDevice);
    connect(m_deviceModel, &DeviceModel::deviceRemoved,
            m_videoProjectionPlanController, &VideoProjectionPlanController::removeMappingsForPc);
    connect(m_timelineController, &TimelineController::stateChanged, this, [this]() {
        const State nextState = m_timelineController->state() == TimelineController::Running
            ? Running
            : (m_timelineController->state() == TimelineController::Paused ? Paused : Stopped);
        if (nextState == Stopped) {
            ++m_runId;
            m_timelineController->setDurationMs(24 * 60 * 60 * 1000);
        }

        if (m_state == nextState)
            return;

        m_state = nextState;
        emit stateChanged();
    });
    connect(m_timelineController, &TimelineController::currentTimeMsChanged, this, [this]() {
        if (m_timelineController->state() != TimelineController::Running)
            return;

        const qint64 currentTimeMs = m_timelineController->currentTimeMs();
        for (TimelineCommand *timelineCommand : m_timelineCommandModel->commands()) {
            if (!timelineCommand
                || timelineCommand->state() != TimelineCommand::Idle
                || timelineCommand->startTimeMs() > currentTimeMs)
                continue;

            const QVariantMap commandParams = timelineCommand->commandParams();
            const QString commandProtocol = commandParams.value(DeviceKey::Protocol).toString().trimmed();
            Device *targetDevice = m_deviceModel ? m_deviceModel->deviceById(timelineCommand->targetDeviceId()) : nullptr;
            if (targetDevice && !targetDevice->supportsProtocol(commandProtocol)) {
                timelineCommand->setErrorMessage(tr("设备不支持该协议"));
                timelineCommand->setState(TimelineCommand::Failed);
                continue;
            }

            DeviceCommand *deviceCommand = DeviceCommand::createFromJson(QJsonObject::fromVariantMap(commandParams), this);
            if (!deviceCommand) {
                timelineCommand->setErrorMessage(tr("无效指令"));
                timelineCommand->setState(TimelineCommand::Failed);
                continue;
            }

            timelineCommand->setState(TimelineCommand::Running);
            const int runId = m_runId;
            QPointer<TimelineCommand> timelineCommandGuard(timelineCommand);
            connect(deviceCommand, &DeviceCommand::executionFinished, this, [this, runId, timelineCommandGuard, deviceCommand](bool success, const QString &errorMessage) {
                if (m_runId == runId && timelineCommandGuard) {
                    timelineCommandGuard->setErrorMessage(errorMessage);
                    timelineCommandGuard->setState(success ? TimelineCommand::Succeeded : TimelineCommand::Failed);
                }
                deviceCommand->deleteLater();
            });
            deviceCommand->execute();
        }
    });

    const QString defaultPlanFilePath = QCoreApplication::applicationDirPath() + QStringLiteral("/default.tlplan");
    if (QFile::exists(defaultPlanFilePath))
        loadPlanFromFile(defaultPlanFilePath);
}

TimelineRuntime::State TimelineRuntime::state() const
{
    return m_state;
}

void TimelineRuntime::setState(State state)
{
    if (state == Running) {
        startTimeline();
        return;
    }

    if (m_timelineController) {
        const TimelineController::State controllerState = state == Paused
            ? TimelineController::Paused
            : TimelineController::Stopped;
        if (m_timelineController->state() != controllerState)
            m_timelineController->setState(controllerState);
    }
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

TimelineController *TimelineRuntime::timelineController() const
{
    return m_timelineController;
}

TimelineCommandModel *TimelineRuntime::timelineCommandModel() const
{
    return m_timelineCommandModel;
}

QString TimelineRuntime::currentPlanFilePath() const
{
    return m_currentPlanFilePath;
}

QString TimelineRuntime::currentPlanName() const
{
    return QFileInfo(m_currentPlanFilePath).completeBaseName();
}

void TimelineRuntime::startTimeline()
{
    if (!m_timelineController)
        return;

    if (m_timelineController->state() == TimelineController::Stopped) {
        qint64 durationMs = 0;
        for (TimelineCommand *command : m_timelineCommandModel->commands()) {
            if (!command)
                continue;

            command->setState(TimelineCommand::Idle);
            command->setErrorMessage(QString());

            const qint64 endTimeMs = command->startTimeMs() + command->durationMs();
            if (durationMs < endTimeMs)
                durationMs = endTimeMs;
        }
        m_timelineController->setDurationMs(durationMs + 10 * 1000);
    }

    m_timelineController->start();
}

void TimelineRuntime::writePlanToStream(QDataStream &stream) const
{
    m_deviceModel->writeToStream(stream);
    m_timelineCommandModel->writeToStream(stream);
    m_videoProjectionPlanController->writeToStream(stream);
}

void TimelineRuntime::readPlanFromStream(QDataStream &stream)
{
    m_deviceModel->readFromStream(stream);
    if (stream.status() != QDataStream::Ok)
        return;

    m_timelineCommandModel->readFromStream(stream);
    if (stream.status() != QDataStream::Ok)
        return;
    if (stream.device() && stream.device()->atEnd())
        return;

    m_videoProjectionPlanController->readFromStream(stream);
}

bool TimelineRuntime::savePlanToFile(const QString &filePath)
{
    const QString normalizedFilePath = filePath.trimmed();
    if (normalizedFilePath.isEmpty())
        return false;

    const QUrl fileUrl(normalizedFilePath);
    QFile file(fileUrl.isLocalFile() ? fileUrl.toLocalFile() : normalizedFilePath);
    if (!file.open(QIODevice::WriteOnly))
        return false;

    QDataStream stream(&file);
    writePlanToStream(stream);
    if (stream.status() != QDataStream::Ok)
        return false;

    if (m_currentPlanFilePath != file.fileName()) {
        m_currentPlanFilePath = file.fileName();
        emit currentPlanFilePathChanged();
    }
    return true;
}

bool TimelineRuntime::loadPlanFromFile(const QString &filePath)
{
    const QString normalizedFilePath = filePath.trimmed();
    if (normalizedFilePath.isEmpty())
        return false;

    const QUrl fileUrl(normalizedFilePath);
    QFile file(fileUrl.isLocalFile() ? fileUrl.toLocalFile() : normalizedFilePath);
    if (!file.open(QIODevice::ReadOnly))
        return false;

    QDataStream stream(&file);
    readPlanFromStream(stream);
    if (stream.status() != QDataStream::Ok)
        return false;

    if (m_currentPlanFilePath != file.fileName()) {
        m_currentPlanFilePath = file.fileName();
        emit currentPlanFilePathChanged();
    }
    return true;
}
