#pragma once

#include <QObject>
#include <QPointer>

namespace EarthUI {

class AppSettings;
class AppShellController;

class BaseRuntime : public QObject
{
    Q_OBJECT

    Q_PROPERTY(EarthUI::AppSettings *settings READ settings CONSTANT FINAL)
    Q_PROPERTY(EarthUI::AppShellController *shell READ shell WRITE setShell NOTIFY shellChanged FINAL)

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

} // namespace EarthUI
