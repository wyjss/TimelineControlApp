import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14
import "../../../foundation"
import "../../../theme" as Theme
import "AppThemeUtils.js" as ThemeUtils

Control {
    id: root

    default property alias contentData: contentHost.data

    property QtObject theme
    property string surfaceTone: "surface"

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

    property var shapeRole: undefined
    property real cornerRadius: -1
    property int strokeWidth: 1

    property var fillOverride: undefined
    property var borderOverride: undefined
    property var hoverOverlayColorOverride: undefined
    property var activeOverlayColorOverride: undefined

    property real hoverOverlayOpacity: 0.14
    property real activeOverlayOpacity: 0.22
    property real hoverScaleFactor: 1.0
    property real pressScaleFactor: 0.96

    readonly property QtObject applicationWindowTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : null
    readonly property QtObject windowTheme: Window.window && Window.window.appTheme
        ? Window.window.appTheme
        : null
    readonly property QtObject resolvedTheme: theme
        ? theme
        : (applicationWindowTheme ? applicationWindowTheme : windowTheme)
    property int transitionDuration: resolvedTheme ? resolvedTheme.motion.durationStandard : 180
    property int transitionEasing: resolvedTheme ? resolvedTheme.motion.easingStandard : Easing.OutCubic

    readonly property QtObject fallbackControlStyles: Theme.AppControlStyles {}
    readonly property QtObject resolvedControlStyles: resolvedTheme && resolvedTheme.controlStyles
        ? resolvedTheme.controlStyles
        : fallbackControlStyles
    readonly property string resolvedSurfaceTone: surfaceTone
    readonly property var resolvedSurfaceToneSpec: resolvedControlStyles.surfaceToneSpec(
        resolvedSurfaceTone,
        active
    )
    readonly property bool hasExplicitShapeRole: !(shapeRole === undefined || shapeRole === null || String(shapeRole).length === 0)
    readonly property int resolvedShapeRole: hasExplicitShapeRole
        ? AppUiEnums.normalizeShapeRole(shapeRole)
        : -1
    readonly property bool effectiveHovered: hoveredState || (interactive && hoverHandler.hovered)
    readonly property bool effectivePressed: pressedState
    readonly property real resolvedRadius: resolveRadius()
    readonly property real resolvedScale: resolveScale()
    readonly property real resolvedHoverOpacity: effectiveHovered ? hoverOverlayOpacity : 0
    readonly property real resolvedActiveOpacity: (active || effectivePressed) ? activeOverlayOpacity : 0
    readonly property real availableContentWidth: availableWidth
    readonly property real availableContentHeight: availableHeight

    property color fillColor: resolveFillColor()
    property color borderColor: resolveBorderColor()
    property color hoverOverlayColor: resolveHoverOverlayColor()
    property color activeOverlayColor: resolveActiveOverlayColor()

    function densityValue(name, fallback) {
        return ThemeUtils.densityValue(resolvedTheme, name, fallback)
    }

    function colorValue(name, fallback) {
        return ThemeUtils.colorValue(resolvedTheme, name, fallback)
    }

    function shapeValue(name, fallback) {
        return ThemeUtils.shapeValue(resolvedTheme, name, fallback)
    }

    function surfaceToneSpecValue(name, fallback) {
        return resolvedSurfaceToneSpec && resolvedSurfaceToneSpec[name] !== undefined
            ? resolvedSurfaceToneSpec[name]
            : fallback
    }

    function resolvedColorSpec(colorSpec, fallback) {
        if (colorSpec === undefined || colorSpec === null)
            return fallback

        if (typeof colorSpec === "string") {
            if (resolvedTheme && resolvedTheme.colors
                    && resolvedTheme.colors[colorSpec] !== undefined)
                return resolvedTheme.colors[colorSpec]

            if (colorSpec === "transparent" || colorSpec.charAt(0) === "#")
                return colorSpec

            return fallback
        }

        return colorSpec
    }

    function resolveRadius() {
        if (cornerRadius >= 0)
            return cornerRadius

        switch (resolvedShapeRole) {
        case AppUiEnums.ShapeRole.None:
            return 0
        case AppUiEnums.ShapeRole.Control:
            return shapeValue("controlRadius", 8)
        case AppUiEnums.ShapeRole.Section:
            return shapeValue("sectionRadius", 10)
        case AppUiEnums.ShapeRole.Panel:
            return shapeValue("panelRadius", 10)
        case AppUiEnums.ShapeRole.Shell:
            return shapeValue("shellRadius", 2)
        case AppUiEnums.ShapeRole.Canvas:
            return shapeValue("canvasRadius", 10)
        case AppUiEnums.ShapeRole.Overlay:
            return shapeValue("overlayRadius", 14)
        case AppUiEnums.ShapeRole.Pill:
            return root.height > 0
                ? root.height * shapeValue("pillRadiusFactor", 0.5)
                : shapeValue("controlRadius", 8)
        }

        switch (resolvedSurfaceTone) {
        case "canvas":
            return shapeValue("canvasRadius", 10)
        case "section":
        case "sectionOverlay":
            return shapeValue("sectionRadius", 10)
        case "ghost":
            return 0
        default:
            return shapeValue("panelRadius", 10)
        }
    }

    function resolveFillColor() {
        if (fillOverride !== undefined)
            return fillOverride

        return resolvedColorSpec(
            surfaceToneSpecValue("fill", "surface"),
            surfaceToneSpecValue("fillFallback", "#171d25")
        )
    }

    function resolveBorderColor() {
        if (borderOverride !== undefined)
            return borderOverride

        return resolvedColorSpec(
            surfaceToneSpecValue("border", "border"),
            surfaceToneSpecValue("borderFallback", "#334155")
        )
    }

    function resolveHoverOverlayColor() {
        if (hoverOverlayColorOverride !== undefined)
            return hoverOverlayColorOverride

        return resolvedColorSpec(
            surfaceToneSpecValue("hoverOverlay", "windowAccent"),
            surfaceToneSpecValue("hoverOverlayFallback", "#222b36")
        )
    }

    function resolveActiveOverlayColor() {
        if (activeOverlayColorOverride !== undefined)
            return activeOverlayColorOverride

        return resolvedColorSpec(
            surfaceToneSpecValue("activeOverlay", "highlightSoft"),
            surfaceToneSpecValue("activeOverlayFallback", "#182b45")
        )
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

    Behavior on scale {
        enabled: root.animateScale
        NumberAnimation {
            duration: root.transitionDuration
            easing.type: root.transitionEasing
        }
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
        property var measuredItems: []

        function refreshContentMeasurement() {
            if (!contentHost)
                return

            contentHost.contentRevision += 1
        }

        function disconnectMeasuredItem(item) {
            if (!item)
                return

            try {
                item.implicitWidthChanged.disconnect(refreshContentMeasurement)
            } catch (error) {
            }

            try {
                item.implicitHeightChanged.disconnect(refreshContentMeasurement)
            } catch (error) {
            }

            try {
                item.visibleChanged.disconnect(refreshContentMeasurement)
            } catch (error) {
            }
        }

        function connectMeasuredItem(item) {
            if (!item)
                return

            item.implicitWidthChanged.connect(refreshContentMeasurement)
            item.implicitHeightChanged.connect(refreshContentMeasurement)
            item.visibleChanged.connect(refreshContentMeasurement)
        }

        function syncMeasuredItems() {
            for (var oldIndex = 0; oldIndex < contentHost.measuredItems.length; ++oldIndex)
                disconnectMeasuredItem(contentHost.measuredItems[oldIndex])

            var nextItems = []
            for (var index = 0; index < contentHost.children.length; ++index) {
                var child = contentHost.children[index]
                nextItems.push(child)
                connectMeasuredItem(child)
            }

            contentHost.measuredItems = nextItems
            refreshContentMeasurement()
        }

        onChildrenChanged: syncMeasuredItems()
        Component.onCompleted: syncMeasuredItems()
        Component.onDestruction: {
            for (var index = 0; index < measuredItems.length; ++index)
                disconnectMeasuredItem(measuredItems[index])
        }

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
