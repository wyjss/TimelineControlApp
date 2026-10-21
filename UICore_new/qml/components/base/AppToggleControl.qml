import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14
import UICore.Style 1.0
import "internal" as Internal
import "internal/AppThemeUtils.js" as ThemeUtils

Switch {
    id: root

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
    readonly property bool interactionHovered: hovered
    readonly property bool interactionActive: activeFocus

    onCurrentWindowThemeChanged: {
        if (currentWindowTheme)
            _retainedTheme = currentWindowTheme
    }

    function colorValue(name) {
        return ThemeUtils.colorValue(resolvedTheme, name)
    }

    implicitWidth: 42
    implicitHeight: 24
    padding: 0
    spacing: 0
    hoverEnabled: true

    Keys.onReleased: {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter) {
            event.accepted = false
            return
        }

        event.accepted = true
        root.toggle()
        root.toggled()
    }

    contentItem: null

    background: Internal.AppSurfaceChrome {
        anchors.fill: parent
        themeContext: root.resolvedTheme
        surfaceTone: root.checked
            ? UiStyle.SurfaceTone.Highlight
            : UiStyle.SurfaceTone.Control
        shapeRole: UiStyle.ShapeRole.Pill
        active: root.enabled && root.checked
        hoveredState: root.enabled && root.hovered
        strokeWidth: root.activeFocus ? 2 : (root.checked && root.enabled ? 0 : 1)
        fillOverride: !root.enabled
            ? root.colorValue("disabledFill")
            : (root.checked
                ? root.colorValue("highlightFill")
                : root.colorValue("backgroundControl"))
        borderOverride: root.activeFocus
            ? root.colorValue("highlightText")
            : (!root.enabled
                ? root.colorValue("disabledBorder")
                : (root.checked
                    ? root.colorValue("highlightFill")
                    : root.colorValue("controlBorder")))
        hoverOverlayOpacity: 0.08
        activeOverlayOpacity: 0.06
    }

    indicator: Item {
        anchors.fill: parent

        Rectangle {
            width: 18
            height: 18
            radius: 9
            y: 3
            x: 3 + root.visualPosition * (parent.width - width - 6)
            color: root.enabled
                ? root.colorValue("inverseText")
                : root.colorValue("disabledText")
            border.width: 1
            border.color: !root.enabled
                ? root.colorValue("disabledBorder")
                : (root.checked
                    ? Qt.rgba(0, 0, 0, 0.08)
                    : root.colorValue("controlBorder"))

            Behavior on color {
                ColorAnimation {
                    duration: root.resolvedTheme.motion.durationStandard
                    easing.type: root.resolvedTheme.motion.easingStandard
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: root.resolvedTheme.motion.durationStandard
                    easing.type: root.resolvedTheme.motion.easingStandard
                }
            }

            Behavior on x {
                enabled: !root.pressed

                NumberAnimation {
                    duration: root.resolvedTheme.motion.durationStandard
                    easing.type: root.resolvedTheme.motion.easingStandard
                }
            }
        }
    }
}
