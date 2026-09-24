#include "runtime/video/PcVideoStateCalculator.h"

#include <algorithm>

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"
#include "timeline/TimelineCommand.h"
#include "utils.h"


PcVideoStateCalculator::State PcVideoStateCalculator::stateAt(
    const QList<TimelineCommand *> &commands, 
    const QString &deviceId, 
    qint64 timeMs)
{
    State result{deviceId, qMax<qint64>(0, timeMs), {}};

    // 过滤出有效指令
    QList<TimelineCommand *> sortedCommands;
    for (TimelineCommand *command : commands) {
        // id匹配
        if (!command || command->targetDeviceId() != deviceId) {
            continue;
        }

        // 时间范围
        if (command->startTimeMs() > result.timelineTimeMs) {
            continue;
        }

        //设备类型匹配
        auto cmd = command->targetCommand();
        if (!cmd || cmd->protocol() != DeviceProtocol::Pc) {
            continue;
        }

        // 指令类型匹配
		const QString commandType = cmd->commandType();
        if (commandType != DeviceKey::CommandOpenVideo
            && commandType != DeviceKey::CommandPlayVideo
            && commandType != DeviceKey::CommandPauseVideo
            && commandType != DeviceKey::CommandSeekVideo
            && commandType != DeviceKey::CommandStopVideo
            && commandType != DeviceKey::CommandClosePlayer) {
			continue;
        }
        
        sortedCommands.append(command);
    }
    qSort(sortedCommands.begin(), sortedCommands.end(),
                     [](TimelineCommand *l, TimelineCommand *r) {
        return l->startTimeMs() < r->startTimeMs();
    });

    //
    qint64 previousTimeMs = 0;
    for (TimelineCommand *command : sortedCommands) {
        //
        DeviceCommand *targetCommand = command->targetCommand();
        const QString commandType = targetCommand->commandType();

        const qint64 eventTimeMs = command->startTimeMs();
        for (VideoState &video : result.videos) {
            if (video.playing)
                video.positionMs += eventTimeMs - previousTimeMs;
        }
        previousTimeMs = eventTimeMs;

        const QVariantMap input = command->executionInputValues();
        const QString source = Utils::getVideoRealSource(input.value(DeviceKey::VideoFile).toString());
        if (commandType == DeviceKey::CommandClosePlayer) {
            result.videos.clear();
        } else if (commandType == DeviceKey::CommandOpenVideo) {
            if (source.isEmpty())
                continue;

            // 等价重开，先移除
            for (int index = result.videos.size() - 1; index >= 0; --index) {
                if (result.videos.at(index).source == source) {
					result.videos.removeAt(index);
                }
            }

            const QVariantMap params = targetCommand->resolvedParams(input);
            VideoState video;
            video.source = source;
            video.windowRect = QRect(params.value(DeviceKey::VideoWindowX).toInt(),
                                     params.value(DeviceKey::VideoWindowY).toInt(),
                                     params.value(DeviceKey::VideoWindowW).toInt(),
                                     params.value(DeviceKey::VideoWindowH).toInt());
            video.sourceRect = QRect(params.value(DeviceKey::VideoSrcX).toInt(),
                                     params.value(DeviceKey::VideoSrcY).toInt(),
                                     params.value(DeviceKey::VideoSrcW).toInt(),
                                     params.value(DeviceKey::VideoSrcH).toInt());
            video.positionMs = qMax<qint64>(0, qRound64(input.value(DeviceKey::VideoTimeSec, 0).toDouble() * 1000.0));
            video.playing = input.value(QStringLiteral("play"), true).toBool();
            result.videos.append(video);
        } else if (commandType == DeviceKey::CommandStopVideo) {
            for (int index = result.videos.size() - 1; index >= 0; --index) {
                if (source.isEmpty() || result.videos.at(index).source == source)
                    result.videos.removeAt(index);
            }
        } else {
            qint64 positionMs = 0;
            if (commandType == DeviceKey::CommandSeekVideo) {
                const QVariantMap params = targetCommand->resolvedParams(input);
                positionMs = qMax<qint64>(0, qRound64(params.value(DeviceKey::VideoSeekTimeSec).toDouble() * 1000.0));
            }
            for (VideoState &video : result.videos) {
                if (!source.isEmpty() && video.source != source)
                    continue;
                if (commandType == DeviceKey::CommandSeekVideo)
                    video.positionMs = positionMs;
                else
                    video.playing = commandType == DeviceKey::CommandPlayVideo;
            }
        }
    }

    for (VideoState &video : result.videos) {
        if (video.playing)
            video.positionMs += result.timelineTimeMs - previousTimeMs;
    }
    return result;
}

