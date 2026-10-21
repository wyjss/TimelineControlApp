import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtQuick.Window 2.14
import UICore.Style 1.0

Popup {
    id: root

    default property alias popupContent: contentColumn.data

    property int surfaceTone: UiStyle.SurfaceTone.Popup
    property real surfaceOpacityScale: 1.0
    property real cornerRadius: -1
    property int strokeWidth: 1
    property int revealOrigin: Item.Center
    property real revealOffsetY: 0
    property color overlayColor: themeReady ? resolvedTheme.colors.scrim : "transparent"
    property real overlayOpacity: 0.44
    property bool showModalOverlay: modal
    property bool elevated: true
    property color shadowColor: themeReady ? resolvedTheme.colors.scrim : "transparent"
    property real shadowOpacity: 0.24
    property int shadowSize: themeReady ? resolvedTheme.density.controlGap : 0
    property bool draggable: false
    property Item dragHandle: null
    property bool constrainDragToParent: true
    property int revealDuration: themeReady ? resolvedTheme.motion.durationStandard : 0
    property int dismissDuration: themeReady ? resolvedTheme.motion.durationFast : 0
    readonly property QtObject applicationWindowTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : null
    readonly property QtObject windowTheme: Window.window && Window.window.appTheme
        ? Window.window.appTheme
        : null
    readonly property QtObject owningWindow: Window.window
    readonly property QtObject currentWindowTheme: applicationWindowTheme
        ? applicationWindowTheme
        : windowTheme
    property QtObject _retainedTheme: currentWindowTheme
    readonly property bool themeReady: !!resolvedTheme
    readonly property Item _dragAreaItem: MouseArea {
        id: dragArea

        parent: root.dragHandle
        anchors.fill: parent
        enabled: root.draggable && !!root.dragHandle && !!root.parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.SizeAllCursor
        preventStealing: true

        property real pressParentX: 0
        property real pressParentY: 0
        property real popupStartX: 0
        property real popupStartY: 0

        onPressed: {
            var pressPosition = mapToItem(root.parent, mouse.x, mouse.y)
            pressParentX = pressPosition.x
            pressParentY = pressPosition.y
            popupStartX = root.x
            popupStartY = root.y
        }

        onPositionChanged: {
            if (!pressed || !root.parent)
                return

            var currentPosition = mapToItem(root.parent, mouse.x, mouse.y)
            var nextX = popupStartX + currentPosition.x - pressParentX
            var nextY = popupStartY + currentPosition.y - pressParentY

            if (root.constrainDragToParent) {
                nextX = Math.max(0, Math.min(nextX, root.parent.width - root.width))
                nextY = Math.max(0, Math.min(nextY, root.parent.height - root.height))
            }

            root.x = nextX
            root.y = nextY
        }
    }
    readonly property QtObject _motionStateObject: QtObject {
        id: motionState

        property real contentRevealProgress: root.visible ? 1 : 0
        property real overlayRevealProgress: root.visible && root.showModalOverlay ? 1 : 0
    }
    readonly property QtObject resolvedTheme: _retainedTheme
    readonly property real popupRevealOffset: themeReady ? resolvedTheme.motion.transitionOffset : 0
    readonly property int emphasizedEasing: themeReady ? resolvedTheme.motion.easingEmphasized : Easing.Linear
    readonly property int standardEasing: themeReady ? resolvedTheme.motion.easingStandard : Easing.Linear
    readonly property real popupRevealStartScale: 0.985
    readonly property real contentRevealProgress: motionState.contentRevealProgress
    readonly property real overlayRevealProgress: motionState.overlayRevealProgress
    readonly property real resolvedCornerRadius: cornerRadius >= 0
        ? cornerRadius
        : (themeReady ? resolvedTheme.shape.overlayRadius : 0)

    padding: themeReady ? resolvedTheme.density.panePadding : 0
    spacing: themeReady ? resolvedTheme.density.paneContentSpacing : 0
    opacity: root.contentRevealProgress
    scale: root.popupRevealStartScale + (1 - root.popupRevealStartScale) * root.contentRevealProgress
    transformOrigin: root.revealOrigin

    onCurrentWindowThemeChanged: {
        if (currentWindowTheme)
            _retainedTheme = currentWindowTheme
    }
    onOwningWindowChanged: Qt.callLater(function() {
        if (root.owningWindow && !root.currentWindowTheme)
            console.error("UICore AppPopup requires appTheme on its window")
    })

    function resolvedOverlayColor() {
        return Qt.rgba(overlayColor.r, overlayColor.g, overlayColor.b, overlayOpacity)
    }

    Overlay.modal: Rectangle {
        visible: root.showModalOverlay || opacity > 0.001
        color: root.resolvedOverlayColor()
        opacity: root.showModalOverlay ? root.overlayRevealProgress : 0
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                target: motionState
                property: "contentRevealProgress"
                from: 0
                to: 1
                duration: root.revealDuration
                easing.type: root.emphasizedEasing
            }

            NumberAnimation {
                target: motionState
                property: "overlayRevealProgress"
                from: 0
                to: root.showModalOverlay ? 1 : 0
                duration: root.showModalOverlay
                    ? (root.themeReady ? root.resolvedTheme.motion.durationFast : 0)
                    : 0
                easing.type: root.standardEasing
            }

            NumberAnimation {
                target: root.contentItem
                property: "y"
                from: root.topPadding + root.revealOffsetY
                to: root.topPadding
                duration: root.revealOffsetY !== 0 ? root.revealDuration : 0
                easing.type: root.emphasizedEasing
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                target: motionState
                property: "contentRevealProgress"
                from: 1
                to: 0
                duration: root.dismissDuration
                easing.type: root.standardEasing
            }

            NumberAnimation {
                target: motionState
                property: "overlayRevealProgress"
                from: root.showModalOverlay ? 1 : 0
                to: 0
                duration: root.showModalOverlay
                    ? (root.themeReady ? root.resolvedTheme.motion.durationFast : 0)
                    : 0
                easing.type: root.standardEasing
            }

            NumberAnimation {
                target: root.contentItem
                property: "y"
                from: root.topPadding
                to: root.topPadding + root.revealOffsetY
                duration: root.revealOffsetY !== 0 ? root.dismissDuration : 0
                easing.type: root.standardEasing
            }
        }
    }

    background: Item {
        Rectangle {
            x: -root.shadowSize * 0.75
            y: root.shadowSize * 0.5
            width: parent.width + root.shadowSize * 1.5
            height: parent.height + root.shadowSize * 1.25
            radius: root.resolvedCornerRadius + root.shadowSize * 0.75
            color: root.shadowColor
            opacity: root.elevated
                ? root.shadowOpacity * 0.34 * root.contentRevealProgress
                : 0
            antialiasing: true
        }

        Rectangle {
            x: -root.shadowSize * 0.5
            y: root.shadowSize * 0.5
            width: parent.width + root.shadowSize
            height: parent.height + root.shadowSize
            radius: root.resolvedCornerRadius + root.shadowSize * 0.5
            color: root.shadowColor
            opacity: root.elevated
                ? root.shadowOpacity * 0.66 * root.contentRevealProgress
                : 0
            antialiasing: true
        }

        AppSurface {
            anchors.fill: parent
            _retainedTheme: root.resolvedTheme
            surfaceTone: root.surfaceTone
            surfaceOpacityScale: root.surfaceOpacityScale
            shapeRole: UiStyle.ShapeRole.Overlay
            cornerRadius: root.cornerRadius
            strokeWidth: root.strokeWidth
        }
    }

    contentItem: ColumnLayout {
        id: contentColumn

        spacing: root.spacing
    }

    Component.onCompleted: {
        motionState.contentRevealProgress = root.visible ? 1 : 0
        motionState.overlayRevealProgress = root.visible && root.showModalOverlay ? 1 : 0
    }
}
