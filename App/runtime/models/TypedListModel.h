#pragma once

#include <QAbstractListModel>
#include <QByteArray>
#include <QHash>
#include <QList>
#include <QModelIndex>
#include <QVariant>

namespace TimelineControl {

class _SelectedListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int selectedIndex READ selectedIndex WRITE setSelectedIndex NOTIFY selectedIndexChanged FINAL)

public:
    explicit _SelectedListModel(QObject *parent = nullptr)
        : QAbstractListModel(parent)
    {
    }

    int selectedIndex() const
    {
        return m_selectedIndex;
    }

    void setSelectedIndex(int selectedIndex, bool itemChanged = true)
    {
        const int normalizedSelectedIndex = selectedIndex >= 0 && selectedIndex < rowCount() ? selectedIndex : -1;
        if (m_selectedIndex == normalizedSelectedIndex)
            return;

        m_selectedIndex = normalizedSelectedIndex;
        emit selectedIndexChanged();
        if (itemChanged) {
            emit selectedItemChanged();
        }
    }

signals:
    void selectedIndexChanged();
    void selectedItemChanged();

protected:
    void adjustSelectedIndexForRowsInserted(int first, int last)
    {
        if (m_selectedIndex < first)
            return;

        const int insertedCount = last - first + 1;
        if (insertedCount > 0)
            setSelectedIndex(m_selectedIndex + insertedCount, false);
    }

    void adjustSelectedIndexForRowsRemoved(int first, int last)
    {
        if (m_selectedIndex < 0)
            return;

        if (m_selectedIndex >= first && m_selectedIndex <= last) {
            setSelectedIndex(-1);
            return;
        }

        const int removedCount = last - first + 1;
        if (removedCount > 0 && m_selectedIndex > last)
            setSelectedIndex(m_selectedIndex - removedCount, false);
    }

    void adjustSelectedIndexForRowsMoved(int first, int last, int destinationRow)
    {
        if (m_selectedIndex < 0)
            return;

        const int movedCount = last - first + 1;
        if (movedCount <= 0)
            return;

        if (m_selectedIndex >= first && m_selectedIndex <= last) {
            const int offset = m_selectedIndex - first;
            const int movedFirst = destinationRow < first
                ? destinationRow
                : destinationRow - movedCount;
            setSelectedIndex(movedFirst + offset, false);
            return;
        }

        if (destinationRow < first) {
            if (m_selectedIndex >= destinationRow && m_selectedIndex < first)
                setSelectedIndex(m_selectedIndex + movedCount, false);
            return;
        }

        if (destinationRow > last + 1 && m_selectedIndex > last && m_selectedIndex < destinationRow)
            setSelectedIndex(m_selectedIndex - movedCount, false);
    }

    void resetSelectedIndex()
    {
        setSelectedIndex(-1);
    }

private:
    int m_selectedIndex = -1;
};

template <typename T>
class TypedListModel : public _SelectedListModel
{
public:
    enum Role
    {
        ValueRole = Qt::UserRole + 1
    };

    explicit TypedListModel(QObject *parent = nullptr)
        : TypedListModel(QByteArrayLiteral("item"), parent)
    {
    }

    explicit TypedListModel(const QByteArray &roleName, QObject *parent = nullptr)
        : _SelectedListModel(parent)
        , m_roleName(roleName)
    {
//         connect(this, _SelectedListModel::selectedRowChanged, this, [this](int r) {
//                 
//                 });
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

        beginResetModel();
        for (int row = 0; row < m_items.size(); ++row)
            itemRemoved(m_items.at(row), row);

        m_items = items;

        for (int row = 0; row < m_items.size(); ++row)
            itemInserted(m_items.at(row), row);
        resetSelectedIndex();
        endResetModel();

        return true;
    }

    bool setItem(int row, const T &item)
    {
        if (row < 0 || row >= m_items.size() || !acceptsItem(item))
            return false;

        const T oldItem = m_items.at(row);
        if (oldItem == item)
            return true;

        const bool changesSelectedItem = row == selectedIndex() && oldItem != item;
        itemRemoved(oldItem, row);
        m_items[row] = item;
        itemInserted(item, row);

        const QModelIndex changedIndex = index(row, 0);
        emit dataChanged(changedIndex, changedIndex, {ValueRole});
        if (changesSelectedItem) {
            emit selectedItemChanged();
        }
        return true;
    }

    bool insertItem(int row, const T &item)
    {
        if (row < 0 || row > m_items.size() || !acceptsItem(item))
            return false;

        beginInsertRows(QModelIndex(), row, row);
        m_items.insert(row, item);
        itemInserted(item, row);
        adjustSelectedIndexForRowsInserted(row, row);
        endInsertRows();
        return true;
    }

    bool appendItem(const T &item)
    {
        return insertItem(m_items.size(), item);
    }

    bool moveItem(int fromRow, int toRow)
    {
        if (fromRow < 0 || fromRow >= m_items.size() || toRow < 0 || toRow >= m_items.size())
            return false;

        if (fromRow == toRow)
            return true;

        const int destinationRow = fromRow < toRow ? toRow + 1 : toRow;
        if (!beginMoveRows(QModelIndex(), fromRow, fromRow, QModelIndex(), destinationRow))
            return false;

        m_items.move(fromRow, toRow);
        adjustSelectedIndexForRowsMoved(fromRow, fromRow, destinationRow);
        endMoveRows();
        return true;
    }

    bool removeItemAt(int row)
    {
        if (row < 0 || row >= m_items.size())
            return false;

        const T item = m_items.at(row);
        beginRemoveRows(QModelIndex(), row, row);
        itemRemoved(item, row);
        m_items.removeAt(row);
        adjustSelectedIndexForRowsRemoved(row, row);
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
    //T m_selectedItem;
};

} // namespace TimelineControl
