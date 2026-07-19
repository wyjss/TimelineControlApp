#include "TimelineRuntime.h"

#include <QMetaType>

#include "devices/DeviceCommand.h"
#include "devices/DeviceCommandFactory.h"
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
#include "timeline/TimelinePlanController.h"
#include "runtime/task/TaskManager.h"
#include "runtime/form/AppForm.h"

#include <QDataStream>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QIODevice>
#include <QJsonObject>
#include <QPointer>
#include <QUrl>


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
    , m_timelinePlanController(new TimelinePlanController(m_timelineCommandModel,
                                                          m_timelineController,
                                                          this))
{
    qRegisterMetaType<DeviceCommand *>("DeviceCommand*");
    qRegisterMetaType<Device *>("Device*");
    qRegisterMetaType<DeviceTemplate *>("DeviceTemplate*");
    qRegisterMetaType<DeviceInspectorFormProvider *>("DeviceInspectorFormProvider*");
    qRegisterMetaType<EarthUI::AppForm *>("EarthUI::AppForm*");
    qRegisterMetaType<TaskManager *>("TaskManager*");
    qRegisterMetaType<DeviceManager *>("DeviceManager*");
    qRegisterMetaType<DeviceModel *>("DeviceModel*");
    qRegisterMetaType<DeviceTemplateModel *>("DeviceTemplateModel*");
    qRegisterMetaType<VideoProjectionPlanController *>("VideoProjectionPlanController*");
    qRegisterMetaType<TimelineController *>("TimelineController*");
    qRegisterMetaType<TimelineCommand *>("TimelineCommand*");
    qRegisterMetaType<TimelineCommandModel *>("TimelineCommandModel*");
    qRegisterMetaType<TimelinePlanController *>("TimelinePlanController*");

    connect(m_deviceModel, &DeviceModel::deviceRemoved,
            m_timelinePlanController, &TimelinePlanController::removeCommandsForDevice);
    connect(m_deviceModel, &DeviceModel::deviceRemoved,
            m_videoProjectionPlanController, &VideoProjectionPlanController::removeMappingsForPc);
    connect(m_timelineController, &TimelineController::stateChanged, this, [this]() {
        const State nextState = m_timelineController->state() == TimelineController::Running
            ? Running
            : (m_timelineController->state() == TimelineController::Paused ? Paused : Stopped);
        if (nextState == Stopped) {
            ++m_runId;
            for (TimelineCommand *command : m_timelineCommandModel->commands()) {
                if (command && command->state() == TimelineCommand::Running) {
                    command->setErrorMessage(tr("已停止"));
                    command->setState(TimelineCommand::Failed);
                }
            }
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
            if (!targetDevice) {
                timelineCommand->setErrorMessage(tr("目标设备不存在"));
                timelineCommand->setState(TimelineCommand::Failed);
                continue;
            }

            if (!targetDevice->supportsProtocol(commandProtocol)) {
                timelineCommand->setErrorMessage(tr("设备不支持该协议"));
                timelineCommand->setState(TimelineCommand::Failed);
                continue;
            }

            DeviceCommand *deviceCommand = DeviceCommandFactory::createFromJson(QJsonObject::fromVariantMap(commandParams), this);
            if (!deviceCommand) {
                timelineCommand->setErrorMessage(tr("无效指令"));
                timelineCommand->setState(TimelineCommand::Failed);
                continue;
            }

            timelineCommand->setState(TimelineCommand::Running);
            const int runId = m_runId;
            QPointer<TimelineCommand> timelineCommandGuard(timelineCommand);
            connect(m_deviceExecutorManager, &DeviceExecutorManager::executionFinished, deviceCommand, [this, runId, timelineCommandGuard, deviceCommand](DeviceCommand *finishedCommand, bool success, const QString &errorMessage) {
                if (finishedCommand != deviceCommand)
                    return;

                if (m_runId == runId && timelineCommandGuard) {
                    timelineCommandGuard->setErrorMessage(errorMessage);
                    timelineCommandGuard->setState(success ? TimelineCommand::Succeeded : TimelineCommand::Failed);
                }
                deviceCommand->deleteLater();
            });
            m_deviceExecutorManager->execute(targetDevice,
                                             deviceCommand,
                                             commandParams.value(QStringLiteral("executionInputFields")).toMap());
        }
    });

    const QString defaultPlanFilePath = QDir::current().filePath(QStringLiteral("default.tlplan"));
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

TimelinePlanController *TimelineRuntime::timelinePlanController() const
{
    return m_timelinePlanController;
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
    m_timelinePlanController->writeToStream(stream);
}

void TimelineRuntime::readPlanFromStream(QDataStream &stream)
{
    m_deviceModel->readFromStream(stream);
    if (stream.status() != QDataStream::Ok)
        return;

    m_timelineCommandModel->readFromStream(stream);
    if (stream.status() != QDataStream::Ok)
        return;
    if (stream.device() && stream.device()->atEnd()) {
        m_timelinePlanController->resetFromCurrentModel();
        return;
    }

    m_videoProjectionPlanController->readFromStream(stream);
    if (stream.status() != QDataStream::Ok)
        return;
    if (stream.device() && stream.device()->atEnd()) {
        m_timelinePlanController->resetFromCurrentModel();
        return;
    }
    if (!m_timelinePlanController->readFromStream(stream))
        stream.setStatus(QDataStream::ReadCorruptData);
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
