#pragma once

#include <QList>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>

namespace EarthUI {

class AppDrawer;

class AppShellController : public QObject
{
    Q_OBJECT

    //! 当前激活的菜单键，同时驱动左侧 rail 和 detail pane。
    Q_PROPERTY(QString activeDrawerKey READ activeDrawerKey WRITE setActiveDrawerKey NOTIFY activeDrawerKeyChanged FINAL)
    //! 左侧 detail pane 的显隐状态。
    Q_PROPERTY(bool drawerOpen READ drawerOpen WRITE setDrawerOpen NOTIFY drawerOpenChanged FINAL)
    //! 右侧 inspector 的显隐状态。
    Q_PROPERTY(bool rightPanelOpen READ rightPanelOpen WRITE setRightPanelOpen NOTIFY rightPanelOpenChanged FINAL)
    //! 左侧菜单是否允许自动收起。
    Q_PROPERTY(bool leftPanelAutoHide READ leftPanelAutoHide WRITE setLeftPanelAutoHide NOTIFY leftPanelAutoHideChanged FINAL)
    //! 画布交互状态，用于驱动壳层行为。
    Q_PROPERTY(QString canvasInteractionState READ canvasInteractionState WRITE setCanvasInteractionState NOTIFY canvasInteractionStateChanged FINAL)
    //! 左侧 pane 的过滤文本。
    Q_PROPERTY(QString leftPaneFilterText READ leftPaneFilterText WRITE setLeftPaneFilterText NOTIFY leftPaneFilterTextChanged FINAL)
    //! 提供给壳层的已注册菜单数据，只读暴露给 QML 消费。
    Q_PROPERTY(QVariantList drawers READ drawers NOTIFY drawersChanged FINAL)
    //! 右侧 inspector 的正式对象桥接。
    Q_PROPERTY(QObject *inspectorObject READ inspectorObject WRITE setInspectorObject NOTIFY inspectorObjectChanged FINAL)
    //! 右侧 inspector 数据。
    Q_PROPERTY(QVariant inspectorData READ inspectorData WRITE setInspectorData NOTIFY inspectorDataChanged FINAL)
    //! 底部 selection overlay 数据。
    Q_PROPERTY(QVariantMap selectionData READ selectionData WRITE setSelectionData NOTIFY selectionDataChanged FINAL)

public:
    explicit AppShellController(QObject *parent = nullptr);

    QString activeDrawerKey() const;
    void setActiveDrawerKey(const QString &key);

    bool drawerOpen() const;
    void setDrawerOpen(bool open);

    bool rightPanelOpen() const;
    void setRightPanelOpen(bool open);

    bool leftPanelAutoHide() const;
    void setLeftPanelAutoHide(bool enabled);

    QString canvasInteractionState() const;
    void setCanvasInteractionState(const QString &state);

    QString leftPaneFilterText() const;
    void setLeftPaneFilterText(const QString &text);

    QVariantList drawers() const;

    QObject *inspectorObject() const;
    void setInspectorObject(QObject *inspectorObject);

    QVariant inspectorData() const;
    void setInspectorData(const QVariant &data);

    QVariantMap selectionData() const;
    void setSelectionData(const QVariantMap &data);

    //! 允许应用层从 C++ 侧注册菜单。
    void registerDrawer(AppDrawer *drawer);
    //! 按 key 注销已注册菜单。
    void unregisterDrawer(const QString &key);

    //! 供 QML 在菜单切换时调用。
    Q_INVOKABLE void selectDrawer(const QString &key);
    //! 供 QML 切换右侧 inspector 面板。
    Q_INVOKABLE void toggleRightPanel();
    //! 供 QML 把交互动作回传给 C++。
    Q_INVOKABLE virtual void handleUiAction(const QString &actionId, const QVariantMap &payload);

signals:
    void activeDrawerKeyChanged();
    void drawerOpenChanged();
    void rightPanelOpenChanged();
    void leftPanelAutoHideChanged();
    void canvasInteractionStateChanged();
    void leftPaneFilterTextChanged();
    void drawersChanged();
    void inspectorObjectChanged();
    void inspectorDataChanged();
    void selectionDataChanged();

    //! 对外转发壳层动作，便于业务层继续扩展。
    void uiActionTriggered(const QString &actionId, const QVariantMap &payload);

protected:
    QString normalizeDrawerKey(const QString &key) const;
    QString defaultDrawerKey() const;
    AppDrawer *registeredDrawer(const QString &key) const;

private:
    void syncInspectorObject(QObject *inspectorObject);
    void connectDrawerSignals(AppDrawer *drawer);
    void disconnectDrawerSignals(AppDrawer *drawer);
    void refreshDrawersFromRegisteredObjects();
    void syncActiveDrawerKeyAfterDrawerChange();
    void removeRegisteredDrawer(QObject *drawerObject);

    QString m_activeDrawerKey;
    bool m_drawerOpen = true;
    bool m_rightPanelOpen = false;
    bool m_leftPanelAutoHide = false;
    QString m_canvasInteractionState = QStringLiteral("idle");
    QString m_leftPaneFilterText;
    QVariantList m_drawers;
    QPointer<QObject> m_inspectorObject;
    QVariant m_inspectorData;
    QVariantMap m_selectionData;
    QList<QPointer<AppDrawer>> m_registeredDrawers;
};

} // namespace EarthUI

Q_DECLARE_METATYPE(EarthUI::AppShellController *)
