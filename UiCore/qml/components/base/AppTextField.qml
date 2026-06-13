import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14
import "../../foundation"
import "internal/AppThemeUtils.js" as ThemeUtils

TextField {
    id: root

    property QtObject theme
    property string surfaceTone: "section"
    property var appearance: AppUiEnums.ControlAppearance.Filled
    property bool emphasized: false

    property real cornerRadius: -1
    property int controlHeight: densityValue("controlHeightMd", 36)
    property int contentPaddingX: densityValue("controlPaddingXMd", 12)
    property int contentPaddingY: 8
    property int slotSpacing: densityValue("controlGap", 8)
    property real leadingInset: 0
    property real trailingInset: 0

    property alias leadingContent: leadingSlot.data
    property alias trailingContent: trailingSlot.data

    readonly property QtObject applicationWindowTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : null
    readonly property QtObject windowTheme: Window.window && Window.window.appTheme
        ? Window.window.appTheme
        : null
    readonly property QtObject resolvedTheme: theme
        ? theme
        : (applicationWindowTheme ? applicationWindowTheme : windowTheme)
    readonly property string resolvedSurfaceTone: surfaceTone
    readonly property int resolvedAppearance: AppUiEnums.normalizeAppearance(appearance)
    readonly property var resolvedInputChromeSpec: resolvedTheme && resolvedTheme.controlStyles
        ? resolvedTheme.controlStyles.inputChromeSpec(resolvedAppearance, hasSelection)
        : ({ "ghost": resolvedAppearance === AppUiEnums.ControlAppearance.Ghost,
             "shapeRole": AppUiEnums.ShapeRole.Control,
             "idleStrokeWidth": resolvedAppearance === AppUiEnums.ControlAppearance.Ghost ? 0 : 1,
             "activeStrokeWidth": resolvedAppearance === AppUiEnums.ControlAppearance.Ghost ? 0 : 2,
             "hoverOverlayOpacity": resolvedAppearance === AppUiEnums.ControlAppearance.Ghost ? 0 : 0.10,
             "activeOverlayOpacity": resolvedAppearance === AppUiEnums.ControlAppearance.Ghost ? 0 : (hasSelection ? 0.14 : 0.08),
             "disabledOpacity": 0.74 })
    readonly property real leadingSlotWidth: leadingSlot.childrenRect.width > 0
        ? leadingSlot.childrenRect.width + slotSpacing
        : 0
    readonly property real trailingSlotWidth: trailingSlot.childrenRect.width > 0
        ? trailingSlot.childrenRect.width + slotSpacing
        : 0
    readonly property bool hasSelection: selectionStart >= 0
        && selectionEnd >= 0
        && selectionStart !== selectionEnd
    readonly property bool ghostAppearance: resolvedInputChromeSpec.ghost
    readonly property bool interactionHovered: fieldHoverHandler.hovered
    readonly property bool interactionActive: activeFocus || emphasized || hasSelection

    function densityValue(name, fallback) {
        return ThemeUtils.densityValue(resolvedTheme, name, fallback)
    }

    function typographyValue(name, fallback) {
        return ThemeUtils.typographyValue(resolvedTheme, name, fallback)
    }

    function colorValue(name, fallback) {
        return ThemeUtils.colorValue(resolvedTheme, name, fallback)
    }

    selectByMouse: true
    implicitHeight: controlHeight
    color: colorValue("text", "#e6edf3")
    placeholderTextColor: colorValue("subtleText", "#97a3b6")
    selectedTextColor: colorValue("inverseText", "#f8fafc")
    selectionColor: colorValue("highlightFill", "#2563eb")

    font.family: typographyValue("familySans", "")
    font.pixelSize: Number(typographyValue("bodyM", 13))
    font.weight: Number(typographyValue("weightRegular", Font.Normal))

    leftPadding: contentPaddingX + leadingInset + leadingSlotWidth
    rightPadding: contentPaddingX + trailingInset + trailingSlotWidth
    topPadding: contentPaddingY
    bottomPadding: contentPaddingY

    background: AppSurface {
        enabled: false
        theme: root.resolvedTheme
        surfaceTone: root.ghostAppearance ? "ghost" : root.resolvedSurfaceTone
        shapeRole: root.resolvedInputChromeSpec.shapeRole
        active: root.ghostAppearance ? false : root.interactionActive
        hoveredState: root.ghostAppearance ? false : root.interactionHovered
        strokeWidth: root.interactionActive
            ? root.resolvedInputChromeSpec.activeStrokeWidth
            : root.resolvedInputChromeSpec.idleStrokeWidth
        cornerRadius: root.cornerRadius
        hoverOverlayOpacity: root.resolvedInputChromeSpec.hoverOverlayOpacity
        activeOverlayOpacity: root.resolvedInputChromeSpec.activeOverlayOpacity
        opacity: root.enabled ? 1 : root.resolvedInputChromeSpec.disabledOpacity
    }

    HoverHandler {
        id: fieldHoverHandler
        enabled: root.enabled
    }

    // Raw accessory slots keep the field generic for future search, filter, and picker variants.
    Item {
        id: leadingSlot
        z: 1
        width: childrenRect.width
        height: parent.height
        anchors.left: parent.left
        anchors.leftMargin: root.contentPaddingX + root.leadingInset
        anchors.verticalCenter: parent.verticalCenter
        visible: width > 0
        opacity: root.enabled ? 1 : 0.56
    }

    Item {
        id: trailingSlot
        z: 1
        width: childrenRect.width
        height: parent.height
        anchors.right: parent.right
        anchors.rightMargin: root.contentPaddingX + root.trailingInset
        anchors.verticalCenter: parent.verticalCenter
        visible: width > 0
        opacity: root.enabled ? 1 : 0.56
    }

}
