#include "TimelineShellController.h"

#include "TimelineRuntime.h"
#include "timeline/Timeline.h"
#include "timeline/TimelineManager.h"

#include <QDir>
#include <QFileInfo>
#include <QUrl>


namespace {

QUrl iconSource(const QString &fileName)
{
    auto f = QStringLiteral("./assets/icons/") + fileName;
	if (QFile::exists(f) == false) {
		f = QFileInfo(QString::fromUtf8(__FILE__)).dir().absoluteFilePath(QString("../") + f);
	}
    return QUrl::fromLocalFile(f);
}

}

TimelineShellController::TimelineShellController(QObject *parent)
    : AppShellController(parent)
    , m_navigationItems{
          QVariantMap{
              {QStringLiteral("key"), QStringLiteral("devices")},
              {QStringLiteral("label"), tr("设备")},
              {QStringLiteral("iconSource"), iconSource(QStringLiteral("设备.svg"))},
              {QStringLiteral("source"), QStringLiteral("qrc:/TimelineControlApp/App/pages/DevicesPage.qml")}
          },
          QVariantMap{
              {QStringLiteral("key"), QStringLiteral("timeline")},
              {QStringLiteral("label"), tr("时间线")},
              {QStringLiteral("iconSource"), iconSource(QStringLiteral("节目单.svg"))},
              {QStringLiteral("source"), QStringLiteral("qrc:/TimelineControlApp/App/pages/TimelinePage.qml")}
          },
          QVariantMap{
              {QStringLiteral("key"), QStringLiteral("locator")},
              {QStringLiteral("label"), tr("地图")},
              {QStringLiteral("iconSource"), iconSource(QStringLiteral("地图.svg"))},
              {QStringLiteral("source"), QString()}
          },
          QVariantMap{
              {QStringLiteral("key"), QStringLiteral("device-control")},
              {QStringLiteral("label"), tr("设备控制")},
              {QStringLiteral("iconName"), QStringLiteral("background-task")},
              {QStringLiteral("source"), QStringLiteral("qrc:/TimelineControlApp/App/pages/DeviceControlPage.qml")}
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
    if (!runtime || !runtime->timelineManager())
        return;
    TimelineManager *timelineManager = runtime->timelineManager();

    if (actionId == QStringLiteral("timeline.plan.save")) {
        if (timelineManager->playbackState() == TimelineManager::Stopped) {
            const QString filePath = payload.value(QStringLiteral("filePath")).toString();
            runtime->savePlanToFile(filePath.isEmpty() ? runtime->currentPlanFilePath() : filePath);
        }
    } else if (actionId == QStringLiteral("timeline.plan.load")) {
        if (timelineManager->playbackState() == TimelineManager::Stopped)
            runtime->loadPlanFromFile(payload.value(QStringLiteral("filePath")).toString());
    } else if (actionId == QStringLiteral("timeline.start")) {
        if (timelineManager->playbackState() == TimelineManager::Paused)
            timelineManager->resumePlayback();
        else if (timelineManager->playbackState() == TimelineManager::Stopped
                 || timelineManager->playbackState() == TimelineManager::Completed) {
            QStringList timelineIds = timelineManager->playQueue();
            if (timelineIds.isEmpty() && timelineManager->currentTimeline())
                timelineIds.append(timelineManager->currentTimeline()->id());
            timelineManager->startPlayback(timelineIds, payload.value(QStringLiteral("startTimeMs")).toLongLong());
        }
    } else if (actionId == QStringLiteral("timeline.pause")) {
        timelineManager->pausePlayback();
    } else if (actionId == QStringLiteral("timeline.stop")) {
        timelineManager->stopPlayback();
    }
}