QVector<PcVideoStateCalculator::ControlCommand> PcVideoStateCalculator::commandsBetween(
    const State &before, const State &after)
{
    Q_ASSERT_X(before.deviceId == after.deviceId, "PcVideoStateCalculator::commandsBetween",
               "States must belong to the same device");

    // 新打开的视频排在已有视频之后，保留目标前缀中顺序、布局均未变的视频。
    QVector<int> retainedIndices;
    int previousIndex = -1;
    for (const VideoState &video : after.videos) {
        int index = previousIndex + 1;
        // 查找同源视频
        while (index < before.videos.size() && before.videos.at(index).source != video.source) {
			++index;
        }
        // 新视频或切换过rect（等他新视频，包含seek）
        if (index == before.videos.size()
            || before.videos.at(index).windowRect != video.windowRect
            || before.videos.at(index).sourceRect != video.sourceRect)
            break;
        retainedIndices.append(index);
        previousIndex = index;
    }

    QVector<ControlCommand> commands;
    for (int index = 0; index < before.videos.size(); ++index) {

        // 未被after包含的就加入
        if (!retainedIndices.contains(index)) {
            commands.append(ControlCommand{after.deviceId, DeviceKey::CommandStopVideo,
                {{DeviceKey::VideoFile, before.videos.at(index).source}}
                            });
        }
    }

    for (int index = 0; index < after.videos.size(); ++index) {
        const VideoState &video = after.videos.at(index);
        if (index >= retainedIndices.size()) {
            commands.append(ControlCommand{after.deviceId, DeviceKey::CommandOpenVideo,
                {{DeviceKey::VideoFile, video.source},
                 {DeviceKey::VideoWindowX, video.windowRect.x()},
                 {DeviceKey::VideoWindowY, video.windowRect.y()},
                 {DeviceKey::VideoWindowW, video.windowRect.width()},
                 {DeviceKey::VideoWindowH, video.windowRect.height()},
                 {DeviceKey::VideoSrcX, video.sourceRect.x()},
                 {DeviceKey::VideoSrcY, video.sourceRect.y()},
                 {DeviceKey::VideoSrcW, video.sourceRect.width()},
                 {DeviceKey::VideoSrcH, video.sourceRect.height()},
                 {DeviceKey::VideoTimeSec, static_cast<double>(video.positionMs) / 1000.0},
                 {QStringLiteral("play"), video.playing}}});
            continue;
        }

        const VideoState &previousVideo = before.videos.at(retainedIndices.at(index));
		if (previousVideo.playing && !video.playing) {
			commands.append(ControlCommand{ after.deviceId, DeviceKey::CommandPauseVideo,
				{{DeviceKey::VideoFile, video.source}}
							});
        }
        if (previousVideo.positionMs != video.positionMs) {
            commands.append(ControlCommand{after.deviceId, DeviceKey::CommandSeekVideo,
                {{DeviceKey::VideoFile, video.source},
                 {DeviceKey::VideoSeekTimeSec, static_cast<double>(video.positionMs) / 1000.0}}});
        }
		if (!previousVideo.playing && video.playing) {
			commands.append(ControlCommand{ after.deviceId, DeviceKey::CommandPlayVideo,
				{{DeviceKey::VideoFile, video.source}}
							});
        }
    }
    return commands;
}
