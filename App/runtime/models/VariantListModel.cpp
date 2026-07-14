#include "models/VariantListModel.h"


VariantListModel::VariantListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int VariantListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_values.size();
}

QVariant VariantListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_values.size())
        return {};

    if (role == ValueRole || role == Qt::DisplayRole)
        return m_values.at(index.row());

    return {};
}

QHash<int, QByteArray> VariantListModel::roleNames() const
{
    return {
        {ValueRole, QByteArrayLiteral("value")}
    };
}

QVariantList VariantListModel::values() const
{
    return m_values;
}

void VariantListModel::resetValues(const QVariantList &values)
{
    beginResetModel();
    m_values = values;
    endResetModel();
}

void VariantListModel::setValue(int row, const QVariant &value)
{
    if (row < 0 || row >= m_values.size())
        return;

    m_values[row] = value;
    const QModelIndex changedIndex = index(row, 0);
    emit dataChanged(changedIndex, changedIndex, {ValueRole});
}

void VariantListModel::appendValue(const QVariant &value)
{
    const int row = m_values.size();
    beginInsertRows(QModelIndex(), row, row);
    m_values.append(value);
    endInsertRows();
}

void VariantListModel::removeValue(int row)
{
    if (row < 0 || row >= m_values.size())
        return;

    beginRemoveRows(QModelIndex(), row, row);
    m_values.removeAt(row);
    endRemoveRows();
}

void VariantListModel::clear()
{
    resetValues({});
}
