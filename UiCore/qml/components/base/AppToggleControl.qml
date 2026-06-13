import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14
import "../../foundation"
import "internal" as Internal
import "internal/AppThemeUtils.js" as ThemeUtils

Item {
    id: root

    property QtObject theme
    property bool checked: false
    property bool enabled: true

    readonly property QtObject applicationWindowTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : null
    readonly property QtObject windowTheme: Window.window && Window.window.appTheme
        ? Window.window.appTheme
        : null
    readonly property QtObject resolvedTheme: theme
        ? theme
        : (applicationWindowTheme ? applicationWindowTheme : windowTheme)
    readonly property bool interactionHovered: toggleTap.hovered
    readonly property bool interactionActive: checked

    signal toggled(bool nextChecked)

    function colorValue(name, fallback) {
        return ThemeUtils.colorValue(resolvedTheme, name, fallback)
    }

    function commit(nextChecked) {
        if (checked === nextChecked)
            return

        checked = nextChecked
        toggled(nextChecked)
    }

    implicitWidth: 42
    implicitHeight: 24
    opacity: enabled ? 1 : 0.68

    AppSurface {
        anchors.fill: parent
        theme: root.resolvedTheme
        surfaceTone: root.checked ? "highlight" : "section"
        shapeRole: AppUiEnums.ShapeRole.Pill
        active: root.checked
        hoveredState: toggleTap.hovered
        interactive: root.enabled
        strokeWidth: root.checked ? 0 : 1
        fillOverride: root.checked
            ? root.colorValue("highlightFill", "#2563eb")
            : root.colorValue("section", "#1e2631")
        borderOverride: root.checked
            ? root.colorValue("highlightFill", "#2563eb")
            : root.colorValue("border", "#334155")
        hoverOverlayOpacity: 0.08
        activeOverlayOpacity: 0.06
    }

    Rectangle {
        width: 18
        height: 18
        radius: 9
        y: 3
        x: root.checked ? parent.width - width - 3 : 3
        color: root.colorValue("inverseText", "#f8fafc")
        border.width: 1
        border.color: root.checked
            ? Qt.rgba(0, 0, 0, 0.08)
            : root.colorValue("border", "#334155")

        Behavior on x {
            NumberAnimation {
                duration: root.resolvedTheme ? root.resolvedTheme.motion.durationStandard : 180
                easing.type: root.resolvedTheme ? root.resolvedTheme.motion.easingStandard : Easing.OutCubic
            }
        }
    }

    Internal.AppTapRegion {
        id: toggleTap

        anchors.fill: parent
        enabled: root.enabled
        onTapped: root.commit(!root.checked)
    }
}
