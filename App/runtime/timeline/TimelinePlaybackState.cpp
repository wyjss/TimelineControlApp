#include "timeline/TimelinePlaybackState.h"

#include "devices/Device.h"
#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"
#include "timeline/TimelineCommand.h"
#include "utils.h"

#include <QHash>

#include <algorithm>
#include <utility>

namespace {

const QString kLoad = QStringLiteral("加载");
const QString kPlaybackId = QStringLiteral("playbackId");
const QString kPositionMs = QStringLiteral("positionMs");
const QString kPlay = QStringLiteral("play");

enum class Action { Load, Play, Pause, Seek, Close, CloseAll };

bool isPcVideoCommand(DeviceCommand *command, const QString &commandType)
{
    return command && command->protocol() == DeviceProtocol::Pc && command->commandType() == commandType;
}

struct CommandGroup
{
    DeviceCommand *load;
    DeviceCommand *play;
    DeviceCommand *pause;
    DeviceCommand *seek;
    DeviceCommand *close;
    DeviceCommand *oldPause = nullptr;
    DeviceCommand *oldSeek = nullptr;
    DeviceCommand *oldClose = nullptr;
    DeviceCommand *oldCloseAll = nullptr;
};

CommandGroup commandsFor(const Device &device, const QString &type)
{
    CommandGroup group{
        device.commandByName(kLoad + type),
        device.commandByName(QStringLiteral("播放") + type),
        device.commandByName(QStringLiteral("暂停") + type),
        device.commandByName(QStringLiteral("定位") + type),
        device.commandByName(QStringLiteral("关闭") + type)
    };
    if (type != QStringLiteral("视频") || !isPcVideoCommand(group.load, DeviceKey::CommandOpenVideo)) {
        // 旧内置名称恰好符合其他类型的命名时，仍只作用于视频。
        if (isPcVideoCommand(group.pause, DeviceKey::CommandPauseVideo))
            group.pause = nullptr;
        if (isPcVideoCommand(group.close, DeviceKey::CommandClosePlayer))
            group.close = nullptr;
        return group;
    }

    // 已保存的 PC 视频指令仍使用旧名称，且「关闭播放器」作用于全部视频。
    auto *oldPause = device.commandByName(QStringLiteral("暂停播放"));
    auto *oldSeek = device.commandByName(QStringLiteral("视频跳转"));
    auto *oldClose = device.commandByName(QStringLiteral("停止播放"));
    auto *oldCloseAll = device.commandByName(QStringLiteral("关闭播放器"));
    if (isPcVideoCommand(oldPause, DeviceKey::CommandPauseVideo)) {
        group.oldPause = oldPause;
        if (!group.pause)
            group.pause = oldPause;
    }
    if (isPcVideoCommand(oldSeek, DeviceKey::CommandSeekVideo)) {
        group.oldSeek = oldSeek;
        if (!group.seek)
            group.seek = oldSeek;
    }
    if (isPcVideoCommand(oldClose, DeviceKey::CommandStopVideo)) {
        group.oldClose = oldClose;
        if (!group.close)
            group.close = oldClose;
    }
    if (isPcVideoCommand(oldCloseAll, DeviceKey::CommandClosePlayer))
        group.oldCloseAll = oldCloseAll;
    return group;
}

}

