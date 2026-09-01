#include "TimelineRuntime.h"

#include <QMetaType>

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"
#include "devices/DeviceInspectorFormProvider.h"
#include "devices/DeviceManager.h"
#include "devices/DeviceModel.h"
#include "devices/Device.h"
#include "devices/DeviceTemplate.h"
#include "devices/DeviceTemplateModel.h"
#include "devices/executors/DeviceExecutorManager.h"
#include "location/FenceManager.h"
#include "projection/VideoProjectionPlanController.h"
#include "timeline/Timeline.h"
#include "timeline/TimelineCommand.h"
#include "timeline/TimelineManager.h"
#include "timeline/TimelineModel.h"
#include <UICore/Forms/AppForm.h>

#include <QDataStream>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QIODevice>
#include <QJsonObject>
#include <QPointer>
#include <QUrl>

namespace {

constexpr quint32 kTimelinePlanMagic = 0x544C504E;
constexpr qint32 kTimelinePlanVersion = 3;

} // namespace

namespace
{
    TimelineRuntime* g_TimelineRuntime = nullptr;
}
TimelineRuntime* TimelineRuntime::getInstance()
{
    return g_TimelineRuntime;
}

TimelineRuntime::TimelineRuntime(QObject *parent)
    : BaseRuntime(parent)
{
    g_TimelineRuntime = this;

    m_taskManager = (new UICore::TaskManager(this));
    m_deviceModel = (new DeviceModel(this));
	m_timelineManager = (new TimelineManager(m_deviceModel, this));
	m_deviceTemplateModel = (new DeviceTemplateModel(m_timelineManager->timelineModel(), this));
	m_deviceExecutorManager = (new DeviceExecutorManager(this));
	m_deviceManager = (new DeviceManager(m_deviceModel, m_deviceTemplateModel, m_deviceExecutorManager, this));
	m_deviceInspectorFormProvider = (new DeviceInspectorFormProvider(m_deviceModel,
																  m_deviceTemplateModel,
																  this));
	m_fenceManager = (new FenceManager(this));
	m_videoProjectionPlanController = (new VideoProjectionPlanController(this));

    qRegisterMetaType<DeviceCommand *>("DeviceCommand*");
    qRegisterMetaType<Device *>("Device*");
    qRegisterMetaType<DeviceTemplate *>("DeviceTemplate*");
    qRegisterMetaType<DeviceInspectorFormProvider *>("DeviceInspectorFormProvider*");
    qRegisterMetaType<UICore::AppForm *>("UICore::AppForm*");
    qRegisterMetaType<UICore::TaskManager *>("UICore::TaskManager*");
    qRegisterMetaType<DeviceManager *>("DeviceManager*");
    qRegisterMetaType<DeviceModel *>("DeviceModel*");
    qRegisterMetaType<DeviceTemplateModel *>("DeviceTemplateModel*");
    qRegisterMetaType<FenceManager *>("FenceManager*");
    qRegisterMetaType<VideoProjectionPlanController *>("VideoProjectionPlanController*");
    qRegisterMetaType<Timeline *>("Timeline*");
    qRegisterMetaType<TimelineCommand *>("TimelineCommand*");
    qRegisterMetaType<TimelineCommandModel *>("TimelineCommandModel*");
    qRegisterMetaType<TimelineManager *>("TimelineManager*");
    qRegisterMetaType<TimelineModel *>("TimelineModel*");

    connect(m_deviceModel, &DeviceModel::deviceRemoved, this, [this](const QString &deviceId) {
        for (Timeline *timeline : m_timelineManager->timelineModel()->items())
            timeline->commandModel()->removeCommandsForDevice(deviceId);
    });
    connect(m_deviceModel, &DeviceModel::deviceRemoved,
            m_videoProjectionPlanController, &VideoProjectionPlanController::removeMappingsForPc);
    connect(m_timelineManager, &TimelineManager::commandTriggered,
            this, [this](Timeline *, TimelineCommand *timelineCommand) {
        executeTimelineCommand(timelineCommand);
    });
    connect(m_timelineManager, &TimelineManager::playbackStateChanged,
            this, [this](TimelineManager::PlaybackState state) {
        if (state != TimelineManager::Stopped)
            return;

        ++m_runId;
        for (Timeline *timeline : m_timelineManager->timelineModel()->items()) {
            for (TimelineCommand *command : timeline->commandModel()->commands()) {
                if (command && command->state() == TimelineCommand::Running) {
                    command->setErrorMessage(tr("已停止"));
                    command->setState(TimelineCommand::Failed);
                }
            }
        }
    });

    const QString defaultPlanFilePath = QDir::current().filePath(QStringLiteral("default.tlplan"));
    if (QFile::exists(defaultPlanFilePath))
        loadPlanFromFile(defaultPlanFilePath);
    if (m_timelineManager->timelineModel()->rowCount() == 0)
        m_timelineManager->createTimeline(tr("主时间轴"));
}

