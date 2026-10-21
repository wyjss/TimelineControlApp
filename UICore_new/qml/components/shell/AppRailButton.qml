import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14
import UICore.Style 1.0
import "../base" as Base

Button {
    id: root

    property string iconName: ""
    property bool active: false
    property int buttonSize: resolvedTheme.shell.railButtonSize
    property bool showText: false
    property bool animated: true

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

    onCurrentWindowThemeChanged: {
        if (currentWindowTheme)
            _retainedTheme = currentWindowTheme
    }

    readonly property color iconTint: active
        ? colorValue("highlightText")
        : (hovered ? colorValue("text") : colorValue("subtleText"))
    readonly property color activeFill: Qt.rgba(iconTint.r, iconTint.g, iconTint.b, active ? 0.12 : 0)

    function colorValue(name) {
        return resolvedTheme.colors[name]
    }

    flat: true
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitWidth: buttonSize
    implicitHeight: showText
        ? contentText.implicitHeight + resolvedTheme.shell.railPadding
            + (contentIcon.visible
                ? contentIcon.height + resolvedTheme.density.controlGap
                : 0)
        : buttonSize

    onPressed: root.forceActiveFocus(Qt.MouseFocusReason)

    background: Item {
        Base.AppSurface {
            anchors.fill: parent
            enabled: false
            surfaceTone: UiStyle.SurfaceTone.Ghost
            shapeRole: UiStyle.ShapeRole.Control
            strokeWidth: 0
            interactive: root.enabled
            hoveredState: root.hovered
            pressedState: root.down
            animated: root.animated
            animateScale: false
            fillOverride: root.activeFill
            hoverOverlayColorOverride: root.colorValue("backgroundWindowVariant")
            hoverOverlayOpacity: root.active ? 0.08 : 0.12
            activeOverlayColorOverride: root.colorValue("backgroundWindowVariant")
            activeOverlayOpacity: 0.1
            transitionDuration: root.resolvedTheme.motion.durationStandard
        }

        Rectangle {
            x: 1
            width: 2
            height: root.active ? Math.round(root.height * 0.65) : 0
            anchors.verticalCenter: parent.verticalCenter
            radius: 1
            color: root.colorValue("highlightText")
            opacity: root.active ? 1 : 0

            Behavior on height {
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

    contentItem: Item {
        implicitWidth: root.buttonSize
        implicitHeight: root.buttonSize

        Base.AppIcon {
            id: contentIcon

            anchors.horizontalCenter: parent.horizontalCenter
            y: root.showText
                ? root.resolvedTheme.shell.railPadding / 2
                : Math.round((parent.height - height) / 2)
            name: root.iconName
            size: Math.round(root.buttonSize * 0.6)
            color: root.iconTint
            animateColor: root.animated
            visible: root.iconName.length > 0
        }

        Base.AppText {
            id: contentText

            anchors.top: contentIcon.visible ? contentIcon.bottom : parent.top
            anchors.topMargin: contentIcon.visible
                ? root.resolvedTheme.density.controlGap
                : root.resolvedTheme.shell.railPadding / 2
            anchors.left: parent.left
            anchors.leftMargin: root.resolvedTheme.shell.railPadding / 2
            anchors.right: parent.right
            anchors.rightMargin: root.resolvedTheme.shell.railPadding / 2
            visible: root.showText
            text: root.text
            styleRole: UiStyle.TypographyRole.BodyS
            colorOverride: root.iconTint
            animateColor: root.animated
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
