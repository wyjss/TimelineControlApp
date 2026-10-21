import QtQuick 2.14
import QtQuick.Dialogs 1.3
import UICore.Style 1.0
import "internal" as Internal

Internal.AppControlBase {
    id: root

    surfaceTone: UiStyle.SurfaceTone.Control

    property var value: ""
    property string placeholderText: "#A8C7FA"
    property bool showAlphaChannel: true
    property int appearance: UiStyle.ControlAppearance.Filled

    readonly property color fallbackDialogColor: Qt.rgba(0.66, 0.78, 0.98, 1.0)
    readonly property var currentColorValue: parsedColor(colorInput.text)
    readonly property bool interactionHovered: colorInput.interactionHovered
        || colorSwatchTap.hovered
    readonly property bool interactionActive: colorInput.interactionActive
        || (colorDialogLoader.item && colorDialogLoader.item.visible)
    property color dialogColorValue: fallbackDialogColor

    signal valueEdited(var nextValue)

    function parsedColor(rawValue) {
        if (rawValue === undefined || rawValue === null)
            return null

        if (rawValue.r !== undefined && rawValue.g !== undefined && rawValue.b !== undefined) {
            return Qt.rgba(rawValue.r,
                           rawValue.g,
                           rawValue.b,
                           rawValue.a !== undefined ? rawValue.a : 1.0)
        }

        var textValue = rawValue.toString ? rawValue.toString() : String(rawValue)
        var trimmed = textValue.trim().toUpperCase()
        var hex = trimmed.charAt(0) === "#" ? trimmed.slice(1) : trimmed

        if (!hex.length)
            return null

        if (!/^[0-9A-F]+$/.test(hex))
            return null

        if (hex.length === 6) {
            return Qt.rgba(parseInt(hex.slice(0, 2), 16) / 255,
                           parseInt(hex.slice(2, 4), 16) / 255,
                           parseInt(hex.slice(4, 6), 16) / 255,
                           1.0)
        }

        if (hex.length === 8) {
            return Qt.rgba(parseInt(hex.slice(2, 4), 16) / 255,
                           parseInt(hex.slice(4, 6), 16) / 255,
                           parseInt(hex.slice(6, 8), 16) / 255,
                           parseInt(hex.slice(0, 2), 16) / 255)
        }

        return null
    }

    function hexChannel(channelValue) {
        var scaled = Math.round(Math.max(0, Math.min(1, channelValue)) * 255)
        var text = scaled.toString(16).toUpperCase()
        return text.length < 2 ? "0" + text : text
    }

    function colorString(colorValue) {
        if (colorValue === null)
            return ""

        var alpha = hexChannel(colorValue.a)
        var red = hexChannel(colorValue.r)
        var green = hexChannel(colorValue.g)
        var blue = hexChannel(colorValue.b)

        if (alpha === "FF")
            return "#" + red + green + blue

        return "#" + alpha + red + green + blue
    }

    function resolvedText(rawValue) {
        var parsed = parsedColor(rawValue)
        if (parsed !== null)
            return colorString(parsed)

        return rawValue === undefined || rawValue === null ? "" : String(rawValue)
    }

    function commitText(rawValue) {
        var parsed = parsedColor(rawValue)
        if (parsed === null)
            return false

        var nextValue = colorString(parsed)
        valueEdited(nextValue)
        syncFieldText(true)
        return true
    }

    function syncFieldText(force) {
        var nextText = resolvedText(value)
        if (force || !colorInput.activeFocus)
            colorInput.text = nextText
    }

    function syncDialogColor(rawValue) {
        var parsed = parsedColor(rawValue)
        dialogColorValue = parsed === null
            ? fallbackDialogColor
            : Qt.rgba(parsed.r,
                      parsed.g,
                      parsed.b,
                      parsed.a !== undefined ? parsed.a : 1.0)
    }

    Component.onCompleted: syncFieldText(true)

    onValueChanged: {
        syncFieldText(true)
        syncDialogColor(value)
    }

    padding: 0
    background: null
    implicitWidth: 220
    implicitHeight: colorInput.implicitHeight

    contentItem: Item {
        implicitWidth: root.availableWidth > 0 ? root.availableWidth : root.implicitWidth
        implicitHeight: colorInput.implicitHeight

        AppTextField {
            id: colorInput

            anchors.left: parent.left
            anchors.right: parent.right
            text: root.resolvedText(root.value)
            surfaceTone: root.surfaceTone
            appearance: root.appearance
            enabled: root.enabled
            animateTextColor: false
            color: !root.enabled
                ? root.colorValue("disabledText")
                : root.currentColorValue !== null
                ? root.currentColorValue
                : root.colorValue("text")
            placeholderText: root.placeholderText
            trailingInset: 26
            onEditingFinished: {
                if (!root.commitText(text))
                    root.syncFieldText(true)
            }
        }

        Loader {
            id: colorDialogLoader

            active: false
            sourceComponent: colorDialogComponent
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: colorInput.verticalCenter
            width: 18
            height: 18
            radius: 9
            color: root.currentColorValue !== null ? root.currentColorValue : "transparent"
            border.width: 1
            border.color: root.currentColorValue !== null
                ? Qt.rgba(1, 1, 1, 0.18)
                : root.colorValue("border")
            opacity: root.enabled ? 1 : 0.56

            Rectangle {
                anchors.centerIn: parent
                width: 10
                height: 1
                rotation: 45
                color: root.colorValue("subtleText")
                visible: root.currentColorValue === null
            }

            Internal.AppTapRegion {
                id: colorSwatchTap

                anchors.fill: parent
                enabled: root.enabled
                onTapped: {
                    root.syncDialogColor(colorInput.text)
                    colorDialogLoader.active = true
                    colorDialogLoader.item.color = root.dialogColorValue
                    colorDialogLoader.item.currentColor = root.dialogColorValue
                    colorDialogLoader.item.open()
                }
            }
        }
    }

    resources: Component {
        id: colorDialogComponent

        ColorDialog {
            title: qsTr("选择颜色")
            color: root.dialogColorValue
            currentColor: root.dialogColorValue
            showAlphaChannel: root.showAlphaChannel
            onVisibleChanged: {
                if (visible) {
                    color = root.dialogColorValue
                    currentColor = root.dialogColorValue
                } else {
                    var closingDialog = colorDialogLoader.item
                    Qt.callLater(function() {
                        if (closingDialog
                                && colorDialogLoader.item === closingDialog
                                && !closingDialog.visible)
                            colorDialogLoader.active = false
                    })
                }
            }
            onAccepted: root.commitText(color)
        }
    }
}
