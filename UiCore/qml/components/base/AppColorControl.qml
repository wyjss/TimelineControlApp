import QtQuick 2.14
import QtQuick.Dialogs 1.3
import "internal" as Internal

Internal.AppControlBase {
    id: root

    property var value: ""
    property string placeholderText: "#A8C7FA"
    property bool showAlphaChannel: true

    readonly property color fallbackDialogColor: Qt.rgba(0.66, 0.78, 0.98, 1.0)
    readonly property var currentColorValue: parsedColor(colorInput.text)
    readonly property bool interactionHovered: colorInput.interactionHovered
        || colorSwatchTap.hovered
    readonly property bool interactionActive: colorInput.interactionActive
        || colorDialog.visible
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

    function normalizedDialogColor(rawValue) {
        var parsed = parsedColor(rawValue)
        if (parsed === null)
            return fallbackDialogColor

        return Qt.rgba(parsed.r,
                       parsed.g,
                       parsed.b,
                       parsed.a !== undefined ? parsed.a : 1.0)
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
        value = nextValue
        valueEdited(nextValue)
        return true
    }

    function syncFieldText(force) {
        var nextText = resolvedText(value)
        if (force || !colorInput.activeFocus)
            colorInput.text = nextText
    }

    function syncDialogColor(rawValue) {
        dialogColorValue = normalizedDialogColor(rawValue)
    }

    Component.onCompleted: syncFieldText(true)

    onValueChanged: {
        syncFieldText(false)
        syncDialogColor(value)
    }

    padding: 0
    background: null
    implicitWidth: 220
    implicitHeight: colorInput.implicitHeight
    opacity: enabled ? 1 : 0.68

    contentItem: Item {
        implicitWidth: root.availableWidth > 0 ? root.availableWidth : root.implicitWidth
        implicitHeight: colorInput.implicitHeight

        AppTextField {
            id: colorInput

            anchors.left: parent.left
            anchors.right: parent.right
            text: root.resolvedText(root.value)
            theme: root.resolvedTheme
            surfaceTone: root.resolvedSurfaceTone
            enabled: root.enabled
            color: root.currentColorValue !== null
                ? root.currentColorValue
                : root.colorValue("text", "#e6edf3")
            placeholderText: root.placeholderText
            trailingInset: 26
            onEditingFinished: {
                if (!root.commitText(text))
                    root.syncFieldText(true)
            }
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
                : root.colorValue("border", "#334155")

            Rectangle {
                anchors.centerIn: parent
                width: 10
                height: 1
                rotation: 45
                color: root.colorValue("subtleText", "#97a3b6")
                visible: root.currentColorValue === null
            }

            Internal.AppTapRegion {
                id: colorSwatchTap

                anchors.fill: parent
                enabled: root.enabled
                onTapped: {
                    root.syncDialogColor(colorInput.text)
                    colorDialog.color = root.dialogColorValue
                    colorDialog.currentColor = root.dialogColorValue
                    colorDialog.open()
                }
            }
        }
    }

    resources: ColorDialog {
        id: colorDialog
        title: qsTr("选择颜色")
        color: root.dialogColorValue
        currentColor: root.dialogColorValue
        showAlphaChannel: root.showAlphaChannel
        onVisibleChanged: {
            if (visible) {
                color = root.dialogColorValue
                currentColor = root.dialogColorValue
            }
        }
        onAccepted: root.commitText(color)
    }
}
