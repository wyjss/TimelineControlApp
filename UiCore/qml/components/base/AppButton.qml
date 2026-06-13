import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14
import "../../foundation"
import "internal/AppThemeUtils.js" as ThemeUtils

Button {
    id: root

    property QtObject theme
    property var variant: AppUiEnums.ButtonVariant.Secondary
    property var size: AppUiEnums.ButtonSize.Medium
    property string contentAlignment: "center"

    property int minWidth: 0
    property string iconName: ""
    property url iconSource: ""
    property string iconSymbol: ""

    property bool animated: true
    property bool animateScale: animated

    readonly property QtObject applicationWindowTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : null
    readonly property QtObject windowTheme: Window.window && Window.window.appTheme
        ? Window.window.appTheme
        : null
    readonly property QtObject resolvedTheme: theme
        ? theme
        : (applicationWindowTheme ? applicationWindowTheme : windowTheme)
    readonly property int resolvedVariant: AppUiEnums.normalizeButtonVariant(variant)
    readonly property int resolvedSize: AppUiEnums.normalizeButtonSize(size)
    readonly property bool activeState: checked || highlighted
    readonly property bool disabledState: !enabled
    readonly property bool hoverState: hovered && enabled
    readonly property bool pressedState: down && enabled
    readonly property bool emphasisState: activeState || hoverState || pressedState
    readonly property bool hasIcon: iconName.length > 0 || iconSource.toString().length > 0 || iconSymbol.length > 0
    readonly property var resolvedSizeSpec: sizeSpec()
    readonly property var resolvedVariantSpec: variantSpec()
    readonly property int resolvedStrokeWidth: disabledState
        ? resolvedVariantSpec.disabledStrokeWidth
        : (emphasisState ? resolvedVariantSpec.emphasisStrokeWidth : resolvedVariantSpec.idleStrokeWidth)

    function densityValue(name, fallback) {
        return ThemeUtils.densityValue(resolvedTheme, name, fallback)
    }

    function metricValue(name, fallback) {
        return ThemeUtils.metricValue(resolvedTheme, name, fallback)
    }

    function colorValue(name, fallback) {
        return ThemeUtils.colorValue(resolvedTheme, name, fallback)
    }

    function resolvedColorSpec(colorSpec, fallback) {
        return ThemeUtils.resolvedColorSpec(resolvedTheme, colorSpec, fallback)
    }

    function sizeSpec() {
        return resolvedTheme && resolvedTheme.controlStyles
            ? resolvedTheme.controlStyles.buttonSizeSpec(resolvedSize)
            : ({ "heightToken": "controlHeightMd", "heightFallback": 36,
                 "paddingToken": "controlPaddingXMd", "paddingFallback": 12,
                 "iconToken": "iconSizeMd", "iconFallback": 16,
                 "textStyleRole": "label" })
    }

    function variantSpec() {
        return resolvedTheme && resolvedTheme.controlStyles
            ? resolvedTheme.controlStyles.buttonVariantSpec(resolvedVariant)
            : ({ "idleFill": "surface", "activeFill": "highlightSoft",
                 "disabledFill": "surface", "idleBorder": "border",
                 "emphasisBorder": "highlightText", "textTone": "primary",
                 "emphasisTextTone": "accent", "idleIconColor": "text",
                 "emphasisIconColor": "highlightText",
                 "hoverOverlayColor": "highlightText",
                 "activeOverlayColor": "highlightSoft", "hoverOpacity": 0.09,
                 "activeOpacity": 0.12, "idleStrokeWidth": 1,
                 "emphasisStrokeWidth": 2, "disabledStrokeWidth": 1 })
    }

    function resolvedHeight() {
        return densityValue(resolvedSizeSpec.heightToken, resolvedSizeSpec.heightFallback)
    }

    function resolvedPaddingX() {
        return densityValue(resolvedSizeSpec.paddingToken, resolvedSizeSpec.paddingFallback)
    }

    function resolvedIconSize() {
        return metricValue(resolvedSizeSpec.iconToken, resolvedSizeSpec.iconFallback)
    }

    function resolvedGap() {
        return densityValue("controlGap", 8)
    }

    function resolvedFill() {
        var colorSpec = disabledState
            ? resolvedVariantSpec.disabledFill
            : (activeState ? resolvedVariantSpec.activeFill : resolvedVariantSpec.idleFill)
        return resolvedColorSpec(colorSpec, colorValue("surface", "#171d25"))
    }

    function resolvedBorder() {
        if (disabledState)
            return colorValue("border", "#334155")

        var colorSpec = emphasisState
            ? resolvedVariantSpec.emphasisBorder
            : resolvedVariantSpec.idleBorder
        return resolvedColorSpec(colorSpec, "transparent")
    }

    function resolvedTextTone() {
        if (disabledState)
            return "secondary"

        return emphasisState
            ? resolvedVariantSpec.emphasisTextTone
            : resolvedVariantSpec.textTone
    }

    function resolvedIconColor() {
        if (disabledState)
            return colorValue("subtleText", "#97a3b6")

        var colorSpec = emphasisState
            ? resolvedVariantSpec.emphasisIconColor
            : resolvedVariantSpec.idleIconColor
        return resolvedColorSpec(colorSpec, colorValue("text", "#e6edf3"))
    }

    function resolvedHoverOverlayColor() {
        return resolvedColorSpec(
            resolvedVariantSpec.hoverOverlayColor,
            colorValue("highlightText", "#7cb4ff")
        )
    }

    function resolvedActiveOverlayColor() {
        return resolvedColorSpec(
            resolvedVariantSpec.activeOverlayColor,
            colorValue("highlightSoft", "#182b45")
        )
    }

    function resolvedHoverOpacity() {
        return disabledState ? 0 : resolvedVariantSpec.hoverOpacity
    }

    function resolvedActiveOpacity() {
        return disabledState ? 0 : resolvedVariantSpec.activeOpacity
    }

    flat: true
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitHeight: resolvedHeight()
    implicitWidth: Math.max(minWidth, buttonContent.implicitWidth)
    opacity: enabled ? 1 : 0.72

    onPressed: root.forceActiveFocus(Qt.MouseFocusReason)

    background: AppSurface {
        enabled: false
        theme: root.resolvedTheme
        shapeRole: AppUiEnums.ShapeRole.Control
        active: root.activeState && root.enabled
        hoveredState: root.hovered
        pressedState: root.down
        interactive: root.enabled
        animated: root.animated
        animateScale: root.animateScale
        strokeWidth: root.resolvedStrokeWidth
        fillOverride: root.resolvedFill()
        borderOverride: root.resolvedBorder()
        hoverOverlayColorOverride: root.resolvedHoverOverlayColor()
        activeOverlayColorOverride: root.resolvedActiveOverlayColor()
        hoverOverlayOpacity: root.resolvedHoverOpacity()
        activeOverlayOpacity: root.resolvedActiveOpacity()
        transitionDuration: root.resolvedTheme ? root.resolvedTheme.motion.durationStandard : 180
    }

    contentItem: Item {
        id: buttonContent

        implicitWidth: contentRow.implicitWidth + root.resolvedPaddingX() * 2
        implicitHeight: root.resolvedHeight()

        Row {
            id: contentRow

            anchors.verticalCenter: parent.verticalCenter
            x: root.contentAlignment === "start"
                ? root.resolvedPaddingX()
                : Math.max(root.resolvedPaddingX(), (parent.width - width) / 2)
            spacing: root.resolvedGap()

            AppIcon {
                visible: root.hasIcon
                theme: root.resolvedTheme
                name: root.iconName
                source: root.iconSource
                symbol: root.iconSymbol
                size: root.resolvedIconSize()
                color: root.resolvedIconColor()
            }

            AppText {
                text: root.text
                theme: root.resolvedTheme
                styleRole: root.resolvedSizeSpec.textStyleRole
                textTone: root.resolvedTextTone()
                elide: Text.ElideRight
            }
        }
    }
}
