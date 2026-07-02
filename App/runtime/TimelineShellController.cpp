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
        {QStringLiteral("primaryAction"), QVariantMap{
            {QStringLiteral("actionId"), QStringLiteral("timeline.primaryAction")},
            {QStringLiteral("text"), QObject::tr("Open")},
            {QStringLiteral("variant"), QStringLiteral("secondary")}
        }},
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

using namespace TimelineControl;

TimelineShellController::TimelineShellController(QObject *parent)
    : AppShellController(parent)
{
    buildDrawers();
    setActiveDrawerKey(QStringLiteral("timeline"));
    syncSelection(tr("Timeline"), tr("Ready to build timeline-based device control."));
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
        syncSelection(label.isEmpty() ? tr("Selection") : label, meta);
        return;
    }

    auto *runtime = qobject_cast<TimelineRuntime *>(parent());
    if (runtime && runtime->timelineController()) {
        if (actionId == QStringLiteral("timeline.start")) {
            runtime->timelineController()->start();
            return;
        }

        if (actionId == QStringLiteral("timeline.pause")) {
            runtime->timelineController()->pause();
            return;
        }

        if (actionId == QStringLiteral("timeline.stop")) {
            runtime->timelineController()->stop();
            return;
        }
    }

    AppShellController::handleUiAction(actionId, payload);
}

void TimelineShellController::buildDrawers()
{
    registerDrawer(makeDrawer(this,
                              QStringLiteral("timeline"),
                              tr("Timeline"),
                              QStringLiteral("workflow"),
                              tr("Tracks, cues, and playback state"),
                              makeLeftPane(tr("Timeline"),
                                           tr("Filter timeline items"),
                                           QVariantList{
                                               makePaneItem(QStringLiteral("sequence-main"),
                                                            tr("Main Sequence"),
                                                            tr("Primary control track"),
                                                            true),
                                               makePaneItem(QStringLiteral("cue-list"),
                                                            tr("Cue List"),
                                                            tr("Timed control events")),
                                               makePaneItem(QStringLiteral("playback"),
                                                            tr("Playback"),
                                                            tr("Transport and clock state"))
                                           })));

    registerDrawer(makeDrawer(this,
                              QStringLiteral("devices"),
                              tr("Devices"),
                              QStringLiteral("resources"),
                              tr("Device groups and connection status"),
                              makeLeftPane(tr("Devices"),
                                           tr("Filter devices"),
                                           QVariantList{
                                               makePaneItem(QStringLiteral("device-groups"),
                                                            tr("Device Groups"),
                                                            tr("Logical control groups"),
                                                            true),
                                               makePaneItem(QStringLiteral("adapters"),
                                                            tr("Adapters"),
                                                            tr("Protocol adapters")),
                                               makePaneItem(QStringLiteral("health"),
                                                            tr("Health"),
                                                            tr("Connection diagnostics"))
                                           })));

    registerDrawer(makeDrawer(this,
                              QStringLiteral("projection"),
                              tr("Projection"),
                              QStringLiteral("scene"),
                              tr("Video crops and mapped PC screens"),
                              makeLeftPane(tr("Projection"),
                                           tr("Filter projection items"),
                                           QVariantList{
                                               makePaneItem(QStringLiteral("video-crops"),
                                                            tr("Video Crops"),
                                                            tr("Simulated capture rectangles"),
                                                            true),
                                               makePaneItem(QStringLiteral("screen-map"),
                                                            tr("Screen Map"),
                                                            tr("Selected PC layout preview")),
                                               makePaneItem(QStringLiteral("pc-targets"),
                                                            tr("PC Targets"),
                                                            tr("Available projection devices"))
                                           })));

    registerDrawer(makeDrawer(this,
                              QStringLiteral("keystone"),
                              tr("Keystone"),
                              QStringLiteral("layer-config"),
                              tr("PC screen corner calibration"),
                              makeLeftPane(tr("Keystone"),
                                           tr("Filter calibration items"),
                                           QVariantList{
                                               makePaneItem(QStringLiteral("pc-keystone"),
                                                            tr("PC Keystone"),
                                                            tr("Calibrate PC screen corners"),
                                                            true),
                                               makePaneItem(QStringLiteral("screen-corners"),
                                                            tr("Screen Corners"),
                                                            tr("Per-screen correction points")),
                                               makePaneItem(QStringLiteral("device-config"),
                                                            tr("Device Config"),
                                                            tr("Stored in PC device config"))
                                           })));

    registerDrawer(makeDrawer(this,
                              QStringLiteral("runs"),
                              tr("Runs"),
                              QStringLiteral("background-task"),
                              tr("Execution logs and background tasks"),
                              makeLeftPane(tr("Runs"),
                                           tr("Filter runs"),
                                           QVariantList{
                                               makePaneItem(QStringLiteral("current-run"),
                                                            tr("Current Run"),
                                                            tr("Live execution state"),
                                                            true),
                                               makePaneItem(QStringLiteral("history"),
                                                            tr("History"),
                                                            tr("Recent timeline runs"))
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
        {QStringLiteral("title"), tr("Selection")},
        {QStringLiteral("lines"), lines}
    });
}

