#pragma once

#include <QSortFilterProxyModel>

class DeviceModel;
class TimelineManager;

//! 只投影源模型中的对象，不持有设备或指令数据。
class DeviceFilterModel final : public QSortFilterProxyModel
{
    Q_OBJECT

public:
    enum Role
    {
        MatchesFilterRole = Qt::UserRole + 2
    };

    explicit DeviceFilterModel(DeviceModel *deviceModel, TimelineManager *timelineManager);

    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;

private:
    void refreshFilter();

    TimelineManager *m_timelineManager = nullptr;
};
