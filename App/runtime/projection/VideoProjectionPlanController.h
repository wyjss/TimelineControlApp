#pragma once

#include <QDateTime>
#include <QObject>
#include <QRect>
#include <QSize>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QVector>


class QDataStream;


//! 视频取景区域，rect 使用视频源像素坐标。
struct VideoProjectionCapture
{
    //! 取景名称，仅用于显示和生成命令时描述。
    QString name;
    //! 取景矩形，坐标系为 videoSize 对应的视频像素空间。
    QRect rect;
};

//! 取景到 PC 屏幕画布的映射关系。
struct VideoProjectionMapping
{
    //! 对应 captures 中的索引。
    int captureIndex = -1;
    //! 目标 PC 设备 id。
    QString pcId;
    //! 输出区域，坐标系为目标 PC 的总屏幕像素空间。
    QRect outputRect;
    //! 目标 PC 的总屏幕尺寸，等于单屏分辨率乘以屏幕布局。
    QSize screenTotalSize;
    //! 目标 PC 的单屏分辨率。
    QSize screenResolution;
    //! 目标 PC 的屏幕布局，width 为列数，height 为行数。
    QSize screenLayout;
    //! 映射所在屏幕列索引，从 0 开始。
    int screenColumn = 0;
    //! 映射所在屏幕行索引，从 0 开始。
    int screenRow = 0;
};

//! 一条完整的视频投影方案数据。
struct VideoProjectionPlan
{
    //! 方案名称。
    QString name;
    //! 投影窗口 id，用于后续关联具体输出窗口。
    QString projectionWindowId;
    //! 当前方案涉及的 PC 设备 id 列表，可由 mappings 推导后写入。
    QStringList targetPcIds;
    //! 视频源地址。
    QUrl videoSource;
    //! 视频源像素尺寸。
    QSize videoSize = QSize(1920, 1080);
    //! 当前方案的所有取景区域。
    QVector<VideoProjectionCapture> captures;
    //! 当前方案的所有输出映射。
    QVector<VideoProjectionMapping> mappings;
    //! 创建时间。
    QDateTime createdAt;
    //! 最近更新时间。
    QDateTime updatedAt;
};

//! 兼容旧方案文件的投影数据读写与设备删除清理。
class VideoProjectionPlanController final : public QObject
{
public:
    using QObject::QObject;

    void writeToStream(QDataStream &stream) const;
    void readFromStream(QDataStream &stream);
    void removeMappingsForPc(const QString &pcId);

private:
    QVector<VideoProjectionPlan> m_plans;
    int m_currentPlanIndex = -1;
};
