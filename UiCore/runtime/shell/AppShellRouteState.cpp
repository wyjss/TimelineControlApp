#include "AppShellRouteState.h"

namespace EarthUI {

AppShellRouteState::AppShellRouteState(QObject *parent)
    : QObject(parent)
{
}

bool AppShellRouteState::active() const
{
    return !m_dialogKey.isEmpty();
}

QString AppShellRouteState::dialogKey() const
{
    return m_dialogKey;
}

QString AppShellRouteState::mode() const
{
    return m_mode;
}

QString AppShellRouteState::targetName() const
{
    return m_targetName;
}

QVariantMap AppShellRouteState::payload() const
{
    return m_payload;
}

void AppShellRouteState::setDialogRoute(const QString &dialogKey,
                                        const QString &mode,
                                        const QString &targetName,
                                        const QVariantMap &payload)
{
    const QString normalizedDialogKey = dialogKey.trimmed();
    const QString normalizedMode = mode.trimmed();
    const QString normalizedTargetName = targetName.trimmed();

    if (m_dialogKey == normalizedDialogKey
        && m_mode == normalizedMode
        && m_targetName == normalizedTargetName
        && m_payload == payload) {
        return;
    }

    m_dialogKey = normalizedDialogKey;
    m_mode = normalizedMode;
    m_targetName = normalizedTargetName;
    m_payload = payload;
    emit routeChanged();
}

void AppShellRouteState::clear()
{
    if (m_dialogKey.isEmpty()
        && m_mode.isEmpty()
        && m_targetName.isEmpty()
        && m_payload.isEmpty()) {
        return;
    }

    m_dialogKey.clear();
    m_mode.clear();
    m_targetName.clear();
    m_payload.clear();
    emit routeChanged();
}

} // namespace EarthUI
