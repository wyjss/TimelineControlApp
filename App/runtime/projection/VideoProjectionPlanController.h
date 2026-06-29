#pragma once

#include <QAbstractItemModel>
#include <QDateTime>
#include <QObject>
#include <QRect>
#include <QSize>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

#include "models/VariantListModel.h"

namespace TimelineControl {

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

//! 由视频投影方案生成出的时间轴命令记录。
struct VideoProjectionGeneratedCommand
{
    //! 生成记录自身 id。
    QString id;
    //! 已加入时间轴后的 TimelineCommand id。
    QString timelineCommandId;
    //! 时间轴执行起始时间，单位毫秒。
    qint64 startTimeMs = 0;
    //! 目标设备 id，通常是 PC 设备 id。
    QString targetDeviceId;
    //! 生成的命令名称。
    QString commandName;
    //! 生成命令时写入 TimelineCommand 的参数快照。
    QVariantMap commandParams;
    //! 生成时间。
    QDateTime createdAt;
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
    //! 当前方案已经生成出的时间轴命令记录。
    QVector<VideoProjectionGeneratedCommand> generatedCommands;
    //! 创建时间。
    QDateTime createdAt;
    //! 最近更新时间。
    QDateTime updatedAt;
};

//! 视频投影方案控制器，负责保存方案数据并向 QML 暴露列表模型。
class VideoProjectionPlanController final : public QObject
{
    Q_OBJECT
    //! 视频投影方案列表模型，modelData/value 为 QVariantMap。
    Q_PROPERTY(QAbstractItemModel *planModel READ planModel CONSTANT FINAL)
    //! 当前方案的取景列表模型，modelData/value 为 QVariantMap。
    Q_PROPERTY(QAbstractItemModel *captureModel READ captureModel CONSTANT FINAL)
    //! 当前方案的映射列表模型，modelData/value 为 QVariantMap。
    Q_PROPERTY(QAbstractItemModel *mappingModel READ mappingModel CONSTANT FINAL)
    //! 当前方案已生成命令列表模型，modelData/value 为 QVariantMap。
    Q_PROPERTY(QAbstractItemModel *generatedCommandModel READ generatedCommandModel CONSTANT FINAL)
    //! 当前选中的方案索引。
    Q_PROPERTY(int currentPlanIndex READ currentPlanIndex WRITE setCurrentPlanIndex NOTIFY currentPlanChanged FINAL)

public:
    explicit VideoProjectionPlanController(QObject *parent = nullptr);

    //! 返回所有视频投影方案的 QML 列表模型。
    QAbstractItemModel *planModel() const;
    //! 返回当前方案的取景列表模型。
    QAbstractItemModel *captureModel() const;
    //! 返回当前方案的映射列表模型。
    QAbstractItemModel *mappingModel() const;
    //! 返回当前方案已生成命令的列表模型。
    QAbstractItemModel *generatedCommandModel() const;

    //! 当前选中的方案索引，-1 表示未选中。
    int currentPlanIndex() const;
    //! 切换当前方案，并刷新当前方案相关模型。
    void setCurrentPlanIndex(int index);

    //! 返回所有方案的内部数据，供 C++ 侧直接读取。
    const QVector<VideoProjectionPlan> &planItems() const;
    //! 返回当前方案的可修改指针；无当前方案时返回 nullptr。
    VideoProjectionPlan *currentPlan();
    //! 返回当前方案的只读指针；无当前方案时返回 nullptr。
    const VideoProjectionPlan *currentPlan() const;

    //! 创建一个新方案并切换为当前方案，返回新方案索引。
    Q_INVOKABLE int createPlan(const QString &name = QString());
    //! 返回指定方案的 QVariantMap 数据。
    Q_INVOKABLE QVariantMap planAt(int index) const;
    //! 返回当前方案的 QVariantMap 数据。
    Q_INVOKABLE QVariantMap currentPlanData() const;
    //! 修改当前方案名称。
    Q_INVOKABLE void setCurrentPlanName(const QString &name);
    //! 修改当前方案关联的投影窗口 id。
    Q_INVOKABLE void setProjectionWindowId(const QString &windowId);
    //! 修改当前方案的视频源地址。
    Q_INVOKABLE void setVideoSource(const QUrl &source);
    //! 修改当前方案的视频像素尺寸。
    Q_INVOKABLE void setVideoSize(int width, int height);

