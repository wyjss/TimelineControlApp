import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtQuick.Window 2.14
import UICore.Style 1.0
import "internal" as Internal
import "internal/AppOptionData.js" as OptionData
import "internal/AppPopupGeometry.js" as PopupGeometry
import "internal/AppThemeUtils.js" as ThemeUtils

TextField {
    id: root

    property int surfaceTone: UiStyle.SurfaceTone.Control
    property int appearance: UiStyle.ControlAppearance.Filled
    property bool emphasized: false
    property bool animateTextColor: true
    property var options: []
    property string textRole: "label"
    property string valueRole: "value"
    property bool _optionsPopupActivated: false

    property real cornerRadius: -1
    property int controlHeight: densityValue("controlHeightMd")
    property int maxPopupHeight: 220
    property int contentPaddingX: densityValue("controlPaddingXMd")
    property int contentPaddingY: 8
    property int slotSpacing: densityValue("controlGap")
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
    readonly property QtObject currentWindowTheme: applicationWindowTheme
        ? applicationWindowTheme
        : windowTheme
    property QtObject _retainedTheme: currentWindowTheme
    readonly property QtObject resolvedTheme: _retainedTheme

    onCurrentWindowThemeChanged: {
        if (currentWindowTheme)
            _retainedTheme = currentWindowTheme
    }

    readonly property var resolvedInputChromeSpec: resolvedTheme.controlStyles.inputChromeSpec(
        appearance,
        hasSelection
    )
    readonly property real leadingSlotWidth: leadingSlot.childrenRect.width > 0
        ? leadingSlot.childrenRect.width + slotSpacing
        : 0
    readonly property real trailingSlotWidth: trailingSlot.childrenRect.width > 0
        ? trailingSlot.childrenRect.width + slotSpacing
        : 0
    readonly property var resolvedOptions: options && options.length !== undefined ? options : []
    readonly property bool hasOptions: resolvedOptions.length > 0
    readonly property bool popupVisible: optionsPopupLoader.item
        ? optionsPopupLoader.item.visible
        : false
    readonly property real optionsIndicatorWidth: hasOptions ? 12 + slotSpacing : 0
    readonly property bool hasSelection: selectionStart >= 0
        && selectionEnd >= 0
        && selectionStart !== selectionEnd
    readonly property bool ghostAppearance: resolvedInputChromeSpec.ghost
    readonly property bool interactionHovered: hovered
    readonly property bool interactionActive: emphasized
        || (!readOnly && (activeFocus || hasSelection || popupVisible))

    onHasOptionsChanged: {
        if (!hasOptions)
            _optionsPopupActivated = false
    }

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

    function updatePopupGeometry() {
        var optionsPopup = optionsPopupLoader.item
        if (!optionsPopup)
            return

        var popupGap = densityValue("popupGap")
        var popupPadding = optionsPopup.padding
        var optionCount = resolvedOptions.length
        var desiredContentHeight = Math.min(
            optionCount * controlHeight
                + Math.max(0, optionCount - 1) * popupGeometry.optionSpacing,
            maxPopupHeight
        )
        var boundary = Window.window && Window.window.contentItem
            ? Window.window.contentItem
            : null
        var geometry = PopupGeometry.resolve(
            root,
            boundary,
            Math.max(root.width, 180),
            desiredContentHeight,
            popupPadding,
            popupGap
        )

        popupGeometry.openAbove = geometry.openAbove
        popupGeometry.popupX = geometry.x
        popupGeometry.popupY = geometry.y
        popupGeometry.popupWidth = geometry.width
        popupGeometry.popupContentHeight = geometry.contentHeight
    }

    selectByMouse: true
    hoverEnabled: enabled && !readOnly
    implicitHeight: controlHeight
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

    leftPadding: contentPaddingX + leadingInset + leadingSlotWidth
    rightPadding: contentPaddingX + trailingInset + trailingSlotWidth + optionsIndicatorWidth
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

    onActiveFocusChanged: {
        if (!activeFocus && popupVisible)
            optionsPopupLoader.item.close()
    }
    Connections {
        target: root.popupVisible ? root : null

        function onWidthChanged() {
            root.updatePopupGeometry()
        }

        function onXChanged() {
            root.updatePopupGeometry()
        }

        function onYChanged() {
            root.updatePopupGeometry()
        }
    }

    Connections {
        target: root.popupVisible && Window.window && Window.window.contentItem
            ? Window.window.contentItem
            : null

        function onWidthChanged() {
            root.updatePopupGeometry()
        }

        function onHeightChanged() {
            root.updatePopupGeometry()
        }
    }

    Keys.onEscapePressed: {
        event.accepted = popupVisible
        if (event.accepted)
            optionsPopupLoader.item.close()
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
        anchors.right: optionsIndicator.visible ? optionsIndicator.left : parent.right
        anchors.rightMargin: optionsIndicator.visible
            ? root.slotSpacing
            : root.contentPaddingX + root.trailingInset
        anchors.verticalCenter: parent.verticalCenter
        visible: width > 0
        opacity: root.enabled ? 1 : 0.56
    }

    Loader {
        id: optionsIndicator

        z: 2
        width: active ? 12 : 0
        height: parent.height
        anchors.right: parent.right
        anchors.rightMargin: root.contentPaddingX + root.trailingInset
        anchors.verticalCenter: parent.verticalCenter
        active: root.hasOptions
        visible: active
        sourceComponent: optionsIndicatorComponent
    }

    Component {
        id: optionsIndicatorComponent

        Item {
            Internal.AppDropdownIndicator {
                anchors.centerIn: parent
                expanded: root.popupVisible
                strokeColor: !root.enabled
                    ? root.colorValue("disabledText")
                    : root.interactionActive
                    ? root.colorValue("highlightText")
                    : root.colorValue("subtleText")
                transitionDuration: root.resolvedTheme.motion.durationStandard
                transitionEasing: root.resolvedTheme.motion.easingStandard
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                enabled: root.enabled && !root.readOnly
                acceptedButtons: Qt.LeftButton
                onClicked: {
                    root.forceActiveFocus(Qt.MouseFocusReason)
                    if (root.popupVisible) {
                        optionsPopupLoader.item.close()
                    } else {
                        root._optionsPopupActivated = true
                        root.updatePopupGeometry()
                        optionsPopupLoader.item.open()
                    }
                }
            }
        }
    }

    QtObject {
        id: popupGeometry

        property bool openAbove: false
        property real popupX: 0
        property real popupY: 0
        property real popupWidth: Math.max(root.width, 180)
        property real popupContentHeight: 0
        readonly property int optionSpacing: 4
    }

    Loader {
        id: optionsPopupLoader

        active: root.hasOptions && root._optionsPopupActivated
        sourceComponent: optionsPopupComponent
    }

    Component {
        id: optionsPopupComponent

        AppPopup {
            id: optionsPopup
            objectName: "appTextFieldOptionsPopup"

            parent: root
            x: popupGeometry.popupX
            y: popupGeometry.popupY
            width: popupGeometry.popupWidth
            revealOrigin: popupGeometry.openAbove ? Item.Bottom : Item.Top
            revealOffsetY: popupGeometry.openAbove
                ? popupRevealOffset
                : -popupRevealOffset
            padding: 6
            spacing: 0
            modal: false
            focus: false
            showModalOverlay: false
            surfaceTone: UiStyle.SurfaceTone.SurfaceOverlay
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            cornerRadius: root.cornerRadius

            onAboutToShow: root.updatePopupGeometry()

            ListView {
                id: optionsList

                objectName: "appTextFieldOptionsScroll"
                Layout.fillWidth: true
                Layout.preferredHeight: popupGeometry.popupContentHeight
                implicitHeight: popupGeometry.popupContentHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height + 1
                model: optionsPopup.visible ? root.resolvedOptions : []
                spacing: popupGeometry.optionSpacing

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                delegate: Internal.AppDropdownOption {
                    readonly property var optionValue: OptionData.optionValue(modelData, root.valueRole)

                    width: optionsList.width
                    optionHeight: root.controlHeight
                    enabled: root.enabled && !root.readOnly
                    text: OptionData.optionLabel(modelData, root.textRole)
                    selected: OptionData.valuesEqual(optionValue, root.text)
                    onClicked: {
                        root.text = optionValue !== undefined && optionValue !== null
                            ? String(optionValue)
                            : ""
                        root.cursorPosition = root.length
                        optionsPopup.close()
                        root.forceActiveFocus(Qt.MouseFocusReason)
                    }
                }
            }
        }
    }

}
