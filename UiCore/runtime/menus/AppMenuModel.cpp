#include "AppMenuModel.h"

#include "runtime/form/AppForm.h"

#include <QtGlobal>

namespace EarthUI {

namespace {

void releaseOwnedBlocks(QList<QObject *> blocks, QObject *owner)
{
    for (QObject *block : blocks) {
        if (block && block->parent() == owner)
            block->deleteLater();
    }
}

} // namespace

AppMenuModel::AppMenuModel(QObject *parent)
    : QObject(parent)
{
}

QString AppMenuModel::title() const
{
    return m_title;
}

void AppMenuModel::setTitle(const QString &title)
{
    if (m_title == title)
        return;

    m_title = title;
    emit titleChanged();
}

QString AppMenuModel::subtitle() const
{
    return m_subtitle;
}

void AppMenuModel::setSubtitle(const QString &subtitle)
{
    if (m_subtitle == subtitle)
        return;

    m_subtitle = subtitle;
    emit subtitleChanged();
}

int AppMenuModel::paneWidth() const
{
    return m_paneWidth;
}

void AppMenuModel::setPaneWidth(int paneWidth)
{
    const int normalizedWidth = qMax(0, paneWidth);
    if (m_paneWidth == normalizedWidth)
        return;

    m_paneWidth = normalizedWidth;
    emit paneWidthChanged();
}

QVariantList AppMenuModel::blocks() const
{
    return m_blocksCache;
}

QVariantList AppMenuModel::fixedTopBlocks() const
{
    return m_fixedTopBlocksCache;
}

int AppMenuModel::blockCount() const
{
    return m_blocks.size();
}

int AppMenuModel::fixedTopBlockCount() const
{
    return m_fixedTopBlocks.size();
}

QObject *AppMenuModel::blockAt(int index) const
{
    if (index < 0 || index >= m_blocks.size())
        return nullptr;

    return m_blocks.at(index);
}

QObject *AppMenuModel::fixedTopBlockAt(int index) const
{
    if (index < 0 || index >= m_fixedTopBlocks.size())
        return nullptr;

    return m_fixedTopBlocks.at(index);
}

bool AppMenuModel::setFieldValue(const QString &fieldKey, const QVariant &value)
{
    const QString normalizedKey = fieldKey.trimmed();
    if (normalizedKey.isEmpty())
        return false;

    auto applyToBlocks = [&](const QList<QObject *> &blocks) {
        for (QObject *block : blocks) {
            AppForm *form = qobject_cast<AppForm *>(block);
            if (form && form->setFieldValue(normalizedKey, value))
                return true;
        }
        return false;
    };

    return applyToBlocks(m_fixedTopBlocks) || applyToBlocks(m_blocks);
}

void AppMenuModel::appendBlock(QObject *block)
{
    appendBlockObject(block, false);
}

void AppMenuModel::appendFixedTopBlock(QObject *block)
{
    appendBlockObject(block, true);
}

void AppMenuModel::clearBlocks()
{
    clearFixedTopBlocks();

    if (m_blocks.isEmpty())
        return;

    const QList<QObject *> blocksToRemove = m_blocks;
    m_blocks.clear();
    m_blocksCache.clear();
    emit blocksChanged();

    for (QObject *block : blocksToRemove)
        QObject::disconnect(block, nullptr, this, nullptr);

    releaseOwnedBlocks(blocksToRemove, this);
}

void AppMenuModel::clearFixedTopBlocks()
{
    if (m_fixedTopBlocks.isEmpty())
        return;

    const QList<QObject *> blocksToRemove = m_fixedTopBlocks;
    m_fixedTopBlocks.clear();
    m_fixedTopBlocksCache.clear();
    emit fixedTopBlocksChanged();

    for (QObject *block : blocksToRemove)
        QObject::disconnect(block, nullptr, this, nullptr);

    releaseOwnedBlocks(blocksToRemove, this);
}

void AppMenuModel::handleAction(const QString &actionId, const QVariantMap &payload)
{
    Q_UNUSED(actionId)
    Q_UNUSED(payload)
}

void AppMenuModel::handleFieldEdited(const QString &fieldKey, const QVariant &value)
{
    setFieldValue(fieldKey, value);
}

bool AppMenuModel::appendBlockObject(QObject *block, bool fixedTop)
{
    if (!block)
        return false;

    QList<QObject *> &targetBlocks = fixedTop ? m_fixedTopBlocks : m_blocks;
    QVariantList &targetCache = fixedTop ? m_fixedTopBlocksCache : m_blocksCache;

    if (targetBlocks.contains(block))
        return false;

    if (!block->parent())
        block->setParent(this);

    targetBlocks.append(block);
    targetCache.append(QVariant::fromValue(block));
    QObject::connect(block,
                     &QObject::destroyed,
                     this,
                     [this](QObject *blockObject) {
                         removeBlockObject(blockObject);
                     });
    emitBlocksChanged(fixedTop);
    return true;
}

void AppMenuModel::removeBlockObject(QObject *blockObject)
{
    auto removeFrom = [blockObject](QList<QObject *> &blocks, QVariantList &cache) {
        for (int index = 0; index < blocks.size(); ++index) {
            if (blocks.at(index) != blockObject)
                continue;

            blocks.removeAt(index);
            if (index < cache.size())
                cache.removeAt(index);
            return true;
        }
        return false;
    };

    const bool removedFixed = removeFrom(m_fixedTopBlocks, m_fixedTopBlocksCache);
    const bool removedRegular = removeFrom(m_blocks, m_blocksCache);

    if (removedFixed)
        emit fixedTopBlocksChanged();
    if (removedRegular)
        emit blocksChanged();
}

void AppMenuModel::emitBlocksChanged(bool fixedTop)
{
    if (fixedTop)
        emit fixedTopBlocksChanged();
    else
        emit blocksChanged();
}

} // namespace EarthUI
