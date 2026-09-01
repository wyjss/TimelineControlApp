#pragma once

#include <QObject>
#include <QVariantList>

class QDataStream;

//! 实例由 TimelineRuntime 创建并管理。
class FenceManager final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList fences READ fences NOTIFY fencesChanged FINAL)

public:
    explicit FenceManager(QObject *parent = nullptr);

    QVariantList fences() const;
    Q_INVOKABLE bool upsertFence(const QString &handle,
                                 const QString &name,
                                 double startLongitude,
                                 double startLatitude,
                                 double endLongitude,
                                 double endLatitude);
    Q_INVOKABLE bool removeFence(const QString &handle);
    void clear();

    void writeToStream(QDataStream &stream) const;
    void readFromStream(QDataStream &stream);

signals:
    void fencesChanged();

private:
    QVariantList m_fences;
};

Q_DECLARE_METATYPE(FenceManager *)
