import QtQuick 2.14
import UICore.Style 1.0

AppTextField {
    id: root

    property real value: 0
    property bool integerMode: false
    property real minimum: 0
    property real maximum: 100
    property int decimals: 2
    property string suffix: ""

    readonly property int resolvedDecimals: Math.max(0, Math.min(15, decimals))

    signal valueEdited(var nextValue)

    function boundedValue(rawValue) {
        var nextValue = Math.min(maximum, Math.max(minimum, Number(rawValue)))
        if (integerMode)
            return Math.round(nextValue)
        return Number(nextValue.toFixed(resolvedDecimals))
    }

    function syncText(force) {
        if (force || !activeFocus) {
            text = String(boundedValue(value))
            cursorPosition = length
        }
    }

    function commitText() {
        var sourceText = text.trim()
        if (sourceText.length === 0 || !isFinite(Number(sourceText))) {
            syncText(true)
            return false
        }

        var nextValue = boundedValue(sourceText)
        text = String(nextValue)
        cursorPosition = length
        if (nextValue !== value)
            valueEdited(nextValue)
        return true
    }

    validator: integerMode ? integerValidator : doubleValidator
    inputMethodHints: Qt.ImhFormattedNumbersOnly

    trailingContent: [
        AppText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.suffix
            visible: text.length > 0
            width: visible ? implicitWidth : 0
            styleRole: UiStyle.TypographyRole.BodyM
            colorOverride: root.enabled
                ? root.colorValue("subtleText")
                : root.colorValue("disabledText")
        }
    ]

    onEditingFinished: commitText()
    onPopupVisibleChanged: {
        if (!popupVisible && activeFocus)
            commitText()
    }
    onValueChanged: syncText()
    onIntegerModeChanged: syncText()
    onMinimumChanged: syncText()
    onMaximumChanged: syncText()
    onDecimalsChanged: syncText()
    Component.onCompleted: syncText()

    resources: [
        IntValidator {
            id: integerValidator

            bottom: root.minimum
            top: root.maximum
        },

        DoubleValidator {
            id: doubleValidator

            bottom: root.minimum
            top: root.maximum
            decimals: root.resolvedDecimals
            notation: DoubleValidator.StandardNotation
            locale: "C"
        }
    ]
}
