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

    readonly property int controlHeight: densityValue("controlHeightMd", 36)
    readonly property int trackInset: 4
    readonly property int segmentGap: 4
    readonly property int segmentPaddingX: densityValue("controlPaddingXMd", 12)
    readonly property int optionCount: root.options && root.options.length !== undefined ? root.options.length : 0
    readonly property int currentIndex: indexOfValue(root.value)
    readonly property real segmentWidth: optionCount > 0
        ? Math.max(0, (segmentRow.width - segmentGap * (optionCount - 1)) / optionCount)
        : 0
    readonly property bool interactionHovered: segmentedHover.hovered
    readonly property bool interactionActive: false

    signal valueSelected(var nextValue)

    function optionLabel(optionData) {
        return OptionData.optionLabel(optionData, textRole)
    }

    function optionValue(optionData) {
        return OptionData.optionValue(optionData, valueRole)
    }

    function indexOfValue(targetValue) {
        return OptionData.indexOfValue(root.options, targetValue, valueRole)
    }

    function textColor(selected, hovered) {
        if (selected)
            return colorValue("inverseText", "#f8fafc")

        if (hovered)
            return colorValue("text", "#e6edf3")

        return colorValue("subtleText", "#97a3b6")
    }

    function textWeight(selected) {
        if (selected)
            return root.resolvedTheme && root.resolvedTheme.typography
                ? root.resolvedTheme.typography.weightBold
                : Font.Bold

        return root.resolvedTheme && root.resolvedTheme.typography
            ? root.resolvedTheme.typography.weightStrong
            : Font.DemiBold
    }

    function commitOption(optionData) {
        var nextValue = optionValue(optionData)
        value = nextValue
        valueSelected(nextValue)
    }

    padding: 0
    background: null
    implicitWidth: 220
    implicitHeight: root.controlHeight
    opacity: enabled ? 1 : 0.68

    contentItem: AppSurface {
        id: segmentedTrack

        width: root.availableWidth > 0 ? root.availableWidth : root.implicitWidth
        height: root.controlHeight
        theme: root.resolvedTheme
        surfaceTone: root.resolvedSurfaceTone
        shapeRole: AppUiEnums.ShapeRole.Pill
        sizeToContent: false
        constrainContentWidth: true
        constrainContentHeight: true
        clipContent: true
        padding: root.trackInset
        strokeWidth: 1
        hoverOverlayOpacity: 0
        activeOverlayOpacity: 0

        AppSurface {
            id: selectionIndicator

            x: root.currentIndex >= 0 ? root.currentIndex * (root.segmentWidth + root.segmentGap) : 0
            y: 0
            width: root.currentIndex >= 0 ? root.segmentWidth : 0
            height: segmentRow.height
            visible: root.currentIndex >= 0 && root.optionCount > 0
            theme: root.resolvedTheme
            shapeRole: AppUiEnums.ShapeRole.Pill
            sizeToContent: false
            constrainContentWidth: true
            constrainContentHeight: true
            fillOverride: root.colorValue("highlightFill", "#2563eb")
            borderOverride: "transparent"
            strokeWidth: 0
            hoverOverlayOpacity: 0
            activeOverlayOpacity: 0

            Behavior on x {
                NumberAnimation {
                    duration: root.resolvedTheme ? root.resolvedTheme.motion.durationStandard : 180
                    easing.type: root.resolvedTheme ? root.resolvedTheme.motion.easingEmphasized : Easing.OutQuint
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: root.resolvedTheme ? root.resolvedTheme.motion.durationStandard : 180
                    easing.type: root.resolvedTheme ? root.resolvedTheme.motion.easingEmphasized : Easing.OutQuint
                }
            }
        }

        Row {
            id: segmentRow

            z: 1
            width: segmentedTrack.availableContentWidth
            height: segmentedTrack.availableContentHeight
            spacing: root.segmentGap

            Repeater {
                model: root.options

                delegate: Item {
                    id: segmentItem

                    readonly property var optionData: modelData
                    readonly property bool selected: OptionData.valuesEqual(root.optionValue(optionData), root.value)

                    width: root.segmentWidth
                    height: segmentRow.height

                    Rectangle {
                        anchors.fill: parent
                        radius: height * 0.5
                        color: root.colorValue("highlightSoft", "#182b45")
                        opacity: !segmentItem.selected && segmentTap.hovered ? 0.34 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.resolvedTheme ? root.resolvedTheme.motion.durationFast : 100
                                easing.type: root.resolvedTheme ? root.resolvedTheme.motion.easingStandard : Easing.OutCubic
                            }
                        }
                    }

                    AppText {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: root.segmentPaddingX
                        anchors.rightMargin: root.segmentPaddingX
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: root.optionLabel(segmentItem.optionData)
                        theme: root.resolvedTheme
                        styleRole: "bodyS"
                        overrideWeight: root.textWeight(segmentItem.selected)
                        colorOverride: root.textColor(segmentItem.selected, segmentTap.hovered)
                    }

                    Internal.AppTapRegion {
                        id: segmentTap

                        anchors.fill: parent
                        enabled: root.enabled
                        onTapped: root.commitOption(segmentItem.optionData)
                    }
                }
            }
        }
    }

    resources: [
        HoverHandler {
            id: segmentedHover
            enabled: root.enabled
        }
    ]
}
