import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtQuick.Window 2.14
import "../../foundation"
import "internal" as Internal
import "internal/AppOptionData.js" as OptionData
import "internal/AppThemeUtils.js" as ThemeUtils

Internal.AppControlBase {
    id: root

    property var options: []
    property var value: undefined

    property string textRole: "label"
    property string valueRole: "value"
    property string placeholderText: ""
    property var appearance: AppUiEnums.ControlAppearance.Filled
    property bool emphasized: false

    property int controlHeight: densityValue("controlHeightMd", 36)
    property int optionHeight: controlHeight
    property int contentPaddingX: densityValue("controlPaddingXMd", 12)
    property int slotSpacing: densityValue("controlGap", 8)
    property int popupMinWidth: 0
    property int popupMaxWidth: 320
    property int maxPopupHeight: 220
    property real leadingInset: 0
    property real trailingInset: 0

    property alias leadingContent: leadingSlot.data
    property alias trailingContent: trailingSlot.data

    readonly property int resolvedAppearance: AppUiEnums.normalizeAppearance(appearance)
    readonly property var resolvedOptions: options && options.length !== undefined ? options : []
    readonly property int currentIndex: OptionData.indexOfValue(resolvedOptions, value, valueRole)
    readonly property var currentOption: currentIndex >= 0 ? resolvedOptions[currentIndex] : null
    readonly property string currentLabel: currentOption !== null
        ? OptionData.optionLabel(currentOption, textRole)
        : ""
    readonly property bool popupVisible: dropdownPopup.visible
    readonly property real leadingSlotWidth: leadingSlot.childrenRect.width > 0
        ? leadingSlot.childrenRect.width + slotSpacing
        : 0
    readonly property real trailingSlotWidth: trailingSlot.childrenRect.width > 0
        ? trailingSlot.childrenRect.width + slotSpacing
        : 0
    readonly property int indicatorWidth: 12
    readonly property real desiredPopupWidth: Math.max(
        width,
        Math.min(popupMaxWidth, Math.max(popupMinWidth, measuredPopupWidth()))
    )
    readonly property real popupBoundaryWidth: resolvedPopupBoundaryWidth()
    readonly property real resolvedPopupWidth: popupBoundaryWidth > 0
        ? Math.min(desiredPopupWidth, popupBoundaryWidth)
        : desiredPopupWidth
    readonly property real resolvedPopupX: boundedPopupX()
    readonly property var resolvedInputChromeSpec: resolvedTheme && resolvedTheme.controlStyles
        ? resolvedTheme.controlStyles.inputChromeSpec(resolvedAppearance, false)
        : ({ "ghost": resolvedAppearance === AppUiEnums.ControlAppearance.Ghost,
             "shapeRole": AppUiEnums.ShapeRole.Control,
             "idleStrokeWidth": resolvedAppearance === AppUiEnums.ControlAppearance.Ghost ? 0 : 1,
             "activeStrokeWidth": resolvedAppearance === AppUiEnums.ControlAppearance.Ghost ? 0 : 2,
             "hoverOverlayOpacity": resolvedAppearance === AppUiEnums.ControlAppearance.Ghost ? 0 : 0.10,
             "activeOverlayOpacity": resolvedAppearance === AppUiEnums.ControlAppearance.Ghost ? 0 : 0.08,
             "disabledOpacity": 0.74 })
    readonly property bool ghostAppearance: resolvedInputChromeSpec.ghost
    readonly property bool interactionHovered: fieldHoverHandler.hovered
    readonly property bool interactionActive: popupVisible || activeFocus || emphasized

    signal valueSelected(var nextValue)

    function typographyValue(name, fallback) {
        return ThemeUtils.typographyValue(resolvedTheme, name, fallback)
    }

    function measuredPopupWidth() {
        var widest = currentLabel.length > 0
            ? selectFontMetrics.advanceWidth(currentLabel)
            : selectFontMetrics.advanceWidth(placeholderText)

        for (var i = 0; i < resolvedOptions.length; ++i)
            widest = Math.max(widest, selectFontMetrics.advanceWidth(OptionData.optionLabel(resolvedOptions[i], textRole)))

        return Math.ceil(widest + 60)
    }

    function popupBoundaryItem() {
        return Window.window && Window.window.contentItem
            ? Window.window.contentItem
            : null
    }

    function resolvedPopupBoundaryWidth() {
        var boundary = popupBoundaryItem()
        return boundary && boundary.width > 0 ? boundary.width : 0
    }

    function boundedPopupX() {
        var boundary = popupBoundaryItem()
        if (!boundary || !(boundary.width > 0))
            return 0

        var mapped = root.mapToItem(boundary, 0, 0)
        var nextX = 0

        if (mapped.x + nextX + resolvedPopupWidth > boundary.width)
            nextX = boundary.width - mapped.x - resolvedPopupWidth

        if (mapped.x + nextX < 0)
            nextX = -mapped.x

        return nextX
    }

    function commitOption(optionData) {
        var nextValue = OptionData.optionValue(optionData, valueRole)
        root.value = nextValue
        root.valueSelected(nextValue)
        popupState.closingFromOptionCommit = true
        dropdownPopup.close()
    }

    surfaceTone: "section"
    implicitWidth: 180
    implicitHeight: controlHeight

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

    contentItem: Item {
        implicitWidth: root.implicitWidth
        implicitHeight: root.controlHeight

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
            id: indicatorWrap
            z: 1
            width: root.indicatorWidth
            height: parent.height
            anchors.right: parent.right
            anchors.rightMargin: root.contentPaddingX + root.trailingInset
            anchors.verticalCenter: parent.verticalCenter
            opacity: root.enabled ? 1 : 0.56
            rotation: root.popupVisible ? 180 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: root.resolvedTheme ? root.resolvedTheme.motion.durationStandard : 180
                    easing.type: root.resolvedTheme ? root.resolvedTheme.motion.easingStandard : Easing.OutCubic
                }
            }

            Canvas {
                anchors.centerIn: parent
                width: 10
                height: 10
                contextType: "2d"

                property color strokeColor: root.interactionActive
                    ? root.colorValue("highlightText", "#7cb4ff")
                    : root.colorValue("subtleText", "#97a3b6")

                onStrokeColorChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    var inset = Math.max(1.6, width * 0.22)
                    var topY = height * 0.34

                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = strokeColor
                    ctx.lineWidth = 1.6
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(inset, topY)
                    ctx.lineTo(width * 0.5, height - inset)
                    ctx.lineTo(width - inset, topY)
                    ctx.stroke()
                }
            }
        }

        Item {
            id: trailingSlot
            z: 1
            width: childrenRect.width
            height: parent.height
            anchors.right: indicatorWrap.left
            anchors.rightMargin: width > 0 ? root.slotSpacing : 0
            anchors.verticalCenter: parent.verticalCenter
            visible: width > 0
            opacity: root.enabled ? 1 : 0.56
        }

        AppText {
            z: 1
            anchors.left: leadingSlot.visible ? leadingSlot.right : parent.left
            anchors.leftMargin: root.contentPaddingX + (leadingSlot.visible ? root.slotSpacing + root.leadingInset : root.leadingInset)
            anchors.right: trailingSlot.visible ? trailingSlot.left : indicatorWrap.left
            anchors.rightMargin: root.slotSpacing
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentLabel.length > 0 ? root.currentLabel : root.placeholderText
            theme: root.resolvedTheme
            styleRole: "bodyM"
            textTone: root.currentLabel.length > 0 ? "primary" : "secondary"
            elide: Text.ElideRight
        }

        MouseArea {
            id: controlTapArea

            anchors.fill: parent
            enabled: root.enabled
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            preventStealing: true
            onClicked: {
                root.forceActiveFocus(Qt.MouseFocusReason)

                if (popupState.suppressNextControlToggle) {
                    popupState.suppressNextControlToggle = false
                    suppressToggleReset.stop()
                    return
                }

                if (dropdownPopup.visible) {
                    popupState.closingFromControlToggle = true
                    dropdownPopup.close()
                } else {
                    dropdownPopup.open()
                }
            }
        }
    }

    resources: [
        QtObject {
            id: popupState

            property bool suppressNextControlToggle: false
            property bool closingFromControlToggle: false
            property bool closingFromOptionCommit: false
        },

        HoverHandler {
            id: fieldHoverHandler
            enabled: root.enabled
        },

        FontMetrics {
            id: selectFontMetrics

            font.family: typographyValue("familySans", "")
            font.pixelSize: Number(typographyValue("bodyM", 13))
            font.weight: Number(typographyValue("weightRegular", Font.Normal))
        },

        Timer {
            id: suppressToggleReset

            interval: 120
            repeat: false
            onTriggered: popupState.suppressNextControlToggle = false
        },

        AppPopup {
            id: dropdownPopup
            objectName: "appSelectPopup"

            parent: root
            x: root.resolvedPopupX
            y: root.height + 6
            width: root.resolvedPopupWidth
            padding: 6
            spacing: 0
            modal: false
            focus: true
            showModalOverlay: false
            surfaceTone: "surface"
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
            theme: root.resolvedTheme
            cornerRadius: root.cornerRadius
            onClosed: {
                if (popupState.closingFromControlToggle) {
                    popupState.closingFromControlToggle = false
                    return
                }

                if (popupState.closingFromOptionCommit) {
                    popupState.closingFromOptionCommit = false
                    return
                }

                popupState.suppressNextControlToggle = true
                suppressToggleReset.restart()
            }

            ListView {
                id: dropdownList

                objectName: "appSelectListView"
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, root.maxPopupHeight)
                implicitHeight: Math.min(contentHeight, root.maxPopupHeight)
                width: parent ? parent.width : root.resolvedPopupWidth
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height + 1
                model: root.resolvedOptions
                spacing: 4
                currentIndex: root.currentIndex

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                delegate: Item {
                    id: optionItem
                    objectName: "appSelectOption_" + index

                    readonly property var optionData: modelData
                    readonly property bool selected: OptionData.valuesEqual(
                        OptionData.optionValue(optionData, root.valueRole),
                        root.value
                    )

                    width: dropdownList.width
                    height: root.optionHeight

                    AppSurface {
                        anchors.fill: parent
                        theme: root.resolvedTheme
                        surfaceTone: optionItem.selected ? "highlight" : "ghost"
                        active: optionItem.selected
                        hoveredState: optionTap.hovered
                        interactive: root.enabled
                        strokeWidth: optionItem.selected || optionTap.hovered ? 1 : 0
                        cornerRadius: root.cornerRadius >= 0
                            ? Math.max(0, root.cornerRadius - 2)
                            : -1
                        shapeRole: AppUiEnums.ShapeRole.Control
                        fillOverride: optionItem.selected
                            ? root.colorValue("highlightSoft", "#182b45")
                            : "transparent"
                        borderOverride: optionItem.selected
                            ? root.colorValue("highlightText", "#7cb4ff")
                            : (optionTap.hovered
                                ? root.colorValue("border", "#334155")
                                : "transparent")
                        hoverOverlayOpacity: optionItem.selected ? 0 : 0.08
                        activeOverlayOpacity: optionItem.selected ? 0.04 : 0
                    }

                    Rectangle {
                        width: 3
                        height: parent.height - 16
                        radius: width / 2
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.colorValue("highlightText", "#7cb4ff")
                        opacity: optionItem.selected ? 1 : (optionTap.hovered ? 0.24 : 0)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.resolvedTheme && root.resolvedTheme.motion
                                    ? root.resolvedTheme.motion.durationFast
                                    : 120
                                easing.type: root.resolvedTheme && root.resolvedTheme.motion
                                    ? root.resolvedTheme.motion.easingStandard
                                    : Easing.OutCubic
                            }
                        }
                    }

                    AppText {
                        anchors.left: parent.left
                        anchors.leftMargin: 22
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: OptionData.optionLabel(optionItem.optionData, root.textRole)
                        theme: root.resolvedTheme
                        styleRole: "bodyM"
                        textTone: optionItem.selected ? "accent" : "primary"
                        elide: Text.ElideRight
                    }

                    Internal.AppTapRegion {
                        id: optionTap

                        anchors.fill: parent
                        enabled: root.enabled
                        onTapped: root.commitOption(optionItem.optionData)
                    }
                }
            }
        }
    ]
}
