#include "timeline/TimelineModel.h"

#include <QSet>


TimelineModel::TimelineModel(QObject *parent)
    : TypedListModel<Timeline *>(QByteArrayLiteral("timeline"), parent)
{
}

int TimelineModel::count() const
{
    return rowCount();
}

Timeline *TimelineModel::timelineAt(int index) const
{
    return itemAt(index);
}

Timeline *TimelineModel::timelineById(const QString &id) const
{
    const QString normalizedId = id.trimmed();
    for (Timeline *timeline : items()) {
        if (timeline->id() == normalizedId)
            return timeline;
    }
    return nullptr;
}

bool TimelineModel::appendTimeline(Timeline *timeline)
{
    if (!timeline || timelineById(timeline->id()) || !appendItem(timeline))
        return false;
    emit timelinesChanged();
    return true;
}

bool TimelineModel::removeTimelineAt(int index)
{
    if (!removeItemAt(index))
        return false;
    emit timelinesChanged();
    return true;
}

bool TimelineModel::moveTimeline(int fromIndex, int toIndex)
{
    if (!moveItem(fromIndex, toIndex))
        return false;
    emit timelinesChanged();
    return true;
}

bool TimelineModel::resetTimelines(const QList<Timeline *> &timelines)
{
    QSet<QString> ids;
    for (Timeline *timeline : timelines) {
        if (!timeline
            || timeline->id().isEmpty()
            || ids.contains(timeline->id()))
            return false;
        ids.insert(timeline->id());
    }
    if (!resetItems(timelines))
        return false;
    emit timelinesChanged();
    return true;
}

bool TimelineModel::acceptsItem(Timeline *timeline) const
{
    return timeline != nullptr;
}
