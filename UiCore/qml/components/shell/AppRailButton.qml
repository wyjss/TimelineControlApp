import QtQuick 2.14
import QtQuick.Controls 2.14
import "../../foundation"
import "../base" as Base

Button {
    id: root

    property QtObject theme
    property string iconName: ""
    property bool active: false
    property int buttonSize: theme && theme.shell ? theme.shell.railButtonSize : 38
    property bool animated: true

    readonly property color iconTint: active
        ? colorValue("highlightText", "#7cb4ff")
        : (hovered ? colorValue("text", "#e6edf3") : colorValue("subtleText", "#97a3b6"))
    readonly property color activeFill: Qt.rgba(iconTint.r, iconTint.g, iconTint.b, active ? 0.12 : 0)

    function colorValue(name, fallback) {
        return theme && theme.colors && theme.colors[name] !== undefined
            ? theme.colors[name]
            : fallback
    }

    flat: true
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitWidth: buttonSize
    implicitHeight: buttonSize

    onPressed: root.forceActiveFocus(Qt.MouseFocusReason)

    background: Item {
        Base.AppSurface {
            anchors.fill: parent
            enabled: false
            theme: root.theme
            surfaceTone: "ghost"
            shapeRole: AppUiEnums.ShapeRole.Control
            strokeWidth: 0
            interactive: root.enabled
            hoveredState: root.hovered
            pressedState: root.down
            animated: root.animated
            animateScale: false
            fillOverride: root.activeFill
            hoverOverlayColorOverride: root.colorValue("windowAccent", "#222b36")
            hoverOverlayOpacity: root.active ? 0.08 : 0.12
            activeOverlayColorOverride: root.colorValue("windowAccent", "#222b36")
            activeOverlayOpacity: 0.1
            transitionDuration: root.theme ? root.theme.motion.durationStandard : 160
        }

        Rectangle {
            x: 1
            width: 2
            height: root.active ? 16 : 8
            anchors.verticalCenter: parent.verticalCenter
            radius: 1
            color: root.colorValue("highlightText", "#7cb4ff")
            opacity: root.active ? 1 : 0

            Behavior on height {
                enabled: root.animated
                NumberAnimation {
                    duration: root.theme ? root.theme.motion.durationStandard : 160
                    easing.type: root.theme ? root.theme.motion.easingStandard : Easing.OutCubic
                }
            }

            Behavior on opacity {
                enabled: root.animated
                NumberAnimation {
                    duration: root.theme ? root.theme.motion.durationFast : 100
                    easing.type: root.theme ? root.theme.motion.easingStandard : Easing.OutCubic
                }
            }
        }
    }

    contentItem: Item {
        implicitWidth: root.buttonSize
        implicitHeight: root.buttonSize

        Base.AppIcon {
            anchors.centerIn: parent
            theme: root.theme
            name: root.iconName
            size: 16
            color: root.iconTint
        }
    }
}
