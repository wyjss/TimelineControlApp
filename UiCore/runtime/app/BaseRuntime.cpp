#include "BaseRuntime.h"

#include <QMetaType>

#include "AppSettings.h"
#include "runtime/shell/AppShellController.h"

namespace EarthUI {

	BaseRuntime::BaseRuntime(QObject* parent)
    : QObject(parent)
    , m_settings(new AppSettings(this))
{
    qRegisterMetaType<EarthUI::AppSettings *>("EarthUI::AppSettings*");
    qRegisterMetaType<EarthUI::AppShellController *>("EarthUI::AppShellController*");
}

AppSettings *BaseRuntime::settings() const
{
    return m_settings;
}

AppShellController *BaseRuntime::shell() const
{
    return m_shell;
}

void BaseRuntime::setShell(AppShellController *shell)
{
    if (m_shell == shell)
        return;

    m_shell = shell;
    if (m_shell && !m_shell->parent())
        m_shell->setParent(this);

    emit shellChanged();
}

} // namespace EarthUI
