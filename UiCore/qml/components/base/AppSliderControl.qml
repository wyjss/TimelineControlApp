import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "internal" as Internal

Internal.AppControlBase {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property string suffix: ""
    property bool showValueLabel: true

    readonly property bool interactionHovered: sliderHover.hovered
    readonly property bool interactionActive: sliderControl.pressed

    signal valueEdited(var nextValue)

    function snap(rawValue) {
        var step = stepSize > 0 ? stepSize : 1
        return Math.round(rawValue / step) * step
    }

    function displayText(rawValue) {
        var digits = stepSize > 0 && stepSize < 1 ? 2 : 0
        return Number(rawValue).toFixed(digits) + suffix
    }

    function shouldSyncSlider(currentValue, nextValue) {
        return Math.abs(Number(currentValue) - Number(nextValue)) > 0.000001
    }

    function syncSliderValue() {
        if (sliderControl.pressed)
            return

        if (shouldSyncSlider(sliderControl.value, root.value))
            sliderControl.value = root.value
    }

    padding: 0
    background: null
    implicitWidth: 220
    implicitHeight: controlRow.implicitHeight
    opacity: enabled ? 1 : 0.68

    contentItem: RowLayout {
        id: controlRow

        spacing: root.densityValue("controlGap", 8)

        Slider {
            id: sliderControl

            Layout.fillWidth: true
            enabled: root.enabled
            from: root.from
            to: root.to
            stepSize: root.stepSize > 0 ? root.stepSize : 1
            Component.onCompleted: root.syncSliderValue()
            onPressedChanged: root.syncSliderValue()
            onMoved: root.valueEdited(root.snap(value))

            background: Item {
                implicitHeight: 18

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    radius: 2
                    color: root.colorValue("border", "#334155")
                    opacity: 0.72
                }

                Rectangle {
                    width: sliderControl.visualPosition * parent.width
                    height: 4
                    radius: 2
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.colorValue("highlightFill", "#2563eb")
                }
            }

            handle: Rectangle {
                x: sliderControl.leftPadding + sliderControl.visualPosition * (sliderControl.availableWidth - width)
                y: sliderControl.topPadding + sliderControl.availableHeight / 2 - height / 2
                width: 16
                height: 16
                radius: 8
                color: root.colorValue("inverseText", "#f8fafc")
                border.width: 2
                border.color: root.colorValue("highlightFill", "#2563eb")
                scale: sliderControl.pressed ? 1.06 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: root.resolvedTheme ? root.resolvedTheme.motion.durationFast : 120
                        easing.type: root.resolvedTheme ? root.resolvedTheme.motion.easingStandard : Easing.OutCubic
                    }
                }
            }
        }

        AppText {
            visible: root.showValueLabel
            text: root.displayText(root.value)
            theme: root.resolvedTheme
            styleRole: "bodyM"
            textTone: "accent"
        }

        Connections {
            target: root

            function onValueChanged() {
                root.syncSliderValue()
            }
        }
    }

    resources: [
        HoverHandler {
            id: sliderHover
            enabled: root.enabled
        }
    ]
}