TimelinePlaybackState::Snapshot TimelinePlaybackState::stateAt(
    const QList<TimelineCommand *> &commands, const Device &device, qint64 timeMs)
{
    struct Operation
    {
        QString type;
        Action action;
        bool pcVideo;
    };
    QHash<DeviceCommand *, Operation> operations;
    for (const QVariant &entry : device.commands()) {
        const QString name = entry.value<DeviceCommand *>()->name();
        if (!name.startsWith(kLoad))
            continue;

        const QString type = name.mid(kLoad.size());
        if (type.isEmpty() || type != type.trimmed())
            continue;

        // 前后拖拽需要能加载、定位和撤销加载。
        const CommandGroup group = commandsFor(device, type);
        if (!group.load || !group.seek || !group.close)
            continue;

        const bool pcVideo = type == QStringLiteral("视频")
            && isPcVideoCommand(group.load, DeviceKey::CommandOpenVideo);
        operations.insert(group.load, {type, Action::Load, pcVideo});
        if (group.play)
            operations.insert(group.play, {type, Action::Play,
                pcVideo && isPcVideoCommand(group.play, DeviceKey::CommandPlayVideo)});
        if (group.pause)
            operations.insert(group.pause, {type, Action::Pause,
                pcVideo && isPcVideoCommand(group.pause, DeviceKey::CommandPauseVideo)});
        operations.insert(group.seek, {type, Action::Seek,
            pcVideo && isPcVideoCommand(group.seek, DeviceKey::CommandSeekVideo)});
        operations.insert(group.close, {type, Action::Close,
            pcVideo && isPcVideoCommand(group.close, DeviceKey::CommandStopVideo)});
        if (group.oldPause)
            operations.insert(group.oldPause, {type, Action::Pause, true});
        if (group.oldSeek)
            operations.insert(group.oldSeek, {type, Action::Seek, true});
        if (group.oldClose)
            operations.insert(group.oldClose, {type, Action::Close, true});
        if (group.oldCloseAll)
            operations.insert(group.oldCloseAll, {type, Action::CloseAll, true});
    }
    if (operations.isEmpty())
        return {};

    Snapshot result;
    const qint64 targetTimeMs = qMax<qint64>(0, timeMs);
    QList<TimelineCommand *> sortedCommands;
    for (TimelineCommand *command : commands) {
        if (command && command->targetDeviceId() == device.id() && command->startTimeMs() <= targetTimeMs
            && operations.contains(device.commandByName(command->commandName())))
            sortedCommands.append(command);
    }
    // 同一时刻保留编排顺序，例如先加载再播放。
    std::stable_sort(sortedCommands.begin(), sortedCommands.end(),
                     [](TimelineCommand *left, TimelineCommand *right) {
        return left->startTimeMs() < right->startTimeMs();
    });

    qint64 previousTimeMs = 0;
    for (TimelineCommand *command : sortedCommands) {
        const qint64 eventTimeMs = command->startTimeMs();
        // 先按上一条指令后的播放状态推进，再应用当前指令。
        for (auto &instances : result) {
            for (Instance &instance : instances) {
                if (instance.playing)
                    instance.positionMs += eventTimeMs - previousTimeMs;
            }
        }
        previousTimeMs = eventTimeMs;

        DeviceCommand *target = device.commandByName(command->commandName());
        const Operation &operation = operations.constFind(target).value();
        auto &instances = result[operation.type];
        if (operation.action == Action::CloseAll) {
            instances.clear();
            continue;
        }

        QVariantMap input = command->executionInputValues();
        const QVariantMap params = target->DeviceCommand::resolvedParams(input);
        // 加载需要实例标识，控制指令留空时作用于同类型的全部实例。
        const QString id = operation.pcVideo
            ? Utils::getVideoRealSource(input.value(DeviceKey::VideoFile).toString())
            : params.value(kPlaybackId).toString().trimmed();
        if (operation.action == Action::Load) {
            if (id.isEmpty())
                continue;

            qint64 positionMs = params.value(kPositionMs).toLongLong();
            const bool playing = operation.pcVideo ? input.value(kPlay, true).toBool() : params.value(kPlay).toBool();
            input.remove(kPositionMs);
            input.remove(kPlay);
            if (operation.pcVideo) {
                positionMs = qRound64(input.take(DeviceKey::VideoTimeSec).toDouble() * 1000.0);
                const QString layoutKeys[] = {
                    DeviceKey::VideoWindowX, DeviceKey::VideoWindowY, DeviceKey::VideoWindowW, DeviceKey::VideoWindowH,
                    DeviceKey::VideoSrcX, DeviceKey::VideoSrcY, DeviceKey::VideoSrcW, DeviceKey::VideoSrcH
                };
                for (const QString &key : layoutKeys)
                    input.insert(key, params.value(key).toInt());
                input.insert(DeviceKey::VideoFile, id);
            } else {
                input.insert(kPlaybackId, id);
            }

            // 重新加载同实例时，设备将其排到后加载的位置。
            instances.erase(std::remove_if(instances.begin(), instances.end(), [&id](const Instance &instance) {
                return instance.id == id;
            }), instances.end());
            instances.append({id, std::move(input), qMax<qint64>(0, positionMs), playing});
        } else if (operation.action == Action::Close) {
            instances.erase(std::remove_if(instances.begin(), instances.end(), [&id](const Instance &instance) {
                return id.isEmpty() || instance.id == id;
            }), instances.end());
        } else {
            qint64 positionMs = 0;
            if (operation.action == Action::Seek) {
                positionMs = operation.pcVideo
                    ? qRound64(params.value(DeviceKey::VideoSeekTimeSec).toDouble() * 1000.0)
                    : params.value(kPositionMs).toLongLong();
            }
            for (Instance &instance : instances) {
                if (!id.isEmpty() && instance.id != id)
                    continue;
                if (operation.action == Action::Seek)
                    instance.positionMs = qMax<qint64>(0, positionMs);
                else
                    instance.playing = operation.action == Action::Play;
            }
        }
    }

    for (auto &instances : result) {
        for (Instance &instance : instances) {
            if (instance.playing)
                instance.positionMs += targetTimeMs - previousTimeMs;
        }
    }
    return result;
}

