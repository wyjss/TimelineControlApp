#pragma once

#include <QObject>
#include <QString>

namespace UICore {

class AppShellController : public QObject
{
    Q_OBJECT

    //! 当前激活的导航键。
    Q_PROPERTY(QString activeNavigationKey READ activeNavigationKey WRITE setActiveNavigationKey NOTIFY activeNavigationKeyChanged FINAL)
    //! 画布交互状态，用于驱动壳层行为。
    Q_PROPERTY(QString canvasInteractionState READ canvasInteractionState WRITE setCanvasInteractionState NOTIFY canvasInteractionStateChanged FINAL)
public:
    explicit AppShellController(QObject *parent = nullptr);

    QString activeNavigationKey() const;
    void setActiveNavigationKey(const QString &key);

    QString canvasInteractionState() const;
    void setCanvasInteractionState(const QString &state);

signals:
    void activeNavigationKeyChanged();
    void canvasInteractionStateChanged();

private:
    QString m_activeNavigationKey;
    QString m_canvasInteractionState = QStringLiteral("idle");
};

} // namespace UICore

Q_DECLARE_METATYPE(UICore::AppShellController *)
