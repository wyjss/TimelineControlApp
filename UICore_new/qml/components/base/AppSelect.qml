import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtQuick.Window 2.14
import UICore.Style 1.0
import "internal" as Internal
import "internal/AppOptionData.js" as OptionData
import "internal/AppPopupGeometry.js" as PopupGeometry
import "internal/AppThemeUtils.js" as ThemeUtils

ComboBox {
    id: root

    property var options: []
    property var value: undefined

    property string placeholderText: ""
    property int surfaceTone: UiStyle.SurfaceTone.Control
    property int appearance: UiStyle.ControlAppearance.Filled
    property bool emphasized: false
    property bool readOnly: false
    property real cornerRadius: -1

    property int controlHeight: densityValue("controlHeightMd")
    property int optionHeight: controlHeight
    property int contentPaddingX: densityValue("controlPaddingXMd")
    property int slotSpacing: densityValue("controlGap")
    property int popupMinWidth: 0
    property int popupMaxWidth: 320
    property int maxPopupHeight: 220
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
    readonly property var resolvedOptions: options && options.length !== undefined ? options : []
    readonly property int optionCount: resolvedOptions.length
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
        Math.min(popupMaxWidth, Math.max(popupMinWidth, popupState.measuredPopupWidth))
    )
    readonly property real resolvedPopupWidth: popupState.popupWidth
    readonly property real resolvedPopupX: popupState.popupX
    readonly property var resolvedInputChromeSpec: resolvedTheme.controlStyles.inputChromeSpec(
        appearance,
        false
    )
    readonly property bool ghostAppearance: resolvedInputChromeSpec.ghost
    readonly property bool interactionHovered: hovered
    readonly property bool interactionActive: emphasized
        || (!readOnly && (popupVisible || activeFocus))

    onCurrentWindowThemeChanged: {
        if (currentWindowTheme)
            _retainedTheme = currentWindowTheme
    }

    signal valueSelected(var nextValue)

    Accessible.role: Accessible.ComboBox
    Accessible.name: currentLabel.length > 0 ? currentLabel : placeholderText
    Accessible.readOnly: readOnly
    Accessible.focusable: enabled && !readOnly
    Accessible.focused: activeFocus
    Accessible.onPressAction: {
        if (root.enabled && !root.readOnly && root.optionCount > 0)
            dropdownPopup.open()
    }

    function densityValue(name) {
        return ThemeUtils.densityValue(resolvedTheme, name)
    }

    function typographyValue(name) {
        return ThemeUtils.typographyValue(resolvedTheme, name)
    }

    function colorValue(name) {
        return ThemeUtils.colorValue(resolvedTheme, name)
    }

    function syncCurrentIndex() {
        var nextIndex = OptionData.indexOfValue(resolvedOptions, value, valueRole)
        if (currentIndex !== nextIndex)
            currentIndex = nextIndex
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

    function updatePopupGeometry() {
        var popupGap = densityValue("popupGap")
        var popupPadding = dropdownPopup.padding
        var desiredContentHeight = Math.min(
            optionCount * optionHeight + Math.max(0, optionCount - 1) * popupState.optionSpacing,
            maxPopupHeight
        )
        var geometry = PopupGeometry.resolve(
            root,
            popupBoundaryItem(),
            desiredPopupWidth,
            desiredContentHeight,
            popupPadding,
            popupGap
        )

        popupState.openAbove = geometry.openAbove
        popupState.popupX = geometry.x
        popupState.popupY = geometry.y
        popupState.popupWidth = geometry.width
        popupState.popupContentHeight = geometry.contentHeight
    }

    model: resolvedOptions
    textRole: "label"
    valueRole: "value"
    currentIndex: -1
    displayText: currentLabel.length > 0 ? currentLabel : placeholderText
    implicitWidth: 180
    implicitHeight: controlHeight
    padding: 0
    spacing: 0
    hoverEnabled: true
    wheelEnabled: false
    focusPolicy: readOnly ? Qt.NoFocus : Qt.StrongFocus

    onActivated: {
        if (index < 0 || index >= root.optionCount)
            return

        root.valueSelected(OptionData.optionValue(root.resolvedOptions[index], root.valueRole))
        root.syncCurrentIndex()
    }

    onCurrentIndexChanged: Qt.callLater(root.syncCurrentIndex)
    onOptionsChanged: {
        popupState.popupWidthValid = false
        Qt.callLater(root.syncCurrentIndex)
    }
    onValueChanged: root.syncCurrentIndex()
    onPlaceholderTextChanged: popupState.popupWidthValid = false
    onTextRoleChanged: popupState.popupWidthValid = false
    onValueRoleChanged: root.syncCurrentIndex()
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
        target: root.popupVisible ? root.popupBoundaryItem() : null

        function onWidthChanged() {
            root.updatePopupGeometry()
        }

        function onHeightChanged() {
            root.updatePopupGeometry()
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

    contentItem: Item {
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
            id: trailingSlot
            z: 1
            width: childrenRect.width
            height: parent.height
            anchors.right: parent.right
            anchors.rightMargin: root.contentPaddingX
                + root.trailingInset
                + root.indicatorWidth
                + (width > 0 ? root.slotSpacing : 0)
            anchors.verticalCenter: parent.verticalCenter
            visible: width > 0
            opacity: root.enabled ? 1 : 0.56
        }

        AppText {
            z: 1
            anchors.left: leadingSlot.visible ? leadingSlot.right : parent.left
            anchors.leftMargin: root.contentPaddingX + (leadingSlot.visible ? root.slotSpacing + root.leadingInset : root.leadingInset)
            anchors.right: trailingSlot.visible ? trailingSlot.left : parent.right
            anchors.rightMargin: trailingSlot.visible
                ? root.slotSpacing
                : root.contentPaddingX + root.trailingInset + root.indicatorWidth + root.slotSpacing
            anchors.verticalCenter: parent.verticalCenter
            text: root.displayText
            styleRole: UiStyle.TypographyRole.BodyM
            textTone: root.currentLabel.length > 0
                ? UiStyle.TextTone.Primary
                : UiStyle.TextTone.Secondary
            colorOverride: root.enabled
                ? undefined
                : root.colorValue("disabledText")
            elide: Text.ElideRight
        }

        MouseArea {
            parent: root
            anchors.fill: parent
            z: 2
            enabled: root.readOnly
            acceptedButtons: Qt.LeftButton
        }
    }

    indicator: Item {
        id: indicatorWrap

        z: 1
        width: root.indicatorWidth
        height: root.height
        anchors.right: parent.right
        anchors.rightMargin: root.contentPaddingX + root.trailingInset
        anchors.verticalCenter: parent.verticalCenter

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
    }

    delegate: ItemDelegate {
        width: 0
        height: 0
        visible: false
    }

    popup: AppPopup {
        id: dropdownPopup
        objectName: "appSelectPopup"

        parent: root
        x: root.resolvedPopupX
        y: popupState.popupY
        width: root.resolvedPopupWidth
        revealOrigin: popupState.openAbove ? Item.Bottom : Item.Top
        revealOffsetY: popupState.openAbove
            ? popupRevealOffset
            : -popupRevealOffset
        padding: 6
        spacing: 0
        modal: false
        focus: false
        showModalOverlay: false
        surfaceTone: UiStyle.SurfaceTone.SurfaceOverlay
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        cornerRadius: root.cornerRadius

        onAboutToShow: {
            if (root.optionCount > 0) {
                if (!popupState.popupWidthValid) {
                    popupState.measuredPopupWidth = root.measuredPopupWidth()
                    popupState.popupWidthValid = true
                }
                root.updatePopupGeometry()
            } else {
                close()
            }
        }

        Loader {
            id: dropdownListLoader

            Layout.fillWidth: true
            Layout.preferredHeight: popupState.popupContentHeight
            active: dropdownPopup.visible
            sourceComponent: dropdownListComponent
        }

        Component {
            id: dropdownListComponent

            ListView {
                id: dropdownList

                objectName: "appSelectListView"
                implicitHeight: popupState.popupContentHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height + 1
                model: root.resolvedOptions
                spacing: popupState.optionSpacing
                currentIndex: root.highlightedIndex
                highlightMoveDuration: 0

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                delegate: Internal.AppDropdownOption {
                    id: optionItem
                    objectName: "appSelectOption_" + index

                    readonly property var optionData: modelData
                    width: dropdownList.width
                    optionHeight: root.optionHeight
                    text: OptionData.optionLabel(optionData, root.textRole)
                    selected: OptionData.valuesEqual(
                        OptionData.optionValue(optionData, root.valueRole),
                        root.value
                    )
                    highlighted: root.highlightedIndex === index
                    enabled: root.enabled && !root.readOnly
                    onClicked: {
                        root.currentIndex = index
                        root.activated(index)
                        dropdownPopup.close()
                    }
                }
            }
        }
    }

    QtObject {
        id: popupState

        property bool openAbove: false
        property real popupX: 0
        property real popupY: 0
        property real popupWidth: root.desiredPopupWidth
        property real popupContentHeight: 0
        property bool popupWidthValid: false
        property real measuredPopupWidth: 0
        readonly property int optionSpacing: 4
    }

    FontMetrics {
        id: selectFontMetrics

        font.family: typographyValue("familySans")
        font.pixelSize: Number(typographyValue("bodyM"))
        font.weight: Number(typographyValue("weightRegular"))
        onFontChanged: popupState.popupWidthValid = false
    }

    Component.onCompleted: syncCurrentIndex()
}
