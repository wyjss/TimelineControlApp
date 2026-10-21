import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14
import UICore.Style 1.0
import "AppThemeUtils.js" as ThemeUtils

Control {
    id: root

    default property alias contentData: contentHost.data

    property int surfaceTone: UiStyle.SurfaceTone.Surface
    property real surfaceOpacityScale: 1.0

    property bool active: false
    property bool hoveredState: false
    property bool pressedState: false
    property bool interactive: false
    property bool clipContent: false
    property bool clearFocusOnTap: false
    property bool sizeToContent: true
    property bool constrainContentWidth: !sizeToContent
    property bool constrainContentHeight: !sizeToContent

    property bool animated: true
    property bool animateColor: animated
    property bool animateOpacity: animated
    property bool animateScale: false

    property int shapeRole: UiStyle.ShapeRole.Auto
    property real cornerRadius: -1
    property int strokeWidth: 1

    property var fillOverride: undefined
    property var borderOverride: undefined
    property var hoverOverlayColorOverride: undefined
    property var activeOverlayColorOverride: undefined

    property real hoverOverlayOpacity: 0.08
    property real activeOverlayOpacity: 0.12
    property real hoverScaleFactor: 1.0
    property real pressScaleFactor: 0.98

    readonly property QtObject applicationWindowTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : null
    readonly property QtObject windowTheme: Window.window && Window.window.appTheme
        ? Window.window.appTheme
        : null
    readonly property QtObject owningWindow: Window.window
    readonly property QtObject currentWindowTheme: applicationWindowTheme
        ? applicationWindowTheme
        : windowTheme
    property QtObject _retainedTheme: currentWindowTheme
    readonly property QtObject resolvedTheme: _retainedTheme
    readonly property bool themeReady: !!resolvedTheme

    onCurrentWindowThemeChanged: {
        if (currentWindowTheme)
            _retainedTheme = currentWindowTheme
    }
    onOwningWindowChanged: Qt.callLater(function() {
        if (root.owningWindow && !root.currentWindowTheme)
            console.error("UICore AppControlBase requires appTheme on its window")
    })

    property int transitionDuration: themeReady ? resolvedTheme.motion.durationStandard : 0
    property int transitionEasing: themeReady ? resolvedTheme.motion.easingStandard : Easing.Linear

    readonly property QtObject resolvedControlStyles: themeReady ? resolvedTheme.controlStyles : null
    readonly property var resolvedSurfaceToneSpec: resolvedControlStyles
        ? resolvedControlStyles.surfaceToneSpec(surfaceTone, active)
        : null
    readonly property bool effectiveHovered: hoveredState || (interactive && hoverHandler.hovered)
    readonly property bool effectivePressed: pressedState
    readonly property real resolvedRadius: themeReady ? resolveRadius() : 0
    readonly property real resolvedScale: resolveScale()
    readonly property real resolvedHoverOpacity: effectiveHovered ? hoverOverlayOpacity : 0
    readonly property real resolvedActiveOpacity: (active || effectivePressed) ? activeOverlayOpacity : 0
    readonly property real availableContentWidth: availableWidth
    readonly property real availableContentHeight: availableHeight

    property color fillColor: resolvedSurfaceToneSpec ? resolveFillColor() : "transparent"
    property color borderColor: resolvedSurfaceToneSpec ? resolveBorderColor() : "transparent"
    property color hoverOverlayColor: resolvedSurfaceToneSpec ? resolveHoverOverlayColor() : "transparent"
    property color activeOverlayColor: resolvedSurfaceToneSpec ? resolveActiveOverlayColor() : "transparent"

    function densityValue(name) {
        return ThemeUtils.densityValue(resolvedTheme, name)
    }

    function colorValue(name) {
        return ThemeUtils.colorValue(resolvedTheme, name)
    }

    function shapeValue(name) {
        return ThemeUtils.shapeValue(resolvedTheme, name)
    }

    function surfaceToneSpecValue(name) {
        return resolvedSurfaceToneSpec[name]
    }

    function resolvedColorSpec(colorSpec) {
        return ThemeUtils.resolvedColorSpec(resolvedTheme, colorSpec)
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

    function resolveFillColor() {
        if (fillOverride !== undefined)
            return fillOverride

        return resolvedColorSpec(surfaceToneSpecValue("fill"))
    }

    function resolveBorderColor() {
        if (borderOverride !== undefined)
            return borderOverride

        return resolvedColorSpec(surfaceToneSpecValue("border"))
    }

    function resolveHoverOverlayColor() {
        if (hoverOverlayColorOverride !== undefined)
            return hoverOverlayColorOverride

        return resolvedColorSpec(surfaceToneSpecValue("hoverOverlay"))
    }

    function resolveActiveOverlayColor() {
        if (activeOverlayColorOverride !== undefined)
            return activeOverlayColorOverride

        return resolvedColorSpec(surfaceToneSpecValue("activeOverlay"))
    }

    function resolveScale() {
        if (!animateScale)
            return 1

        if (effectivePressed)
            return pressScaleFactor

        if (effectiveHovered)
            return hoverScaleFactor

        return 1
    }

    function hasAnchor(anchorLine) {
        return anchorLine !== undefined && anchorLine !== null
    }

    function measuredChildWidth(item) {
        if (!item)
            return 0

        var implicitWidth = Number(item.implicitWidth)
        if (!isNaN(implicitWidth) && implicitWidth > 0)
            return implicitWidth

        if (item.anchors && (hasAnchor(item.anchors.fill)
                || (hasAnchor(item.anchors.left) && hasAnchor(item.anchors.right)))) {
            return 0
        }

        var actualWidth = Number(item.width)
        var hostWidth = Number(contentHost.width)
        if (!isNaN(actualWidth) && actualWidth > 0
                && (isNaN(hostWidth) || hostWidth <= 0 || Math.abs(actualWidth - hostWidth) > 0.5)) {
            return actualWidth
        }

        return 0
    }

    function childHeightDependsOnHost(item) {
        return !!(item && item.anchors && hasAnchor(item.anchors.fill))
    }

    function measuredChildHeight(item) {
        if (!item)
            return 0

        var implicitHeight = Number(item.implicitHeight)
        if (!isNaN(implicitHeight) && implicitHeight > 0)
            return implicitHeight

        if (childHeightDependsOnHost(item))
            return 0

        return 0
    }

    function measuredChildrenWidth(children) {
        var maxRight = 0

        for (var index = 0; index < children.length; ++index) {
            var child = children[index]
            if (!child || child.visible === false)
                continue

            var childX = Number(child.x)
            if (isNaN(childX))
                childX = 0

            maxRight = Math.max(maxRight, childX + measuredChildWidth(child))
        }

        return maxRight
    }

    function measuredChildrenHeight(children) {
        var maxBottom = 0

        for (var index = 0; index < children.length; ++index) {
            var child = children[index]
            if (!child || child.visible === false)
                continue

            maxBottom = Math.max(maxBottom, measuredChildHeight(child))
        }

        return maxBottom
    }

    padding: 0
    transformOrigin: Item.Center
    scale: resolvedScale

    implicitWidth: sizeToContent
        ? Math.max(
            background ? background.implicitWidth : 0,
            leftPadding + rightPadding + (constrainContentWidth ? 0 : (contentItem ? contentItem.implicitWidth : 0))
        )
        : Math.max(background ? background.implicitWidth : 0, leftPadding + rightPadding)
    implicitHeight: sizeToContent
        ? Math.max(
            background ? background.implicitHeight : 0,
            topPadding + bottomPadding + (constrainContentHeight ? 0 : (contentItem ? contentItem.implicitHeight : 0))
        )
        : Math.max(background ? background.implicitHeight : 0, topPadding + bottomPadding)

    HoverHandler {
        id: hoverHandler
        enabled: root.interactive
    }

    TapHandler {
        enabled: root.clearFocusOnTap
        acceptedButtons: Qt.LeftButton
        grabPermissions: PointerHandler.TakeOverForbidden
        onTapped: root.forceActiveFocus(Qt.MouseFocusReason)
    }

    Behavior on fillColor {
        enabled: root.animateColor
        ColorAnimation {
            duration: root.transitionDuration
            easing.type: root.transitionEasing
        }
    }

    Behavior on borderColor {
        enabled: root.animateColor
        ColorAnimation {
            duration: root.transitionDuration
            easing.type: root.transitionEasing
        }
    }

    background: Item {
        implicitWidth: 0
        implicitHeight: 0

        Rectangle {
            anchors.fill: parent
            radius: root.resolvedRadius
            color: root.fillColor
            opacity: root.surfaceOpacityScale
            border.width: root.strokeWidth
            border.color: root.borderColor
            antialiasing: true
        }

        Rectangle {
            anchors.fill: parent
            radius: root.resolvedRadius
            color: root.hoverOverlayColor
            opacity: root.resolvedHoverOpacity
            visible: opacity > 0

            Behavior on opacity {
                enabled: root.animateOpacity
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
                enabled: root.animateOpacity
                NumberAnimation {
                    duration: root.transitionDuration
                    easing.type: root.transitionEasing
                }
            }
        }
    }

    contentItem: Item {
        id: contentHost

        property int contentRevision: 0

        function refreshContentMeasurement() {
            if (!root.constrainContentWidth || !root.constrainContentHeight)
                contentRevision += 1
        }

        onChildrenChanged: refreshContentMeasurement()
        Component.onCompleted: refreshContentMeasurement()

        implicitWidth: {
            var _ = contentRevision
            return root.constrainContentWidth ? 0 : root.measuredChildrenWidth(children)
        }
        implicitHeight: {
            var _ = contentRevision
            return root.constrainContentHeight ? 0 : root.measuredChildrenHeight(children)
        }
        clip: root.clipContent
    }
}
