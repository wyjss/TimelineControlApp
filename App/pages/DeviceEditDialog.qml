import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UICore/qml/components/base" as Base

Base.AppDialog {
    id: root
    objectName: "deviceEditDialog"

    property var deviceManager: null
    property var manualDeviceTypes: []
    property var availableGroupNames: []
    property string preferredDeviceType: ""
    property string templateProtocolsText: ""
    property QtObject pageTheme: resolvedTheme

    property var deviceTemplate: null
    property var editingDevice: null
    property var fieldSpecs: []
    property string deviceName: ""
    property var groupNames: []
    property string selectedDeviceTypeOption: ""
    property string customDeviceType: ""
    readonly property string customDeviceTypeOption: "__custom__"
    readonly property bool editing: editingDevice !== null
    readonly property bool templateHasDeviceType: templateDeviceType(deviceTemplate).length > 0
    readonly property bool customDeviceTypeSelected: selectedDeviceTypeOption === customDeviceTypeOption
    readonly property string deviceType: editing
        ? String(editingDevice.deviceType || "")
        : (templateHasDeviceType
            ? templateDeviceType(deviceTemplate)
            : (customDeviceTypeSelected ? customDeviceType : selectedDeviceTypeOption))
    readonly property var deviceTypeOptions: buildDeviceTypeOptions()
    readonly property bool formValid: firstInvalidReason().length === 0

    signal deviceCreated(string createdDeviceType)

    function openForTemplate(nextTemplate, nextFieldSpecs) {
        open()

        Qt.callLater(function() {
            editingDevice = null
            deviceTemplate = nextTemplate
            fieldSpecs = nextFieldSpecs || []
            deviceName = defaultDeviceName(nextTemplate)
            selectedDeviceTypeOption = defaultDeviceType(nextTemplate)
            customDeviceType = ""
            createDeviceFieldForm.resetValues()
        })
    }

    function openForDevice(nextDevice, nextTemplate, nextFieldSpecs) {
        if (!nextDevice || !nextTemplate)
            return

        open()

        Qt.callLater(function() {
            editingDevice = nextDevice
            deviceTemplate = nextTemplate
            fieldSpecs = nextFieldSpecs || []
            deviceName = String(nextDevice.name || "")
            groupNames = nextDevice.groupNames ? nextDevice.groupNames.slice(0) : []
            newGroupNameInput.clear()
            selectedDeviceTypeOption = String(nextDevice.deviceType || "")
            customDeviceType = ""
            createDeviceFieldForm.values = nextDevice.configValues || ({})
        })
    }

    function defaultDeviceName(nextTemplate) {
        return nextTemplate ? qsTr("新建%1").arg(String(nextTemplate.name)) : qsTr("新设备")
    }

    function templateDeviceType(nextTemplate) {
        if (!nextTemplate || nextTemplate.deviceType === undefined || nextTemplate.deviceType === null)
            return ""

        return String(nextTemplate.deviceType).trim()
    }

    function defaultDeviceType(nextTemplate) {
        var lockedType = templateDeviceType(nextTemplate)
        if (lockedType.length > 0)
            return lockedType

        if (preferredDeviceType.length > 0)
            return preferredDeviceType

        return root.manualDeviceTypes.length > 0 ? String(root.manualDeviceTypes[0]) : ""
    }

    function buildDeviceTypeOptions() {
        var result = []
        for (var index = 0; index < root.manualDeviceTypes.length; ++index) {
            var nextType = String(root.manualDeviceTypes[index])
            result.push({ "label": nextType, "value": nextType })
        }
        result.push({ "label": qsTr("自定义类型…"), "value": customDeviceTypeOption })
        return result
    }

    function isBlank(value) {
        return value === undefined || value === null || String(value).trim().length === 0
    }

    function firstInvalidReason() {
        if (deviceManager) {
            var deviceReason = editing
                ? deviceManager.validateDeviceUpdate(editingDevice, deviceName)
                : deviceManager.validateDeviceCreation(
                    deviceType,
                    deviceName,
                    deviceTemplate ? String(deviceTemplate.name) : ""
                )
            if (deviceReason.length > 0)
                return deviceReason
        } else if (isBlank(deviceName)) {
            return qsTr("设备名称必填")
        }

        return createDeviceFieldForm.firstInvalidReason()
    }

    function buildConfigValues() {
        return createDeviceFieldForm.valueMap()
    }

    function commit() {
        if (!deviceManager || !deviceTemplate || !formValid)
            return

        if (editing) {
            if (newGroupNameInput.text.length > 0 && groupNames.indexOf(newGroupNameInput.text) < 0)
                groupNames = groupNames.concat([newGroupNameInput.text])

            if (deviceManager.updateDevice(editingDevice, deviceName, buildConfigValues(), groupNames))
                close()
            return
        }

        var created = deviceManager.createDeviceFromTemplate(
            String(deviceTemplate.name),
            buildConfigValues(),
            deviceName,
            deviceType
        )
        if (created) {
            deviceCreated(deviceType)
            close()
        }
    }

    width: Math.min(560, Math.max(420, parent ? parent.width - 96 : 520))
    maximumDialogHeight: Math.min(620, Math.max(360, parent ? parent.height - 96 : 480))
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0
    title: editing ? qsTr("编辑设备") : qsTr("创建设备")
    message: deviceTemplate
        ? String(deviceTemplate.name) + " / " + templateProtocolsText
        : ""
    rejectText: qsTr("取消")
    acceptText: editing ? qsTr("保存") : qsTr("创建")
    acceptIconName: "resources"
    acceptEnabled: formValid
    closeOnAccepted: false
    onAccepted: commit()

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.pageTheme.density.paneHeaderSpacing

        Base.AppText {
            text: qsTr("名称") + " *"
            styleRole: UiStyle.TypographyRole.BodyS
            textTone: UiStyle.TextTone.Secondary
        }

        Base.AppTextField {
            Layout.fillWidth: true
            text: root.deviceName
            placeholderText: qsTr("设备名称")
            onTextChanged: root.deviceName = text
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.pageTheme.density.paneHeaderSpacing

        Base.AppText {
            text: qsTr("设备类型") + " *"
            styleRole: UiStyle.TypographyRole.BodyS
            textTone: UiStyle.TextTone.Secondary
        }

        Base.AppTextField {
            visible: root.editing || root.templateHasDeviceType
            Layout.fillWidth: true
            enabled: false
            text: root.deviceType
        }

        RowLayout {
            visible: !root.editing && !root.templateHasDeviceType
            Layout.fillWidth: true
            spacing: root.pageTheme.density.controlGap

            Base.AppSelect {
                Layout.fillWidth: true
                placeholderText: qsTr("现有类型")
                options: root.deviceTypeOptions
                value: root.selectedDeviceTypeOption
                onValueSelected: root.selectedDeviceTypeOption = String(nextValue)
            }

            Base.AppTextField {
                visible: root.customDeviceTypeSelected
                Layout.fillWidth: true
                text: root.customDeviceType
                placeholderText: qsTr("设备类型")
                onTextChanged: root.customDeviceType = text
            }
        }
    }

    ColumnLayout {
        visible: root.editing
        Layout.fillWidth: true
        spacing: root.pageTheme.density.controlGap

        Base.AppText {
            text: qsTr("所属分组")
            styleRole: UiStyle.TypographyRole.BodyS
            textTone: UiStyle.TextTone.Secondary
        }

        Flow {
            id: groupChoices
            objectName: "deviceGroupChoices"
            Layout.fillWidth: true
            spacing: root.pageTheme.density.controlGap

            Repeater {
                model: {
                    var names = root.availableGroupNames.slice(0)
                    for (var index = 0; index < root.groupNames.length; ++index) {
                        var name = root.groupNames[index]
                        if (names.indexOf(name) < 0)
                            names.push(name)
                    }
                    return names
                }
                delegate: Base.AppCheckBox {
                    objectName: "deviceGroupChoice_" + index
                    width: Math.min(implicitWidth, groupChoices.width)
                    text: modelData
                    Component.onCompleted: contentItem.elide = Text.ElideRight
                    checked: root.groupNames.indexOf(String(modelData)) >= 0
                    onClicked: {
                        var names = root.groupNames.slice(0)
                        if (checked)
                            names.push(String(modelData))
                        else
                            names.splice(names.indexOf(String(modelData)), 1)
                        root.groupNames = names
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: root.pageTheme.density.controlGap

            Base.AppTextField {
                id: newGroupNameInput
                objectName: "deviceNewGroupName"
                Layout.fillWidth: true
                placeholderText: qsTr("输入新组名")
                onAccepted: {
                    if (addGroupButton.enabled)
                        addGroupButton.clicked()
                }
            }

            Base.AppButton {
                id: addGroupButton
                objectName: "deviceAddGroup"
                text: qsTr("添加")
                enabled: newGroupNameInput.text.length > 0
                    && root.groupNames.indexOf(newGroupNameInput.text) < 0
                onClicked: {
                    root.groupNames = root.groupNames.concat([newGroupNameInput.text])
                    newGroupNameInput.clear()
                }
            }
        }

        Base.AppText {
            text: root.groupNames.length > 0
                ? qsTr("已选择 %1 个分组").arg(root.groupNames.length)
                : qsTr("未选择分组，设备将归入未分组")
            styleRole: UiStyle.TypographyRole.BodyS
            textTone: UiStyle.TextTone.Secondary
        }
    }

    Base.AppText {
        Layout.fillWidth: true
        visible: text.length > 0
        text: root.firstInvalidReason()
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Danger
        elide: Text.ElideRight
    }

    DeviceFieldForm {
        id: createDeviceFieldForm

        Layout.fillWidth: true
        fields: root.fieldSpecs
        writeBack: false
        emptyText: qsTr("无初始参数")
    }
}
