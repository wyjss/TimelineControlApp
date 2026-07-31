#include "TimelineShellController.h"

#include "TimelineRuntime.h"
#include "timeline/TimelineController.h"


TimelineShellController::TimelineShellController(QObject *parent)
    : AppShellController(parent)
    , m_navigationItems{
          QVariantMap{
              {QStringLiteral("key"), QStringLiteral("devices")},
              {QStringLiteral("label"), tr("设备")},
              {QStringLiteral("iconName"), QStringLiteral("resources")},
              {QStringLiteral("source"), QStringLiteral("qrc:/TimelineControlApp/App/pages/DevicesPage.qml")}
          },
          QVariantMap{
              {QStringLiteral("key"), QStringLiteral("device-control")},
              {QStringLiteral("label"), tr("设备控制")},
              {QStringLiteral("iconName"), QStringLiteral("background-task")},
              {QStringLiteral("source"), QStringLiteral("qrc:/TimelineControlApp/App/pages/DeviceControlPage.qml")}
          },
          QVariantMap{
              {QStringLiteral("key"), QStringLiteral("timeline")},
              {QStringLiteral("label"), tr("时间线")},
              {QStringLiteral("iconName"), QStringLiteral("workflow")},
              {QStringLiteral("source"), QStringLiteral("qrc:/TimelineControlApp/App/pages/TimelinePage.qml")}
          },
          QVariantMap{
              {QStringLiteral("key"), QStringLiteral("virtual-playback")},
              {QStringLiteral("label"), tr("虚拟播放")},
              {QStringLiteral("iconName"), QStringLiteral("scene")},
              {QStringLiteral("source"), QStringLiteral("qrc:/TimelineControlApp/App/pages/VirtualPlaybackCommandPage.qml")}
          },
          QVariantMap{
              {QStringLiteral("key"), QStringLiteral("projection")},
              {QStringLiteral("label"), tr("投影")},
              {QStringLiteral("iconName"), QStringLiteral("scene")},
              {QStringLiteral("source"), QStringLiteral("qrc:/TimelineControlApp/App/pages/ProjectionPage.qml")}
          },
          QVariantMap{
              {QStringLiteral("key"), QStringLiteral("keystone")},
              {QStringLiteral("label"), tr("梯形校正")},
              {QStringLiteral("iconName"), QStringLiteral("layer-config")},
              {QStringLiteral("source"), QStringLiteral("qrc:/TimelineControlApp/App/pages/ProjectionKeystonePage.qml")}
          }
      }
{
    setActiveNavigationKey(QStringLiteral("devices"));
}

QVariantList TimelineShellController::navigationItems() const
{
    return m_navigationItems;
}

void TimelineShellController::handleUiAction(const QString &actionId, const QVariantMap &payload)
{
    auto *runtime = qobject_cast<TimelineRuntime *>(parent());
    if (!runtime || !runtime->timelineController())
        return;

    if (actionId == QStringLiteral("timeline.plan.save")) {
        if (runtime->state() == TimelineRuntime::Stopped) {
            const QString filePath = payload.value(QStringLiteral("filePath")).toString();
            runtime->savePlanToFile(filePath.isEmpty() ? runtime->currentPlanFilePath() : filePath);
        }
    } else if (actionId == QStringLiteral("timeline.plan.load")) {
        if (runtime->state() == TimelineRuntime::Stopped)
            runtime->loadPlanFromFile(payload.value(QStringLiteral("filePath")).toString());
    } else if (actionId == QStringLiteral("timeline.start")) {
        runtime->startTimeline();
    } else if (actionId == QStringLiteral("timeline.pause")) {
        runtime->timelineController()->pause();
    } else if (actionId == QStringLiteral("timeline.stop")) {
        runtime->stopTimeline();
    }
}
