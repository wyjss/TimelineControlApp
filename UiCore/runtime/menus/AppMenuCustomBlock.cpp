#include "AppMenuCustomBlock.h"

namespace EarthUI {

AppMenuCustomBlock::AppMenuCustomBlock(QObject *parent)
    : QObject(parent)
{
}

QString AppMenuCustomBlock::title() const
{
    return m_title;
}

void AppMenuCustomBlock::setTitle(const QString &title)
{
    if (m_title == title)
        return;

    m_title = title;
    emit titleChanged();
}

QString AppMenuCustomBlock::subtitle() const
{
    return m_subtitle;
}

void AppMenuCustomBlock::setSubtitle(const QString &subtitle)
{
    if (m_subtitle == subtitle)
        return;

    m_subtitle = subtitle;
    emit subtitleChanged();
}

int AppMenuCustomBlock::menuBlockKind() const
{
    return 1;
}

QUrl AppMenuCustomBlock::delegateSource() const
{
    return m_delegateSource;
}

void AppMenuCustomBlock::setDelegateSource(const QUrl &delegateSource)
{
    if (m_delegateSource == delegateSource)
        return;

    m_delegateSource = delegateSource;
    emit delegateSourceChanged();
}

QObject *AppMenuCustomBlock::controller() const
{
    return m_controller;
}

void AppMenuCustomBlock::setController(QObject *controller)
{
    if (m_controller == controller)
        return;

    m_controller = controller;
    emit controllerChanged();
}

QVariantMap AppMenuCustomBlock::blockData() const
{
    return m_blockData;
}

void AppMenuCustomBlock::setBlockData(const QVariantMap &blockData)
{
    if (m_blockData == blockData)
        return;

    m_blockData = blockData;
    emit blockDataChanged();
}

} // namespace EarthUI
