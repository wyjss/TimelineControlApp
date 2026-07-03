#include "BaseRuntime.h"

#include <QMetaType>

#include "AppSettings.h"
#include "runtime/fields/BaseField.h"
#include "runtime/form/AppForm.h"
#include "runtime/form/AppFormField.h"
#include "runtime/form/AppFormSection.h"
#include "runtime/shell/AppShellController.h"

namespace EarthUI {

BaseRuntime::BaseRuntime(QObject* parent)
    : QObject(parent)
    , m_settings(new AppSettings(this))
{
    qRegisterMetaType<EarthUI::AppSettings *>("EarthUI::AppSettings*");
    qRegisterMetaType<EarthUI::AppShellController *>("EarthUI::AppShellController*");
    qRegisterMetaType<EarthUI::BaseField *>("EarthUI::BaseField*");
    qRegisterMetaType<EarthUI::AppForm *>("EarthUI::AppForm*");
    qRegisterMetaType<EarthUI::AppFormSection *>("EarthUI::AppFormSection*");
    qRegisterMetaType<EarthUI::AppFormField *>("EarthUI::AppFormField*");
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
