#include "AppDrawer.h"

namespace EarthUI {

AppDrawer::AppDrawer(QObject *parent)
    : QObject(parent)
{
}

QString AppDrawer::key() const
{
    return m_key;
}

void AppDrawer::setKey(const QString &key)
{
    if (m_key == key)
        return;

    m_key = key;
    emit keyChanged();
}

QString AppDrawer::label() const
{
    return m_label;
}

void AppDrawer::setLabel(const QString &label)
{
    if (m_label == label)
        return;

    m_label = label;
    emit labelChanged();
}

QString AppDrawer::iconName() const
{
    return m_iconName;
}

void AppDrawer::setIconName(const QString &iconName)
{
    if (m_iconName == iconName)
        return;

    m_iconName = iconName;
    emit iconNameChanged();
}

QString AppDrawer::detail() const
{
    return m_detail;
}

void AppDrawer::setDetail(const QString &detail)
{
    if (m_detail == detail)
        return;

    m_detail = detail;
    emit detailChanged();
}

QVariantMap AppDrawer::leftPaneData() const
{
    return m_leftPaneData;
}

void AppDrawer::setLeftPaneData(const QVariantMap &leftPaneData)
{
    if (m_leftPaneData == leftPaneData)
        return;

    m_leftPaneData = leftPaneData;
    emit leftPaneDataChanged();
}

QUrl AppDrawer::paneDelegateSource() const
{
    return m_paneDelegateSource;
}

void AppDrawer::setPaneDelegateSource(const QUrl &paneDelegateSource)
{
    if (m_paneDelegateSource == paneDelegateSource)
        return;

    m_paneDelegateSource = paneDelegateSource;
    emit paneDelegateSourceChanged();
}

QObject *AppDrawer::paneController() const
{
    return m_paneController;
}

void AppDrawer::setPaneController(QObject *paneController)
{
    if (m_paneController == paneController)
        return;

    m_paneController = paneController;
    emit paneControllerChanged();
}

QVariantMap AppDrawer::toVariantMap() const
{
    QVariantMap drawerData;
    drawerData.insert(QStringLiteral("key"), m_key);
    drawerData.insert(QStringLiteral("label"), m_label);
    drawerData.insert(QStringLiteral("iconName"), m_iconName);
    drawerData.insert(QStringLiteral("detail"), m_detail);
    drawerData.insert(QStringLiteral("leftPane"), m_leftPaneData);
    drawerData.insert(QStringLiteral("paneDelegateSource"), m_paneDelegateSource);
    drawerData.insert(QStringLiteral("paneController"), QVariant::fromValue(m_paneController));
    return drawerData;
}

} // namespace EarthUI
