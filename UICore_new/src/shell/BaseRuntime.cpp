#include <UICore/Shell/BaseRuntime.h>

#include <QMetaType>

#include <UICore/Fields/AppField.h>
#include <UICore/Fields/BaseField.h>
#include <UICore/Forms/AppForm.h>
#include <UICore/Forms/AppFormSection.h>
#include <UICore/Shell/AppSettings.h>
#include <UICore/Shell/AppShellController.h>

using namespace UICore;

BaseRuntime::BaseRuntime(QObject* parent)
    : QObject(parent)
    , m_settings(new AppSettings(this))
{
    qRegisterMetaType<UICore::AppSettings *>("UICore::AppSettings*");
    qRegisterMetaType<UICore::AppShellController *>("UICore::AppShellController*");
    qRegisterMetaType<UICore::BaseField *>("UICore::BaseField*");
    qRegisterMetaType<UICore::AppForm *>("UICore::AppForm*");
    qRegisterMetaType<UICore::AppFormSection *>("UICore::AppFormSection*");
    qRegisterMetaType<UICore::AppField *>("UICore::AppField*");
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
