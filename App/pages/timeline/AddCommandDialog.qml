import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UiCore/qml/components/base" as Base

Base.AppPopup {
    id: root

    property QtObject theme
    property string selectedProtocol: "serial"
    property int startTimeMs: 0
    property var fieldValues: ({})
    readonly property var protocolOptions: [
        { "label": qsTr("Serial"), "value": "serial" },
        { "label": qsTr("DMX512"), "value": "dmx512" },
        { "label": qsTr("HTTP"), "value": "http" },
        { "label": qsTr("PC"), "value": "pc" }
    ]
    readonly property var fieldSpecs: fieldsForProtocol(selectedProtocol)
    readonly property bool commandValid: isCommandValid()

    signal commandAccepted(var command)

    function openForTime(timeMs) {
        startTimeMs = Math.max(0, Math.round(timeMs))
        resetValues()
        open()
    }

    function fieldsForProtocol(protocol) {
        var commonFields = [
            { "key": "name", "label": qsTr("Name"), "type": "string", "editor": "text", "required": true, "defaultValue": defaultNameForProtocol(protocol) },
            { "key": "durationMs", "label": qsTr("Duration"), "type": "int", "editor": "text", "defaultValue": 0, "minimum": 0, "maximum": 3600000, "suffix": "ms" }
        ]

        switch (String(protocol)) {
        case "dmx512":
            return commonFields.concat([
                { "key": "channel", "label": qsTr("Channel"), "type": "int", "editor": "text", "required": true, "defaultValue": 1, "minimum": 1, "maximum": 512 },
                { "key": "value", "label": qsTr("Value"), "type": "int", "editor": "slider", "required": true, "defaultValue": 255, "minimum": 0, "maximum": 255, "stepSize": 1 }
            ])
        case "http":
            return commonFields.concat([
                { "key": "address", "label": qsTr("Address"), "type": "string", "editor": "text", "required": true, "defaultValue": "", "placeholder": "http://192.168.1.10:8080", "pattern": "^(http://)?((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(:[0-9]{1,5})?$" },
                { "key": "method", "label": qsTr("Method"), "type": "enum", "editor": "select", "required": true, "defaultValue": "POST", "options": [
                    { "label": "GET", "value": "GET" },
                    { "label": "POST", "value": "POST" },
                    { "label": "PUT", "value": "PUT" },
                    { "label": "PATCH", "value": "PATCH" },
                    { "label": "DELETE", "value": "DELETE" }
                ] },
                { "key": "path", "label": qsTr("Path"), "type": "string", "editor": "text", "required": true, "defaultValue": "/api/command", "placeholder": "/api/command", "pattern": "^/.*" },
                { "key": "body", "label": qsTr("Body"), "type": "string", "editor": "textarea", "defaultValue": "{ \"enabled\": true }" }
            ])
        case "pc":
            return commonFields.concat([
                { "key": "path", "label": qsTr("Path"), "type": "string", "editor": "text", "required": true, "defaultValue": "/api/command", "placeholder": "/api/command", "pattern": "^/.*" }
            ])
        case "serial":
        default:
            return commonFields.concat([
                { "key": "hex", "label": qsTr("Hex"), "type": "bool", "editor": "toggle", "defaultValue": true, "trueLabel": "HEX", "falseLabel": qsTr("Text") },
                { "key": "payload", "label": qsTr("Payload"), "type": "string", "editor": "textarea", "required": true, "defaultValue": "", "placeholder": "A5 5A 01 00" }
            ])
        }
    }

    function defaultNameForProtocol(protocol) {
        switch (String(protocol)) {
        case "dmx512":
            return qsTr("DMX Cue")
        case "http":
            return qsTr("HTTP Cue")
        case "pc":
            return qsTr("PC Cue")
        case "serial":
        default:
            return qsTr("Serial Cue")
        }
    }

    function resetValues() {
        var nextValues = {}
        for (var index = 0; index < fieldSpecs.length; ++index) {
            var spec = fieldSpecs[index]
            nextValues[spec.key] = spec.defaultValue !== undefined ? spec.defaultValue : ""
        }
        fieldValues = nextValues
    }

    function protocolLabel(protocol) {
        for (var index = 0; index < protocolOptions.length; ++index) {
            if (protocolOptions[index].value === protocol)
                return protocolOptions[index].label
        }
        return String(protocol)
    }

    function fieldValue(key, fallback) {
        if (fieldValues && fieldValues[key] !== undefined && fieldValues[key] !== null)
            return fieldValues[key]
        return fallback !== undefined ? fallback : ""
    }

    function setFieldValue(key, value) {
        var nextValues = {}
        for (var name in fieldValues)
            nextValues[name] = fieldValues[name]
        nextValues[key] = value
        fieldValues = nextValues
    }

    function normalizedValue(spec, rawValue) {
        if (spec.type === "int")
            return Math.round(Number(rawValue))
        if (spec.type === "double")
            return Number(rawValue)
        if (spec.type === "bool")
            return !!rawValue
        return rawValue
    }

    function formatValue(spec, rawValue) {
        var text = String(rawValue)
        if (spec.suffix !== undefined && spec.suffix !== "")
            text += spec.suffix
        return text
    }

    function hexPayloadPattern() {
        return /^([0-9A-Fa-f]{2})(\s+[0-9A-Fa-f]{2})*$/
    }

    function isBlank(value) {
        return value === undefined || value === null || String(value).trim().length === 0
    }

    function fieldInvalidReason(spec) {
        var value = fieldValue(spec.key, spec.defaultValue)
        if (spec.required && isBlank(value))
            return qsTr("%1 is required").arg(spec.label)

        if (isBlank(value))
            return ""

        if (selectedProtocol === "serial" && spec.key === "payload" && !!fieldValue("hex", true)) {
            if (!hexPayloadPattern().test(String(value).trim()))
                return qsTr("%1 must be hex bytes").arg(spec.label)
        }

        if (spec.pattern !== undefined && spec.pattern !== "") {
            var pattern = new RegExp(spec.pattern)
            if (!pattern.test(String(value)))
                return qsTr("%1 has an invalid format").arg(spec.label)
        }

        if (spec.type === "int" || spec.type === "double") {
            var numberValue = Number(value)
            if (isNaN(numberValue))
                return qsTr("%1 must be numeric").arg(spec.label)

            if (spec.minimum !== undefined && numberValue < Number(spec.minimum))
                return qsTr("%1 is below minimum").arg(spec.label)

            if (spec.maximum !== undefined && numberValue > Number(spec.maximum))
                return qsTr("%1 is above maximum").arg(spec.label)
        }

        return ""
    }

    function isCommandValid() {
        for (var index = 0; index < fieldSpecs.length; ++index) {
            if (fieldInvalidReason(fieldSpecs[index]).length > 0)
                return false
        }
        return true
    }

    function firstInvalidReason() {
        for (var index = 0; index < fieldSpecs.length; ++index) {
            var reason = fieldInvalidReason(fieldSpecs[index])
            if (reason.length > 0)
                return reason
        }
        return ""
    }

    function buildCommand() {
        var params = {}
        var name = ""
        var durationMs = 0

        for (var index = 0; index < fieldSpecs.length; ++index) {
            var spec = fieldSpecs[index]
            var value = normalizedValue(spec, fieldValue(spec.key, spec.defaultValue))
            if (spec.key === "name")
                name = String(value)
            else if (spec.key === "durationMs")
                durationMs = value
            else
                params[spec.key] = value
        }

        return {
            "protocol": selectedProtocol,
            "name": name,
            "startTimeMs": startTimeMs,
            "durationMs": durationMs,
            "params": params
        }
    }

    function commit() {
        if (!commandValid)
            return

        commandAccepted(buildCommand())
        close()
    }

    modal: true
    focus: true
    width: Math.min(720, Math.max(520, parent ? parent.width - 96 : 640))
    height: Math.min(720, Math.max(520, parent ? parent.height - 96 : 620))
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0
    padding: 18
    spacing: 14
    theme: root.theme
    surfaceTone: "section"
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    onSelectedProtocolChanged: resetValues()
    Component.onCompleted: resetValues()

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("Add Command")
                theme: root.theme
                styleRole: "titleM"
            }

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("Create a protocol command at the current timeline position.")
                theme: root.theme
                styleRole: "bodyS"
                textTone: "secondary"
                elide: Text.ElideRight
            }
        }

        Base.AppButton {
            text: qsTr("Cancel")
            theme: root.theme
            onClicked: root.close()
        }

        Base.AppButton {
            text: qsTr("Add")
            theme: root.theme
            enabled: root.commandValid
            iconName: "workflow"
            onClicked: root.commit()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Base.AppText {
            text: qsTr("Protocol")
            theme: root.theme
            styleRole: "bodyS"
            textTone: "secondary"
        }

        Base.AppSelect {
            Layout.preferredWidth: 220
            theme: root.theme
            options: root.protocolOptions
            value: root.selectedProtocol
            onValueSelected: root.selectedProtocol = String(nextValue)
        }

        Item {
            Layout.fillWidth: true
        }

        Base.AppText {
            text: root.firstInvalidReason()
            visible: text.length > 0
            theme: root.theme
            styleRole: "bodyS"
            colorOverride: "#ef4444"
            elide: Text.ElideRight
        }
    }

    Base.AppScrollPane {
        Layout.fillWidth: true
        Layout.fillHeight: true
        theme: root.theme
        contentSpacing: 12
        fillContentWidth: true

        Repeater {
            model: root.fieldSpecs

            delegate: ColumnLayout {
                id: fieldRow

                property var fieldSpec: modelData
                readonly property string editor: String(fieldSpec.editor || "text")
                readonly property string invalidReason: root.fieldInvalidReason(fieldSpec)

                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Base.AppText {
                        Layout.fillWidth: true
                        text: fieldRow.fieldSpec.label + (fieldRow.fieldSpec.required ? " *" : "")
                        theme: root.theme
                        styleRole: "bodyS"
                        textTone: "secondary"
                        elide: Text.ElideRight
                    }

                    Base.AppText {
                        text: String(fieldRow.fieldSpec.type || "")
                        theme: root.theme
                        styleRole: "bodyS"
                        textTone: fieldRow.invalidReason.length > 0 ? "primary" : "secondary"
                        colorOverride: fieldRow.invalidReason.length > 0 ? "#ef4444" : undefined
                    }
                }

                Base.AppTextField {
                    visible: fieldRow.editor === "text"
                    Layout.fillWidth: true
                    theme: root.theme
                    text: String(root.fieldValue(fieldRow.fieldSpec.key, fieldRow.fieldSpec.defaultValue))
                    placeholderText: String(fieldRow.fieldSpec.placeholder || "")
                    inputMethodHints: fieldRow.fieldSpec.type === "int"
                        ? Qt.ImhDigitsOnly
                        : (fieldRow.fieldSpec.type === "double" ? Qt.ImhFormattedNumbersOnly : Qt.ImhNone)
                    onEditingFinished: root.setFieldValue(fieldRow.fieldSpec.key, text)
                }

                Base.AppSelect {
                    visible: fieldRow.editor === "select"
                    Layout.fillWidth: true
                    theme: root.theme
                    options: fieldRow.fieldSpec.options || []
                    value: root.fieldValue(fieldRow.fieldSpec.key, fieldRow.fieldSpec.defaultValue)
                    onValueSelected: root.setFieldValue(fieldRow.fieldSpec.key, nextValue)
                }

                Base.AppSliderControl {
                    visible: fieldRow.editor === "slider"
                    Layout.fillWidth: true
                    theme: root.theme
                    from: Number(fieldRow.fieldSpec.minimum !== undefined ? fieldRow.fieldSpec.minimum : 0)
                    to: Number(fieldRow.fieldSpec.maximum !== undefined ? fieldRow.fieldSpec.maximum : 100)
                    stepSize: Number(fieldRow.fieldSpec.stepSize !== undefined ? fieldRow.fieldSpec.stepSize : 1)
                    suffix: String(fieldRow.fieldSpec.suffix || "")
                    value: Number(root.fieldValue(fieldRow.fieldSpec.key, fieldRow.fieldSpec.defaultValue))
                    onValueEdited: root.setFieldValue(fieldRow.fieldSpec.key, nextValue)
                }

                Base.AppSurface {
                    visible: fieldRow.editor === "textarea"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 104
                    sizeToContent: false
                    theme: root.theme
                    surfaceTone: "surface"
                    strokeWidth: fieldRow.invalidReason.length > 0 ? 2 : 1
                    borderOverride: fieldRow.invalidReason.length > 0 ? "#ef4444" : undefined

                    TextArea {
                        id: textArea

                        anchors.fill: parent
                        anchors.margins: 10
                        text: String(root.fieldValue(fieldRow.fieldSpec.key, fieldRow.fieldSpec.defaultValue))
                        placeholderText: String(fieldRow.fieldSpec.placeholder || "")
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        color: root.theme && root.theme.colors ? root.theme.colors.text : "#e6edf3"
                        placeholderTextColor: root.theme && root.theme.colors ? root.theme.colors.subtleText : "#97a3b6"
                        background: null
                        onActiveFocusChanged: {
                            if (!activeFocus)
                                root.setFieldValue(fieldRow.fieldSpec.key, text)
                        }
                    }
                }

                RowLayout {
                    visible: fieldRow.editor === "toggle"
                    Layout.fillWidth: true
                    spacing: 10

                    Base.AppToggleControl {
                        theme: root.theme
                        checked: !!root.fieldValue(fieldRow.fieldSpec.key, fieldRow.fieldSpec.defaultValue)
                        onToggled: root.setFieldValue(fieldRow.fieldSpec.key, nextChecked)
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        text: root.fieldValue(fieldRow.fieldSpec.key, fieldRow.fieldSpec.defaultValue)
                            ? String(fieldRow.fieldSpec.trueLabel || qsTr("Enabled"))
                            : String(fieldRow.fieldSpec.falseLabel || qsTr("Disabled"))
                        theme: root.theme
                        styleRole: "bodyS"
                        textTone: "secondary"
                    }
                }

                Base.AppText {
                    visible: fieldRow.invalidReason.length > 0
                    Layout.fillWidth: true
                    text: fieldRow.invalidReason
                    theme: root.theme
                    styleRole: "bodyS"
                    colorOverride: "#ef4444"
                    elide: Text.ElideRight
                }
            }
        }
    }

    Base.AppSurface {
        Layout.fillWidth: true
        Layout.preferredHeight: 74
        sizeToContent: false
        theme: root.theme
        surfaceTone: "surface"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4

            Base.AppText {
                text: qsTr("Preview")
                theme: root.theme
                styleRole: "bodyS"
                textTone: "secondary"
            }

            Base.AppText {
                Layout.fillWidth: true
                text: root.protocolLabel(root.selectedProtocol) + " / " + String(root.fieldValue("name", ""))
                theme: root.theme
                styleRole: "bodyM"
                elide: Text.ElideRight
            }
        }
    }
}
