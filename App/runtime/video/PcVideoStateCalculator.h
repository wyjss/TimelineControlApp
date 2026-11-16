#pragma once

#include <QList>
#include <QRect>
#include <QString>
#include <QVector>
#include <QtGlobal>

class Device;
class TimelineCommand;

//! 将通用播放快照转换为本地 PC 视频预览使用的布局和进度。
class PcVideoStateCalculator final
{
public:
    struct VideoState
    {
        //! 解析后的资源路径，同一设备内按此区分视频。
        QString source;

        //! 原始播放窗口和视频源裁剪区域。
        QRect windowRect;
        QRect sourceRect;

        //! 视频内部进度，单位毫秒。
        qint64 positionMs = 0;
        bool playing = false;
    };

    static QVector<VideoState> stateAt(const QList<TimelineCommand *> &commands,
                                       const Device &device,
                                       qint64 timeMs);
};
