#include "timeline/TimelineCommandFilterModel.h"

#include "devices/DeviceModel.h"
#include "timeline/TimelineManager.h"
#include "timeline/Timeline.h"
#include "timeline/TimelineCommand.h"

TimelineCommandFilterModel::TimelineCommandFilterModel(DeviceModel *deviceModel, TimelineManager *timelineManager)
    : QSortFilterProxyModel(timelineManager)
    , m_timelineManager(timelineManager)
{
    setFilterRole(TimelineCommandModel::ValueRole);
    Timeline *timeline = timelineManager->currentTimeline();
    setSourceModel(timeline ? timeline->commandModel() : nullptr);
    connect(timelineManager, &TimelineManager::currentTimelineChanged,
            this, [this](Timeline *currentTimeline) {
        setSourceModel(currentTimeline ? currentTimeline->commandModel() : nullptr);
    });
    connect(timelineManager, &TimelineManager::filterDeviceIdsChanged,
            this, &TimelineCommandFilterModel::refreshFilter);
    connect(timelineManager, &TimelineManager::filterGroupNamesChanged,
            this, &TimelineCommandFilterModel::refreshFilter);
    connect(timelineManager, &TimelineManager::filterDeviceTypesChanged,
            this, &TimelineCommandFilterModel::refreshFilter);
    connect(timelineManager, &TimelineManager::showFilteredOutChanged,
            this, &TimelineCommandFilterModel::refreshFilter);
    if (deviceModel) {
        connect(deviceModel, &DeviceModel::deviceTypesChanged,
                this, &TimelineCommandFilterModel::refreshFilter);
        connect(deviceModel, &DeviceModel::groupNamesChanged,
                this, &TimelineCommandFilterModel::refreshFilter);
    }
}

QVariant TimelineCommandFilterModel::data(const QModelIndex &index, int role) const
{
    if (role == MatchesFilterRole) {
        TimelineCommand *command = QSortFilterProxyModel::data(index, TimelineCommandModel::ValueRole)
            .value<TimelineCommand *>();
        return command ? QVariant(m_timelineManager->matchesDeviceFilter(command->targetDeviceId())) : QVariant();
    }
    return QSortFilterProxyModel::data(index, role);
}

QHash<int, QByteArray> TimelineCommandFilterModel::roleNames() const
{
    return {
        {TimelineCommandModel::ValueRole, QByteArrayLiteral("command")},
        {MatchesFilterRole, QByteArrayLiteral("matchesFilter")}
    };
}

bool TimelineCommandFilterModel::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const
{
    if (m_timelineManager->showFilteredOut())
        return true;

    const QModelIndex sourceIndex = sourceModel()->index(sourceRow, 0, sourceParent);
    TimelineCommand *command = sourceIndex.data(TimelineCommandModel::ValueRole).value<TimelineCommand *>();
    return command && m_timelineManager->matchesDeviceFilter(command->targetDeviceId());
}

void TimelineCommandFilterModel::refreshFilter()
{
    invalidateFilter();
    if (rowCount() > 0)
        emit dataChanged(index(0, 0), index(rowCount() - 1, 0), {MatchesFilterRole});
}
