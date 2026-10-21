#include <UICore/Shell/AppShellController.h>

using namespace UICore;

AppShellController::AppShellController(QObject *parent)
    : QObject(parent)
{
}

QString AppShellController::activeNavigationKey() const
{
    return m_activeNavigationKey;
}

void AppShellController::setActiveNavigationKey(const QString &key)
{
    const QString normalizedKey = key.trimmed();
    if (m_activeNavigationKey == normalizedKey)
        return;

    m_activeNavigationKey = normalizedKey;
    emit activeNavigationKeyChanged();
}

QString AppShellController::canvasInteractionState() const
{
    return m_canvasInteractionState;
}

void AppShellController::setCanvasInteractionState(const QString &state)
{
    if (m_canvasInteractionState == state)
        return;

    m_canvasInteractionState = state;
    emit canvasInteractionStateChanged();
}
