#include "TimelineRuntime.h"
#include "ResourceSyncManager.h"

#include <QMetaType>

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"
#include "devices/CrossConditionModel.h"
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
#include "video/PcVideoStateCalculator.h"

#include "LogMacros.h"

#include <QDataStream>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QIODevice>
#include <QJsonObject>
#include <QPointer>
#include <QTemporaryFile>
#include <QUuid>
#include <QUrl>

namespace {

constexpr quint32 kTimelinePlanMagic = 0x544C504E;
constexpr qint32 kTimelinePlanVersion = 7;

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
    m_fenceManager = (new FenceManager(this));
    m_resourceSyncManager = (new ResourceSyncManager(m_deviceModel, this));
    m_timelineManager = (new TimelineManager(m_deviceModel, this));
    m_deviceTemplateModel = (new DeviceTemplateModel(m_timelineManager->timelineModel(), this));
    m_deviceExecutorManager = (new DeviceExecutorManager(this));
    m_deviceManager = (new DeviceManager(m_deviceModel, m_deviceTemplateModel, m_deviceExecutorManager, this));
    m_videoProjectionPlanController = (new VideoProjectionPlanController(this));

    qRegisterMetaType<DeviceCommand *>("DeviceCommand*");
    qRegisterMetaType<Device *>("Device*");
    qRegisterMetaType<DeviceTemplate *>("DeviceTemplate*");
    qRegisterMetaType<UICore::TaskManager *>("UICore::TaskManager*");
    qRegisterMetaType<DeviceManager *>("DeviceManager*");
    qRegisterMetaType<DeviceModel *>("DeviceModel*");
    qRegisterMetaType<DeviceTemplateModel *>("DeviceTemplateModel*");
    qRegisterMetaType<CrossCondition *>("CrossCondition*");
    qRegisterMetaType<CrossConditionModel *>("CrossConditionModel*");
    qRegisterMetaType<FenceManager *>("FenceManager*");
    qRegisterMetaType<ResourceSyncManager *>("ResourceSyncManager*");
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
    m_pcVideoSeekTimer.setInterval(200);
    m_pcVideoSeekTimer.setSingleShot(true);
    connect(&m_pcVideoSeekTimer, &QTimer::timeout, this, &TimelineRuntime::flushPcVideoPreview);
    connect(m_timelineManager, &TimelineManager::currentTimelineChanged,
            this, [this]() {
        m_pcVideoSeekTimer.stop();
        m_pendingPcVideoTimeline.clear();
    });
    connect(m_timelineManager->timelineModel(), &TimelineModel::timelinesChanged,
            this, [this]() {
        for (Timeline *timeline : m_timelineManager->timelineModel()->items()) {
            connect(timeline, &Timeline::seekPreviewRequested,
                    this, &TimelineRuntime::seekPcVideoPreview, Qt::UniqueConnection);
        }
    });
    connect(m_timelineManager, &TimelineManager::commandTriggered,
            this, [this](Timeline *, TimelineCommand *timelineCommand) {
        executeTimelineCommand(timelineCommand, timelineCommand->executionInputValues(), false);
    });
    connect(m_timelineManager, &TimelineManager::deviceCommandTriggered,
            this, [this](DeviceCommand *command) {
        m_deviceExecutorManager->execute(
            QUuid::createUuid().toString(QUuid::WithoutBraces), command);
    });
    connect(m_timelineManager, &TimelineManager::playbackStateChanged,
            this, [this](TimelineManager::PlaybackState state) {
        if (state != TimelineManager::Paused) {
            m_pcVideoSeekTimer.stop();
            m_pendingPcVideoTimeline.clear();
            m_pcVideoPreviewStates.clear();
        }
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

void TimelineRuntime::seekPcVideoPreview(qint64 timeMs)
{
    Timeline *timeline = qobject_cast<Timeline *>(sender());
    if (m_timelineManager->playbackState() != TimelineManager::Paused
        || !timeline || timeline->state() != Timeline::Running)
        return;

    // 首次拖动时记录原状态，避免松手提交时间后才计算比较基准。
    auto &states = m_pcVideoPreviewStates[timeline->id()];
    const QList<TimelineCommand *> commands = timeline->commandModel()->commands();
    for (Device *device : m_deviceModel->items()) {
        if ((m_timelineManager->executionFilterEnabled()
             && !m_timelineManager->matchesDeviceFilter(device->id()))
            || !device->supportsProtocol(DeviceProtocol::Pc)
            || states.contains(device->id()))
            continue;
        states.insert(device->id(), PcVideoStateCalculator::stateAt(
            commands, device->id(), timeline->currentTimeMs()));
    }

    m_pendingPcVideoTimeline = timeline;
    m_pendingPcVideoTimeMs = timeMs;
    // 窗口内只覆盖目标位置，不重启定时器，持续拖动时仍定期同步。
    if (!m_pcVideoSeekTimer.isActive())
        m_pcVideoSeekTimer.start();
}

void TimelineRuntime::flushPcVideoPreview()
{
    Timeline *timeline = m_pendingPcVideoTimeline.data();
    const qint64 timeMs = m_pendingPcVideoTimeMs;
    m_pendingPcVideoTimeline.clear();
    if (m_timelineManager->playbackState() != TimelineManager::Paused
        || !timeline || timeline->state() != Timeline::Running)
        return;

    const QList<TimelineCommand *> commands = timeline->commandModel()->commands();
    auto &states = m_pcVideoPreviewStates[timeline->id()];
    for (auto state = states.begin(); state != states.end(); ++state) {
        Device *device = m_deviceModel->deviceById(state.key());
        if (!device || (m_timelineManager->executionFilterEnabled()
                        && !m_timelineManager->matchesDeviceFilter(device->id()))
            || !device->supportsProtocol(DeviceProtocol::Pc))
            continue;

        const auto after = PcVideoStateCalculator::stateAt(commands, device->id(), timeMs);
        const auto controlCommands = PcVideoStateCalculator::commandsBetween(state.value(), after);
        bool sentAllCommands = true;
        for (const auto &controlCommand : controlCommands) {
            // 暂停期间保留加载、关闭、布局和进度变化，但不启动播放。
            if (controlCommand.commandType == DeviceKey::CommandPlayVideo)
                continue;

            DeviceCommand *targetCommand = nullptr;
            for (const QVariant &value : device->commands()) {
                DeviceCommand *command = value.value<DeviceCommand *>();
                if (command->protocol() == DeviceProtocol::Pc
                    && command->commandType() == controlCommand.commandType) {
                    targetCommand = command;
                    break;
                }
            }
            if (!targetCommand) {
                LOG_WARN("PC 视频同步缺少指令：" << device->name() << controlCommand.commandType);
                sentAllCommands = false;
                break;
            }

            QVariantMap input = controlCommand.executionInputValues;
            if (controlCommand.commandType == DeviceKey::CommandOpenVideo)
                input.insert(QStringLiteral("play"), false);
            m_deviceExecutorManager->execute(
                QUuid::createUuid().toString(QUuid::WithoutBraces), targetCommand, input);
        }
        // 保存本轮已发送的目标，下一轮不能再使用尚未提交的时间线位置。
        if (sentAllCommands)
            state.value() = after;
    }
}

void TimelineRuntime::executeTimelineCommand(TimelineCommand *timelineCommand,
                                             const QVariantMap &executionInputValues,
                                             bool isTest)
{
    if (!timelineCommand)
        return;

    Device *targetDevice = m_deviceModel
        ? m_deviceModel->deviceById(timelineCommand->targetDeviceId())
        : nullptr;
    if (!targetDevice) {
        timelineCommand->setErrorMessage(tr("目标设备不存在"));
        timelineCommand->setState(TimelineCommand::Failed);
        return;
    }

    DeviceCommand *deviceCommand = timelineCommand->targetCommand();
    if (!deviceCommand) {
        deviceCommand = targetDevice->commandByName(timelineCommand->commandName());
        timelineCommand->setTargetCommand(deviceCommand);
    }
    if (!deviceCommand || deviceCommand->device() != targetDevice) {
        timelineCommand->setErrorMessage(tr("目标指令不存在"));
        timelineCommand->setState(TimelineCommand::Failed);
        return;
    }
    //if (!targetDevice->supportsProtocol(deviceCommand->protocol())) {
    //    timelineCommand->setErrorMessage(tr("设备不支持该协议"));
    //    timelineCommand->setState(TimelineCommand::Failed);
    //    return;
    //}
    const QString invalidReason = deviceCommand->invalidReason();
    if (!invalidReason.isEmpty()) {
        timelineCommand->setErrorMessage(invalidReason);
        timelineCommand->setState(TimelineCommand::Failed);
        return;
    }

    timelineCommand->setState(TimelineCommand::Running);
    const int runId = m_runId;
    const QString executionId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    QPointer<TimelineCommand> timelineCommandGuard(timelineCommand);
    disconnect(m_deviceExecutorManager, &DeviceExecutorManager::executionFinished,
               timelineCommand, nullptr);
    connect(m_deviceExecutorManager, &DeviceExecutorManager::executionFinished,
            timelineCommand,
            [this, runId, executionId, timelineCommandGuard, deviceCommand, isTest](
                const QString &finishedExecutionId,
                DeviceCommand *finishedCommand,
                bool success,
                const QString &errorMessage) {
        if (finishedExecutionId != executionId || finishedCommand != deviceCommand)
            return;

        if ((isTest || m_runId == runId) && timelineCommandGuard
            && timelineCommandGuard->state() == TimelineCommand::Running) {
            timelineCommandGuard->setErrorMessage(errorMessage);
            timelineCommandGuard->setState(success
                                               ? TimelineCommand::Succeeded
                                               : TimelineCommand::Failed);
        }
    });
    m_deviceExecutorManager->execute(
        executionId,
        deviceCommand,
        executionInputValues);
}

TimelineCommand *TimelineRuntime::testDeviceCommand(const QString &targetDeviceId,
                                                    DeviceCommand *deviceCommand,
                                                    const QVariantMap &executionInputValues)
{
    auto *command = new TimelineCommand(0,
                                        targetDeviceId,
                                        deviceCommand ? deviceCommand->name() : QString(),
                                        executionInputValues,
                                        deviceCommand);
    executeTimelineCommand(command, executionInputValues, true);
    return command;
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

FenceManager *TimelineRuntime::fenceManager() const
{
    return m_fenceManager;
}

ResourceSyncManager *TimelineRuntime::resourceSyncManager() const
{
    return m_resourceSyncManager;
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
        || version != kTimelinePlanVersion) {
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

    QTemporaryFile backupFile(QDir::temp().filePath(QStringLiteral("TimelineControlApp-backup-XXXXXX.tlplan")));
    if (!backupFile.open()) {
        LOG_ERROR("无法创建当前方案备份，已取消加载：" << backupFile.errorString());
        return false;
    }

    QDataStream backupStream(&backupFile);
    writePlanToStream(backupStream);
    if (backupStream.status() != QDataStream::Ok || !backupFile.flush()) {
        LOG_ERROR("当前方案备份失败，已取消加载：" << backupFile.errorString());
        return false;
    }

    QDataStream stream(&file);
    readPlanFromStream(stream);
    if (stream.status() != QDataStream::Ok) {
        backupFile.setAutoRemove(false);
        if (!backupFile.seek(0)) {
            LOG_ERROR("加载失败，无法读取恢复备份，备份保留在："
                      << backupFile.fileName() << backupFile.errorString());
            return false;
        }

        QDataStream restoreStream(&backupFile);
        readPlanFromStream(restoreStream);
        if (restoreStream.status() != QDataStream::Ok) {
            LOG_ERROR("加载失败，原方案恢复失败，备份保留在：" << backupFile.fileName());
        } else {
            backupFile.setAutoRemove(true);
            LOG_WARN("方案加载失败，已恢复原方案：" << file.fileName());
        }
        return false;
    }

    if (m_currentPlanFilePath != file.fileName()) {
        m_currentPlanFilePath = file.fileName();
        emit currentPlanFilePathChanged();
    }

	temp_loadConfig();

    return true;
}

#include <QSettings>
#include "runtime/utils.h"
void TimelineRuntime::temp_loadConfig()
{
    LOG_ERROR("----------------------temp_loadConfig----------------");
    QSettings settings(R"(D:\Program\RA\TimelineControlApp\docs\auto-create.ini)",
                       QSettings::IniFormat);
    settings.setIniCodec("utf-8");

    auto gs = settings.childGroups();


    { // 设备
        settings.beginGroup("device");
        auto keys = settings.childGroups();
        settings.endGroup();

        // 读取
        QList<QVariantMap> devices;
        for (const auto& key : keys) {
            QString deviceName = QString::fromUtf8(key.toLatin1());
            QString fullGroupKey = "device/" + key;
            settings.beginGroup(fullGroupKey);
			auto childKeys = settings.childKeys();
            QVariantMap params;
            params[DeviceKey::Name] = deviceName;
            for (auto childKey : childKeys) {
                auto var = settings.value(childKey);
                QString paramName = QString::fromUtf8(childKey.toLatin1());
				if (paramName.startsWith("虚拟")) {
					int a = 0;
				}
                params[paramName] = var;
            }
            devices.push_back(params);
            settings.endGroup();
        }
        
        // 配置
        for (const auto& params : devices) {
            QString deviceName = params.value(DeviceKey::Name).toString();
			QString templateName = params.value("template").toString();
			QString deviceType = params.value("deviceType").toString();

			if (deviceName.isEmpty()) {
				LOG_ERROR("缺少设备名称");
				continue;
			}

			if (templateName.isEmpty()) {
				LOG_ERROR("缺少设备模板名称");
				continue;
			}
            auto groups = params.value("group", "").toString().split(",", Qt::SkipEmptyParts);
			// 设备-仅在不存在时创建
			auto device = m_deviceModel->deviceByName(deviceName);
			if (!device) { // 创建
                bool createResult = m_deviceManager->createDeviceFromTemplate(
                    templateName,
                    params,
                    deviceName,
                    deviceType,
                    groups
                );
                if (!createResult) {
					LOG_ERROR("创建设备失败" << params);
					continue;
                } else {
                    device = m_deviceModel->deviceByName(deviceName);
                }
            } 
            
			// 更新
			for (auto itr = params.begin(); itr != params.end(); ++itr) {
				if (itr.key().startsWith("虚拟")) {
					int a = 0;
				}
				auto param = device->getParamByNameOrId(itr.key());
				if (param) {
					param->setValue(itr.value());
				}
			}

            // 设备指令
			for (auto itr = params.begin(); itr != params.end(); ++itr) {
                QString k = itr.key();
                if (k.startsWith("cmd-") == false) {
                    continue;
                }

                QString cmdName = k.mid(4);
                if (cmdName.isEmpty()) {
                    continue;
                }

                bool useText = false;
                if (cmdName.startsWith("-text")) {
                    useText = true;
                    cmdName = cmdName.mid(5);
                }

                auto cmd = device->commandByName(cmdName);
                bool isNew = !cmd;
                // 创建指令
                if (isNew) {
					cmd = device->createCommandDraft("");
					cmd->setName(cmdName);
                }
                // 更新载荷
				auto payload = cmd->getField(DeviceKey::Payload);
				if (!payload) {
                    LOG_ERROR("不支持payload");

                    cmd->deleteLater();
                    continue;
                } else {
                    payload->setValue(itr.value());
                }

                // 自动判断hex or text
				auto payloadType = cmd->getField(DeviceKey::PayloadType);
                if (payloadType) {
                    payloadType->setValue(useText ?
                                          DeviceKey::PayloadType_Text :
                                          DeviceKey::PayloadType_Hex
                    );
                }
                
                // append
                if (isNew) {
                    device->appendCommand(cmd);
                }
			}
            
        }// end for devices
    }// end device
   
    QList<Utils::TL> tls;

    for (const auto& tl : tls) {
        auto items = m_timelineManager->timelineModel()->items();
       
        Timeline* timeline = nullptr;
        // 查找目标时间线
        for (auto item : items) {
            if (item->name() == tl.name) {
                timeline = item;
                break;
            }
        }

        // 删除重建
        if (timeline) {
            m_timelineManager->removeTimeline(timeline->id());
        }
        timeline = m_timelineManager->createTimeline(tl.name);

        // 添加指令
        for (const auto& tlCmd : tl.cmds) {
            auto device = m_deviceModel->deviceByName(tlCmd.deviceName);
            if (!device) {
                LOG_ERROR("缺少设备" << tlCmd.deviceName);
                continue;
            }

            auto cmd = device->commandByName(tlCmd.cmdName);
			if (!cmd) {
				LOG_ERROR("缺少指令" << tlCmd.cmdName);
				continue;
			}

            timeline->commandModel()->addCommand(
                0,
                device->id(),
                tlCmd.cmdName,
                tlCmd.params,
                cmd
            );
        }
    }
}