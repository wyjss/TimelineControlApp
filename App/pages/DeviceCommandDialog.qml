import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UiCore/qml/components/base" as Base

Base.AppPopup {
    id: root

    property QtObject theme
    property var device: null
    property var draftCommand: null
    property string selectedProtocol: "serial"
    property bool validationVisible: false
    readonly property var protocolOptions: [
        { "label": qsTr("Serial"), "value": "serial" },
        { "label": qsTr("DMX512"), "value": "dmx512" },
        { "label": qsTr("HTTP"), "value": "http" },
        { "label": qsTr("PC"), "value": "pc" }
    ]
    readonly property bool commandValid: draftCommand
        && creationFieldForm.valid
        && executionFieldForm.valid
        && firstInvalidReason().length === 0

    signal commandAccepted(var command)

    function openForDevice(nextDevice) {
        clearDraft()
        device = nextDevice
        selectedProtocol = defaultProtocol(nextDevice)
        validationVisible = false
        resetDraft()
        open()
    }

    function defaultProtocol(nextDevice) {
        var protocol = nextDevice && nextDevice.protocol !== undefined
            ? String(nextDevice.protocol).trim().toLowerCase()
            : ""
        for (var index = 0; index < protocolOptions.length; ++index) {
            if (protocolOptions[index].value === protocol)
                return protocol
        }
        return "serial"
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
        if (device && device.createCommandDraft !== undefined)
            draftCommand = device.createCommandDraft(selectedProtocol)
    }

    function firstInvalidReason() {
        if (!device)
            return qsTr("No device selected")
        if (!draftCommand)
            return qsTr("Unsupported protocol")

        var reason = creationFieldForm.firstInvalidReason()
        if (reason.length > 0)
            return reason

        reason = executionFieldForm.firstInvalidReason()
        if (reason.length > 0)
            return reason

        if (draftCommand.validate !== undefined) {
            reason = String(draftCommand.validate())
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

    function commit() {
        validationVisible = true
        if (!commandValid || !device || device.createCommand === undefined)
            return

        var creationValues = creationFieldForm.valueMap()
        var command = device.createCommand(selectedProtocol, String(creationValues.name || ""))
        if (!command)
            return

        applyFieldValues(command.creationInputFields || [], creationValues)
        applyFieldValues(command.executionInputFields || [], executionFieldForm.valueMap())
        commandAccepted(command)
        close()
    }

    modal: true
    focus: true
    width: Math.min(640, Math.max(460, parent ? parent.width - 96 : 560))
    height: Math.min(680, Math.max(420, parent ? parent.height - 96 : 560))
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0
    padding: 18
    spacing: 14
    theme: root.theme
    surfaceTone: "section"
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    onSelectedProtocolChanged: {
        if (visible) {
            validationVisible = false
            resetDraft()
        }
    }
    onClosed: clearDraft()

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
                elide: Text.ElideRight
            }

            Base.AppText {
                Layout.fillWidth: true
                text: root.device ? String(root.device.name || "") : ""
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
            enabled: root.draftCommand !== null
            iconName: "workflow"
            onClicked: root.commit()
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        Base.AppText {
            text: qsTr("Protocol")
            theme: root.theme
            styleRole: "bodyS"
            textTone: "secondary"
        }

        Base.AppSegmentedControl {
            Layout.fillWidth: true
            theme: root.theme
            options: root.protocolOptions
            value: root.selectedProtocol
            onValueSelected: root.selectedProtocol = String(nextValue)
        }

        Base.AppText {
            Layout.fillWidth: true
            text: root.firstInvalidReason()
            visible: root.validationVisible && text.length > 0
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

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("Creation Parameters")
                theme: root.theme
                styleRole: "bodyS"
                textTone: "secondary"
                elide: Text.ElideRight
            }

            DeviceFieldForm {
                id: creationFieldForm

                Layout.fillWidth: true
                fields: root.draftCommand ? root.draftCommand.creationInputFields : []
                writeBack: true
                showErrors: root.validationVisible
                theme: root.theme
                emptyText: qsTr("No creation parameters")
            }

            Base.AppText {
                Layout.fillWidth: true
                visible: root.draftCommand && root.draftCommand.executionInputFields.length > 0
                text: qsTr("Execution Parameters")
                theme: root.theme
                styleRole: "sectionTitle"
                elide: Text.ElideRight
            }

            DeviceFieldForm {
                id: executionFieldForm

                Layout.fillWidth: true
                visible: root.draftCommand && root.draftCommand.executionInputFields.length > 0
                fields: root.draftCommand ? root.draftCommand.executionInputFields : []
                writeBack: true
                showErrors: root.validationVisible
                theme: root.theme
                emptyText: qsTr("No execution parameters")
            }
        }
    }

    Base.AppSurface {
        Layout.fillWidth: true
        Layout.preferredHeight: 70
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
                text: root.protocolLabel(root.selectedProtocol)
                    + " / "
                    + String(creationFieldForm.valueMap().name || "")
                theme: root.theme
                styleRole: "bodyM"
                elide: Text.ElideRight
            }
        }
    }
}
