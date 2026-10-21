import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14
import UICore.Style 1.0
import "internal/AppThemeUtils.js" as ThemeUtils

CheckBox {
    id: root

    property int surfaceTone: UiStyle.SurfaceTone.Control
    property int textTone: UiStyle.TextTone.Primary

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

    readonly property bool interactionHovered: hovered
    readonly property bool interactionActive: visualFocus
    readonly property bool selected: checkState !== Qt.Unchecked

    function densityValue(name) {
        return ThemeUtils.densityValue(resolvedTheme, name)
    }

    function metricValue(name) {
        return ThemeUtils.metricValue(resolvedTheme, name)
    }

    function colorValue(name) {
        return ThemeUtils.colorValue(resolvedTheme, name)
    }

    padding: 0
    spacing: densityValue("controlGap")
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitHeight: Math.max(densityValue("controlHeightSm"), implicitContentHeight)

    background: null

    indicator: AppSurface {
        implicitWidth: root.metricValue("iconSizeLg")
        implicitHeight: root.metricValue("iconSizeLg")
        x: root.text.length > 0
            ? (root.mirrored
                ? root.width - width - root.rightPadding
                : root.leftPadding)
            : root.leftPadding + (root.availableWidth - width) / 2
        y: root.topPadding + (root.availableHeight - height) / 2
        enabled: false
        surfaceTone: root.selected ? UiStyle.SurfaceTone.Highlight : root.surfaceTone
        shapeRole: UiStyle.ShapeRole.Control
        active: root.enabled && root.selected
        hoveredState: root.enabled && root.hovered
        pressedState: root.enabled && root.down
        strokeWidth: root.visualFocus ? 2 : 1
        fillOverride: !root.enabled
            ? root.colorValue("disabledFill")
            : (root.selected
                ? root.colorValue("highlightFill")
                : root.colorValue("backgroundControl"))
        borderOverride: root.visualFocus
            ? root.colorValue("highlightText")
            : (!root.enabled
                ? root.colorValue("disabledBorder")
                : (root.selected
                    ? root.colorValue("highlightFill")
                    : root.colorValue("controlBorder")))
        hoverOverlayOpacity: 0.08
        activeOverlayOpacity: 0.08

        AppText {
            anchors.centerIn: parent
            visible: root.selected
            text: root.checkState === Qt.PartiallyChecked ? "−" : "✓"
            styleRole: UiStyle.TypographyRole.BodyS
            textTone: UiStyle.TextTone.Inverse
            overrideWeight: root.resolvedTheme.typography.weightBold
        }
    }

    contentItem: AppText {
        leftPadding: root.indicator && !root.mirrored
            ? root.indicator.width + (root.text.length > 0 ? root.spacing : 0)
            : 0
        rightPadding: root.indicator && root.mirrored
            ? root.indicator.width + (root.text.length > 0 ? root.spacing : 0)
            : 0
        text: root.text
        styleRole: UiStyle.TypographyRole.BodyM
        textTone: root.textTone
        colorOverride: root.enabled ? undefined : root.colorValue("disabledText")
        verticalAlignment: Text.AlignVCenter
    }
}
