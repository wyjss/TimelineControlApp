#pragma once

#include <QAbstractListModel>
#include <QVariant>
#include <QVariantList>


class VariantListModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Role
    {
        ValueRole = Qt::UserRole + 1
    };

    explicit VariantListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    QVariantList values() const;
    void resetValues(const QVariantList &values);
    void setValue(int row, const QVariant &value);
    void appendValue(const QVariant &value);
    void removeValue(int row);
    void clear();

private:
    QVariantList m_values;
};
