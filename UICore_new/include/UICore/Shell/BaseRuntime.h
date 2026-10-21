#pragma once

#include <QObject>
#include <QPointer>

namespace UICore {

class AppSettings;
class AppShellController;

class BaseRuntime : public QObject
{
    Q_OBJECT

    Q_PROPERTY(UICore::AppSettings *settings READ settings CONSTANT FINAL)
    Q_PROPERTY(UICore::AppShellController *shell READ shell WRITE setShell NOTIFY shellChanged FINAL)

public:
    explicit BaseRuntime(QObject *parent = nullptr);

    AppSettings *settings() const;
    AppShellController *shell() const;
    void setShell(AppShellController *shell);

signals:
    void shellChanged();

private:
    AppSettings *m_settings = nullptr;
    QPointer<AppShellController> m_shell;
};

} // namespace UICore
