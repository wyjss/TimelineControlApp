#include "devices/DeviceFilterModel.h"

#include "devices/DeviceModel.h"
#include "timeline/TimelineManager.h"

DeviceFilterModel::DeviceFilterModel(DeviceModel *deviceModel, TimelineManager *timelineManager)
    : QSortFilterProxyModel(timelineManager)
    , m_timelineManager(timelineManager)
{
    setFilterRole(DeviceModel::ValueRole);
    setSourceModel(deviceModel);
    connect(timelineManager, &TimelineManager::filterDeviceIdsChanged,
            this, &DeviceFilterModel::refreshFilter);
    connect(timelineManager, &TimelineManager::filterGroupNamesChanged,
            this, &DeviceFilterModel::refreshFilter);
    connect(timelineManager, &TimelineManager::filterDeviceTypesChanged,
            this, &DeviceFilterModel::refreshFilter);
    connect(timelineManager, &TimelineManager::showFilteredOutChanged,
            this, &DeviceFilterModel::refreshFilter);
    if (deviceModel) {
        connect(deviceModel, &DeviceModel::deviceTypesChanged,
                this, &DeviceFilterModel::refreshFilter);
        connect(deviceModel, &DeviceModel::groupNamesChanged,
                this, &DeviceFilterModel::refreshFilter);
    }
}

QVariant DeviceFilterModel::data(const QModelIndex &index, int role) const
{
    if (role == MatchesFilterRole) {
        Device *device = QSortFilterProxyModel::data(index, DeviceModel::ValueRole).value<Device *>();
        return device ? QVariant(m_timelineManager->matchesDeviceFilter(device->id())) : QVariant();
    }
    return QSortFilterProxyModel::data(index, role);
}

QHash<int, QByteArray> DeviceFilterModel::roleNames() const
{
    return {
        {DeviceModel::ValueRole, QByteArrayLiteral("item")},
        {MatchesFilterRole, QByteArrayLiteral("matchesFilter")}
    };
}

bool DeviceFilterModel::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const
{
    if (m_timelineManager->showFilteredOut())
        return true;

    const QModelIndex sourceIndex = sourceModel()->index(sourceRow, 0, sourceParent);
    Device *device = sourceIndex.data(DeviceModel::ValueRole).value<Device *>();
    return device && m_timelineManager->matchesDeviceFilter(device->id());
}

void DeviceFilterModel::refreshFilter()
{
    invalidateFilter();
    if (rowCount() > 0)
        emit dataChanged(index(0, 0), index(rowCount() - 1, 0), {MatchesFilterRole});
}
