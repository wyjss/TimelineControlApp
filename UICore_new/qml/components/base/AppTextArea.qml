import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14
import UICore.Style 1.0
import "internal" as Internal
import "internal/AppThemeUtils.js" as ThemeUtils

TextArea {
    id: root

    property int surfaceTone: UiStyle.SurfaceTone.Control
    property int appearance: UiStyle.ControlAppearance.Filled
    property bool emphasized: false
    property bool animateTextColor: true
    property real cornerRadius: -1
    property int contentPaddingX: densityValue("controlPaddingXMd")
    property int contentPaddingY: densityValue("controlGap")
    property real _contentHeightForImplicitSize: 0

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

    readonly property bool hasSelection: selectionStart >= 0
        && selectionEnd >= 0
        && selectionStart !== selectionEnd
    readonly property var resolvedInputChromeSpec: resolvedTheme.controlStyles.inputChromeSpec(
        appearance,
        hasSelection
    )
    readonly property bool ghostAppearance: resolvedInputChromeSpec.ghost
    readonly property bool interactionHovered: hovered
    readonly property bool interactionActive: emphasized
        || (!readOnly && (activeFocus || hasSelection))

    Accessible.name: placeholderText

    function densityValue(name) {
        return ThemeUtils.densityValue(resolvedTheme, name)
    }

    function typographyValue(name) {
        return ThemeUtils.typographyValue(resolvedTheme, name)
    }

    function colorValue(name) {
        return ThemeUtils.colorValue(resolvedTheme, name)
    }

    function syncImplicitContentHeight() {
        _contentHeightForImplicitSize = contentHeight
    }

    selectByMouse: true
    hoverEnabled: enabled && !readOnly
    wrapMode: TextEdit.Wrap
    implicitHeight: Math.max(
        densityValue("textAreaMinHeight"),
        _contentHeightForImplicitSize + topPadding + bottomPadding
    )
    color: enabled
        ? colorValue("text")
        : colorValue("disabledText")
    placeholderTextColor: enabled
        ? colorValue("subtleText")
        : colorValue("disabledText")
    selectedTextColor: colorValue("inverseText")
    selectionColor: colorValue("highlightFill")

    font.family: typographyValue("familySans")
    font.pixelSize: Number(typographyValue("bodyM"))
    font.weight: Number(typographyValue("weightRegular"))

    leftPadding: contentPaddingX
    rightPadding: contentPaddingX
    topPadding: contentPaddingY
    bottomPadding: contentPaddingY

    Behavior on color {
        enabled: root.animateTextColor
        ColorAnimation {
            duration: root.resolvedTheme.motion.durationStandard
            easing.type: root.resolvedTheme.motion.easingStandard
        }
    }

    Behavior on placeholderTextColor {
        enabled: root.animateTextColor
        ColorAnimation {
            duration: root.resolvedTheme.motion.durationStandard
            easing.type: root.resolvedTheme.motion.easingStandard
        }
    }

    background: Internal.AppSurfaceChrome {
        themeContext: root.resolvedTheme
        surfaceTone: root.ghostAppearance ? UiStyle.SurfaceTone.Ghost : root.surfaceTone
        shapeRole: root.resolvedInputChromeSpec.shapeRole
        active: root.enabled && !root.readOnly && root.interactionActive
        hoveredState: root.enabled && !root.readOnly && root.interactionHovered
        strokeWidth: root.enabled && !root.readOnly && root.interactionActive
            ? root.resolvedInputChromeSpec.activeStrokeWidth
            : root.resolvedInputChromeSpec.idleStrokeWidth
        cornerRadius: root.cornerRadius
        fillOverride: !root.enabled
            ? root.colorValue("disabledFill")
            : (root.readOnly ? root.colorValue("backgroundSurface") : undefined)
        borderOverride: !root.enabled
            ? root.colorValue("disabledBorder")
            : (root.readOnly
                ? root.colorValue("border")
                : (root.ghostAppearance
                    ? (root.interactionActive
                        ? root.colorValue("highlightFill")
                        : (root.interactionHovered
                            ? root.colorValue("controlBorder")
                            : "transparent"))
                    : (root.interactionActive ? undefined : root.colorValue("controlBorder"))))
        hoverOverlayOpacity: root.resolvedInputChromeSpec.hoverOverlayOpacity
        activeOverlayOpacity: root.resolvedInputChromeSpec.activeOverlayOpacity
    }

    onContentHeightChanged: Qt.callLater(syncImplicitContentHeight)
    Component.onCompleted: syncImplicitContentHeight()
}
