#include "runtime/video/PcVideoStateCalculator.h"

#include "devices/DeviceConstants.h"
#include "timeline/TimelinePlaybackState.h"

QVector<PcVideoStateCalculator::VideoState> PcVideoStateCalculator::stateAt(
    const QList<TimelineCommand *> &commands, const Device &device, qint64 timeMs)
{
    const auto snapshot = TimelinePlaybackState::stateAt(commands, device, timeMs);
    const auto videoInstances = snapshot.value(QStringLiteral("视频"));
    QVector<VideoState> videos;
    for (const auto &instance : videoInstances) {
        const QVariantMap &input = instance.loadInput;
        const QString source = input.value(DeviceKey::VideoFile).toString();
        if (source.isEmpty())
            continue;

        VideoState video;
        video.source = source;
        video.windowRect = QRect(input.value(DeviceKey::VideoWindowX).toInt(),
                                 input.value(DeviceKey::VideoWindowY).toInt(),
                                 input.value(DeviceKey::VideoWindowW).toInt(),
                                 input.value(DeviceKey::VideoWindowH).toInt());
        video.sourceRect = QRect(input.value(DeviceKey::VideoSrcX).toInt(),
                                 input.value(DeviceKey::VideoSrcY).toInt(),
                                 input.value(DeviceKey::VideoSrcW).toInt(),
                                 input.value(DeviceKey::VideoSrcH).toInt());
        video.positionMs = instance.positionMs;
        video.playing = instance.playing;
        videos.append(video);
    }
    return videos;
}
