import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import ".."
import "qrc:/UiCore/qml/components/base" as Base

Base.AppPopup {
    id: root

    property QtObject theme
    property string selectedProtocol: "serial"
    property int startTimeMs: 0
    readonly property var protocolOptions: [
        { "label": qsTr("串口"), "value": "serial" },
        { "label": qsTr("DMX512"), "value": "dmx512" },
        { "label": qsTr("HTTP"), "value": "http" },
        { "label": qsTr("PC"), "value": "pc" }
    ]
    readonly property var fieldSpecs: fieldsForProtocol(selectedProtocol)
    readonly property bool commandValid: fieldForm.valid && serialInvalidReason().length === 0

    signal commandAccepted(var command)

    function openForTime(timeMs) {
        startTimeMs = Math.max(0, Math.round(timeMs))
        fieldForm.resetValues()
        open()
    }

    function fieldsForProtocol(protocol) {
        var commonFields = [
            { "key": "name", "label": qsTr("名称"), "type": "string", "editor": "text", "required": true, "defaultValue": defaultNameForProtocol(protocol) },
            { "key": "durationMs", "label": qsTr("持续时间"), "type": "int", "editor": "text", "defaultValue": 0, "minimum": 0, "maximum": 3600000, "suffix": "ms" }
        ]

        switch (String(protocol)) {
        case "dmx512":
            return commonFields.concat([
                { "key": "channel", "label": qsTr("通道"), "type": "int", "editor": "text", "required": true, "defaultValue": 1, "minimum": 1, "maximum": 512 },
                { "key": "value", "label": qsTr("值"), "type": "int", "editor": "slider", "required": true, "defaultValue": 255, "minimum": 0, "maximum": 255, "stepSize": 1 }
            ])
        case "http":
            return commonFields.concat([
                { "key": "address", "label": qsTr("地址"), "type": "string", "editor": "text", "required": true, "defaultValue": "", "placeholder": "http://192.168.1.10:8080", "pattern": "^(http://)?((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(:[0-9]{1,5})?$" },
                { "key": "method", "label": qsTr("方法"), "type": "enum", "editor": "select", "required": true, "defaultValue": "POST", "options": [
                    { "label": "GET", "value": "GET" },
                    { "label": "POST", "value": "POST" },
                    { "label": "PUT", "value": "PUT" },
                    { "label": "PATCH", "value": "PATCH" },
                    { "label": "DELETE", "value": "DELETE" }
                ] },
                { "key": "path", "label": qsTr("路径"), "type": "string", "editor": "text", "required": true, "defaultValue": "/api/command", "placeholder": "/api/command", "pattern": "^/.*" },
                { "key": "body", "label": qsTr("内容"), "type": "string", "editor": "textarea", "defaultValue": "{ \"enabled\": true }" }
            ])
        case "pc":
            return commonFields.concat([
                { "key": "path", "label": qsTr("路径"), "type": "string", "editor": "text", "required": true, "defaultValue": "/api/command", "placeholder": "/api/command", "pattern": "^/.*" }
            ])
        case "serial":
        default:
            return commonFields.concat([
                { "key": "hex", "label": qsTr("十六进制"), "type": "bool", "editor": "toggle", "defaultValue": true, "trueLabel": "HEX", "falseLabel": qsTr("文本") },
                { "key": "payload", "label": qsTr("数据内容"), "type": "string", "editor": "textarea", "required": true, "defaultValue": "", "placeholder": "A5 5A 01 00" }
            ])
        }
    }

    function defaultNameForProtocol(protocol) {
        switch (String(protocol)) {
        case "dmx512":
            return qsTr("DMX 指令")
        case "http":
            return qsTr("HTTP 指令")
        case "pc":
            return qsTr("PC 指令")
        case "serial":
        default:
            return qsTr("串口指令")
        }
    }

    function protocolLabel(protocol) {
        for (var index = 0; index < protocolOptions.length; ++index) {
            if (protocolOptions[index].value === protocol)
                return protocolOptions[index].label
        }
        return String(protocol)
    }

    function hexPayloadPattern() {
        return /^([0-9A-Fa-f]{2})(\s+[0-9A-Fa-f]{2})*$/
    }

    function serialInvalidReason() {
        var values = fieldForm.valueMap()
        if (selectedProtocol === "serial" && !!values.hex && !hexPayloadPattern().test(String(values.payload || "").trim()))
            return qsTr("数据内容必须为十六进制字节")
        return ""
    }

    function firstInvalidReason() {
        var reason = fieldForm.firstInvalidReason()
        return reason.length > 0 ? reason : serialInvalidReason()
    }

    function buildCommand() {
        var params = {}
        var values = fieldForm.valueMap()
        var name = String(values.name || "")
        var durationMs = values.durationMs !== undefined ? values.durationMs : 0

        for (var index = 0; index < fieldSpecs.length; ++index) {
            var key = fieldSpecs[index].key
            if (key !== "name" && key !== "durationMs")
                params[key] = values[key]
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

    onSelectedProtocolChanged: fieldForm.resetValues()
    Component.onCompleted: fieldForm.resetValues()

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("添加指令")
                theme: root.theme
                styleRole: "titleM"
            }

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("在当前时间线位置创建协议指令。")
                theme: root.theme
                styleRole: "bodyS"
                textTone: "secondary"
                elide: Text.ElideRight
            }
        }

        Base.AppButton {
            text: qsTr("取消")
            theme: root.theme
            onClicked: root.close()
        }

        Base.AppButton {
            text: qsTr("添加")
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
            text: qsTr("协议")
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

        DeviceFieldForm {
            id: fieldForm

            Layout.fillWidth: true
            fields: root.fieldSpecs
            writeBack: false
            theme: root.theme
            emptyText: qsTr("无指令参数")
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
                text: qsTr("预览")
                theme: root.theme
                styleRole: "bodyS"
                textTone: "secondary"
            }

            Base.AppText {
                Layout.fillWidth: true
                text: root.protocolLabel(root.selectedProtocol) + " / " + String(fieldForm.valueMap().name || "")
                theme: root.theme
                styleRole: "bodyM"
                elide: Text.ElideRight
            }
        }
    }
}
