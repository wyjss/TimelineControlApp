import QtQuick 2.14
import UICore.Style 1.0
import "internal" as Internal
import "internal/AppOptionData.js" as OptionData

Internal.AppControlBase {
    id: root

    surfaceTone: UiStyle.SurfaceTone.Control

    property var options: []
    property var value: undefined
    property string textRole: "label"
    property string valueRole: "value"

    readonly property int currentIndex: OptionData.indexOfValue(root.options, root.value, valueRole)
    readonly property bool interactionHovered: choiceHover.hovered
    readonly property bool interactionActive: visualFocus

    signal valueSelected(var nextValue)

    Accessible.role: Accessible.Grouping
    Accessible.focusable: enabled
    Accessible.focused: activeFocus

    function optionLabel(optionData) {
        return OptionData.optionLabel(optionData, textRole)
    }

    function optionValue(optionData) {
        return OptionData.optionValue(optionData, valueRole)
    }

    function optionColor(optionData) {
        if (optionData && optionData.color !== undefined)
            return optionData.color

        return "transparent"
    }

    function optionIcon(optionData) {
        if (!optionData)
            return ""

        if (optionData.iconName !== undefined)
            return String(optionData.iconName)

        if (optionData.iconKey !== undefined)
            return String(optionData.iconKey)

        return ""
    }

    function commitOption(optionData) {
        var nextValue = optionValue(optionData)
        valueSelected(nextValue)
    }

    padding: 0
    background: null
    implicitWidth: 220
    implicitHeight: optionFlow.implicitHeight
    focusPolicy: Qt.StrongFocus

    Keys.onPressed: {
        var optionCount = root.options && root.options.length !== undefined ? root.options.length : 0
        if (optionCount <= 0)
            return

        var nextIndex = root.currentIndex >= 0 ? root.currentIndex : 0
        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_Up:
            nextIndex = Math.max(0, nextIndex - 1)
            break
        case Qt.Key_Right:
        case Qt.Key_Down:
            nextIndex = Math.min(optionCount - 1, nextIndex + 1)
            break
        case Qt.Key_Home:
            nextIndex = 0
            break
        case Qt.Key_End:
            nextIndex = optionCount - 1
            break
        case Qt.Key_Space:
        case Qt.Key_Return:
        case Qt.Key_Enter:
            break
        default:
            return
        }

        event.accepted = true
        root.commitOption(root.options[nextIndex])
    }

    contentItem: Flow {
        id: optionFlow

        width: root.availableWidth > 0 ? root.availableWidth : root.implicitWidth
        spacing: root.densityValue("controlGap")

        Repeater {
            model: root.options

            delegate: Item {
                id: optionItem

                readonly property var optionData: modelData
                readonly property bool selected: OptionData.valuesEqual(root.optionValue(optionData), root.value)
                readonly property bool hasSwatch: root.optionColor(optionData) !== "transparent"
                readonly property string iconName: root.optionIcon(optionData)
                readonly property bool focusTarget: root.visualFocus
                    && (selected || (root.currentIndex < 0 && index === 0))

                width: optionSurface.implicitWidth
                height: optionSurface.implicitHeight
                implicitWidth: width
                implicitHeight: height

                Accessible.role: Accessible.RadioButton
                Accessible.name: root.optionLabel(optionData)
                Accessible.checkable: true
                Accessible.checked: selected
                Accessible.onPressAction: {
                    if (root.enabled)
                        root.commitOption(optionData)
                }

                AppSurface {
                    id: optionSurface
                    anchors.fill: parent

                    animated: root.animated
                    surfaceTone: optionItem.selected
                        ? UiStyle.SurfaceTone.Highlight
                        : root.surfaceTone
                    shapeRole: UiStyle.ShapeRole.Pill
                    active: root.enabled && optionItem.selected
                    hoveredState: root.enabled && optionTap.hovered
                    interactive: root.enabled
                    strokeWidth: optionItem.focusTarget ? 2 : 1
                    padding: 10
                    fillOverride: !root.enabled
                        ? (optionItem.selected
                            ? root.colorValue("disabledBorder")
                            : root.colorValue("disabledFill"))
                        : (optionItem.selected
                            ? root.colorValue("highlightSoft")
                            : root.colorValue("backgroundControl"))
                    borderOverride: optionItem.focusTarget
                        ? root.colorValue("highlightText")
                        : (root.enabled
                            ? root.colorValue("controlBorder")
                            : root.colorValue("disabledBorder"))
                    hoverOverlayColorOverride: root.colorValue("highlightText")
                    activeOverlayColorOverride: root.colorValue("highlightText")
                    hoverOverlayOpacity: 0.09
                    activeOverlayOpacity: 0.04

                    contentItem: Row {
                        id: optionRow

                        width: implicitWidth
                        height: implicitHeight
                        spacing: 8

                        Rectangle {
                            visible: optionItem.hasSwatch
                            width: 12
                            height: 12
                            radius: 6
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.optionColor(optionItem.optionData)
                            opacity: root.enabled ? 1 : 0.56
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.18)
                        }

                        Loader {
                            active: !optionItem.hasSwatch && optionItem.iconName.length > 0
                            visible: active
                            anchors.verticalCenter: parent.verticalCenter

                            sourceComponent: AppIcon {
                                name: optionItem.iconName
                                size: root.resolvedTheme.metrics.iconSizeSm
                                animateColor: root.animated
                                color: !root.enabled
                                    ? root.colorValue("disabledText")
                                    : optionItem.selected
                                    ? root.colorValue("highlightText")
                                    : root.colorValue("text")
                            }
                        }

                        AppText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.optionLabel(optionItem.optionData)
                            styleRole: UiStyle.TypographyRole.BodyS
                            animateColor: root.animated
                            textTone: optionItem.selected
                                ? UiStyle.TextTone.Accent
                                : UiStyle.TextTone.Primary
                            colorOverride: root.enabled
                                ? undefined
                                : root.colorValue("disabledText")
                        }
                    }
                }

                Rectangle {
                    objectName: "choiceSelectionIndicator_" + index
                    width: Math.max(0, optionSurface.width - 20)
                    height: 2
                    radius: 1
                    anchors.horizontalCenter: optionSurface.horizontalCenter
                    anchors.bottom: optionSurface.bottom
                    anchors.bottomMargin: 1
                    color: root.colorValue("highlightText")
                    opacity: optionItem.selected && root.enabled ? 1 : 0

                    Behavior on opacity {
                        enabled: root.animated

                        NumberAnimation {
                            duration: root.resolvedTheme.motion.durationFast
                            easing.type: root.resolvedTheme.motion.easingStandard
                        }
                    }
                }

                Internal.AppTapRegion {
                    id: optionTap

                    anchors.fill: parent
                    enabled: root.enabled
                    focusTarget: root
                    onTapped: root.commitOption(optionItem.optionData)
                }
            }
        }
    }

    resources: [
        HoverHandler {
            id: choiceHover
            enabled: root.enabled
        }
    ]
}
