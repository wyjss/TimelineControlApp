import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14
import "../base" as Base

Item {
    id: root

    enum DisplayMode {
        Hidden,
        Pinned,
        AutoHide
    }

    // 面板只负责承载内容，不限定内容的业务结构和外观。
    property Component content: null
    // source 非空时优先加载对应 QML，空值继续使用 content。
    property url source: ""
    // 显示策略统一表达固定隐藏、固定显示和鼠标自动显隐。
    property int displayMode: AppSidebarPane.Pinned
    // 仅在 AutoHide 模式下使用；面板自身和桥接区的悬停会在内部合并。
    property bool triggerActive: false
    property bool animated: true
    property bool loadOnDemand: true
    property bool retainContent: true
    property int edge: Qt.LeftEdge
    property Item anchorItem: null
    property real paneWidth: resolvedTheme.shell.sidebarWidth
    property real inset: resolvedTheme.shell.shellOverlayMargin
    property real gap: inset
    property int revealDelay: resolvedTheme.motion.shellPanelRevealDelay
    property int hideDelay: resolvedTheme.motion.shellPanelHideDelay

    // 实际显隐状态由显示模式和自动隐藏控制器共同维护，调用方只读。
    readonly property bool opened: paneState.opened
    readonly property Item paneItem: paneLoader.item
    readonly property bool hasSource: source.toString().length > 0
    // 对外提供 Pane 与桥接区的合并悬停状态，便于相邻 Sidebar 保持展开。
    readonly property bool hovered: paneHoverArea.containsMouse || bridgeHoverHandler.hovered
    readonly property bool rightEdge: edge === Qt.RightEdge
    readonly property real anchorX: anchorItem
        ? (rightEdge ? anchorItem.x : anchorItem.x + anchorItem.width)
        : (rightEdge ? width : 0)
    readonly property QtObject applicationWindowTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : null
    readonly property QtObject windowTheme: Window.window && Window.window.appTheme
        ? Window.window.appTheme
        : null
    readonly property QtObject currentWindowTheme: applicationWindowTheme
        ? applicationWindowTheme
        : windowTheme
    property QtObject _retainedTheme: currentWindowTheme
    readonly property QtObject resolvedTheme: _retainedTheme

    // 固定模式直接决定状态；进入自动模式时保留当前状态并交给触发器收敛。
    function syncDisplayMode() {
        if (displayMode === AppSidebarPane.Hidden)
            paneState.opened = false
        else if (displayMode === AppSidebarPane.Pinned)
            paneState.opened = true
    }

    function reveal() {
        if (displayMode === AppSidebarPane.AutoHide)
            paneState.opened = true
    }

    function dismiss() {
        if (displayMode === AppSidebarPane.AutoHide)
            paneState.opened = false
    }

    onOpenedChanged: {
        if (opened)
            contentLoadState.activated = true
    }
    onDisplayModeChanged: syncDisplayMode()

    Component.onCompleted: {
        syncDisplayMode()
        contentLoadState.activated = opened
    }

    QtObject {
        id: paneState

        // 唯一的内部显隐状态；初始关闭，完成构造后由 displayMode 决定。
        property bool opened: false
    }

    QtObject {
        id: contentLoadState

        // 记录内容是否创建过，关闭后由 retainContent 决定是否继续保留。
        property bool activated: false
    }

    onCurrentWindowThemeChanged: {
        if (currentWindowTheme)
            _retainedTheme = currentWindowTheme
    }

    Base.AppAutoHideController {
        enabled: root.displayMode === AppSidebarPane.AutoHide
        opened: root.opened
        triggerActive: root.triggerActive || root.hovered
        revealDelay: root.revealDelay
        hideDelay: root.hideDelay
        onOpenRequested: function(opened) {
            paneState.opened = opened
        }
    }

    Item {
        id: hoverBridge

        x: root.rightEdge ? root.anchorX - width : root.anchorX
        y: root.inset
        width: root.gap
        height: Math.max(0, parent.height - root.inset * 2)
        visible: root.displayMode === AppSidebarPane.AutoHide && root.opened

        HoverHandler {
            id: bridgeHoverHandler

            acceptedDevices: PointerDevice.Mouse
        }
    }

    Item {
        id: pane

        x: root.rightEdge
            ? (root.opened ? root.anchorX - width - root.gap : root.anchorX + root.gap)
            : (root.opened ? root.anchorX + root.gap : root.anchorX - width - root.gap)
        y: root.inset
        width: root.paneWidth
        height: Math.max(0, parent.height - root.inset * 2)
        visible: opacity > 0 || root.opened
        opacity: root.opened ? 1 : 0

        Loader {
            id: paneLoader

            anchors.fill: parent
            active: (root.content !== null || root.hasSource)
                && (!root.loadOnDemand
                    || root.opened
                    || pane.visible
                    || (root.retainContent && contentLoadState.activated))
            source: root.hasSource ? root.source : ""
            sourceComponent: root.hasSource ? null : root.content

            MouseArea {
                id: paneHoverArea

                anchors.fill: parent
                z: 1
                hoverEnabled: root.displayMode === AppSidebarPane.AutoHide
                // 只跟踪悬停，点击继续交给面板内容。
                acceptedButtons: Qt.NoButton
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            z: 2
            radius: root.resolvedTheme.shape.panelRadius + 1
            color: "transparent"
            border.width: 1
            border.color: root.resolvedTheme.colors.borderPane
        }

        Behavior on x {
            enabled: root.animated

            NumberAnimation {
                duration: root.resolvedTheme.motion.durationStandard
                easing.type: root.resolvedTheme.motion.easingStandard
            }
        }

        Behavior on width {
            enabled: root.animated

            NumberAnimation {
                duration: root.resolvedTheme.motion.durationStandard
                easing.type: root.resolvedTheme.motion.easingStandard
            }
        }

        Behavior on opacity {
            enabled: root.animated

            NumberAnimation {
                duration: root.resolvedTheme.motion.durationFast
                easing.type: root.resolvedTheme.motion.easingStandard
            }
        }
    }
}
