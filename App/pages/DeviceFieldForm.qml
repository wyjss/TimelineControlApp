import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UiCore/qml/components/base" as Base

ColumnLayout {
    id: root

    property var fields: []
    property var values: ({})
    property bool writeBack: true
    property bool readOnly: false
    property bool showErrors: true
    property QtObject theme
    property string emptyText: qsTr("No fields")
    readonly property bool valid: firstInvalidReason().length === 0

    signal fieldEdited(var field, var value)

    spacing: 12

    function fieldKey(field) {
        return field && field.key !== undefined ? String(field.key) : ""
    }

    function defaultValue(field) {
        if (!field)
            return ""
        if (field.defaultValue !== undefined && field.defaultValue !== null)
            return field.defaultValue
        return ""
    }

    function fieldValue(field) {
        var key = fieldKey(field)
        if (writeBack)
            return field && field.value !== undefined && field.value !== null ? field.value : defaultValue(field)
        if (values && values[key] !== undefined && values[key] !== null)
            return values[key]
        return defaultValue(field)
    }

    function setFieldValue(field, value) {
        if (readOnly)
            return

        var nextValue = normalizedValue(field, value)
        if (writeBack) {
            field.value = nextValue
        } else {
            var nextValues = {}
            for (var name in values)
                nextValues[name] = values[name]
            nextValues[fieldKey(field)] = nextValue
            values = nextValues
        }
        fieldEdited(field, nextValue)
    }

    function resetValues() {
        var nextValues = {}
        for (var index = 0; index < fields.length; ++index)
            nextValues[fieldKey(fields[index])] = defaultValue(fields[index])
        values = nextValues
    }

    function valueMap() {
        var result = {}
        for (var index = 0; index < fields.length; ++index) {
            var field = fields[index]
            result[fieldKey(field)] = normalizedValue(field, fieldValue(field))
        }
        return result
    }

    function editorForField(field) {
        var editor = field && field.editor !== undefined ? String(field.editor) : ""
        if (editor.length > 0)
            return editor
        var hint = field && field.editorHint !== undefined ? Number(field.editorHint) : -1
        if (hint === 2)
            return "slider"
        if (hint === 3)
            return "toggle"
        if (hint === 4 || hint === 5 || hint === 6)
            return "select"
        if (field && field.options && field.options.length > 0)
            return "select"
        if (field && String(field.type) === "bool")
            return "toggle"
        return "text"
    }

    function normalizedValue(field, value) {
        var type = field ? String(field.type) : ""
        if (type === "int")
            return Math.round(Number(value))
        if (type === "double")
            return Number(value)
        if (type === "bool")
            return !!value
        if (type === "size")
            return parsedSize(value)
        return value
    }

    function displayValue(field, value) {
        return field && String(field.type) === "size" ? sizeText(value) : value
    }

    function sizeText(value) {
        if (value === undefined || value === null)
            return ""
        if (value.width !== undefined && value.height !== undefined)
            return String(Math.round(Number(value.width))) + "x" + String(Math.round(Number(value.height)))
        return String(value)
    }

    function parsedSize(value) {
        if (value && value.width !== undefined && value.height !== undefined)
            return Qt.size(Math.round(Number(value.width)), Math.round(Number(value.height)))
        var match = String(value).match(/^\s*(\d+)\s*[xX,]\s*(\d+)\s*$/)
        return match ? Qt.size(Math.round(Number(match[1])), Math.round(Number(match[2]))) : Qt.size(0, 0)
    }

    function fieldInvalidReason(field) {
        return field && field.invalidReason ? field.invalidReason(fieldValue(field)) : ""
    }

    function firstInvalidReason() {
        for (var index = 0; index < fields.length; ++index) {
            var reason = fieldInvalidReason(fields[index])
            if (reason.length > 0)
                return reason
        }
        return ""
    }

    Base.AppText {
        Layout.fillWidth: true
        visible: root.fields.length === 0
        text: root.emptyText
        theme: root.theme
        styleRole: "bodyS"
        textTone: "secondary"
        elide: Text.ElideRight
    }

    Repeater {
        model: root.fields

        delegate: ColumnLayout {
            id: fieldRow

            property var fieldSpec: modelData
            readonly property string editor: root.editorForField(fieldSpec)
            readonly property string invalidReason: root.showErrors && !root.readOnly ? root.fieldInvalidReason(fieldSpec) : ""

            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Base.AppText {
                    Layout.fillWidth: true
                    text: String(fieldRow.fieldSpec.label || fieldRow.fieldSpec.key || "") + (fieldRow.fieldSpec.required ? " *" : "")
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
                text: String(root.displayValue(fieldRow.fieldSpec, root.fieldValue(fieldRow.fieldSpec)))
                placeholderText: String(fieldRow.fieldSpec.placeholderText || fieldRow.fieldSpec.placeholder || "")
                enabled: !root.readOnly
                inputMethodHints: fieldRow.fieldSpec.type === "int"
                    ? Qt.ImhDigitsOnly
                    : (fieldRow.fieldSpec.type === "double" ? Qt.ImhFormattedNumbersOnly : Qt.ImhNone)
                onEditingFinished: root.setFieldValue(fieldRow.fieldSpec, text)
            }

            Base.AppSelect {
                visible: fieldRow.editor === "select"
                Layout.fillWidth: true
                theme: root.theme
                enabled: !root.readOnly
                options: fieldRow.fieldSpec.options || []
                value: root.fieldValue(fieldRow.fieldSpec)
                onValueSelected: root.setFieldValue(fieldRow.fieldSpec, nextValue)
            }

            Base.AppSliderControl {
                visible: fieldRow.editor === "slider"
                Layout.fillWidth: true
                theme: root.theme
                enabled: !root.readOnly
                from: Number(fieldRow.fieldSpec.minimum !== undefined ? fieldRow.fieldSpec.minimum : 0)
                to: Number(fieldRow.fieldSpec.maximum !== undefined ? fieldRow.fieldSpec.maximum : 100)
                stepSize: Number(fieldRow.fieldSpec.stepSize !== undefined ? fieldRow.fieldSpec.stepSize : 1)
                suffix: String(fieldRow.fieldSpec.suffix || "")
                value: Number(root.fieldValue(fieldRow.fieldSpec))
                onValueEdited: root.setFieldValue(fieldRow.fieldSpec, nextValue)
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
                    anchors.fill: parent
                    anchors.margins: 10
                    readOnly: root.readOnly
                    text: String(root.fieldValue(fieldRow.fieldSpec))
                    placeholderText: String(fieldRow.fieldSpec.placeholderText || fieldRow.fieldSpec.placeholder || "")
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: root.theme && root.theme.colors ? root.theme.colors.text : "#e6edf3"
                    placeholderTextColor: root.theme && root.theme.colors ? root.theme.colors.subtleText : "#97a3b6"
                    background: null
                    onActiveFocusChanged: {
                        if (!activeFocus)
                            root.setFieldValue(fieldRow.fieldSpec, text)
                    }
                }
            }

            RowLayout {
                visible: fieldRow.editor === "toggle"
                Layout.fillWidth: true
                spacing: 10

                Base.AppToggleControl {
                    theme: root.theme
                    enabled: !root.readOnly
                    checked: !!root.fieldValue(fieldRow.fieldSpec)
                    onToggled: root.setFieldValue(fieldRow.fieldSpec, nextChecked)
                }

                Base.AppText {
                    Layout.fillWidth: true
                    text: root.fieldValue(fieldRow.fieldSpec)
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
