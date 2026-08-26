#pragma once

#include "models/TypedListModel.h"
#include "timeline/Timeline.h"


class TimelineModel final : public TypedListModel<Timeline *>
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY timelinesChanged FINAL)

public:
    explicit TimelineModel(QObject *parent = nullptr);

    int count() const;
    Q_INVOKABLE Timeline *timelineAt(int index) const;
    Timeline *timelineById(const QString &id) const;

signals:
    void timelinesChanged();

protected:
    bool acceptsItem(Timeline *timeline) const override;

private:
    friend class TimelineManager;

    bool appendTimeline(Timeline *timeline);
    bool removeTimelineAt(int index);
    bool moveTimeline(int fromIndex, int toIndex);
    bool resetTimelines(const QList<Timeline *> &timelines);
};


Q_DECLARE_METATYPE(TimelineModel *)
