import QtQuick 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "components/base" as Base
import "components/shell" as Shell

Base.AppBackdrop {
    id: root

    property alias topNavigationBar: topMenuBar
    property alias bottomNavigationBar: bottomMenuBar
    property alias sidebar: leftSidebar
    property alias sidebarPane: leftSidebarPane
    property alias leftPaneContent: leftSidebarPane.content
    property alias leftPaneSource: leftSidebarPane.source
    property alias leftPanelWidth: leftSidebarPane.paneWidth
    property string applicationTitle: qsTr("应用")
    property bool showBottomBar: (bottomMenuBar.menuItems
        && bottomMenuBar.menuItems.length > 0)
        || bottomMenuBar.content !== null
        || bottomMenuBar.trailingContent !== null
    property var navigationItems: []
    property string activeNavigationKey: ""
    property bool sidebarOpen: true
    // 左侧 Pane 的配置模式；应用只需选择固定隐藏、固定显示或自动显隐。
    property int leftPaneDisplayMode: Shell.AppSidebarPane.Pinned
    property bool sidebarAutoHideSuspended: false
    property bool sidebarAutoHideTriggerActive: false
    property string canvasInteractionState: "idle"
    property string canvasDelegateSource: ""

    signal navigationRequested(string key)
    signal sidebarOpenRequested(bool open)

    readonly property QtObject shellTheme: resolvedTheme.shell
    readonly property int topBarHeight: shellTheme.topBarHeight
    readonly property int bottomBarHeight: shellTheme.bottomBarHeight
    readonly property int railWidth: shellTheme.railWidth
    readonly property real leftContentInset: leftSidebar.occupiedWidth
    readonly property int overlayMargin: shellTheme.shellOverlayMargin

    // 画布交互期间把自动显隐临时解释为固定显示，交互结束后自动恢复配置模式。
    readonly property int effectiveLeftPaneDisplayMode:
        leftPaneDisplayMode === Shell.AppSidebarPane.AutoHide
            && canvasInteractionState !== "idle"
        ? Shell.AppSidebarPane.Pinned
        : leftPaneDisplayMode
    // Pane 的实际打开状态是显示模式与鼠标触发共同计算后的只读结果。
    readonly property bool leftPaneOpen: leftSidebarPane.opened
    // 仅表示当前生效的自动模式，供 Sidebar 悬停联动和画布点击收起使用。
    readonly property bool leftPaneAutoHideActive:
        effectiveLeftPaneDisplayMode === Shell.AppSidebarPane.AutoHide
    readonly property bool hasInteractiveCanvas: canvasDelegateSource.length > 0

    function focusCanvas() {
        if (canvasLoader.item)
            canvasLoader.item.forceActiveFocus(Qt.OtherFocusReason)
    }

    // 显示左侧 Pane；未指定模式时使用固定显示。
    function showLeftPane(mode) {
        leftPaneDisplayMode = mode === undefined
            ? Shell.AppSidebarPane.Pinned
            : mode
    }

    // 固定隐藏左侧 Pane。
    function hideLeftPane() {
        leftPaneDisplayMode = Shell.AppSidebarPane.Hidden
    }

    // 在隐藏和指定显示模式之间切换；未指定模式时恢复为固定显示。
    function toggleLeftPane(mode) {
        leftPaneDisplayMode = leftPaneDisplayMode === Shell.AppSidebarPane.Hidden
            ? (mode === undefined ? Shell.AppSidebarPane.Pinned : mode)
            : Shell.AppSidebarPane.Hidden
    }

    sizeToContent: false
    clipContent: true

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Shell.AppTopNavigationBar {
            id: topMenuBar

            Layout.fillWidth: true
            Layout.preferredHeight: root.topBarHeight
            title: root.applicationTitle
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Shell.AppSidebar {
                id: leftSidebar

                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: root.railWidth
                z: 4

                opened: root.sidebarOpen
                menuItems: root.navigationItems
                activeItemKey: root.activeNavigationKey
                interactive: autoHideEnabled || root.leftPaneAutoHideActive
                autoHideSuspended: root.sidebarAutoHideSuspended
                autoHideTriggerActive: leftSidebarPane.hovered
                    || sidebarEdgeHover.hovered
                    || root.sidebarAutoHideTriggerActive
                onOpenRequested: function(opened) {
                    if (root.sidebarOpen !== opened)
                        root.sidebarOpenRequested(opened)
                }
                onItemTriggered: function(key) {
                    root.navigationRequested(key)
                    root.focusCanvas()
                }
            }

            Item {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: leftSidebar.padding
                visible: leftSidebar.autoHideEnabled
                z: leftSidebar.z

                HoverHandler {
                    id: sidebarEdgeHover

                    acceptedDevices: PointerDevice.Mouse
                }
            }

            Item {
                anchors.fill: parent
                anchors.leftMargin: root.leftContentInset

                Base.AppSurface {
                    id: canvasHost

                    anchors.fill: parent
                    sizeToContent: false
                    clipContent: true
                    surfaceTone: UiStyle.SurfaceTone.Canvas
                    shapeRole: UiStyle.ShapeRole.None
                    strokeWidth: 0

                    TapHandler {
                        enabled: !root.hasInteractiveCanvas
                        acceptedButtons: Qt.LeftButton
                        onTapped: {
                            if (root.leftPaneAutoHideActive)
                                leftSidebarPane.dismiss()
                        }
                    }

                    Loader {
                        id: canvasLoader

                        anchors.fill: parent
                        active: root.hasInteractiveCanvas
                        source: root.canvasDelegateSource
                        onLoaded: {
                            if (item)
                                item.forceActiveFocus(Qt.OtherFocusReason)
                        }
                    }
                }
            }

            Shell.AppSidebarPane {
                id: leftSidebarPane

                anchors.fill: parent
                anchorItem: leftSidebar
                displayMode: root.effectiveLeftPaneDisplayMode
                triggerActive: leftSidebar.effectiveHovered
                inset: root.overlayMargin
                gap: root.overlayMargin
                z: 3
            }
        }

        Shell.AppBottomNavigationBar {
            id: bottomMenuBar

            Layout.fillWidth: true
            Layout.preferredHeight: root.bottomBarHeight
            visible: root.showBottomBar
        }
    }

}

