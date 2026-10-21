import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14
import UICore.Style 1.0
import "internal/AppThemeUtils.js" as ThemeUtils

Button {
    id: root

    property int variant: UiStyle.ButtonVariant.Secondary
    property int size: UiStyle.ButtonSize.Medium
    property bool raised: false
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
    readonly property QtObject currentWindowTheme: applicationWindowTheme
        ? applicationWindowTheme
        : windowTheme
    property QtObject _retainedTheme: currentWindowTheme
    readonly property QtObject resolvedTheme: _retainedTheme

    onCurrentWindowThemeChanged: {
        if (currentWindowTheme)
            _retainedTheme = currentWindowTheme
    }

    readonly property bool activeState: checked || highlighted
    readonly property bool disabledState: !enabled
    readonly property bool hoverState: hovered && enabled
    readonly property bool pressedState: down && enabled
    readonly property bool focusState: visualFocus && enabled
    readonly property bool emphasisState: activeState || hoverState || pressedState || focusState
    readonly property bool hasIcon: iconName.length > 0 || iconSource.toString().length > 0 || iconSymbol.length > 0
    readonly property var resolvedSizeSpec: resolvedTheme.controlStyles.buttonSizeSpec(size)
    readonly property var resolvedVariantSpec: resolvedTheme.controlStyles.buttonVariantSpec(variant)
    readonly property int resolvedStrokeWidth: focusState
        ? 2
        : (raised && enabled
            ? 0
            : (disabledState
                ? resolvedVariantSpec.disabledStrokeWidth
                : (emphasisState ? resolvedVariantSpec.emphasisStrokeWidth : resolvedVariantSpec.idleStrokeWidth)))

    function densityValue(name) {
        return ThemeUtils.densityValue(resolvedTheme, name)
    }

    function metricValue(name) {
        return ThemeUtils.metricValue(resolvedTheme, name)
    }

    function colorValue(name) {
        return ThemeUtils.colorValue(resolvedTheme, name)
    }

    function resolvedColorSpec(colorSpec) {
        return ThemeUtils.resolvedColorSpec(resolvedTheme, colorSpec)
    }

    function resolvedHeight() {
        return densityValue(resolvedSizeSpec.heightToken)
    }

    function resolvedPaddingX() {
        return densityValue(resolvedSizeSpec.paddingToken)
    }

    function resolvedIconSize() {
        return metricValue(resolvedSizeSpec.iconToken)
    }

    function resolvedFill() {
        var colorSpec = disabledState
            ? resolvedVariantSpec.disabledFill
            : (activeState ? resolvedVariantSpec.activeFill : resolvedVariantSpec.idleFill)
        return resolvedColorSpec(colorSpec)
    }

    function resolvedBorder() {
        if (focusState) {
            return colorValue(variant === UiStyle.ButtonVariant.Primary
                || variant === UiStyle.ButtonVariant.Danger
                ? "inverseText"
                : "highlightText")
        }

        if (disabledState)
            return colorValue("disabledBorder")

        if (activeState && variant === UiStyle.ButtonVariant.Secondary)
            return colorValue("highlightFill")

        var colorSpec = emphasisState
            ? resolvedVariantSpec.emphasisBorder
            : resolvedVariantSpec.idleBorder
        return resolvedColorSpec(colorSpec)
    }

    function resolvedIconColor() {
        if (disabledState)
            return colorValue("disabledText")

        var colorSpec = emphasisState
            ? resolvedVariantSpec.emphasisIconColor
            : resolvedVariantSpec.idleIconColor
        return resolvedColorSpec(colorSpec)
    }

    function resolvedHoverOverlayColor() {
        return resolvedColorSpec(resolvedVariantSpec.hoverOverlayColor)
    }

    function resolvedActiveOverlayColor() {
        return resolvedColorSpec(resolvedVariantSpec.activeOverlayColor)
    }

    function resolvedHoverOpacity() {
        return disabledState ? 0 : resolvedVariantSpec.hoverOpacity
    }

    function resolvedActiveOpacity() {
        return disabledState ? 0 : resolvedVariantSpec.activeOpacity
    }

    flat: true
    padding: 0
    leftPadding: 0
    rightPadding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitHeight: resolvedHeight()
    implicitWidth: Math.max(minWidth, buttonContent.implicitWidth)

    onPressed: root.forceActiveFocus(Qt.MouseFocusReason)

    background: AppSurface {
        enabled: false
        sizeToContent: false
        shapeRole: UiStyle.ShapeRole.Control
        active: root.activeState && root.enabled
        hoveredState: root.hovered
        pressedState: root.down
        interactive: root.enabled
        animated: root.animated
        animateScale: root.animateScale
        pressScaleFactor: 0.97
        strokeWidth: root.resolvedStrokeWidth
        fillOverride: root.resolvedFill()
        borderOverride: root.resolvedBorder()
        hoverOverlayColorOverride: root.resolvedHoverOverlayColor()
        activeOverlayColorOverride: root.resolvedActiveOverlayColor()
        hoverOverlayOpacity: root.resolvedHoverOpacity()
        activeOverlayOpacity: root.resolvedActiveOpacity()
        transitionDuration: root.down
            ? root.resolvedTheme.motion.durationFast
            : root.resolvedTheme.motion.durationStandard

        Behavior on scale {
            enabled: root.animateScale
            NumberAnimation {
                duration: root.down
                    ? root.resolvedTheme.motion.durationFast
                    : root.resolvedTheme.motion.durationStandard
                easing.type: root.resolvedTheme.motion.easingStandard
            }
        }

        Loader {
            active: root.raised && root.enabled
                && ((root.variant !== UiStyle.ButtonVariant.Ghost
                    && root.variant !== UiStyle.ButtonVariant.Nav) || root.emphasisState)
            anchors.fill: parent
            anchors.margins: root.resolvedStrokeWidth

            sourceComponent: Rectangle {
                id: raisedSurface

                objectName: "buttonRaisedSurface"
                radius: Math.max(0, root.resolvedTheme.shape.controlRadius - root.resolvedStrokeWidth)
                antialiasing: true
                border.width: root.focusState ? 0 : root.resolvedTheme.shape.buttonRaisedEdgeWidth
                border.color: root.resolvedTheme.colors.buttonRaisedBorder
                opacity: root.pressedState || root.activeState
                    ? root.resolvedTheme.controlStyles.buttonRaisedPressedOpacity
                    : (root.hoverState
                        ? root.resolvedTheme.controlStyles.buttonRaisedHoverOpacity
                        : root.resolvedTheme.controlStyles.buttonRaisedIdleOpacity)
                // 渐变与细边框共用圆角，聚焦时只保留外层焦点描边。
                gradient: Gradient {
                    GradientStop { position: 0; color: root.resolvedTheme.colors.buttonRaisedTopEdge }
                    GradientStop {
                        position: Math.min(0.5, root.resolvedTheme.shape.buttonRaisedEdgeWidth / Math.max(1, raisedSurface.height))
                        color: root.resolvedTheme.colors.buttonRaisedTop
                    }
                    GradientStop {
                        position: 1 - Math.min(0.5, root.resolvedTheme.shape.buttonRaisedEdgeWidth / Math.max(1, raisedSurface.height))
                        color: root.resolvedTheme.colors.buttonRaisedBottom
                    }
                    GradientStop { position: 1; color: root.resolvedTheme.colors.buttonRaisedBottomEdge }
                }

                Behavior on opacity {
                    enabled: root.animated
                    NumberAnimation {
                        duration: root.down
                            ? root.resolvedTheme.motion.durationFast
                            : root.resolvedTheme.motion.durationStandard
                        easing.type: root.resolvedTheme.motion.easingStandard
                    }
                }
            }
        }

        Loader {
            active: root.variant === UiStyle.ButtonVariant.Nav && root.enabled
            anchors.left: parent.left
            anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter

            sourceComponent: Rectangle {
                width: 2
                height: root.activeState ? 16 : 8
                radius: 1
                color: root.colorValue("highlightText")
                opacity: root.activeState ? 1 : 0

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
    }

    contentItem: Item {
        id: buttonContent

        implicitWidth: contentRow.implicitWidth + root.resolvedPaddingX() * 2
        implicitHeight: root.resolvedHeight()

        Row {
            id: contentRow

            anchors.verticalCenter: parent.verticalCenter
            height: Math.max(iconLoader.visible ? iconLoader.height : 0, buttonText.implicitHeight)
            x: root.contentAlignment === "start"
                ? root.resolvedPaddingX()
                : Math.max(root.resolvedPaddingX(), (parent.width - width) / 2)
            spacing: root.densityValue("controlGap")

            Loader {
                id: iconLoader

                active: root.hasIcon
                visible: active
                width: active ? root.resolvedIconSize() : 0
                height: root.resolvedIconSize()
                y: Math.round((parent.height - height) / 2)

                sourceComponent: AppIcon {
                    name: root.iconName
                    source: root.iconSource
                    symbol: root.iconSymbol
                    size: root.resolvedIconSize()
                    color: root.resolvedIconColor()
                    animateColor: root.animated
                }
            }

            AppText {
                id: buttonText

                y: Math.round((parent.height - height) / 2)
                text: root.text
                styleRole: root.resolvedSizeSpec.textStyleRole
                textTone: root.disabledState
                    ? UiStyle.TextTone.Secondary
                    : (root.emphasisState
                        ? root.resolvedVariantSpec.emphasisTextTone
                        : root.resolvedVariantSpec.textTone)
                colorOverride: root.disabledState
                    ? root.colorValue("disabledText")
                    : undefined
                animateColor: root.animated
                elide: Text.ElideRight
            }
        }
    }
}