    //! 添加一个取景区域，返回新增取景索引。
    Q_INVOKABLE int addCapture(const QString &name = QString());
    //! 删除指定取景，并同步删除或修正相关映射。
    Q_INVOKABLE void removeCapture(int index);
    //! 返回指定取景的 QVariantMap 数据。
    Q_INVOKABLE QVariantMap captureAt(int index) const;
    //! 修改取景名称。
    Q_INVOKABLE void setCaptureName(int index, const QString &name);
    //! 修改取景矩形，坐标为视频像素坐标。
    Q_INVOKABLE void setCaptureRect(int index, int x, int y, int width, int height);

    //! 添加映射关系；同一个取景已有映射时会先移除旧映射。
    Q_INVOKABLE int addMapping(int captureIndex,
                               const QString &pcId,
                               int x,
                               int y,
                               int width,
                               int height,
                               int totalScreenWidth,
                               int totalScreenHeight,
                               int screenColumns,
                               int screenRows,
                               int screenWidth,
                               int screenHeight);
    //! 删除指定映射。
    Q_INVOKABLE void removeMapping(int index);
    //! 返回指定映射的 QVariantMap 数据。
    Q_INVOKABLE QVariantMap mappingAt(int index) const;
    //! 返回指定取景对应的映射；不存在时返回空 map。
    Q_INVOKABLE QVariantMap mappingForCapture(int captureIndex) const;
    //! 返回指定 PC 设备上的映射数量。
    Q_INVOKABLE int mappingCountForPc(const QString &pcId) const;
    //! 修改映射输出矩形，坐标为目标 PC 总屏幕像素坐标。
    Q_INVOKABLE void setMappingRect(int index, int x, int y, int width, int height);

    //! 记录一条已经生成出的时间轴命令，返回记录索引。
    Q_INVOKABLE int addGeneratedCommand(const QString &timelineCommandId,
                                        qint64 startTimeMs,
                                        const QString &targetDeviceId,
                                        const QString &commandName,
                                        const QVariantMap &commandParams);
    //! 删除指定生成命令记录。
    Q_INVOKABLE void removeGeneratedCommand(int index);
    //! 返回指定生成命令记录的 QVariantMap 数据。
    Q_INVOKABLE QVariantMap generatedCommandAt(int index) const;

signals:
    //! 当前方案索引变化时发出。
    void currentPlanChanged();

private:
    QString defaultPlanName() const;
    QVariantList planValues() const;
    QVariantList captureValues() const;
    QVariantList mappingValues() const;
    QVariantList generatedCommandValues() const;
    QVariantMap planToMap(const VideoProjectionPlan &plan, int index) const;
    QVariantMap captureToMap(const VideoProjectionCapture &capture, int index) const;
    QVariantMap mappingToMap(const VideoProjectionMapping &mapping, int index) const;
    QVariantMap generatedCommandToMap(const VideoProjectionGeneratedCommand &command, int index) const;
    QVariantMap rectToMap(const QRect &rect) const;
    QVariantMap sizeToMap(const QSize &size) const;
    QRect boundedRect(int x, int y, int width, int height, const QSize &bounds) const;
    QString defaultCaptureName(int index) const;
    QString makeGeneratedCommandId() const;
    void touchCurrentPlan();
    void refreshTargetPcIds(VideoProjectionPlan &plan);
    void refreshPlanModel();
    void refreshCurrentPlanRow();
    void refreshCurrentPlanModels();

    QVector<VideoProjectionPlan> m_plans;
    VariantListModel m_planModel;
    VariantListModel m_captureModel;
    VariantListModel m_mappingModel;
    VariantListModel m_generatedCommandModel;
    int m_currentPlanIndex = -1;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::VideoProjectionCapture)
Q_DECLARE_METATYPE(TimelineControl::VideoProjectionMapping)
Q_DECLARE_METATYPE(TimelineControl::VideoProjectionGeneratedCommand)
Q_DECLARE_METATYPE(TimelineControl::VideoProjectionPlan)
Q_DECLARE_METATYPE(TimelineControl::VideoProjectionPlanController *)
