import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtQml 2.14
import UICore.Style 1.0
import "internal" as Internal

Internal.AppControlBase {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property string suffix: ""
    property bool showValueLabel: true

    readonly property bool interactionHovered: sliderControl.hovered
    readonly property bool interactionActive: sliderControl.pressed || sliderControl.visualFocus

    signal valueEdited(var nextValue)

    function displayText(rawValue) {
        var digits = stepSize > 0 && stepSize < 1 ? 2 : 0
        return Number(rawValue).toFixed(digits) + suffix
    }

    padding: 0
    background: null
    implicitWidth: 220
    implicitHeight: controlRow.implicitHeight

    contentItem: RowLayout {
        id: controlRow

        spacing: root.densityValue("controlGap")

        Slider {
            id: sliderControl

            Layout.fillWidth: true
            enabled: root.enabled
            from: root.from
            to: root.to
            stepSize: root.stepSize > 0 ? root.stepSize : 1
            focusPolicy: Qt.StrongFocus
            hoverEnabled: root.enabled
            leftPadding: 0
            rightPadding: 0
            onMoved: root.valueEdited(value)

            Binding on value {
                when: !sliderControl.pressed
                value: root.value
                restoreMode: Binding.RestoreBinding
            }

            background: Item {
                implicitHeight: 18

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    radius: 2
                    color: root.enabled
                        ? root.colorValue("border")
                        : root.colorValue("disabledBorder")
                    opacity: sliderControl.pressed
                        ? 1
                        : (root.interactionHovered ? 0.9 : 0.72)

                    Behavior on color {
                        enabled: root.animated

                        ColorAnimation {
                            duration: root.transitionDuration
                            easing.type: root.transitionEasing
                        }
                    }

                    Behavior on opacity {
                        enabled: root.animated

                        NumberAnimation {
                            duration: root.resolvedTheme.motion.durationFast
                            easing.type: root.resolvedTheme.motion.easingStandard
                        }
                    }
                }

                Rectangle {
                    width: sliderControl.visualPosition * parent.width
                    height: 4
                    radius: 2
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.enabled
                        ? root.colorValue("highlightFill")
                        : root.colorValue("disabledText")

                    Behavior on color {
                        enabled: root.animated

                        ColorAnimation {
                            duration: root.transitionDuration
                            easing.type: root.transitionEasing
                        }
                    }
                }
            }

            handle: Rectangle {
                objectName: "sliderHandle"
                x: sliderControl.leftPadding + sliderControl.visualPosition * (sliderControl.availableWidth - width)
                y: sliderControl.topPadding + sliderControl.availableHeight / 2 - height / 2
                width: 16
                height: 16
                radius: 8
                color: root.enabled
                    ? root.colorValue("inverseText")
                    : root.colorValue("disabledText")
                border.width: sliderControl.pressed || sliderControl.visualFocus ? 3 : 2
                border.color: !root.enabled
                    ? root.colorValue("disabledBorder")
                    : (sliderControl.pressed || sliderControl.visualFocus || root.interactionHovered
                        ? root.colorValue("highlightText")
                        : root.colorValue("highlightFill"))
                scale: sliderControl.pressed
                    ? 1.14
                    : (root.interactionHovered ? 1.08 : 1)

                Behavior on color {
                    enabled: root.animated

                    ColorAnimation {
                        duration: root.transitionDuration
                        easing.type: root.transitionEasing
                    }
                }

                Behavior on border.color {
                    enabled: root.animated

                    ColorAnimation {
                        duration: root.transitionDuration
                        easing.type: root.transitionEasing
                    }
                }

                Behavior on scale {
                    enabled: root.animated

                    NumberAnimation {
                        duration: root.resolvedTheme.motion.durationFast
                        easing.type: root.resolvedTheme.motion.easingStandard
                    }
                }
            }
        }

        TextMetrics {
            id: fromValueMetrics

            font: valueLabel.font
            text: root.displayText(root.from)
        }

        TextMetrics {
            id: toValueMetrics

            font: valueLabel.font
            text: root.displayText(root.to)
        }

        AppText {
            id: valueLabel

            objectName: "sliderValueLabel"
            visible: root.showValueLabel
            Layout.preferredWidth: Math.max(fromValueMetrics.advanceWidth, toValueMetrics.advanceWidth)
            text: root.displayText(root.value)
            styleRole: UiStyle.TypographyRole.BodyM
            textTone: UiStyle.TextTone.Accent
            animateColor: root.animated
            colorOverride: root.enabled
                ? undefined
                : root.colorValue("disabledText")
            horizontalAlignment: Text.AlignRight
        }
    }
}
