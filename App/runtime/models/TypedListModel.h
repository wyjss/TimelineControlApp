#pragma once

#include <QAbstractListModel>
#include <QByteArray>
#include <QHash>
#include <QList>
#include <QModelIndex>
#include <QVariant>

namespace TimelineControl {

template <typename T>
class TypedListModel : public QAbstractListModel
{
public:
    enum Role
    {
        ValueRole = Qt::UserRole + 1
    };

    explicit TypedListModel(QObject *parent = nullptr)
        : TypedListModel(QByteArrayLiteral("value"), parent)
    {
    }

    explicit TypedListModel(const QByteArray &roleName, QObject *parent = nullptr)
        : QAbstractListModel(parent)
        , m_roleName(roleName)
    {
    }

public: // QAbstractListModel
    int rowCount(const QModelIndex &parent = QModelIndex()) const override
    {
        return parent.isValid() ? 0 : m_items.size();
    }

    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override
    {
        if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
            return {};

        if (role == ValueRole || role == Qt::DisplayRole)
            return QVariant::fromValue(m_items.at(index.row()));

        return {};
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return {
            {ValueRole, m_roleName}
        };
    }

public:
    const QList<T> &items() const
    {
        return m_items;
    }

    T itemAt(int row) const
    {
        return row >= 0 && row < m_items.size() ? m_items.at(row) : T();
    }

    int indexOfItem(const T &item) const
    {
        return m_items.indexOf(item);
    }

protected:
    virtual bool acceptsItem(T item) const
    {
        Q_UNUSED(item)
        return true;
    }

    virtual void itemInserted(T item, int row)
    {
        Q_UNUSED(item)
        Q_UNUSED(row)
    }

    virtual void itemRemoved(T item, int row)
    {
        Q_UNUSED(item)
        Q_UNUSED(row)
    }

    bool resetItems(const QList<T> &items)
    {
        for (const T &item : items) {
            if (!acceptsItem(item))
                return false;
        }

        for (int row = 0; row < m_items.size(); ++row)
            itemRemoved(m_items.at(row), row);

        beginResetModel();
        m_items = items;
        endResetModel();

        for (int row = 0; row < m_items.size(); ++row)
            itemInserted(m_items.at(row), row);

        return true;
    }

    bool setItem(int row, const T &item)
    {
        if (row < 0 || row >= m_items.size() || !acceptsItem(item))
            return false;

        const T oldItem = m_items.at(row);
        itemRemoved(oldItem, row);
        m_items[row] = item;
        itemInserted(item, row);

        const QModelIndex changedIndex = index(row, 0);
        emit dataChanged(changedIndex, changedIndex, {ValueRole});
        return true;
    }

    bool appendItem(const T &item)
    {
        if (!acceptsItem(item))
            return false;

        const int row = m_items.size();
        beginInsertRows(QModelIndex(), row, row);
        m_items.append(item);
        itemInserted(item, row);
        endInsertRows();
        return true;
    }

    bool removeItemAt(int row)
    {
        if (row < 0 || row >= m_items.size())
            return false;

        itemRemoved(m_items.at(row), row);
        beginRemoveRows(QModelIndex(), row, row);
        m_items.removeAt(row);
        endRemoveRows();
        return true;
    }

    void clearItems()
    {
        resetItems({});
    }

    void notifyItemChanged(int row)
    {
        if (row < 0 || row >= m_items.size())
            return;

        const QModelIndex changedIndex = index(row, 0);
        emit dataChanged(changedIndex, changedIndex, {ValueRole});
    }

private:
    QList<T> m_items;
    QByteArray m_roleName;
};

} // namespace TimelineControl
