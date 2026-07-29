import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/components/form" as Form
import "qrc:/UICore/qml/theme" as Theme

Item {
    id: root

    focus: true

    Theme.AppTheme {
        id: fallbackTheme
    }

    property QtObject pageTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : fallbackTheme
    readonly property int pageMargin: pageTheme && pageTheme.density ? pageTheme.density.pageMargin : 20
    property var appRuntime: typeof app !== "undefined" ? app : null
    property var deviceManager: appRuntime && appRuntime.deviceManager ? appRuntime.deviceManager : null
    property var deviceModel: appRuntime && appRuntime.deviceModel ? appRuntime.deviceModel : null
    property var deviceTemplateModel: appRuntime && appRuntime.deviceTemplateModel ? appRuntime.deviceTemplateModel : null
    property var deviceInspectorFormProvider: appRuntime && appRuntime.deviceInspectorFormProvider
        ? appRuntime.deviceInspectorFormProvider
        : null

    readonly property var devices: deviceModel ? deviceModel.devices : []
    readonly property var deviceTemplates: deviceTemplateModel ? deviceTemplateModel.templates : []
    readonly property var deviceTypes: deviceModel ? deviceModel.deviceTypes : []
    readonly property var manualDeviceTypes: buildManualDeviceTypes()
    readonly property var selectedDevice: deviceModel ? deviceModel.currentDevice : ({})
    readonly property var selectedDeviceCommands: selectedDeviceInCurrentView
        && selectedDevice
        && selectedDevice.commands
        ? selectedDevice.commands
        : []
    property int selectedCommandIndex: -1
    property int expandedCommandIndex: -1
    readonly property var selectedCommand: selectedCommandIndex >= 0
        && selectedCommandIndex < selectedDeviceCommands.length
        ? selectedDeviceCommands[selectedCommandIndex]
        : null
    property string deviceDisplayMode: "template"
    property string selectedTemplateName: deviceTemplates.length > 0 ? String(deviceTemplates[0].name) : ""
    property string selectedDeviceType: deviceTypes.length > 0 ? String(deviceTypes[0]) : ""
    readonly property var selectedTemplate: findTemplate(selectedTemplateName)
    readonly property var groupItems: deviceDisplayMode === "type" ? deviceTypes : deviceTemplates
    readonly property var filteredDevices: buildFilteredDevices()
    readonly property bool selectedDeviceInCurrentView: selectedDevice
        && selectedDevice.id !== undefined
        && (deviceDisplayMode === "type"
            ? (selectedDevice.deviceType !== undefined && String(selectedDevice.deviceType) === selectedDeviceType)
            : (selectedDevice.templateName !== undefined && String(selectedDevice.templateName) === selectedTemplateName))
    onDeviceTypesChanged: {
        if (selectedDeviceType.length === 0 && deviceTypes.length > 0)
            selectedDeviceType = String(deviceTypes[0])
    }

    onSelectedTemplateNameChanged: syncTemplateInspector()
    onSelectedDeviceChanged: {
        selectedCommandIndex = -1
        expandedCommandIndex = -1
        ensureSelectedCommandForDevice()
    }
    onSelectedDeviceCommandsChanged: ensureSelectedCommandForDevice()
    onSelectedDeviceInCurrentViewChanged: ensureSelectedCommandForDevice()
    onSelectedCommandIndexChanged: syncCommandInspector()
    onDeviceInspectorFormProviderChanged: {
        syncTemplateInspector()
        syncCommandInspector()
    }
    onFilteredDevicesChanged: ensureSelectedDeviceForView()

    Component.onCompleted: {
        syncTemplateInspector()
        ensureSelectedCommandForDevice()
    }

    function objectValue(object, field, fallback) {
        if (!object || object[field] === undefined || object[field] === null)
            return fallback

        return String(object[field])
    }

    function deviceValue(field, fallback) {
        if (!selectedDeviceInCurrentView)
            return fallback

        return objectValue(selectedDevice, field, fallback)
    }

    function templateValue(field, fallback) {
        return objectValue(selectedTemplate, field, fallback)
    }

    function findTemplate(templateName) {
        var normalizedTemplateName = String(templateName || "")
        for (var index = 0; index < deviceTemplates.length; ++index) {
            if (String(deviceTemplates[index].name) === normalizedTemplateName)
                return deviceTemplates[index]
        }

        return deviceTemplates.length > 0 ? deviceTemplates[0] : null
    }

    function buildManualDeviceTypes() {
        var result = []
        for (var index = 0; index < deviceTypes.length; ++index) {
            var nextType = String(deviceTypes[index])
            if (!isTemplateOnlyDeviceType(nextType))
                result.push(nextType)
        }
        return result
    }

    function isTemplateOnlyDeviceType(deviceType) {
        var normalizedDeviceType = String(deviceType || "").trim()
        if (normalizedDeviceType.length === 0)
            return false

        for (var index = 0; index < deviceTemplates.length; ++index) {
            var deviceTemplate = deviceTemplates[index]
            if (!deviceTemplate || deviceTemplate.deviceType === undefined || deviceTemplate.deviceType === null)
                continue

            if (String(deviceTemplate.deviceType).trim() === normalizedDeviceType)
                return true
        }
        return false
    }

    function buildFilteredDevices() {
        var result = []
        for (var index = 0; index < devices.length; ++index) {
            var device = devices[index]
            if (deviceDisplayMode === "type") {
                if (String(device.deviceType || "") === selectedDeviceType)
                    result.push(device)
            } else if (String(device.templateName) === selectedTemplateName) {
                result.push(device)
            }
        }

        return result
    }

    function ensureSelectedDeviceForView() {
        if (!deviceModel || filteredDevices.length === 0 || selectedDeviceInCurrentView)
            return

        deviceModel.selectDevice(String(filteredDevices[0].id))
    }

    function selectTemplate(templateName) {
        var normalizedTemplateName = String(templateName)
        if (selectedTemplateName === normalizedTemplateName)
            return

        selectedTemplateName = normalizedTemplateName
    }

    function syncTemplateInspector() {
        if (deviceInspectorFormProvider)
            deviceInspectorFormProvider.inspectTemplate(selectedTemplateName)
    }

    function ensureSelectedCommandForDevice() {
        var commands = selectedDeviceCommands || []
        var nextIndex = selectedCommandIndex
        if (!selectedDeviceInCurrentView || commands.length === 0)
            nextIndex = -1
        else if (nextIndex < 0 || nextIndex >= commands.length)
            nextIndex = 0

        if (selectedCommandIndex !== nextIndex)
            selectedCommandIndex = nextIndex
        else
            syncCommandInspector()

        if (expandedCommandIndex >= commands.length)
            expandedCommandIndex = -1
    }

    function syncCommandInspector() {
        if (deviceInspectorFormProvider)
            deviceInspectorFormProvider.inspectCommand(selectedCommand)
    }

    function selectCommandIndex(commandIndex) {
        selectedCommandIndex = commandIndex >= 0 && commandIndex < selectedDeviceCommands.length
            ? commandIndex
            : -1
    }

    function addCommandForSelectedDevice() {
        if (!selectedDeviceInCurrentView
            || !selectedDevice
            || selectedDevice.createCommandDraft === undefined
            || selectedDevice.createCommand === undefined) {
            return
        }

        addCommandPopupLoader.openForDevice(selectedDevice)
    }

    function removeSelectedCommand() {
        if (!selectedDeviceInCurrentView
            || !selectedDevice
            || selectedDevice.removeCommandAt === undefined
            || selectedCommandIndex < 0) {
            return
        }

        var removedIndex = selectedCommandIndex
        if (selectedDevice.removeCommandAt(selectedCommandIndex)) {
            var nextCount = Math.max(0, selectedDeviceCommands.length - 1)
            selectedCommandIndex = nextCount > 0 ? Math.min(removedIndex, nextCount - 1) : -1
        }
    }

    function requestRemoveSelectedDevice() {
        if (!deviceModel || !selectedDeviceInCurrentView || !selectedDevice)
            return

        removeDevicePopupLoader.openForDevice(selectedDevice)
    }

    function commandName(command) {
        if (!command)
            return qsTr("指令")

        var name = String(command.name || "").trim()
        return name.length > 0 ? name : qsTr("指令")
    }

    function commandProtocol(command) {
        return command && command.protocol !== undefined && command.protocol !== null
            ? String(command.protocol)
            : ""
    }

    function executionParameterNames(command) {
        var fields = command ? command.executionInputFields || [] : []
        var names = []
        for (var index = 0; index < fields.length; ++index) {
            var name = String(fields[index].label || fields[index].key || "").trim()
            if (name.length > 0)
                names.push(name)
        }
        return names.join("、")
    }

    function commandInputCount(command) {
        if (!command)
            return 0

        var creationFields = command.creationInputFields || []
        return creationFields.length
    }

    function commandFieldValue(command, key, fallback) {
        var fields = command ? command.creationInputFields || [] : []
        for (var index = 0; index < fields.length; ++index) {
            if (String(fields[index].key || "") === key)
                return fields[index].value
        }
        return fallback
    }

    function commandSummary(command) {
        var protocol = root.commandProtocol(command).toLowerCase()
        if (protocol === "http" || protocol === "pc") {
            var address = String(commandFieldValue(command, "ip", "") || "").trim()
            var port = String(commandFieldValue(command, "port", "") || "").trim()
            var path = String(commandFieldValue(command, "apiPath", "") || "").trim()
            var method = String(commandFieldValue(command, "httpMethod", "") || "").trim()
            if (address.length > 0 && port.length > 0)
                address += ":" + port
            return [method, address, path].filter(function(part) { return part.length > 0 }).join(" / ")
        }
        if (protocol === "serial") {
            var serialPort = String(commandFieldValue(command, "serialPort", "") || "").trim()
            var baudRate = String(commandFieldValue(command, "baudRate", "") || "").trim()
            var serialPayload = String(commandFieldValue(command, "serialPayload", "") || "").trim()
            return [serialPort, baudRate, serialPayload].filter(function(part) { return part.length > 0 }).join(" / ")
        }
        if (protocol === "dmx512")
            return qsTr("通道 %1 / 值 %2")
                .arg(commandFieldValue(command, "channel", 1))
                .arg(commandFieldValue(command, "value", 0))
        return qsTr("%1 个字段").arg(root.commandInputCount(command))
    }

    function selectDeviceType(deviceType) {
        var normalizedDeviceType = String(deviceType || "")
        if (selectedDeviceType === normalizedDeviceType)
            return

        selectedDeviceType = normalizedDeviceType
    }

    function setDeviceDisplayMode(mode) {
        if (deviceDisplayMode === mode)
            return

        deviceDisplayMode = mode
        if (deviceDisplayMode === "type" && selectedDeviceType.length === 0 && deviceTypes.length > 0)
            selectedDeviceType = String(deviceTypes[0])
        ensureSelectedDeviceForView()
    }

    function selectGroup(groupData) {
        if (deviceDisplayMode === "type")
            selectDeviceType(groupData)
        else
            selectTemplate(groupData.name)
    }

    function groupName(groupData) {
        return deviceDisplayMode === "type"
            ? String(groupData || "")
            : String(groupData.name || "")
    }

    function groupDescription(groupData) {
        if (deviceDisplayMode === "type")
            return qsTr("%1 台设备").arg(deviceCountForType(groupData))

        return String((groupData.supportedProtocols || []).join(", ")) + " - " + String(groupData.description || "")
    }

    function groupFootnote(groupData) {
        if (deviceDisplayMode === "type")
            return qsTr("设备类型")

        return qsTr("%1 项配置").arg(groupData.configSpecs ? groupData.configSpecs.length : 0)
    }

    function deviceAddress(device) {
        var values = device && device.configValues ? device.configValues : {}
        var ip = String(values.ip || "").trim()
        var port = String(values.port || "").trim()
        var address = ip.length > 0 && port.length > 0 ? ip + ":" + port : ip
        if (address.length === 0)
            address = String(values.serialPort || "").trim()
        return address.length > 0 ? address : qsTr("未分配")
    }

    function deviceProtocols(device) {
        return String((device && device.supportedProtocols ? device.supportedProtocols : []).join(", "))
    }

    function groupSelected(groupData) {
        return deviceDisplayMode === "type"
            ? String(groupData || "") === selectedDeviceType
            : String(groupData.name || "") === selectedTemplateName
    }

    function deviceCountForType(deviceType) {
        var count = 0
        for (var index = 0; index < devices.length; ++index) {
            if (String(devices[index].deviceType || "") === String(deviceType || ""))
                ++count
        }

        return count
    }

    function selectDevice(deviceId) {
        if (deviceModel)
            deviceModel.selectDevice(String(deviceId))
    }

    function initialInputSpecs(deviceTemplate) {
        var specs = deviceTemplate && deviceTemplate.configSpecs ? deviceTemplate.configSpecs : []
        var result = []

        for (var index = 0; index < specs.length; ++index) {
            if (!specs[index].readOnly)
                result.push(specs[index])
        }

        return result
    }

    function createDeviceFromSelectedTemplate() {
        if (!deviceManager || !selectedTemplate)
            return

        createDevicePopupLoader.openForTemplate(selectedTemplate, initialInputSpecs(selectedTemplate))
    }

    function updateField(field, value) {
        if (selectedDeviceInCurrentView && selectedDevice && selectedDevice.setFieldValue)
            selectedDevice.setFieldValue(field, value)
    }

    function configSpecSummary(configSpec) {
        var defaultText = configSpec.defaultValue === undefined || configSpec.defaultValue === null
            ? qsTr("空")
            : String(configSpec.defaultValue)
        return String(configSpec.type) + " / " + defaultText
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: root.pageMargin
        anchors.rightMargin: root.pageMargin
        anchors.topMargin: root.pageMargin
        anchors.bottomMargin: root.pageMargin
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Base.AppText {
                text: qsTr("设备")
                styleRole: UiStyle.TypographyRole.TitleL
            }

            Base.AppSurface {
                Layout.preferredHeight: 28
                sizeToContent: true
                surfaceTone: UiStyle.SurfaceTone.Section
                padding: 10

                Base.AppText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("%1 个模板").arg(root.deviceTemplates.length)
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                }
            }

            Base.AppSurface {
                Layout.preferredHeight: 28
                sizeToContent: true
                surfaceTone: UiStyle.SurfaceTone.Section
                padding: 10

                Base.AppText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("%1 台设备").arg(root.filteredDevices.length)
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Base.AppButton {
                visible: root.deviceDisplayMode === "template"
                text: qsTr("创建设备")
                iconName: "resources"
                onClicked: root.createDeviceFromSelectedTemplate()
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            columnSpacing: 14
            rowSpacing: 14

            Base.AppSurface {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                sizeToContent: false
                surfaceTone: UiStyle.SurfaceTone.Surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Base.AppText {
                        text: root.deviceDisplayMode === "type" ? qsTr("设备类型") : qsTr("设备模板")
                        styleRole: UiStyle.TypographyRole.SectionTitle
                    }

                    Base.AppSegmentedControl {
                        Layout.fillWidth: true
                        options: [
                            { "label": qsTr("模板"), "value": "template" },
                            { "label": qsTr("类型"), "value": "type" }
                        ]
                        value: root.deviceDisplayMode
                        onValueSelected: root.setDeviceDisplayMode(String(nextValue))
                    }

                    Base.AppScrollPane {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentSpacing: 8
                        fillContentWidth: true

                        Repeater {
                            model: root.groupItems

                            delegate: Base.AppSurface {
                                id: groupRow

                                readonly property bool selected: root.groupSelected(modelData)

                                Layout.fillWidth: true
                                Layout.preferredHeight: 92
                                sizeToContent: false
                                surfaceTone: selected ? UiStyle.SurfaceTone.Highlight : UiStyle.SurfaceTone.Surface
                                active: selected
                                hoveredState: groupMouse.containsMouse
                                interactive: true
                                strokeWidth: 1
                                borderOverride: selected ? "transparent" : undefined

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 10
                                    anchors.bottomMargin: 10
                                    spacing: 4

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: root.groupName(modelData)
                                        styleRole: UiStyle.TypographyRole.BodyM
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: root.groupDescription(modelData)
                                        styleRole: UiStyle.TypographyRole.BodyS
                                        textTone: UiStyle.TextTone.Secondary
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: root.groupFootnote(modelData)
                                        styleRole: UiStyle.TypographyRole.BodyS
                                        textTone: selected ? UiStyle.TextTone.Accent : UiStyle.TextTone.Secondary
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: groupMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: root.selectGroup(modelData)
                                }
                            }
                        }
                    }
                }
            }

            Base.AppSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 420
                sizeToContent: false
                surfaceTone: UiStyle.SurfaceTone.Surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Base.AppText {
                            Layout.fillWidth: true
                            text: qsTr("设备实例")
                            styleRole: UiStyle.TypographyRole.SectionTitle
                        }

                        Base.AppText {
                            Layout.preferredWidth: 90
                            text: qsTr("协议")
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                        }

                        Base.AppText {
                            Layout.preferredWidth: 88
                            text: qsTr("状态")
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Base.AppScrollPane {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentSpacing: 8
                        fillContentWidth: true

                        Repeater {
                            model: root.filteredDevices

                            delegate: Base.AppSurface {
                                id: deviceRow

                                readonly property bool selected: modelData.id === root.deviceValue("id", "")

                                Layout.fillWidth: true
                                Layout.preferredHeight: 66
                                sizeToContent: false
                                surfaceTone: selected ? UiStyle.SurfaceTone.Highlight : UiStyle.SurfaceTone.Surface
                                active: selected
                                hoveredState: rowMouse.containsMouse
                                interactive: true
                                strokeWidth: 1
                                borderOverride: selected ? "transparent" : undefined

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 12

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Base.AppText {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            styleRole: UiStyle.TypographyRole.BodyM
                                            elide: Text.ElideRight
                                        }

                                        Base.AppText {
                                            Layout.fillWidth: true
                                            text: root.deviceAddress(modelData)
                                            styleRole: UiStyle.TypographyRole.BodyS
                                            textTone: UiStyle.TextTone.Secondary
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Base.AppText {
                                        Layout.preferredWidth: 90
                                        text: root.deviceProtocols(modelData)
                                        styleRole: UiStyle.TypographyRole.BodyS
                                        textTone: UiStyle.TextTone.Secondary
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        Layout.preferredWidth: 88
                                        text: modelData.status
                                        styleRole: UiStyle.TypographyRole.BodyS
                                        textTone: modelData.status === qsTr("在线") ? UiStyle.TextTone.Accent : UiStyle.TextTone.Secondary
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: rowMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: root.selectDevice(modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            Base.AppSurface {
                Layout.preferredWidth: 380
                Layout.fillHeight: true
                sizeToContent: false
                surfaceTone: UiStyle.SurfaceTone.Surface

                Base.AppScrollPane {
                    anchors.fill: parent
                    anchors.margins: 18
                    contentSpacing: 10
                    fillContentWidth: true

                    Base.AppText {
                        Layout.fillWidth: true
                        text: root.deviceDisplayMode === "type" ? qsTr("类型详情") : qsTr("模板详情")
                        styleRole: UiStyle.TypographyRole.SectionTitle
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 96
                        sizeToContent: false
                        surfaceTone: UiStyle.SurfaceTone.Surface

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.deviceDisplayMode === "type"
                                    ? (root.selectedDeviceType.length > 0 ? root.selectedDeviceType : qsTr("无类型"))
                                    : root.templateValue("name", qsTr("无模板"))
                                styleRole: UiStyle.TypographyRole.BodyM
                                elide: Text.ElideRight
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.deviceDisplayMode === "type"
                                    ? qsTr("%1 台设备").arg(root.filteredDevices.length)
                                    : String((root.selectedTemplate && root.selectedTemplate.supportedProtocols ? root.selectedTemplate.supportedProtocols : []).join(", ")) + " - " + root.templateValue("description", "")
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                                elide: Text.ElideRight
                            }

                            Base.AppButton {
                                Layout.fillWidth: true
                                visible: root.deviceDisplayMode === "template"
                                text: qsTr("从模板创建设备")
                                iconName: "resources"
                                onClicked: root.createDeviceFromSelectedTemplate()
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Base.AppText {
                            Layout.fillWidth: true
                            text: qsTr("设备档案")
                            styleRole: UiStyle.TypographyRole.SectionTitle
                            elide: Text.ElideRight
                        }

                        Base.AppButton {
                            text: qsTr("删除")
                            enabled: root.selectedDeviceInCurrentView
                            onClicked: root.requestRemoveSelectedDevice()
                        }
                    }

                    Form.AppFormContent {
                        Layout.fillWidth: true
                        formData: root.deviceInspectorFormProvider
                            ? root.deviceInspectorFormProvider.deviceForm
                            : ({})
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 4
                            Layout.preferredHeight: 30
                            radius: 2
                            color: "#60a5fa"
                            visible: root.selectedDeviceInCurrentView
                        }

                        Base.AppText {
                            Layout.fillWidth: true
                            text: qsTr("设备指令")
                            styleRole: UiStyle.TypographyRole.TitleM
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            visible: root.selectedDeviceInCurrentView
                            Layout.preferredWidth: Math.max(82, commandCountText.implicitWidth + 18)
                            Layout.preferredHeight: 28
                            radius: 4
                            color: "#111827"
                            border.width: 1
                            border.color: "#334155"

                            Base.AppText {
                                id: commandCountText

                                anchors.centerIn: parent
                                text: qsTr("%1 条指令").arg(root.selectedDeviceCommands.length)
                                styleRole: UiStyle.TypographyRole.BodyS
                                colorOverride: "#bfdbfe"
                                elide: Text.ElideRight
                            }
                        }

                        Base.AppButton {
                            text: qsTr("添加")
                            iconName: "workflow"
                            enabled: root.selectedDeviceInCurrentView
                                && root.selectedDevice
                                && root.selectedDevice.createCommandDraft !== undefined
                                && root.selectedDevice.createCommand !== undefined
                            onClicked: root.addCommandForSelectedDevice()
                        }
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        visible: root.selectedDeviceInCurrentView && root.selectedDeviceCommands.length === 0
                        text: qsTr("暂无指令")
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Secondary
                        elide: Text.ElideRight
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.selectedDeviceCommands.length > 0
                        spacing: 8

                        Repeater {
                            model: root.selectedDeviceCommands

                            delegate: Item {
                                id: commandRow

                                readonly property var commandData: modelData
                                readonly property bool selected: index === root.selectedCommandIndex
                                readonly property bool expanded: index === root.expandedCommandIndex
                                readonly property string summaryText: root.commandSummary(modelData)
                                readonly property int inputCount: root.commandInputCount(modelData)

                                Layout.fillWidth: true
                                Layout.preferredHeight: commandRow.expanded
                                    ? commandRowContent.implicitHeight + 16
                                    : 58

                                Base.AppSurface {
                                    anchors.fill: parent
                                    surfaceTone: commandRow.selected ? UiStyle.SurfaceTone.Highlight : UiStyle.SurfaceTone.Ghost
                                    active: commandRow.selected
                                    hoveredState: commandMouse.containsMouse
                                    interactive: true
                                    strokeWidth: commandRow.selected || commandMouse.containsMouse ? 1 : 0
                                    borderOverride: commandRow.selected ? "#60a5fa" : "#334155"
                                    hoverOverlayOpacity: 0.08
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: parent.height - 18
                                    radius: 2
                                    color: commandRow.expanded || commandRow.selected ? "#60a5fa" : "#334155"
                                    opacity: commandRow.expanded || commandRow.selected ? 1 : (commandMouse.containsMouse ? 0.44 : 0.18)
                                }

                                MouseArea {
                                    id: commandMouse

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: 58
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: root.selectCommandIndex(index)
                                    onDoubleClicked: {
                                        root.selectCommandIndex(index)
                                        root.expandedCommandIndex = commandRow.expanded ? -1 : index
                                    }
                                }

                                ColumnLayout {
                                    id: commandRowContent

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.leftMargin: 18
                                    anchors.rightMargin: 12
                                    spacing: commandRow.expanded ? 10 : 0

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 58
                                        spacing: 8

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Base.AppText {
                                                    Layout.fillWidth: true
                                                    text: root.commandName(commandRow.commandData)
                                                    styleRole: UiStyle.TypographyRole.BodyM
                                                    colorOverride: commandRow.selected ? "#f8fafc" : undefined
                                                    elide: Text.ElideRight
                                                }

                                                Base.AppText {
                                                    Layout.maximumWidth: 120
                                                    text: root.executionParameterNames(commandRow.commandData)
                                                    visible: text.length > 0
                                                    styleRole: UiStyle.TypographyRole.BodyS
                                                    colorOverride: "#ef4444"
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            Base.AppText {
                                                Layout.fillWidth: true
                                                text: commandRow.summaryText.length > 0
                                                    ? commandRow.summaryText
                                                    : qsTr("%1 个字段").arg(commandRow.inputCount)
                                                styleRole: UiStyle.TypographyRole.BodyS
                                                textTone: UiStyle.TextTone.Secondary
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Base.AppButton {
                                            size: UiStyle.ButtonSize.Small
                                            variant: UiStyle.ButtonVariant.Ghost
                                            text: commandRow.expanded ? "▾" : "›"
                                            onClicked: {
                                                root.selectCommandIndex(index)
                                                root.expandedCommandIndex = commandRow.expanded ? -1 : index
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: commandRow.expanded
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                        color: "#60a5fa"
                                        opacity: 0.34
                                    }

                                    RowLayout {
                                        visible: commandRow.expanded
                                        Layout.fillWidth: true
                                        spacing: 8

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Base.AppText {
                                                Layout.fillWidth: true
                                                text: root.commandName(commandRow.commandData)
                                                styleRole: UiStyle.TypographyRole.BodyM
                                                elide: Text.ElideRight
                                            }

                                            Base.AppText {
                                                Layout.fillWidth: true
                                                text: root.commandProtocol(commandRow.commandData).toUpperCase()
                                                    + " / "
                                                    + root.commandSummary(commandRow.commandData)
                                                styleRole: UiStyle.TypographyRole.BodyS
                                                textTone: UiStyle.TextTone.Secondary
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Base.AppButton {
                                            text: qsTr("移除")
                                            onClicked: root.removeSelectedCommand()
                                        }
                                    }

                                    Rectangle {
                                        visible: commandRow.expanded
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                        color: "#334155"
                                        opacity: 0.48
                                    }

                                    Base.AppText {
                                        visible: commandRow.expanded
                                        Layout.fillWidth: true
                                        text: qsTr("创建参数")
                                        styleRole: UiStyle.TypographyRole.BodyS
                                        textTone: UiStyle.TextTone.Secondary
                                        elide: Text.ElideRight
                                    }

                                    DeviceFieldForm {
                                        visible: commandRow.expanded
                                        Layout.fillWidth: true
                                        fields: commandRow.commandData ? commandRow.commandData.creationInputFields : []
                                        readOnly: true
                                        writeBack: true
                                        emptyText: qsTr("无创建参数")
                                    }

                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: createDevicePopupLoader

        active: false

        function openForTemplate(deviceTemplate, fieldSpecs) {
            active = true
            item.openForTemplate(deviceTemplate, fieldSpecs)
        }

        sourceComponent: Component {
            Base.AppPopup {
                id: createDevicePopup
                parent: root
                onClosed: createDevicePopupLoader.active = false

        property var deviceTemplate: null
        property var fieldSpecs: []
        property string deviceName: ""
        property string selectedDeviceTypeOption: ""
        property string customDeviceType: ""
        readonly property string customDeviceTypeOption: "__custom__"
        readonly property bool templateHasDeviceType: templateDeviceType(deviceTemplate).length > 0
        readonly property bool customDeviceTypeSelected: selectedDeviceTypeOption === customDeviceTypeOption
        readonly property string deviceType: templateHasDeviceType
            ? templateDeviceType(deviceTemplate)
            : (customDeviceTypeSelected ? customDeviceType : selectedDeviceTypeOption)
        readonly property var deviceTypeOptions: buildDeviceTypeOptions()
        readonly property bool formValid: firstInvalidReason().length === 0

        function openForTemplate(nextTemplate, nextFieldSpecs) {
            deviceTemplate = nextTemplate
            fieldSpecs = nextFieldSpecs || []
            deviceName = defaultDeviceName(nextTemplate)
            selectedDeviceTypeOption = defaultDeviceType(nextTemplate)
            customDeviceType = ""
            createDeviceFieldForm.resetValues()
            open()
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

            if (root.deviceDisplayMode === "type" && root.selectedDeviceType.length > 0)
                return root.selectedDeviceType

            return root.manualDeviceTypes.length > 0 ? String(root.manualDeviceTypes[0]) : ""
        }

        function buildDeviceTypeOptions() {
            var result = []
            for (var index = 0; index < root.manualDeviceTypes.length; ++index) {
                var nextType = String(root.manualDeviceTypes[index])
                result.push({ "label": nextType, "value": nextType })
            }
            result.push({ "label": qsTr("其它"), "value": customDeviceTypeOption })
            return result
        }

        function isBlank(value) {
            return value === undefined || value === null || String(value).trim().length === 0
        }

        function firstInvalidReason() {
            if (deviceManager) {
                var creationReason = deviceManager.validateDeviceCreation(
                    deviceType,
                    deviceName,
                    deviceTemplate ? String(deviceTemplate.name) : ""
                )
                if (creationReason.length > 0)
                    return creationReason
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

            var created = deviceManager.createDeviceFromTemplate(
                String(deviceTemplate.name),
                buildConfigValues(),
                deviceName,
                deviceType
            )
            if (created) {
                root.selectedDeviceType = deviceType
                close()
            }
        }

        modal: true
        focus: true
        width: Math.min(560, Math.max(420, parent ? parent.width - 96 : 520))
        height: Math.min(620, Math.max(360, parent ? parent.height - 96 : 480))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        padding: 18
        spacing: 14
        surfaceTone: UiStyle.SurfaceTone.Section
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Base.AppText {
                    Layout.fillWidth: true
                    text: qsTr("创建设备")
                    styleRole: UiStyle.TypographyRole.TitleM
                    elide: Text.ElideRight
                }

                Base.AppText {
                    Layout.fillWidth: true
                    text: createDevicePopup.deviceTemplate
                        ? String(createDevicePopup.deviceTemplate.name) + " / " + String((createDevicePopup.deviceTemplate.supportedProtocols || []).join(", "))
                        : ""
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    elide: Text.ElideRight
                }
            }

            Base.AppButton {
                text: qsTr("取消")
                onClicked: createDevicePopup.close()
            }

            Base.AppButton {
                text: qsTr("创建")
                enabled: createDevicePopup.formValid
                iconName: "resources"
                onClicked: createDevicePopup.commit()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Base.AppText {
                text: qsTr("名称") + " *"
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }

            Base.AppTextField {
                Layout.fillWidth: true
                text: createDevicePopup.deviceName
                placeholderText: qsTr("设备名称")
                onTextChanged: createDevicePopup.deviceName = text
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Base.AppText {
                text: qsTr("设备类型") + " *"
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }

            Base.AppTextField {
                visible: createDevicePopup.templateHasDeviceType
                Layout.fillWidth: true
                enabled: false
                text: createDevicePopup.deviceType
            }

            RowLayout {
                visible: !createDevicePopup.templateHasDeviceType
                Layout.fillWidth: true
                spacing: 8

                Base.AppSelect {
                    Layout.fillWidth: true
                    placeholderText: qsTr("现有类型")
                    options: createDevicePopup.deviceTypeOptions
                    value: createDevicePopup.selectedDeviceTypeOption
                    onValueSelected: createDevicePopup.selectedDeviceTypeOption = String(nextValue)
                }

                Base.AppTextField {
                    visible: createDevicePopup.customDeviceTypeSelected
                    Layout.fillWidth: true
                    text: createDevicePopup.customDeviceType
                    placeholderText: qsTr("设备类型")
                    onTextChanged: createDevicePopup.customDeviceType = text
                }
            }
        }

        Base.AppText {
            Layout.fillWidth: true
            visible: text.length > 0
            text: createDevicePopup.firstInvalidReason()
            styleRole: UiStyle.TypographyRole.BodyS
            colorOverride: "#ef4444"
            elide: Text.ElideRight
        }

        Base.AppScrollPane {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentSpacing: 12
            fillContentWidth: true

            DeviceFieldForm {
                id: createDeviceFieldForm

                Layout.fillWidth: true
                fields: createDevicePopup.fieldSpecs
                writeBack: false
                emptyText: qsTr("无初始参数")
            }
        }
            }
        }
    }

    Loader {
        id: removeDevicePopupLoader

        active: false

        function openForDevice(device) {
            active = true
            item.openForDevice(device)
        }

        sourceComponent: Component {
            Base.AppPopup {
                id: removeDevicePopup
                parent: root
                onClosed: removeDevicePopupLoader.active = false

        property string deviceId: ""
        property string deviceName: ""

        function openForDevice(device) {
            deviceId = String(device.id || "")
            deviceName = root.deviceValue("name", qsTr("设备"))
            open()
        }

        function commit() {
            if (deviceModel && deviceId.length > 0)
                deviceModel.removeDevice(deviceId)
            close()
        }

        modal: true
        focus: true
        width: Math.min(420, Math.max(320, parent ? parent.width - 96 : 380))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        padding: 18
        spacing: 14
        surfaceTone: UiStyle.SurfaceTone.Section
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("删除设备")
            styleRole: UiStyle.TypographyRole.TitleM
            elide: Text.ElideRight
        }

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("确定删除 %1？关联的时间线指令和投影映射也会被移除。").arg(removeDevicePopup.deviceName)
            styleRole: UiStyle.TypographyRole.BodyM
            textTone: UiStyle.TextTone.Secondary
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.fillWidth: true
            }

            Base.AppButton {
                text: qsTr("取消")
                onClicked: removeDevicePopup.close()
            }

            Base.AppButton {
                text: qsTr("删除")
                onClicked: removeDevicePopup.commit()
            }
        }
            }
        }
    }

    Loader {
        id: addCommandPopupLoader

        active: false

        function openForDevice(device) {
            active = true
            item.openForDevice(device)
        }

        sourceComponent: Component {
            DeviceCommandDialog {
                id: addCommandPopup
                parent: root
                onClosed: addCommandPopupLoader.active = false

                onCommandAccepted: {
                    Qt.callLater(function() {
                        root.selectedCommandIndex = root.selectedDeviceCommands.length - 1
                    })
                }
            }
        }
    }
}
