import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UICore/qml/components/base" as Base

Base.AppDialog {
    id: root

    property var device: null
    property var draftCommand: null
    property var editingCommand: null
    property string selectedProtocol: "serial"
    property bool validationVisible: false
    readonly property bool editing: editingCommand !== null
    readonly property var protocolOptions: [
        { "label": qsTr("无协议"), "value": "internal" },
        { "label": qsTr("串口"), "value": "serial" },
        { "label": qsTr("UDP"), "value": "udp" },
        { "label": qsTr("HTTP"), "value": "http" },
        { "label": qsTr("PC"), "value": "pc" },
        { "label": qsTr("DMX512"), "value": "dmx512" },
        { "label": qsTr("OSC"), "value": "osc" }
    ]
    readonly property var availableProtocolOptions: buildAvailableProtocolOptions()
    readonly property bool commandValid: draftCommand
        && creationFieldForm.valid
        && firstInvalidReason().length === 0

    signal commandAccepted(var command)

    function openForDevice(nextDevice) {
        open()

        Qt.callLater(function() {
            clearDraft()
            device = nextDevice
            editingCommand = null
            validationVisible = false

            var nextProtocol = defaultProtocol(nextDevice)
            if (selectedProtocol === nextProtocol)
                resetDraft()
            else
                selectedProtocol = nextProtocol
        })
    }

    function openForCommand(nextDevice, nextCommand) {
        if (!nextDevice || !nextCommand)
            return

        open()

        Qt.callLater(function() {
            clearDraft()
            device = nextDevice
            editingCommand = nextCommand
            validationVisible = false

            var nextProtocol = String(nextCommand.protocol || "")
            if (selectedProtocol === nextProtocol)
                resetDraft()
            else
                selectedProtocol = nextProtocol
        })
    }

    function defaultProtocol(nextDevice) {
        var options = buildAvailableProtocolOptions(nextDevice)
        return options.length > 0 ? String(options[0].value) : ""
    }

    function buildAvailableProtocolOptions(targetDevice) {
        var sourceDevice = targetDevice || device
        var protocols = sourceDevice && sourceDevice.supportedProtocols !== undefined
            ? sourceDevice.supportedProtocols
            : []
        var supportedProtocols = []
        for (var index = 0; index < protocols.length; ++index) {
            var protocol = String(protocols[index] || "").trim().toLowerCase()
            if (protocol.length > 0 && supportedProtocols.indexOf(protocol) < 0)
                supportedProtocols.push(protocol)
        }
        if (supportedProtocols.length === 0)
            return []

        var result = []
        for (var index = 0; index < supportedProtocols.length; ++index) {
            for (var optionIndex = 0; optionIndex < protocolOptions.length; ++optionIndex) {
                if (String(protocolOptions[optionIndex].value) === supportedProtocols[index]) {
                    result.push(protocolOptions[optionIndex])
                    break
                }
            }
        }
        return result
    }

    function protocolLabel(protocol) {
        for (var index = 0; index < protocolOptions.length; ++index) {
            if (protocolOptions[index].value === protocol)
                return protocolOptions[index].label
        }
        return String(protocol)
    }

    function clearDraft() {
        var command = draftCommand
        draftCommand = null
        if (device && command && device.deleteCommandDraft !== undefined)
            device.deleteCommandDraft(command)
    }

    function resetDraft() {
        clearDraft()
        if (device && device.createCommandDraft !== undefined) {
            draftCommand = device.createCommandDraft(selectedProtocol)
            if (editing && draftCommand) {
                applyFieldValues(draftCommand.creationInputFields || [], fieldValues(editingCommand.creationInputFields || []))
                var fields = draftCommand.creationInputFields || []
                for (var index = 0; index < fields.length; ++index) {
                    if (String(fields[index].key || "") === "name")
                        fields[index].readOnly = true
                }
            }
        }
    }

    function firstInvalidReason() {
        if (!device)
            return qsTr("未选择设备")
        if (availableProtocolOptions.length === 0)
            return qsTr("该设备没有可用协议")
        if (!draftCommand)
            return qsTr("不支持的协议")

        var reason = creationFieldForm.firstInvalidReason()
        if (reason.length > 0)
            return reason

        if (draftCommand.invalidReason !== undefined) {
            reason = draftCommand.invalidReason()
            if (reason.length > 0)
                return reason
        }

        if (device.commandInvalidReason !== undefined) {
            reason = device.commandInvalidReason(draftCommand, editingCommand)
            if (reason.length > 0)
                return reason
        }

        return ""
    }

    function applyFieldValues(fields, values) {
        for (var index = 0; index < fields.length; ++index) {
            var field = fields[index]
            var key = field && field.key !== undefined ? String(field.key) : ""
            if (key.length > 0 && values[key] !== undefined)
                field.value = values[key]
        }
    }

    function fieldValues(fields) {
        var values = {}
        for (var index = 0; index < fields.length; ++index) {
            var field = fields[index]
            var key = field && field.key !== undefined ? String(field.key) : ""
            if (key.length > 0)
                values[key] = field.value
        }
        return values
    }

    function commit() {
        validationVisible = true
        if (!commandValid || !device || device.commitCommandDraft === undefined)
            return

        var creationValues = creationFieldForm.valueMap()
        if (editing) {
            applyFieldValues(editingCommand.creationInputFields || [], creationValues)
            commandAccepted(editingCommand)
            close()
            return
        }

        applyFieldValues(draftCommand.creationInputFields || [], creationValues)
        var command = draftCommand
        if (!device.commitCommandDraft(command))
            return

        draftCommand = null
        commandAccepted(command)
        close()
    }

    width: Math.min(640, Math.max(460, parent ? parent.width - 96 : 560))
    maximumDialogHeight: Math.min(680, Math.max(420, parent ? parent.height - 96 : 560))
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0
    title: editing ? qsTr("编辑指令") : qsTr("添加指令")
    message: device ? String(device.name || "") : ""
    rejectText: qsTr("取消")
    acceptText: editing ? qsTr("保存") : qsTr("添加")
    acceptIconName: "workflow"
    acceptEnabled: commandValid
    closeOnAccepted: false
    onAccepted: commit()

    onSelectedProtocolChanged: {
        if (visible) {
            validationVisible = false
            resetDraft()
        }
    }
    onClosed: {
        clearDraft()
        editingCommand = null
    }

    Base.AppDialogSection {
        Layout.fillWidth: true
        title: qsTr("协议")
        compact: true
        bodyFillHeight: false

        Base.AppSegmentedControl {
            Layout.fillWidth: true
            options: root.availableProtocolOptions
            value: root.selectedProtocol
            enabled: !root.editing
            onValueSelected: root.selectedProtocol = String(nextValue)
        }

    }

    Base.AppText {
        Layout.fillWidth: true
        text: root.firstInvalidReason()
        visible: text.length > 0
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Danger
        elide: Text.ElideRight
    }

    Base.AppDialogSection {
        Layout.fillWidth: true
        title: qsTr("创建参数")
        compact: true
        bodyFillHeight: false

        DeviceFieldForm {
            id: creationFieldForm

            Layout.fillWidth: true
            fields: root.draftCommand && root.draftCommand.creationMinInputFields !== undefined
                ? root.draftCommand.creationMinInputFields()
                : []
            writeBack: true
            showErrors: true
            emptyText: qsTr("无创建参数")
        }
    }

    Base.AppDialogSection {
        Layout.fillWidth: true
        title: qsTr("预览")
        compact: true
        bodyFillHeight: false

        Base.AppText {
            Layout.fillWidth: true
            text: root.protocolLabel(root.selectedProtocol)
                + " / "
                + String(creationFieldForm.valueMap().name || "")
            styleRole: UiStyle.TypographyRole.BodyM
            elide: Text.ElideRight
        }
    }
}
