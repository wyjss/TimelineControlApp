#include "TimelineShellController.h"

#include "TimelineRuntime.h"
#include "runtime/shell/AppDrawer.h"
#include "timeline/TimelineController.h"

namespace {

QVariantMap makePaneItem(const QString &id, const QString &label, const QString &meta, bool selected = false)
{
    return QVariantMap{
        {QStringLiteral("id"), id},
        {QStringLiteral("label"), label},
        {QStringLiteral("meta"), meta},
        {QStringLiteral("selected"), selected}
    };
}

QVariantMap makeLeftPane(const QString &title, const QString &filterPlaceholder, const QVariantList &items)
{
    return QVariantMap{
        {QStringLiteral("title"), title},
        {QStringLiteral("filterPlaceholder"), filterPlaceholder},
        {QStringLiteral("items"), items}
    };
}

EarthUI::AppDrawer *makeDrawer(QObject *parent,
                               const QString &key,
                               const QString &label,
                               const QString &iconName,
                               const QString &detail,
                               const QVariantMap &leftPaneData)
{
    auto *drawer = new EarthUI::AppDrawer(parent);
    drawer->setKey(key);
    drawer->setLabel(label);
    drawer->setIconName(iconName);
    drawer->setDetail(detail);
    drawer->setLeftPaneData(leftPaneData);
    return drawer;
}

} // namespace


TimelineShellController::TimelineShellController(QObject *parent)
    : AppShellController(parent)
{
    buildDrawers();
    setActiveDrawerKey(QStringLiteral("devices"));
    syncSelection(tr("设备"), tr("设备分组与连接状态"));
}

void TimelineShellController::handleUiAction(const QString &actionId, const QVariantMap &payload)
{
    if (actionId == QStringLiteral("leftPane.filterEdited")) {
        setLeftPaneFilterText(payload.value(QStringLiteral("text")).toString());
        return;
    }

    if (actionId == QStringLiteral("leftPane.rowTriggered")) {
        const QVariantMap rowData = payload.value(QStringLiteral("rowData")).toMap();
        const QString label = rowData.value(QStringLiteral("label")).toString();
        const QString meta = rowData.value(QStringLiteral("meta")).toString();
        syncSelection(label.isEmpty() ? tr("选择") : label, meta);
        return;
    }

    auto *runtime = qobject_cast<TimelineRuntime *>(parent());
    if (runtime && runtime->timelineController()) {
        if (actionId == QStringLiteral("timeline.plan.save")) {
            if (runtime->state() == TimelineRuntime::Stopped) {
                const QString filePath = payload.value(QStringLiteral("filePath")).toString();
                runtime->savePlanToFile(filePath.isEmpty() ? runtime->currentPlanFilePath() : filePath);
            }
            return;
        }

        if (actionId == QStringLiteral("timeline.plan.load")) {
            if (runtime->state() == TimelineRuntime::Stopped)
                runtime->loadPlanFromFile(payload.value(QStringLiteral("filePath")).toString());
            return;
        }

        if (actionId == QStringLiteral("timeline.start")) {
            runtime->startTimeline();
            return;
        }

        if (actionId == QStringLiteral("timeline.pause")) {
            runtime->timelineController()->pause();
            return;
        }

        if (actionId == QStringLiteral("timeline.stop")) {
            runtime->stopTimeline();
            return;
        }
    }

    AppShellController::handleUiAction(actionId, payload);
}

