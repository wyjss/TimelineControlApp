import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtQuick.Window 2.14
import "../../foundation"

Popup {
    id: root

    default property alias popupContent: contentColumn.data

    property QtObject theme
    property string surfaceTone: "surface"
    property real cornerRadius: -1
    property int strokeWidth: 1
    property color overlayColor: resolvedTheme && resolvedTheme.colors ? resolvedTheme.colors.scrim : "#000000"
    property real overlayOpacity: 0.50
    property bool showModalOverlay: modal
    readonly property QtObject applicationWindowTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : null
    readonly property QtObject windowTheme: Window.window && Window.window.appTheme
        ? Window.window.appTheme
        : null
    readonly property QtObject resolvedTheme: theme
        ? theme
        : (applicationWindowTheme ? applicationWindowTheme : windowTheme)
    readonly property string resolvedSurfaceTone: surfaceTone
    readonly property real popupRevealOffset: resolvedTheme && resolvedTheme.motion ? resolvedTheme.motion.transitionOffset : 10
    readonly property real popupRevealStartScale: 0.985
    readonly property real contentRevealProgress: motionState.contentRevealProgress
    readonly property real overlayRevealProgress: motionState.overlayRevealProgress

    padding: 18
    spacing: 14
    opacity: root.contentRevealProgress
    scale: root.popupRevealStartScale + (1 - root.popupRevealStartScale) * root.contentRevealProgress

    QtObject {
        id: motionState

        property real contentRevealProgress: root.visible ? 1 : 0
        property real overlayRevealProgress: root.visible && root.showModalOverlay ? 1 : 0
    }

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
                duration: root.resolvedTheme ? root.resolvedTheme.motion.durationStandard : 180
                easing.type: root.resolvedTheme ? root.resolvedTheme.motion.easingEmphasized : Easing.OutQuint
            }

            NumberAnimation {
                target: motionState
                property: "overlayRevealProgress"
                from: root.showModalOverlay ? 0 : 0
                to: root.showModalOverlay ? 1 : 0
                duration: root.resolvedTheme ? root.resolvedTheme.motion.durationFast : 120
                easing.type: root.resolvedTheme ? root.resolvedTheme.motion.easingStandard : Easing.OutCubic
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
                duration: root.resolvedTheme ? root.resolvedTheme.motion.durationFast : 120
                easing.type: root.resolvedTheme ? root.resolvedTheme.motion.easingStandard : Easing.InCubic
            }

            NumberAnimation {
                target: motionState
                property: "overlayRevealProgress"
                from: root.showModalOverlay ? 1 : 0
                to: 0
                duration: root.resolvedTheme ? root.resolvedTheme.motion.durationFast : 120
                easing.type: root.resolvedTheme ? root.resolvedTheme.motion.easingStandard : Easing.OutCubic
            }
        }
    }

    background: Item {
        AppSurface {
            anchors.fill: parent
            theme: root.resolvedTheme
            surfaceTone: root.resolvedSurfaceTone
            shapeRole: AppUiEnums.ShapeRole.Overlay
            active: true
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
