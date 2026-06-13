import QtQuick 2.14
import "../../foundation"
import "internal" as Internal
import "internal/AppOptionData.js" as OptionData

Internal.AppControlBase {
    id: root

    property var options: []
    property var value: undefined
    property string textRole: "label"
    property string valueRole: "value"

    readonly property bool interactionHovered: choiceHover.hovered
    readonly property bool interactionActive: false

    signal valueSelected(var nextValue)

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
        value = nextValue
        valueSelected(nextValue)
    }

    padding: 0
    background: null
    implicitWidth: 220
    implicitHeight: optionFlow.implicitHeight
    opacity: enabled ? 1 : 0.68

    contentItem: Flow {
        id: optionFlow

        width: root.availableWidth > 0 ? root.availableWidth : root.implicitWidth
        spacing: root.densityValue("controlGap", 8)

        Repeater {
            model: root.options

            delegate: Item {
                id: optionItem

                readonly property var optionData: modelData
                readonly property bool selected: OptionData.valuesEqual(root.optionValue(optionData), root.value)
                readonly property bool hasSwatch: root.optionColor(optionData) !== "transparent"
                readonly property string iconName: root.optionIcon(optionData)

                width: optionSurface.implicitWidth
                height: optionSurface.implicitHeight
                implicitWidth: width
                implicitHeight: height

                AppSurface {
                    id: optionSurface
                    anchors.fill: parent

                    theme: root.resolvedTheme
                    surfaceTone: optionItem.selected ? "highlight" : root.resolvedSurfaceTone
                    shapeRole: AppUiEnums.ShapeRole.Pill
                    active: optionItem.selected
                    hoveredState: optionTap.hovered
                    interactive: root.enabled
                    strokeWidth: optionItem.selected ? 0 : 1
                    padding: 10
                    fillOverride: optionItem.selected
                        ? root.colorValue("highlightSoft", "#182b45")
                        : root.colorValue("section", "#1e2631")
                    borderOverride: optionItem.selected
                        ? root.colorValue("highlightText", "#7cb4ff")
                        : root.colorValue("border", "#334155")

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
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.18)
                        }

                        AppIcon {
                            visible: !optionItem.hasSwatch && optionItem.iconName.length > 0
                            anchors.verticalCenter: parent.verticalCenter
                            theme: root.resolvedTheme
                            name: optionItem.iconName
                            size: 14
                            color: optionItem.selected
                                ? root.colorValue("highlightText", "#7cb4ff")
                                : root.colorValue("text", "#e6edf3")
                        }

                        AppText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.optionLabel(optionItem.optionData)
                            theme: root.resolvedTheme
                            styleRole: "bodyS"
                            textTone: optionItem.selected ? "accent" : "primary"
                        }
                    }
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

    resources: [
        HoverHandler {
            id: choiceHover
            enabled: root.enabled
        }
    ]
}
