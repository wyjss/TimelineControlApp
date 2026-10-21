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

    readonly property int controlHeight: densityValue("controlHeightMd")
    readonly property int trackInset: 4
    readonly property int segmentGap: 4
    readonly property int segmentPaddingX: densityValue("controlPaddingXMd")
    readonly property int optionCount: root.options && root.options.length !== undefined ? root.options.length : 0
    readonly property int currentIndex: indexOfValue(root.value)
    readonly property real segmentWidth: optionCount > 0
        ? Math.max(0, (segmentRow.width - segmentGap * (optionCount - 1)) / optionCount)
        : 0
    readonly property bool interactionHovered: segmentedHover.hovered
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

    function indexOfValue(targetValue) {
        return OptionData.indexOfValue(root.options, targetValue, valueRole)
    }

    function textColor(selected, hovered) {
        if (!enabled)
            return colorValue("disabledText")

        if (selected)
            return colorValue("inverseText")

        if (hovered)
            return colorValue("text")

        return colorValue("subtleText")
    }

    function textWeight(selected) {
        if (selected)
            return root.resolvedTheme.typography.weightBold

        return root.resolvedTheme.typography.weightStrong
    }

    function commitOption(optionData) {
        var nextValue = optionValue(optionData)
        valueSelected(nextValue)
    }

    padding: 0
    background: null
    implicitWidth: 220
    implicitHeight: root.controlHeight
    focusPolicy: Qt.StrongFocus

    Keys.onPressed: {
        if (root.optionCount <= 0)
            return

        var nextIndex = root.currentIndex >= 0 ? root.currentIndex : 0
        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_Up:
            nextIndex = Math.max(0, nextIndex - 1)
            break
        case Qt.Key_Right:
        case Qt.Key_Down:
            nextIndex = Math.min(root.optionCount - 1, nextIndex + 1)
            break
        case Qt.Key_Home:
            nextIndex = 0
            break
        case Qt.Key_End:
            nextIndex = root.optionCount - 1
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

    contentItem: AppSurface {
        id: segmentedTrack

        animated: root.animated
        width: root.availableWidth > 0 ? root.availableWidth : root.implicitWidth
        height: root.controlHeight
        surfaceTone: root.surfaceTone
        shapeRole: UiStyle.ShapeRole.Pill
        sizeToContent: false
        constrainContentWidth: true
        constrainContentHeight: true
        clipContent: true
        padding: root.trackInset
        strokeWidth: root.visualFocus ? 2 : 1
        fillOverride: root.enabled ? undefined : root.colorValue("disabledFill")
        borderOverride: root.visualFocus
            ? root.colorValue("highlightText")
            : (root.enabled
                ? root.colorValue("controlBorder")
                : root.colorValue("disabledBorder"))
        hoverOverlayOpacity: 0
        activeOverlayOpacity: 0

        AppSurface {
            id: selectionIndicator

            objectName: "segmentedSelectionIndicator"
            x: root.currentIndex >= 0 ? root.currentIndex * (root.segmentWidth + root.segmentGap) : 0
            y: 0
            width: root.currentIndex >= 0 ? root.segmentWidth : 0
            height: segmentRow.height
            visible: root.currentIndex >= 0 && root.optionCount > 0
            shapeRole: UiStyle.ShapeRole.Pill
            sizeToContent: false
            constrainContentWidth: true
            constrainContentHeight: true
            fillOverride: root.enabled
                ? root.colorValue("highlightFill")
                : root.colorValue("disabledBorder")
            borderOverride: "transparent"
            strokeWidth: 0
            hoverOverlayOpacity: 0
            activeOverlayOpacity: 0
            animated: root.animated

            Behavior on x {
                enabled: root.animated

                NumberAnimation {
                    duration: root.resolvedTheme.motion.durationStandard
                    easing.type: root.resolvedTheme.motion.easingEmphasized
                }
            }

            Behavior on width {
                enabled: root.animated

                NumberAnimation {
                    duration: root.resolvedTheme.motion.durationStandard
                    easing.type: root.resolvedTheme.motion.easingEmphasized
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

                    Accessible.role: Accessible.RadioButton
                    Accessible.name: root.optionLabel(optionData)
                    Accessible.checkable: true
                    Accessible.checked: selected
                    Accessible.onPressAction: {
                        if (root.enabled)
                            root.commitOption(optionData)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: height * 0.5
                        color: root.colorValue("highlightSoft")
                        opacity: !segmentItem.selected && segmentTap.hovered ? 0.34 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            enabled: root.animated

                            NumberAnimation {
                                duration: root.resolvedTheme.motion.durationFast
                                easing.type: root.resolvedTheme.motion.easingStandard
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
                        styleRole: UiStyle.TypographyRole.BodyS
                        animateColor: root.animated
                        overrideWeight: root.textWeight(segmentItem.selected)
                        colorOverride: root.textColor(segmentItem.selected, segmentTap.hovered)
                    }

                    Internal.AppTapRegion {
                        id: segmentTap

                        anchors.fill: parent
                        enabled: root.enabled
                        focusTarget: root
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
