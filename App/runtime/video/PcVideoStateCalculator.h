#pragma once

#include <QList>
#include <QRect>
#include <QString>
#include <QVariantMap>
#include <QVector>
#include <QtGlobal>


class TimelineCommand;

//! 根据时间线计算 PC 视频状态，并生成状态转换所需的指令。
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

    //! 一台 PC 在指定时间线时刻的视频状态快照。
    struct State
    {
        QString deviceId;
        qint64 timelineTimeMs = 0;

        //! 按打开顺序保存，同源视频唯一；空集合表示已知没有视频。
        QVector<VideoState> videos;
    };

    //! 待执行的设备指令描述。
    struct ControlCommand
    {
        QString targetDeviceId;

        //! 使用现有 DeviceKey::Command* 类型值。
        QString commandType;

        //! 使用现有 DeviceKey 参数，交由对应 DeviceCommand 解析。
        QVariantMap executionInputValues;
    };

    //! 计算指定设备在 timeMs 时的视频状态，负时间按 0 处理。
    //! 包含开始时间等于 timeMs 的指令，同刻指令保持输入顺序。
    //! 在指令所属线程调用；closePlayer 仅清空视频集合。
    static State stateAt(const QList<TimelineCommand *> &commands,
                         const QString &deviceId,
                         qint64 timeMs);

    //! 生成从 before 转换到 after 所需的有序指令。
    //! 两个状态必须属于同一设备，视频状态相同则返回空列表。
    //! 直接比较快照，不按时间线时刻差或网络耗时推进进度。
    static QVector<ControlCommand> commandsBetween(const State &before,
                                                   const State &after);
};
