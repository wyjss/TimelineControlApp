#pragma once

#include <UICore/Shell/AppShellController.h>

#include <QVariantList>


class TimelineShellController final : public UICore::AppShellController
{
    Q_OBJECT
    Q_PROPERTY(QVariantList navigationItems READ navigationItems CONSTANT FINAL)

public:
    explicit TimelineShellController(QObject *parent = nullptr);

    QVariantList navigationItems() const;
    Q_INVOKABLE void handleUiAction(const QString &actionId, const QVariantMap &payload);

private:
    QVariantList m_navigationItems;
};