void TimelineShellController::buildDrawers()
{
    registerDrawer(makeDrawer(this,
                              QStringLiteral("devices"),
                              tr("设备"),
                              QStringLiteral("resources"),
                              tr("设备分组与连接状态"),
                              makeLeftPane(tr("设备"),
                                           tr("筛选设备"),
                                           QVariantList{
                                               makePaneItem(QStringLiteral("device-groups"),
                                                            tr("设备分组"),
                                                            tr("逻辑控制分组"),
                                                            true),
                                               makePaneItem(QStringLiteral("adapters"),
                                                            tr("适配器"),
                                                            tr("协议适配器")),
                                               makePaneItem(QStringLiteral("health"),
                                                            tr("状态"),
                                                            tr("连接诊断"))
                                           })));

    registerDrawer(makeDrawer(this,
                              QStringLiteral("timeline"),
                              tr("时间线"),
                              QStringLiteral("workflow"),
                              tr("轨道、指令与播放状态"),
                              makeLeftPane(tr("时间线"),
                                           tr("筛选时间线项目"),
                                           QVariantList{
                                               makePaneItem(QStringLiteral("sequence-main"),
                                                            tr("主序列"),
                                                            tr("主控制轨"),
                                                            true),
                                               makePaneItem(QStringLiteral("cue-list"),
                                                            tr("指令列表"),
                                                            tr("定时控制事件")),
                                                makePaneItem(QStringLiteral("playback"),
                                                             tr("播放"),
                                                             tr("播放控制与时钟状态"))
                                            })));

    registerDrawer(makeDrawer(this,
                              QStringLiteral("virtual-playback"),
                              tr("虚拟播放"),
                              QStringLiteral("scene"),
                              tr("虚拟播放指令编辑"),
                              makeLeftPane(tr("虚拟播放"),
                                           tr("筛选虚拟播放"),
                                           QVariantList{
                                               makePaneItem(QStringLiteral("virtual-command-editor"),
                                                            tr("指令编辑"),
                                                            tr("PC与视频框"),
                                                            true)
                                           })));

    registerDrawer(makeDrawer(this,
                              QStringLiteral("projection"),
                              tr("投影"),
                              QStringLiteral("scene"),
                              tr("视频取景与 PC 屏幕映射"),
                              makeLeftPane(tr("投影"),
                                           tr("筛选投影项目"),
                                           QVariantList{
                                               makePaneItem(QStringLiteral("video-crops"),
                                                            tr("视频取景"),
                                                            tr("模拟取景区域"),
                                                            true),
                                               makePaneItem(QStringLiteral("screen-map"),
                                                            tr("屏幕映射"),
                                                            tr("已选 PC 布局预览")),
                                               makePaneItem(QStringLiteral("pc-targets"),
                                                            tr("PC 目标"),
                                                            tr("可用投影设备"))
                                           })));

    registerDrawer(makeDrawer(this,
                              QStringLiteral("keystone"),
                              tr("梯形校正"),
                              QStringLiteral("layer-config"),
                              tr("PC 屏幕角点校正"),
                              makeLeftPane(tr("梯形校正"),
                                           tr("筛选校正项目"),
                                           QVariantList{
                                               makePaneItem(QStringLiteral("pc-keystone"),
                                                            tr("PC 梯形校正"),
                                                            tr("校正 PC 屏幕角点"),
                                                            true),
                                               makePaneItem(QStringLiteral("screen-corners"),
                                                            tr("屏幕角点"),
                                                            tr("单屏校正点")),
                                               makePaneItem(QStringLiteral("device-config"),
                                                            tr("设备配置"),
                                                            tr("存储在 PC 设备配置中"))
                                           })));

}

void TimelineShellController::syncSelection(const QString &title, const QString &detail)
{
    QVariantList lines{
        QVariantMap{
            {QStringLiteral("text"), title},
            {QStringLiteral("styleRole"), QStringLiteral("bodyS")},
            {QStringLiteral("textTone"), QStringLiteral("primary")}
        }
    };

    if (!detail.isEmpty()) {
        lines.append(QVariantMap{
            {QStringLiteral("text"), detail},
            {QStringLiteral("styleRole"), QStringLiteral("bodyS")},
            {QStringLiteral("textTone"), QStringLiteral("accent")}
        });
    }

    setSelectionData(QVariantMap{
        {QStringLiteral("title"), tr("选择")},
        {QStringLiteral("lines"), lines}
    });
}

