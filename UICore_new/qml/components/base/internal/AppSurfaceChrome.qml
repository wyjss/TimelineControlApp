import QtQuick 2.14
import UICore.Style 1.0
import "AppThemeUtils.js" as ThemeUtils

Rectangle {
    id: root

    property QtObject themeContext: null
    property int surfaceTone: UiStyle.SurfaceTone.Surface
    property bool active: false
    property bool hoveredState: false
    property bool pressedState: false
    property bool animated: true
    property int shapeRole: UiStyle.ShapeRole.Auto
    property real cornerRadius: -1
    property int strokeWidth: 1
    property var fillOverride: undefined
    property var borderOverride: undefined
    property real hoverOverlayOpacity: 0.08
    property real activeOverlayOpacity: 0.12

    readonly property bool themeReady: !!themeContext
    readonly property int transitionDuration: themeReady ? themeContext.motion.durationStandard : 0
    readonly property int transitionEasing: themeReady ? themeContext.motion.easingStandard : Easing.Linear
    readonly property var resolvedSurfaceToneSpec: themeReady
        ? themeContext.controlStyles.surfaceToneSpec(surfaceTone, active)
        : null
    readonly property real resolvedRadius: themeReady ? resolveRadius() : 0
    readonly property real resolvedHoverOpacity: hoveredState ? hoverOverlayOpacity : 0
    readonly property real resolvedActiveOpacity: (active || pressedState) ? activeOverlayOpacity : 0

    property color fillColor: !resolvedSurfaceToneSpec
        ? "transparent"
        : (fillOverride !== undefined
            ? fillOverride
            : ThemeUtils.resolvedColorSpec(themeContext, resolvedSurfaceToneSpec.fill))
    property color borderColor: !resolvedSurfaceToneSpec
        ? "transparent"
        : (borderOverride !== undefined
            ? borderOverride
            : ThemeUtils.resolvedColorSpec(themeContext, resolvedSurfaceToneSpec.border))
    property color hoverOverlayColor: resolvedSurfaceToneSpec
        ? ThemeUtils.resolvedColorSpec(themeContext, resolvedSurfaceToneSpec.hoverOverlay)
        : "transparent"
    property color activeOverlayColor: resolvedSurfaceToneSpec
        ? ThemeUtils.resolvedColorSpec(themeContext, resolvedSurfaceToneSpec.activeOverlay)
        : "transparent"

    function shapeValue(name) {
        return ThemeUtils.shapeValue(themeContext, name)
    }

    function resolveRadius() {
        if (cornerRadius >= 0)
            return cornerRadius

        switch (shapeRole) {
        case UiStyle.ShapeRole.None:
            return 0
        case UiStyle.ShapeRole.Control:
            return shapeValue("controlRadius")
        case UiStyle.ShapeRole.Section:
            return shapeValue("sectionRadius")
        case UiStyle.ShapeRole.Panel:
            return shapeValue("panelRadius")
        case UiStyle.ShapeRole.Shell:
            return shapeValue("shellRadius")
        case UiStyle.ShapeRole.Canvas:
            return shapeValue("canvasRadius")
        case UiStyle.ShapeRole.Overlay:
            return shapeValue("overlayRadius")
        case UiStyle.ShapeRole.Pill:
            return root.height > 0
                ? root.height * shapeValue("pillRadiusFactor")
                : shapeValue("controlRadius")
        }

        switch (surfaceTone) {
        case UiStyle.SurfaceTone.Control:
            return shapeValue("controlRadius")
        case UiStyle.SurfaceTone.Canvas:
            return shapeValue("canvasRadius")
        case UiStyle.SurfaceTone.Section:
        case UiStyle.SurfaceTone.SectionOverlay:
        case UiStyle.SurfaceTone.DialogSection:
            return shapeValue("sectionRadius")
        case UiStyle.SurfaceTone.Popup:
            return shapeValue("overlayRadius")
        case UiStyle.SurfaceTone.Ghost:
            return 0
        default:
            return shapeValue("panelRadius")
        }
    }

    radius: resolvedRadius
    color: fillColor
    border.width: strokeWidth
    border.color: borderColor
    antialiasing: true

    Behavior on fillColor {
        enabled: root.animated

        ColorAnimation {
            duration: root.transitionDuration
            easing.type: root.transitionEasing
        }
    }

    Behavior on borderColor {
        enabled: root.animated

        ColorAnimation {
            duration: root.transitionDuration
            easing.type: root.transitionEasing
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.resolvedRadius
        color: root.hoverOverlayColor
        opacity: root.resolvedHoverOpacity
        visible: opacity > 0

        Behavior on opacity {
            enabled: root.animated

            NumberAnimation {
                duration: root.transitionDuration
                easing.type: root.transitionEasing
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.resolvedRadius
        color: root.activeOverlayColor
        opacity: root.resolvedActiveOpacity
        visible: opacity > 0

        Behavior on opacity {
            enabled: root.animated

            NumberAnimation {
                duration: root.transitionDuration
                easing.type: root.transitionEasing
            }
        }
    }
}