void TimelineRuntime::executeTimelineCommand(TimelineCommand *timelineCommand)
{
    if (!timelineCommand)
        return;

    const QVariantMap commandParams = timelineCommand->commandParams();
    const QString commandProtocol = commandParams.value(DeviceKey::Protocol).toString().trimmed();
    Device *targetDevice = m_deviceModel
        ? m_deviceModel->deviceById(timelineCommand->targetDeviceId())
        : nullptr;
    if (!targetDevice) {
        timelineCommand->setErrorMessage(tr("目标设备不存在"));
        timelineCommand->setState(TimelineCommand::Failed);
        return;
    }
    if (!targetDevice->supportsProtocol(commandProtocol)) {
        timelineCommand->setErrorMessage(tr("设备不支持该协议"));
        timelineCommand->setState(TimelineCommand::Failed);
        return;
    }

    DeviceCommand *deviceCommand = targetDevice->createCommandFromJson(
        QJsonObject::fromVariantMap(commandParams),
        this,
        m_timelineManager->timelineModel());
    if (!deviceCommand) {
        timelineCommand->setErrorMessage(tr("无效指令"));
        timelineCommand->setState(TimelineCommand::Failed);
        return;
    }

    timelineCommand->setState(TimelineCommand::Running);
    const int runId = m_runId;
    QPointer<TimelineCommand> timelineCommandGuard(timelineCommand);
    connect(m_deviceExecutorManager, &DeviceExecutorManager::executionFinished,
            deviceCommand,
            [this, runId, timelineCommandGuard, deviceCommand](
                DeviceCommand *finishedCommand,
                bool success,
                const QString &errorMessage) {
        if (finishedCommand != deviceCommand)
            return;

        if (m_runId == runId && timelineCommandGuard) {
            timelineCommandGuard->setErrorMessage(errorMessage);
            timelineCommandGuard->setState(success
                                               ? TimelineCommand::Succeeded
                                               : TimelineCommand::Failed);
        }
        deviceCommand->deleteLater();
    });
    m_deviceExecutorManager->execute(
        deviceCommand,
        commandParams.value(QStringLiteral("executionInputFields")).toMap());
}

UICore::TaskManager *TimelineRuntime::taskManager() const
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

FenceManager *TimelineRuntime::fenceManager() const
{
    return m_fenceManager;
}

VideoProjectionPlanController *TimelineRuntime::videoProjectionPlanController() const
{
    return m_videoProjectionPlanController;
}

TimelineManager *TimelineRuntime::timelineManager() const
{
    return m_timelineManager;
}

QString TimelineRuntime::currentPlanFilePath() const
{
    return m_currentPlanFilePath;
}

QString TimelineRuntime::currentPlanName() const
{
    return QFileInfo(m_currentPlanFilePath).completeBaseName();
}

void TimelineRuntime::writePlanToStream(QDataStream &stream) const
{
    stream << kTimelinePlanMagic
           << kTimelinePlanVersion;
    m_deviceModel->writeToStream(stream);
    m_timelineManager->writeToStream(stream);
    m_videoProjectionPlanController->writeToStream(stream);
    m_fenceManager->writeToStream(stream);
}

void TimelineRuntime::readPlanFromStream(QDataStream &stream)
{
    quint32 magic = 0;
    qint32 version = 0;
    stream >> magic >> version;
    if (stream.status() != QDataStream::Ok
        || magic != kTimelinePlanMagic
        || (version != 2 && version != kTimelinePlanVersion)) {
        stream.setStatus(QDataStream::ReadCorruptData);
        return;
    }

    m_deviceModel->readFromStream(stream,
                                  m_deviceTemplateModel,
                                  m_timelineManager->timelineModel());
    if (stream.status() != QDataStream::Ok)
        return;

    if (!m_timelineManager->readFromStream(stream))
        return;

    m_videoProjectionPlanController->readFromStream(stream);
    if (stream.status() == QDataStream::Ok && version >= 3)
        m_fenceManager->readFromStream(stream);
    else if (stream.status() == QDataStream::Ok)
        m_fenceManager->clear();
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
