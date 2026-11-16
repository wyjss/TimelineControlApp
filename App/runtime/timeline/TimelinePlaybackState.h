#pragma once

#include <QList>
#include <QMap>
#include <QString>
#include <QVariantMap>
#include <QVector>

#include <optional>

class Device;
class DeviceCommand;
class TimelineCommand;

namespace TimelinePlaybackState {

struct Instance
{
    QString id;
    //! 用于重新加载的参数。位置和播放状态单独比较。
    QVariantMap loadInput;
    //! 资源内的绝对位置，单位毫秒。
    qint64 positionMs = 0;
    bool playing = false;
};

//! 按类型保存播放实例，每种类型内保留加载顺序。
using Snapshot = QMap<QString, QVector<Instance>>;

struct Command
{
    DeviceCommand *target;
    QVariantMap input;
};

//! 重建指定设备的播放状态，包含时间线 timeMs 处的指令。
Snapshot stateAt(const QList<TimelineCommand *> &commands, const Device &device, qint64 timeMs);
//! 生成暂停预览的差异指令，缺少必要命令时返回 std::nullopt。
std::optional<QVector<Command>> previewCommands(const Device &device, const Snapshot &before, const Snapshot &after);

}
