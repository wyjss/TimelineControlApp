#pragma once

#include "runtime/shell/AppShellController.h"

namespace TimelineControl {

class TimelineShellController final : public EarthUI::AppShellController
{
    Q_OBJECT

public:
    explicit TimelineShellController(QObject *parent = nullptr);

    Q_INVOKABLE void handleUiAction(const QString &actionId, const QVariantMap &payload) override;

private:
    void buildDrawers();
    void syncSelection(const QString &title, const QString &detail);
};

} // namespace TimelineControl