std::optional<QVector<TimelinePlaybackState::Command>> TimelinePlaybackState::previewCommands(
    const Device &device, const Snapshot &before, const Snapshot &after)
{
    QVector<Command> commands;
    QStringList types = before.keys();
    for (auto entry = after.cbegin(); entry != after.cend(); ++entry) {
        if (!before.contains(entry.key()))
            types.append(entry.key());
    }
    for (const QString &type : types) {
        const auto oldInstances = before.value(type);
        const auto newInstances = after.value(type);
        if (oldInstances.isEmpty() && newInstances.isEmpty())
            continue;

        const CommandGroup group = commandsFor(device, type);
        if (!group.load || !group.seek || !group.close)
            return std::nullopt;

        const bool pcVideo = type == QStringLiteral("视频")
            && isPcVideoCommand(group.load, DeviceKey::CommandOpenVideo);

        // 重新加载会把实例排在最后，保留顺序和加载参数均未变的目标前缀。
        QVector<int> retainedIndices;
        int oldIndex = 0;
        for (const Instance &instance : newInstances) {
            while (oldIndex < oldInstances.size() && oldInstances.at(oldIndex).id != instance.id)
                ++oldIndex;
            if (oldIndex == oldInstances.size() || oldInstances.at(oldIndex).loadInput != instance.loadInput)
                break;
            retainedIndices.append(oldIndex);
            ++oldIndex;
        }

        const QString closeIdKey = pcVideo && isPcVideoCommand(group.close, DeviceKey::CommandStopVideo)
            ? DeviceKey::VideoFile : kPlaybackId;
        for (int index = 0; index < oldInstances.size(); ++index) {
            if (!retainedIndices.contains(index))
                commands.append({group.close, {{closeIdKey, oldInstances.at(index).id}}});
        }

        for (int index = 0; index < newInstances.size(); ++index) {
            const Instance &instance = newInstances.at(index);
            if (index >= retainedIndices.size()) {
                QVariantMap input = instance.loadInput;
                if (pcVideo)
                    input.insert(DeviceKey::VideoTimeSec, instance.positionMs / 1000.0);
                else
                    input.insert(kPositionMs, instance.positionMs);
                // 即使目标时刻原本在播放，预览加载也从暂停状态打开。
                input.insert(kPlay, false);
                commands.append({group.load, std::move(input)});
                continue;
            }

            const Instance &previous = oldInstances.at(retainedIndices.at(index));
            if (group.pause && previous.playing && !instance.playing) {
                const QString idKey = pcVideo && isPcVideoCommand(group.pause, DeviceKey::CommandPauseVideo)
                    ? DeviceKey::VideoFile : kPlaybackId;
                commands.append({group.pause, {{idKey, instance.id}}});
            }
            if (previous.positionMs != instance.positionMs) {
                if (pcVideo && isPcVideoCommand(group.seek, DeviceKey::CommandSeekVideo)) {
                    commands.append({group.seek, {{DeviceKey::VideoFile, instance.id},
                                                  {DeviceKey::VideoSeekTimeSec, instance.positionMs / 1000.0}}});
                } else {
                    commands.append({group.seek, {{kPlaybackId, instance.id}, {kPositionMs, instance.positionMs}}});
                }
            }
        }
    }
    return commands;
}
