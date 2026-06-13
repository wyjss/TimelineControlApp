#include "AppMenuModel.h"

namespace EarthUI {

namespace {

QVariantList blockListValues(const QList<QObject *> &blocks)
{
    QVariantList values;
    values.reserve(blocks.size());

    for (QObject *block : blocks)
        values.append(QVariant::fromValue(block));

    return values;
}

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
    return blockListValues(m_blocks);
}

QVariantList AppMenuModel::fixedTopBlocks() const
{
    return blockListValues(m_fixedTopBlocks);
}

void AppMenuModel::appendBlock(QObject *block)
{
    if (!block || m_blocks.contains(block))
        return;

    if (!block->parent())
        block->setParent(this);

    m_blocks.append(block);
    emit blocksChanged();
}

void AppMenuModel::appendFixedTopBlock(QObject *block)
{
    if (!block || m_fixedTopBlocks.contains(block))
        return;

    if (!block->parent())
        block->setParent(this);

    m_fixedTopBlocks.append(block);
    emit fixedTopBlocksChanged();
}

void AppMenuModel::clearBlocks()
{
    clearFixedTopBlocks();

    if (m_blocks.isEmpty())
        return;

    const QList<QObject *> blocksToRemove = m_blocks;
    m_blocks.clear();
    emit blocksChanged();

    releaseOwnedBlocks(blocksToRemove, this);
}

void AppMenuModel::clearFixedTopBlocks()
{
    if (m_fixedTopBlocks.isEmpty())
        return;

    const QList<QObject *> blocksToRemove = m_fixedTopBlocks;
    m_fixedTopBlocks.clear();
    emit fixedTopBlocksChanged();

    releaseOwnedBlocks(blocksToRemove, this);
}

void AppMenuModel::handleAction(const QString &actionId, const QVariantMap &payload)
{
    Q_UNUSED(actionId)
    Q_UNUSED(payload)
}

void AppMenuModel::handleFieldEdited(const QString &fieldKey, const QVariant &value)
{
    Q_UNUSED(fieldKey)
    Q_UNUSED(value)
}

} // namespace EarthUI
