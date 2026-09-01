#include "location/FenceManager.h"

#include <QDataStream>
#include <QVariantMap>

FenceManager::FenceManager(QObject *parent)
    : QObject(parent)
{
}

QVariantList FenceManager::fences() const
{
    return m_fences;
}

bool FenceManager::upsertFence(const QString &handle,
                               const QString &name,
                               double startLongitude,
                               double startLatitude,
                               double endLongitude,
                               double endLatitude)
{
    const QString value = handle.trimmed();
    if (value.isEmpty())
        return false;

    const QVariantMap fence{
        {QStringLiteral("handle"), value},
        {QStringLiteral("name"), name.trimmed().isEmpty() ? value : name.trimmed()},
        {QStringLiteral("startLongitude"), startLongitude},
        {QStringLiteral("startLatitude"), startLatitude},
        {QStringLiteral("endLongitude"), endLongitude},
        {QStringLiteral("endLatitude"), endLatitude}
    };
    for (int index = 0; index < m_fences.size(); ++index) {
        if (m_fences.at(index).toMap().value(QStringLiteral("handle")).toString() == value) {
            m_fences[index] = fence;
            emit fencesChanged();
            return true;
        }
    }

    m_fences.append(fence);
    emit fencesChanged();
    return true;
}

bool FenceManager::removeFence(const QString &handle)
{
    for (int index = 0; index < m_fences.size(); ++index) {
        if (m_fences.at(index).toMap().value(QStringLiteral("handle")).toString() == handle) {
            m_fences.removeAt(index);
            emit fencesChanged();
            return true;
        }
    }
    return false;
}

void FenceManager::clear()
{
    if (m_fences.isEmpty())
        return;

    m_fences.clear();
    emit fencesChanged();
}

void FenceManager::writeToStream(QDataStream &stream) const
{
    stream << m_fences;
}

void FenceManager::readFromStream(QDataStream &stream)
{
    stream >> m_fences;
    emit fencesChanged();
}
