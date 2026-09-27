import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/theme" as Theme
import "../components" as AppComponents

Item {
    id: root

    focus: true

    Theme.AppTheme {
        id: fallbackTheme
    }

    property QtObject pageTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : fallbackTheme
    property var appRuntime: typeof app !== "undefined" ? app : null
    property var deviceManager: appRuntime && appRuntime.deviceManager ? appRuntime.deviceManager : null
    property var deviceModel: appRuntime && appRuntime.deviceModel ? appRuntime.deviceModel : null
    property var deviceTemplateModel: appRuntime && appRuntime.deviceTemplateModel ? appRuntime.deviceTemplateModel : null

    readonly property var devices: deviceModel ? deviceModel.devices : []
    readonly property var deviceTemplates: deviceTemplateModel ? deviceTemplateModel.templates : []
    readonly property var deviceTypes: deviceModel ? deviceModel.deviceTypes : []
    readonly property var deviceGroupNames: deviceModel && deviceModel.groupNames ? deviceModel.groupNames : []
    readonly property var manualDeviceTypes: buildManualDeviceTypes()
    readonly property var selectedDevice: deviceModel ? deviceModel.currentDevice : ({})
    readonly property var selectedDeviceCommands: selectedDeviceInCurrentView
        && selectedDevice
        && selectedDevice.commands
        ? selectedDevice.commands
        : []
    readonly property bool supportsPowerOn: selectedDeviceCommands.some(function(command) {
        return command.name === "$开机"
    })
    readonly property bool supportsPowerOff: selectedDeviceCommands.some(function(command) {
        return command.name === "$关机"
    })
    property string powerControlDeviceId: ""
    property string powerControlDeviceName: ""
    property string powerControlStatus: ""
    readonly property var groupPowerOnDevices: groupPowerDevices(true)
    readonly property var groupPowerOffDevices: groupPowerDevices(false)
    property string groupPowerName: ""
    property bool groupPowerOn: true
    property int groupPowerTotalCount: 0
    property int groupPowerSentCount: 0
    property var groupPowerPendingDevices: []
    property var groupPowerErrors: []
    readonly property bool groupPowerBusy: groupPowerPendingDevices.length > 0
    property int selectedCommandIndex: -1
    property int expandedCommandIndex: -1
    property string deviceSearchText: ""
    property string deviceStatusFilter: "all"
    property bool compactDevices: false
    property bool selectingDevices: false
    property var batchSelectedDeviceIds: []
    readonly property int visibleBatchSelectionCount: {
        var count = 0
        for (var index = 0; index < filteredDevices.length; ++index) {
            if (batchSelectedDeviceIds.indexOf(String(filteredDevices[index].id)) >= 0)
                ++count
        }
        return count
    }
    property string deviceDisplayMode: "template"
    property string selectedTemplateName: deviceTemplates.length > 0 ? String(deviceTemplates[0].name) : ""
    property string selectedDeviceType: deviceTypes.length > 0 ? String(deviceTypes[0]) : ""
    readonly property var selectedTemplate: findTemplate(selectedTemplateName)
    property string selectedGroupKind: "all"
    property string selectedGroupName: ""
    readonly property string selectedGroupTitle: selectedGroupKind === "all" ? qsTr("全部设备")
        : (selectedGroupKind === "ungrouped" ? qsTr("未分组") : selectedGroupName)
    readonly property var groupItems: {
        if (deviceDisplayMode === "type")
            return deviceTypes
        if (deviceDisplayMode !== "group")
            return deviceTemplates
        var groups = [{ "kind": "all", "name": qsTr("全部设备") },
                      { "kind": "ungrouped", "name": qsTr("未分组") }]
        for (var index = 0; index < deviceGroupNames.length; ++index)
            groups.push({ "kind": "named", "name": deviceGroupNames[index] })
        return groups
    }
    readonly property var filteredDevices: buildFilteredDevices()
    readonly property bool selectedDeviceInCurrentView: selectedDevice
        && selectedDevice.id !== undefined
        && filteredDevices.some(function(device) {
            return String(device.id) === String(selectedDevice.id)
        })

    onSelectingDevicesChanged: {
        if (!selectingDevices)
            batchSelectedDeviceIds = []
    }
    onDeviceDisplayModeChanged: selectingDevices = false
    onDevicesChanged: {
        var ids = []
        for (var index = 0; index < devices.length; ++index) {
            var id = String(devices[index].id)
            if (batchSelectedDeviceIds.indexOf(id) >= 0)
                ids.push(id)
        }
        if (ids.length !== batchSelectedDeviceIds.length)
            batchSelectedDeviceIds = ids
    }

    onDeviceTypesChanged: {
        if (selectedDeviceType.length === 0 && deviceTypes.length > 0)
            selectedDeviceType = String(deviceTypes[0])
    }

    onDeviceGroupNamesChanged: {
        if (selectedGroupKind === "named" && deviceGroupNames.indexOf(selectedGroupName) < 0) {
            selectedGroupKind = "all"
            selectedGroupName = ""
        }
    }

    onSelectedDeviceChanged: {
        selectedCommandIndex = -1
        expandedCommandIndex = -1
        ensureSelectedCommandForDevice()
    }
    onSelectedDeviceCommandsChanged: ensureSelectedCommandForDevice()
    onSelectedDeviceInCurrentViewChanged: ensureSelectedCommandForDevice()
    onFilteredDevicesChanged: Qt.callLater(ensureSelectedDeviceForView)

    Component.onCompleted: ensureSelectedCommandForDevice()

    Connections {
        target: root.deviceManager
        onDevicePowerFinished: {
            for (var index = 0; index < root.groupPowerPendingDevices.length; ++index) {
                if (root.groupPowerPendingDevices[index].id !== deviceId)
                    continue
                var pending = root.groupPowerPendingDevices.slice(0)
                var finishedDevice = pending.splice(index, 1)[0]
                if (success)
                    ++root.groupPowerSentCount
                else
                    root.groupPowerErrors = root.groupPowerErrors.concat([
                        qsTr("%1：%2").arg(finishedDevice.name).arg(errorMessage)
                    ])
                root.groupPowerPendingDevices = pending
                return
            }
            if (deviceId !== root.powerControlDeviceId)
                return
            root.powerControlDeviceId = ""
            root.powerControlStatus = success
                ? qsTr("%1：指令已发送").arg(root.powerControlDeviceName)
                : qsTr("%1：失败，%2").arg(root.powerControlDeviceName).arg(errorMessage)
        }
    }

    function setDevicePower(deviceId, deviceName, powerOn) {
        if (!deviceManager || powerControlDeviceId.length > 0 || groupPowerBusy)
            return
        powerControlDeviceId = deviceId
        powerControlDeviceName = deviceName
        powerControlStatus = qsTr("%1：正在发送%2指令…")
            .arg(deviceName).arg(powerOn ? qsTr("开机") : qsTr("关机"))
        deviceManager.setDevicePower(deviceId, powerOn)
    }

    function groupPowerDevices(powerOn) {
        var result = []
        if (deviceDisplayMode !== "group" || selectedGroupKind !== "named")
            return result
        var commandName = powerOn ? "$开机" : "$关机"
        for (var index = 0; index < devices.length; ++index) {
            var device = devices[index]
            if ((device.groupNames || []).indexOf(selectedGroupName) < 0)
                continue
            var commands = device.commands || []
            for (var commandIndex = 0; commandIndex < commands.length; ++commandIndex) {
                if (commands[commandIndex].name === commandName) {
                    result.push({ "id": String(device.id), "name": String(device.name) })
                    break
                }
            }
        }
        return result
    }

    function setGroupPower(groupName, targetDevices, powerOn) {
        if (!deviceManager || powerControlDeviceId.length > 0 || groupPowerBusy || targetDevices.length === 0)
            return
        groupPowerName = groupName
        groupPowerOn = powerOn
        groupPowerTotalCount = targetDevices.length
        groupPowerSentCount = 0
        groupPowerErrors = []
        groupPowerPendingDevices = targetDevices.slice(0)
        for (var index = 0; index < targetDevices.length; ++index)
            deviceManager.setDevicePower(targetDevices[index].id, powerOn)
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
        var query = deviceSearchText.trim().toLowerCase()
        var result = []
        for (var index = 0; index < devices.length; ++index) {
            var device = devices[index]
            if (query.length > 0
                    && (String(device.name || "") + " " + deviceAddress(device)).toLowerCase().indexOf(query) < 0)
                continue
            if (deviceStatusFilter !== "all" && !!device.online !== (deviceStatusFilter === "online"))
                continue
            if (deviceDisplayMode === "group") {
                var names = device.groupNames || []
                if (selectedGroupKind === "all"
                    || (selectedGroupKind === "ungrouped" && names.length === 0)
                    || (selectedGroupKind === "named" && names.indexOf(selectedGroupName) >= 0))
                    result.push(device)
            } else if (deviceDisplayMode === "type") {
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

    function ensureSelectedCommandForDevice() {
        var commands = selectedDeviceCommands || []
        var nextIndex = selectedCommandIndex
        if (!selectedDeviceInCurrentView || commands.length === 0)
            nextIndex = -1
        else if (nextIndex < 0 || nextIndex >= commands.length)
            nextIndex = 0

        if (selectedCommandIndex !== nextIndex)
            selectedCommandIndex = nextIndex

        if (expandedCommandIndex >= commands.length)
            expandedCommandIndex = -1
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
            || selectedDevice.commitCommandDraft === undefined) {
            return
        }

        addCommandPopupLoader.openForDevice(selectedDevice)
    }

    function editCommand(command) {
        if (!selectedDeviceInCurrentView || !selectedDevice || !command || !command.editable)
            return

        addCommandPopupLoader.openForCommand(selectedDevice, command)
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

    function requestEditSelectedDevice() {
        if (!selectedDeviceInCurrentView || !selectedDevice)
            return

        var deviceTemplate = null
        var templateName = String(selectedDevice.templateName || "")
        for (var index = 0; index < deviceTemplates.length; ++index) {
            if (String(deviceTemplates[index].name || "") === templateName) {
                deviceTemplate = deviceTemplates[index]
                break
            }
        }
        if (deviceTemplate)
            createDevicePopupLoader.openForDevice(selectedDevice,
                                                  deviceTemplate,
                                                  initialInputSpecs(deviceTemplate))
    }

    function commandName(command) {
        if (!command)
            return qsTr("指令")

        var name = String(command.name || "").trim()
        return name.length > 0 ? name : qsTr("指令")
    }

    function executionParameterNames(command) {
        var fields = command ? command.executionInputFields || [] : []
        var names = []
        for (var index = 0; index < fields.length; ++index) {
            var name = String(fields[index].label || fields[index].key || "").trim()
            if (name.length > 0)
                names.push(name)
        }
        return names.join(" · ")
    }

    function commandInputCount(command) {
        if (!command)
            return 0

        var creationFields = command.creationInputFields || []
        return creationFields.length
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
        if (deviceDisplayMode === "group") {
            selectedGroupName = groupData.kind === "named" ? String(groupData.name) : ""
            selectedGroupKind = groupData.kind
        } else if (deviceDisplayMode === "type")
            selectDeviceType(groupData)
        else
            selectTemplate(groupData.name)
    }

    function groupName(groupData) {
        return deviceDisplayMode === "type"
            ? String(groupData || "")
            : String(groupData.name || "")
    }

    function groupIconName(groupData) {
        if (deviceDisplayMode === "type")
            return String(groupData || "")

        var deviceType = String(groupData.deviceType || "")
        return deviceType.length > 0 ? deviceType : String(groupData.name || "")
    }

    function groupDescription(groupData) {
        if (deviceDisplayMode === "type" || deviceDisplayMode === "group")
            return qsTr("%1 台设备").arg(deviceCountForGroup(groupData))

        var deviceType = String(groupData.deviceType || "")
        var protocols = protocolsText(groupData.supportedProtocols, " · ")
        return deviceType.length > 0 && protocols.length > 0
            ? deviceType + " · " + protocols
            : deviceType + protocols
    }

    function groupFootnote(groupData) {
        if (deviceDisplayMode === "group")
            return groupData.kind === "named" ? qsTr("自定义分组") : qsTr("设备分组")
        if (deviceDisplayMode === "type")
            return qsTr("设备类型")

        var description = String(groupData.description || "")
        return description.length > 0 && description !== String(groupData.name || "")
            ? description
            : qsTr("%1 项配置").arg(groupData.configSpecs ? groupData.configSpecs.length : 0)
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

    function protocolsText(protocols, separator) {
        return (protocols || []).map(function(protocol) {
            return String(protocol).toLowerCase() === "internal" ? qsTr("无协议") : String(protocol)
        }).join(separator || ", ")
    }

    function groupSelected(groupData) {
        if (deviceDisplayMode === "group")
            return groupData.kind === selectedGroupKind
                && (groupData.kind !== "named" || groupData.name === selectedGroupName)
        return deviceDisplayMode === "type"
            ? String(groupData || "") === selectedDeviceType
            : String(groupData.name || "") === selectedTemplateName
    }

    function deviceCountForGroup(groupData) {
        var groupValue = deviceDisplayMode === "type"
            ? String(groupData || "")
            : String(groupData.name || "")
        var count = 0
        for (var index = 0; index < devices.length; ++index) {
            if (deviceDisplayMode === "group") {
                var names = devices[index].groupNames || []
                if (groupData.kind === "all"
                    || (groupData.kind === "ungrouped" && names.length === 0)
                    || (groupData.kind === "named" && names.indexOf(groupData.name) >= 0))
                    ++count
                continue
            }
            var nextValue = deviceDisplayMode === "type"
                ? String(devices[index].deviceType || "")
                : String(devices[index].templateName || "")
            if (nextValue === groupValue)
                ++count
        }

        return count
    }

    function selectDevice(deviceId) {
        if (selectingDevices) {
            var ids = batchSelectedDeviceIds.slice(0)
            var index = ids.indexOf(String(deviceId))
            if (index < 0)
                ids.push(String(deviceId))
            else
                ids.splice(index, 1)
            batchSelectedDeviceIds = ids
            return
        }
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pageTheme.density.panePaddingCompact
        spacing: root.pageTheme.density.controlGap

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            columnSpacing: root.pageTheme.density.controlGap
            rowSpacing: root.pageTheme.density.controlGap

            Base.AppSurface {
                Layout.preferredWidth: 250
                Layout.minimumWidth: 230
                Layout.maximumWidth: 250
                Layout.fillHeight: true
                sizeToContent: false
                surfaceTone: UiStyle.SurfaceTone.Surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.pageTheme.density.panePadding
                    spacing: root.pageTheme.density.paneSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.pageTheme.density.controlGap

                        Base.AppText {
                            Layout.fillWidth: true
                            text: root.deviceDisplayMode === "group" ? qsTr("设备分组")
                                : (root.deviceDisplayMode === "type" ? qsTr("设备类型") : qsTr("设备模板"))
                            styleRole: UiStyle.TypographyRole.SectionTitle
                        }

                        Base.AppText {
                            text: root.deviceDisplayMode === "group" ? qsTr("%1 个分组").arg(root.deviceGroupNames.length)
                                : (root.deviceDisplayMode === "type"
                                    ? qsTr("%1 个类型").arg(root.groupItems.length)
                                    : qsTr("%1 个模板").arg(root.deviceTemplates.length))
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                        }
                    }

                    Base.AppSegmentedControl {
                        objectName: "deviceDisplayModeSelector"
                        Layout.fillWidth: true
                        surfaceTone: UiStyle.SurfaceTone.Section
                        options: [
                            { "label": qsTr("模板"), "value": "template" },
                            { "label": qsTr("类型"), "value": "type" },
                            { "label": qsTr("分组"), "value": "group" }
                        ]
                        value: root.deviceDisplayMode
                        onValueSelected: root.setDeviceDisplayMode(String(nextValue))
                    }

                    Base.AppScrollPane {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        fillContentWidth: true

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: groupCardLayout.implicitHeight

                            ColumnLayout {
                                id: groupCardLayout

                                anchors.fill: parent
                                spacing: root.pageTheme.density.controlGap

                                Repeater {
                                    model: root.groupItems

                                    delegate: Base.AppCard {
                                        id: groupRow
                                        objectName: "deviceCategory_" + index

                                        readonly property bool selected: root.groupSelected(modelData)

                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 68
                                        text: root.groupName(modelData)
                                        compact: true
                                        contentSpacing: 0
                                        checkable: true
                                        checked: selected
                                        surfaceTone: UiStyle.SurfaceTone.SectionOverlay
                                        selectionTransition: groupCardSelectionTransition
                                        animateScale: false
                                        onClicked: root.selectGroup(modelData)
                                        ToolTip.visible: hovered
                                        ToolTip.text: root.groupDescription(modelData) + " · " + root.groupFootnote(modelData)

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            spacing: root.pageTheme.density.controlGap

                                            AppComponents.DeviceIcon {
                                                visible: root.deviceDisplayMode !== "group"
                                                size: 32
                                                name: root.deviceDisplayMode === "group" ? "" : root.groupIconName(modelData)
                                            }

                                            Base.AppIcon {
                                                visible: root.deviceDisplayMode === "group"
                                                size: 32
                                                name: "resources"
                                                color: groupRow.selected ? root.pageTheme.colors.highlightText
                                                    : root.pageTheme.colors.subtleText
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: root.pageTheme.density.controlGap

                                                    Base.AppText {
                                                        Layout.fillWidth: true
                                                        text: root.groupName(modelData)
                                                        styleRole: UiStyle.TypographyRole.BodyM
                                                        elide: Text.ElideRight
                                                    }

                                                    Base.AppText {
                                                        visible: root.deviceDisplayMode === "template"
                                                        text: qsTr("%1 台").arg(root.deviceCountForGroup(modelData))
                                                        styleRole: UiStyle.TypographyRole.BodyS
                                                        textTone: groupRow.selected
                                                            ? UiStyle.TextTone.Accent
                                                            : UiStyle.TextTone.Secondary
                                                    }
                                                }

                                                Base.AppText {
                                                    Layout.fillWidth: true
                                                    text: root.groupDescription(modelData)
                                                    styleRole: UiStyle.TypographyRole.BodyS
                                                    textTone: UiStyle.TextTone.Secondary
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            AppComponents.SubtleCardSelectionTransition {
                                id: groupCardSelectionTransition

                                anchors.fill: parent
                                selectionColor: root.pageTheme.colors.highlightText
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
                    anchors.margins: root.pageTheme.density.panePadding
                    spacing: root.pageTheme.density.paneSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.pageTheme.density.paneSpacing

                        Base.AppText {
                            Layout.fillWidth: root.deviceDisplayMode === "group"
                            text: root.deviceDisplayMode === "group" ? root.selectedGroupTitle : qsTr("设备实例")
                            styleRole: UiStyle.TypographyRole.SectionTitle
                            elide: Text.ElideRight
                        }

                        Base.AppText {
                            text: qsTr("%1 台").arg(root.filteredDevices.length)
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                        }

                        Base.AppButton {
                            objectName: "deviceResourceSyncButton"
                            text: qsTr("资源同步")
                            enabled: root.appRuntime && root.appRuntime.resourceSyncManager
                            onClicked: {
                                resourceSyncDialog.initialDeviceIds = root.selectingDevices
                                    ? root.batchSelectedDeviceIds.slice(0)
                                    : root.selectedDeviceInCurrentView ? [String(root.selectedDevice.id)] : []
                                resourceSyncDialog.open()
                            }
                        }

                        Base.AppButton {
                            objectName: "deviceSelectModeButton"
                            visible: root.deviceDisplayMode === "group"
                            text: root.selectingDevices ? qsTr("退出多选") : qsTr("选择设备")
                            variant: root.selectingDevices ? UiStyle.ButtonVariant.Tonal : UiStyle.ButtonVariant.Secondary
                            enabled: root.devices.length > 0 || root.selectingDevices
                            onClicked: root.selectingDevices = !root.selectingDevices
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.deviceDisplayMode === "group" && !root.selectingDevices
                            && (root.selectedGroupKind === "named" || root.groupPowerTotalCount > 0)
                        spacing: root.pageTheme.density.controlGap

                        RowLayout {
                            objectName: "deviceGroupPowerActions"
                            Layout.fillWidth: true
                            visible: root.selectedGroupKind === "named"
                            spacing: root.pageTheme.density.controlGap

                            Base.AppButton {
                                objectName: "deviceGroupPowerOnButton"
                                text: qsTr("整组开机")
                                enabled: root.deviceManager && root.groupPowerOnDevices.length > 0
                                    && root.powerControlDeviceId.length === 0 && !root.groupPowerBusy
                                onClicked: {
                                    groupPowerDialog.groupName = root.selectedGroupName
                                    groupPowerDialog.targetDevices = root.groupPowerOnDevices.slice(0)
                                    groupPowerDialog.powerOn = true
                                    groupPowerDialog.open()
                                }
                            }

                            Base.AppButton {
                                objectName: "deviceGroupPowerOffButton"
                                text: qsTr("整组关机")
                                variant: UiStyle.ButtonVariant.Danger
                                enabled: root.deviceManager && root.groupPowerOffDevices.length > 0
                                    && root.powerControlDeviceId.length === 0 && !root.groupPowerBusy
                                onClicked: {
                                    groupPowerDialog.groupName = root.selectedGroupName
                                    groupPowerDialog.targetDevices = root.groupPowerOffDevices.slice(0)
                                    groupPowerDialog.powerOn = false
                                    groupPowerDialog.open()
                                }
                            }
                        }

                        Base.AppText {
                            Layout.fillWidth: true
                            visible: root.selectedGroupKind === "named"
                            text: qsTr("整组执行，不受筛选影响 · 可开机 %1 台 / 可关机 %2 台")
                                .arg(root.groupPowerOnDevices.length).arg(root.groupPowerOffDevices.length)
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                            wrapMode: Text.Wrap
                        }

                        Base.AppScrollPane {
                            objectName: "deviceGroupPowerResults"
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(96, availableContentHeight)
                            visible: root.groupPowerTotalCount > 0

                            Base.AppText {
                                objectName: "deviceGroupPowerStatus"
                                Layout.fillWidth: true
                                text: {
                                    var action = root.groupPowerOn ? qsTr("开机") : qsTr("关机")
                                    var summary = root.groupPowerBusy
                                        ? qsTr("“%1”整组%2：正在发送，已完成 %3/%4 台")
                                            .arg(root.groupPowerName).arg(action)
                                            .arg(root.groupPowerTotalCount - root.groupPowerPendingDevices.length)
                                            .arg(root.groupPowerTotalCount)
                                        : qsTr("“%1”整组%2：已发送 %3 台，失败 %4 台")
                                            .arg(root.groupPowerName).arg(action)
                                            .arg(root.groupPowerSentCount).arg(root.groupPowerErrors.length)
                                    return root.groupPowerErrors.length > 0
                                        ? summary + "\n" + root.groupPowerErrors.join("\n") : summary
                                }
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: root.groupPowerErrors.length > 0
                                    ? UiStyle.TextTone.Danger : UiStyle.TextTone.Secondary
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.pageTheme.density.controlGap

                        Base.AppTextField {
                            objectName: "deviceSearchInput"
                            Layout.fillWidth: true
                            Layout.minimumWidth: 120
                            placeholderText: qsTr("搜索名称或地址")
                            text: root.deviceSearchText
                            onTextEdited: root.deviceSearchText = text
                        }

                        Base.AppSelect {
                            Layout.preferredWidth: 100
                            options: [
                                { "label": qsTr("全部"), "value": "all" },
                                { "label": qsTr("在线"), "value": "online" },
                                { "label": qsTr("离线"), "value": "offline" }
                            ]
                            value: root.deviceStatusFilter
                            onValueSelected: root.deviceStatusFilter = String(nextValue)
                        }

                        Base.AppButton {
                            text: qsTr("紧凑")
                            variant: root.compactDevices
                                ? UiStyle.ButtonVariant.Tonal : UiStyle.ButtonVariant.Ghost
                            onClicked: root.compactDevices = !root.compactDevices
                            ToolTip.visible: hovered
                            ToolTip.text: root.compactDevices ? qsTr("切换为卡片视图") : qsTr("切换为紧凑视图")
                        }
                    }

                    Base.AppText {
                        objectName: "deviceSearchScope"
                        Layout.fillWidth: true
                        visible: root.deviceDisplayMode === "group"
                        text: qsTr("搜索范围：%1").arg(root.selectedGroupTitle)
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Secondary
                        elide: Text.ElideRight
                    }

                    ColumnLayout {
                        objectName: "deviceBatchActions"
                        Layout.fillWidth: true
                        visible: root.selectingDevices
                        spacing: root.pageTheme.density.controlGap

                        Base.AppText {
                            objectName: "deviceBatchSelectionSummary"
                            Layout.fillWidth: true
                            text: root.batchSelectedDeviceIds.length > 0
                                ? qsTr("已选 %1 台 · 当前可见 %2 台")
                                    .arg(root.batchSelectedDeviceIds.length).arg(root.visibleBatchSelectionCount)
                                : qsTr("点击设备卡片进行多选，可继续搜索其他设备")
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: root.batchSelectedDeviceIds.length > 0
                            spacing: root.pageTheme.density.controlGap

                            Base.AppButton {
                                objectName: "deviceBatchAddGroupsButton"
                                text: qsTr("加入分组")
                                variant: UiStyle.ButtonVariant.Primary
                                onClicked: addToGroupsDialog.open()
                            }

                            Base.AppButton {
                                objectName: "deviceBatchRemoveGroupButton"
                                visible: root.selectedGroupKind === "named"
                                text: qsTr("移出当前组")
                                enabled: {
                                    for (var index = 0; index < root.devices.length; ++index) {
                                        var device = root.devices[index]
                                        if (root.batchSelectedDeviceIds.indexOf(String(device.id)) >= 0
                                            && (device.groupNames || []).indexOf(root.selectedGroupName) >= 0)
                                            return true
                                    }
                                    return false
                                }
                                onClicked: {
                                    var groupName = root.selectedGroupName
                                    for (var index = 0; index < root.devices.length; ++index) {
                                        var device = root.devices[index]
                                        if (root.batchSelectedDeviceIds.indexOf(String(device.id)) < 0)
                                            continue
                                        var names = (device.groupNames || []).slice(0)
                                        var groupIndex = names.indexOf(groupName)
                                        if (groupIndex >= 0) {
                                            names.splice(groupIndex, 1)
                                            device.groupNames = names
                                        }
                                    }
                                    root.selectingDevices = false
                                }
                            }

                            Base.AppButton {
                                objectName: "deviceBatchClearSelectionButton"
                                text: qsTr("清空选择")
                                variant: UiStyle.ButtonVariant.Ghost
                                onClicked: root.batchSelectedDeviceIds = []
                            }
                        }
                    }

                    Base.AppScrollPane {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        fillContentWidth: true

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: Math.max(deviceCardFlow.implicitHeight,
                                                     root.filteredDevices.length === 0 ? 160 : 0)

                            Flow {
                                id: deviceCardFlow

                                readonly property real availableWidth: parent ? parent.width : 0
                                readonly property real minimumCardWidth: 240
                                readonly property real maximumCardWidth: 320
                                readonly property int maximumColumnCount: 4
                                readonly property int itemCount: root.filteredDevices.length
                                readonly property int fitColumnCount: Math.max(1,
                                    Math.floor((availableWidth + spacing) / (minimumCardWidth + spacing)))
                                readonly property int columnCount: root.compactDevices ? 1 : Math.min(maximumColumnCount,
                                    fitColumnCount, Math.max(1, itemCount))
                                readonly property real cardWidth: root.compactDevices ? availableWidth : Math.min(maximumCardWidth,
                                    (availableWidth - spacing * (columnCount - 1)) / columnCount)
                                anchors.top: parent.top
                                anchors.left: parent.left
                                width: columnCount * cardWidth + (columnCount - 1) * spacing
                                spacing: root.pageTheme.density.controlGap

                                Repeater {
                                    model: root.filteredDevices

                                    delegate: Item {
                                        id: deviceCardSlot

                                        width: deviceCardFlow.cardWidth
                                        height: (root.compactDevices ? 96 : 180) + deviceGroupTags.implicitHeight + 8

                                        Base.AppCard {
                                            id: deviceRow
                                            objectName: "deviceCard_" + modelData.id

                                        readonly property bool selected: root.selectingDevices
                                            ? root.batchSelectedDeviceIds.indexOf(String(modelData.id)) >= 0
                                            : modelData.id === root.deviceValue("id", "")
                                        readonly property bool online: modelData.online
                                        readonly property var groupNames: modelData.groupNames || []
                                        readonly property var deviceConfig: modelData.configValues || ({})
                                        readonly property int screenColumns: Math.max(0, Number(deviceConfig.screenColumns || 0))
                                        readonly property int screenRows: Math.max(0, Number(deviceConfig.screenRows || 0))
                                        readonly property bool hasScreenLayout: screenColumns > 0 && screenRows > 0

                                        anchors.right: parent.right
                                        width: deviceCardFlow.cardWidth
                                        height: parent.height
                                        text: modelData.name
                                        padding: 0
                                        contentSpacing: 0
                                        checkable: true
                                        checked: selected
                                        emphasizedSelection: root.selectingDevices
                                        selectionTransition: root.selectingDevices ? null : deviceCardSelectionTransition
                                        animateScale: false
                                        onClicked: root.selectDevice(modelData.id)
                                        ToolTip.visible: hovered
                                        ToolTip.delay: 600
                                        ToolTip.text: String(modelData.name || "") + "\n"
                                            + root.deviceAddress(modelData) + " · " + root.protocolsText(modelData && modelData.supportedProtocols)

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            spacing: 0

                                            Item {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true

                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: root.pageTheme.density.panePaddingCompact
                                                    spacing: root.pageTheme.density.controlGap

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        spacing: root.pageTheme.density.controlGap

                                                        Base.AppSurface {
                                                            Layout.preferredWidth: 32
                                                            Layout.preferredHeight: 32
                                                            sizeToContent: false
                                                            surfaceTone: deviceRow.selected
                                                                ? UiStyle.SurfaceTone.Highlight
                                                                : UiStyle.SurfaceTone.Control
                                                            shapeRole: UiStyle.ShapeRole.Control
                                                            strokeWidth: root.selectingDevices ? 1 : 0

                                                            AppComponents.DeviceIcon {
                                                                anchors.centerIn: parent
                                                                visible: !root.selectingDevices
                                                                size: 20
                                                                name: String(modelData.deviceType || "")
                                                            }

                                                            Base.AppText {
                                                                anchors.centerIn: parent
                                                                visible: root.selectingDevices
                                                                text: deviceRow.selected ? "✓" : ""
                                                                styleRole: UiStyle.TypographyRole.BodyM
                                                                textTone: UiStyle.TextTone.Accent
                                                            }
                                                        }

                                                        Base.AppText {
                                                            Layout.fillWidth: true
                                                            text: modelData.name
                                                            styleRole: UiStyle.TypographyRole.BodyM
                                                            overrideWeight: root.pageTheme.typography.weightStrong
                                                            elide: Text.ElideRight
                                                        }
                                                    }

                                                    Item {
                                                        visible: !root.compactDevices
                                                        Layout.fillWidth: true
                                                        Layout.fillHeight: true

                                                        ColumnLayout {
                                                            anchors.centerIn: parent
                                                            spacing: root.pageTheme.density.controlGap

                                                            Grid {
                                                                id: screenLayoutPreview

                                                                readonly property int columnCount: Math.max(1, deviceRow.screenColumns)
                                                                readonly property int rowCount: Math.max(1, deviceRow.screenRows)
                                                                readonly property real maximumWidth: Math.min(150, deviceRow.width - 64)
                                                                readonly property real cellWidth: Math.max(1, Math.min(48,
                                                                                                           (48 - spacing * (rowCount - 1)) / rowCount / 0.58,
                                                                                                           (maximumWidth
                                                                                                            - spacing * (columnCount - 1))
                                                                                                           / columnCount))

                                                                Layout.alignment: Qt.AlignHCenter
                                                                visible: deviceRow.hasScreenLayout
                                                                columns: columnCount
                                                                spacing: 2

                                                                Repeater {
                                                                    model: deviceRow.hasScreenLayout
                                                                        ? screenLayoutPreview.columnCount * screenLayoutPreview.rowCount
                                                                        : 0

                                                                    Rectangle {
                                                                        width: screenLayoutPreview.cellWidth
                                                                        height: Math.round(width * 0.58)
                                                                        radius: 2
                                                                        color: "transparent"
                                                                        border.width: 1
                                                                        border.color: deviceRow.selected
                                                                            ? root.pageTheme.colors.highlightText
                                                                            : root.pageTheme.colors.neutralText
                                                                    }
                                                                }
                                                            }

                                                            Base.AppText {
                                                                Layout.alignment: Qt.AlignHCenter
                                                                text: deviceRow.hasScreenLayout
                                                                    ? qsTr("屏幕布局 %1×%2")
                                                                        .arg(deviceRow.screenColumns)
                                                                        .arg(deviceRow.screenRows)
                                                                    : String(modelData.description || modelData.deviceType || "")
                                                                styleRole: UiStyle.TypographyRole.BodyS
                                                                textTone: UiStyle.TextTone.Secondary
                                                                elide: Text.ElideRight
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            Flow {
                                                id: deviceGroupTags
                                                objectName: "deviceGroups_" + modelData.id
                                                Layout.fillWidth: true
                                                Layout.leftMargin: root.pageTheme.density.panePaddingCompact
                                                Layout.rightMargin: root.pageTheme.density.panePaddingCompact
                                                Layout.bottomMargin: 8
                                                spacing: 4

                                                Repeater {
                                                    model: deviceRow.groupNames.length > 0 ? deviceRow.groupNames : [qsTr("未分组")]
                                                    delegate: Base.AppSurface {
                                                        width: Math.min(cardGroupLabel.implicitWidth + 16, deviceGroupTags.width)
                                                        height: 24
                                                        sizeToContent: false
                                                        surfaceTone: UiStyle.SurfaceTone.Control
                                                        shapeRole: UiStyle.ShapeRole.Control

                                                        Base.AppText {
                                                            id: cardGroupLabel
                                                            anchors.fill: parent
                                                            anchors.leftMargin: 8
                                                            anchors.rightMargin: 8
                                                            text: modelData
                                                            styleRole: UiStyle.TypographyRole.BodyS
                                                            textTone: UiStyle.TextTone.Secondary
                                                            verticalAlignment: Text.AlignVCenter
                                                            elide: Text.ElideRight
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 32
                                                color: "transparent"

                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.top: parent.top
                                                    height: 1
                                                    color: root.pageTheme.colors.borderOverlay
                                                }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: root.pageTheme.density.panePaddingCompact
                                                    anchors.rightMargin: root.pageTheme.density.panePaddingCompact
                                                    spacing: root.pageTheme.density.controlGap

                                                    Base.AppText {
                                                        Layout.fillWidth: true
                                                        text: root.deviceAddress(modelData)
                                                        styleRole: UiStyle.TypographyRole.BodyS
                                                        textTone: UiStyle.TextTone.Secondary
                                                        elide: Text.ElideRight
                                                    }

                                                    Rectangle {
                                                        Layout.preferredWidth: 6
                                                        Layout.preferredHeight: 6
                                                        radius: 3
                                                        color: deviceRow.online
                                                            ? root.pageTheme.colors.successFill
                                                            : root.pageTheme.colors.dangerFill
                                                    }

                                                    Base.AppText {
                                                        text: deviceRow.online ? qsTr("在线") : qsTr("离线")
                                                        styleRole: UiStyle.TypographyRole.BodyS
                                                        textTone: deviceRow.online
                                                            ? UiStyle.TextTone.Success : UiStyle.TextTone.Secondary
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    }
                                }
                            }

                            Base.AppText {
                                anchors.centerIn: parent
                                visible: root.filteredDevices.length === 0
                                text: root.deviceSearchText.trim().length > 0 || root.deviceStatusFilter !== "all"
                                    ? qsTr("没有匹配的设备，请调整搜索或状态筛选")
                                    : qsTr("当前分类暂无设备")
                                width: parent.width
                                wrapMode: Text.Wrap
                                horizontalAlignment: Text.AlignHCenter
                                styleRole: UiStyle.TypographyRole.BodyM
                                textTone: UiStyle.TextTone.Secondary
                            }

                            AppComponents.SubtleCardSelectionTransition {
                                id: deviceCardSelectionTransition

                                anchors.fill: parent
                                selectionColor: root.pageTheme.colors.highlightText
                            }
                        }
                    }
                }
            }

            Base.AppSurface {
                Layout.preferredWidth: 340
                Layout.minimumWidth: 320
                Layout.maximumWidth: 340
                Layout.fillHeight: true
                sizeToContent: false
                surfaceTone: UiStyle.SurfaceTone.Surface

                Base.AppScrollPane {
                    anchors.fill: parent
                    anchors.margins: root.pageTheme.density.panePadding
                    contentSpacing: root.pageTheme.density.controlGap
                    fillContentWidth: true

                    Base.AppSurface {
                        Layout.fillWidth: true
                        sizeToContent: true
                        surfaceTone: UiStyle.SurfaceTone.Section
                        strokeWidth: 0
                        padding: root.pageTheme.density.panePaddingCompact

                        ColumnLayout {
                            width: parent ? parent.width : 0
                            spacing: root.pageTheme.density.controlGap

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.deviceDisplayMode === "group" ? qsTr("分组详情")
                                    : (root.deviceDisplayMode === "type" ? qsTr("类型详情") : qsTr("模板详情"))
                                styleRole: UiStyle.TypographyRole.SectionTitle
                                elide: Text.ElideRight
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.deviceDisplayMode === "group" ? root.selectedGroupTitle
                                    : (root.deviceDisplayMode === "type"
                                        ? (root.selectedDeviceType.length > 0 ? root.selectedDeviceType : qsTr("无类型"))
                                        : root.templateValue("name", qsTr("无模板")))
                                styleRole: UiStyle.TypographyRole.BodyM
                                elide: Text.ElideRight
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.deviceDisplayMode === "type" || root.deviceDisplayMode === "group"
                                    ? qsTr("%1 台设备").arg(root.filteredDevices.length)
                                    : root.protocolsText(root.selectedTemplate && root.selectedTemplate.supportedProtocols ? root.selectedTemplate.supportedProtocols : []) + " - " + root.templateValue("description", "")
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                                elide: Text.ElideRight
                            }

                            Base.AppButton {
                                Layout.fillWidth: true
                                visible: root.deviceDisplayMode === "template"
                                text: qsTr("从模板创建设备")
                                iconName: "resources"
                                variant: UiStyle.ButtonVariant.Primary
                                enabled: !!root.selectedTemplate
                                onClicked: root.createDeviceFromSelectedTemplate()
                            }
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        sizeToContent: true
                        surfaceTone: UiStyle.SurfaceTone.Section
                        strokeWidth: 0
                        padding: root.pageTheme.density.panePaddingCompact

                        ColumnLayout {
                            width: parent ? parent.width : 0
                            spacing: root.pageTheme.density.paneSpacing

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: root.pageTheme.density.controlGap

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: qsTr("设备档案")
                                    styleRole: UiStyle.TypographyRole.SectionTitle
                                    elide: Text.ElideRight
                                }

                                Base.AppButton {
                                    raised: true
                                    size: UiStyle.ButtonSize.Small
                                    objectName: "deviceEditButton"
                                    text: qsTr("编辑")
                                    enabled: root.selectedDeviceInCurrentView
                                    onClicked: root.requestEditSelectedDevice()
                                }

                                Base.AppButton {
                                    variant: UiStyle.ButtonVariant.Danger
                                    size: UiStyle.ButtonSize.Small
                                    text: qsTr("删除")
                                    enabled: root.selectedDeviceInCurrentView
                                    onClicked: root.requestRemoveSelectedDevice()
                                }
                            }

                            ColumnLayout {
                                objectName: "deviceProfile"
                                Layout.fillWidth: true
                                spacing: 6

                                DeviceReadOnlyField {
                                    Layout.fillWidth: true
                                    fieldData: ({ "label": qsTr("模板"), "value": root.objectValue(root.selectedDevice, "templateName", "") })
                                }
                                DeviceReadOnlyField {
                                    Layout.fillWidth: true
                                    fieldData: ({ "label": qsTr("设备类型"), "value": root.objectValue(root.selectedDevice, "deviceType", "") })
                                }
                                DeviceReadOnlyField {
                                    objectName: "deviceProfileName"
                                    Layout.fillWidth: true
                                    fieldData: ({ "label": qsTr("名称"), "value": root.objectValue(root.selectedDevice, "name", "") })
                                }
                                DeviceProfilePairField {
                                    objectName: "deviceProfileProtocolStatus"
                                    Layout.fillWidth: true
                                    fieldData: ({ "customData": {
                                        "leftLabel": qsTr("支持协议"),
                                        "leftValue": root.selectedDevice && root.selectedDevice.supportedProtocols
                                            ? root.selectedDevice.supportedProtocols.join(", ") : "",
                                        "rightLabel": qsTr("状态"),
                                        "rightValue": root.selectedDevice && root.selectedDevice.online !== undefined
                                            ? (root.selectedDevice.online ? qsTr("在线") : qsTr("离线")) : ""
                                    } })
                                }
                                ColumnLayout {
                                    objectName: "deviceProfileGroups"
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Base.AppText {
                                        text: qsTr("所属分组")
                                        styleRole: UiStyle.TypographyRole.BodyS
                                        textTone: UiStyle.TextTone.Secondary
                                    }

                                    Flow {
                                        id: profileGroupTags
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: root.selectedDevice && root.selectedDevice.groupNames
                                                && root.selectedDevice.groupNames.length > 0
                                                ? root.selectedDevice.groupNames : [qsTr("未分组")]
                                            delegate: Base.AppSurface {
                                                width: Math.min(profileGroupLabel.implicitWidth + 16, profileGroupTags.width)
                                                height: 24
                                                sizeToContent: false
                                                surfaceTone: UiStyle.SurfaceTone.Control
                                                shapeRole: UiStyle.ShapeRole.Control

                                                Base.AppText {
                                                    id: profileGroupLabel
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 8
                                                    anchors.rightMargin: 8
                                                    text: modelData
                                                    styleRole: UiStyle.TypographyRole.BodyS
                                                    verticalAlignment: Text.AlignVCenter
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }

                                DeviceReadOnlyField {
                                    objectName: "deviceProfileDescription"
                                    Layout.fillWidth: true
                                    fieldData: ({ "label": qsTr("描述"), "value": root.objectValue(root.selectedDevice, "description", "") })
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: root.pageTheme.density.controlGap

                                Base.AppButton {
                                    objectName: "devicePowerOnButton"
                                    size: UiStyle.ButtonSize.Small
                                    text: qsTr("开机")
                                    enabled: root.deviceManager && root.supportsPowerOn
                                        && root.powerControlDeviceId.length === 0 && !root.groupPowerBusy
                                    onClicked: {
                                        powerDialog.deviceId = String(root.selectedDevice.id)
                                        powerDialog.deviceName = String(root.selectedDevice.name)
                                        powerDialog.powerOn = true
                                        powerDialog.open()
                                    }
                                }

                                Base.AppButton {
                                    objectName: "devicePowerOffButton"
                                    size: UiStyle.ButtonSize.Small
                                    variant: UiStyle.ButtonVariant.Danger
                                    text: qsTr("关机")
                                    enabled: root.deviceManager && root.supportsPowerOff
                                        && root.powerControlDeviceId.length === 0 && !root.groupPowerBusy
                                    onClicked: {
                                        powerDialog.deviceId = String(root.selectedDevice.id)
                                        powerDialog.deviceName = String(root.selectedDevice.name)
                                        powerDialog.powerOn = false
                                        powerDialog.open()
                                    }
                                }
                            }

                            Base.AppText {
                                objectName: "devicePowerStatus"
                                Layout.fillWidth: true
                                visible: root.powerControlStatus.length > 0
                                text: root.powerControlStatus
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        sizeToContent: true
                        surfaceTone: UiStyle.SurfaceTone.Section
                        strokeWidth: 0
                        padding: root.pageTheme.density.panePaddingCompact

                        ColumnLayout {
                            width: parent ? parent.width : 0
                            spacing: root.pageTheme.density.controlGap

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: root.pageTheme.density.controlGap

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: qsTr("设备指令")
                                    styleRole: UiStyle.TypographyRole.SectionTitle
                                    elide: Text.ElideRight
                                }

                                Base.AppText {
                                    visible: root.selectedDeviceInCurrentView
                                    text: String(root.selectedDeviceCommands.length)
                                    styleRole: UiStyle.TypographyRole.BodyS
                                    textTone: UiStyle.TextTone.Secondary
                                }

                                Base.AppButton {
                                    raised: true
                                    size: UiStyle.ButtonSize.Small
                                    text: qsTr("添加")
                                    iconName: "workflow"
                                    enabled: root.selectedDeviceInCurrentView
                                        && root.selectedDevice
                                        && root.selectedDevice.createCommandDraft !== undefined
                                        && root.selectedDevice.commitCommandDraft !== undefined
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

                            Item {
                                Layout.fillWidth: true
                                visible: root.selectedDeviceCommands.length > 0
                                implicitHeight: commandCardLayout.implicitHeight

                                ColumnLayout {
                                    id: commandCardLayout

                                    anchors.fill: parent
                                    spacing: 0

                                    Repeater {
                                        model: root.selectedDeviceCommands

                                        delegate: ColumnLayout {
                                            id: commandEntry

                                            readonly property var commandData: modelData
                                            readonly property bool selected: index === root.selectedCommandIndex
                                            readonly property bool expanded: index === root.expandedCommandIndex
                                            readonly property string executionParametersText: root.executionParameterNames(modelData)
                                            readonly property int inputCount: root.commandInputCount(modelData)

                                            Layout.fillWidth: true
                                            spacing: 0

                                            Base.AppCard {
                                                id: commandRow

                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 56
                                                text: root.commandName(commandEntry.commandData)
                                                padding: 0
                                                surfaceTone: UiStyle.SurfaceTone.Ghost
                                                shapeRole: UiStyle.ShapeRole.Control
                                                checkable: true
                                                checked: commandEntry.selected
                                                selectionTransition: commandCardSelectionTransition
                                                animateScale: false
                                                onClicked: root.selectCommandIndex(index)
                                                ToolTip.visible: hovered
                                                ToolTip.delay: 600
                                                ToolTip.text: text + "\n" + (commandEntry.executionParametersText || qsTr("无需参数"))

                                                Item {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 56

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 10
                                                        anchors.rightMargin: 6
                                                        spacing: root.pageTheme.density.controlGap

                                                        ColumnLayout {
                                                            Layout.fillWidth: true
                                                            spacing: 3

                                                            Base.AppText {
                                                                Layout.fillWidth: true
                                                                text: root.commandName(commandEntry.commandData)
                                                                styleRole: UiStyle.TypographyRole.BodyM
                                                                overrideWeight: root.pageTheme.typography.weightStrong
                                                                elide: Text.ElideRight
                                                            }

                                                            Base.AppText {
                                                                Layout.fillWidth: true
                                                                text: commandEntry.executionParametersText || qsTr("无需参数")
                                                                styleRole: UiStyle.TypographyRole.BodyS
                                                                textTone: UiStyle.TextTone.Secondary
                                                                elide: Text.ElideRight
                                                            }
                                                        }

                                                        Base.AppButton {
                                                            Layout.preferredWidth: 28
                                                            size: UiStyle.ButtonSize.Small
                                                            variant: UiStyle.ButtonVariant.Ghost
                                                            text: commandEntry.expanded ? "▾" : "›"
                                                            onClicked: {
                                                                root.selectCommandIndex(index)
                                                                root.expandedCommandIndex = commandEntry.expanded ? -1 : index
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                visible: commandEntry.expanded
                                                Layout.fillWidth: true
                                                Layout.leftMargin: 10
                                                Layout.rightMargin: 8
                                                Layout.preferredHeight: 1
                                                color: root.pageTheme.colors.borderOverlay
                                            }

                                            ColumnLayout {
                                                visible: commandEntry.expanded
                                                Layout.fillWidth: true
                                                Layout.leftMargin: 10
                                                Layout.rightMargin: 8
                                                Layout.topMargin: 8
                                                Layout.bottomMargin: 8
                                                spacing: root.pageTheme.density.controlGap

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: root.pageTheme.density.controlGap

                                                    Base.AppText {
                                                        id: commandInputCountText

                                                        visible: commandEntry.inputCount > 0
                                                        Layout.fillWidth: true
                                                        text: qsTr("%1 个创建参数").arg(commandEntry.inputCount)
                                                        styleRole: UiStyle.TypographyRole.BodyS
                                                        textTone: UiStyle.TextTone.Secondary
                                                        elide: Text.ElideRight
                                                    }

                                                    Item {
                                                        visible: !commandInputCountText.visible
                                                        Layout.fillWidth: true
                                                    }

                                                    Base.AppButton {
                                                        size: UiStyle.ButtonSize.Small
                                                        variant: UiStyle.ButtonVariant.Ghost
                                                        text: qsTr("编辑")
                                                        visible: commandEntry.commandData && commandEntry.commandData.editable
                                                        onClicked: root.editCommand(commandEntry.commandData)
                                                    }

                                                    Base.AppButton {
                                                        size: UiStyle.ButtonSize.Small
                                                        variant: UiStyle.ButtonVariant.Danger
                                                        text: qsTr("移除")
                                                        onClicked: root.removeSelectedCommand()
                                                    }
                                                }

                                                Loader {
                                                    Layout.fillWidth: true
                                                    active: commandEntry.expanded && commandEntry.inputCount > 0

                                                    sourceComponent: DeviceFieldForm {
                                                        fields: commandEntry.commandData
                                                            ? commandEntry.commandData.creationInputFields
                                                            : []
                                                        readOnly: true
                                                        writeBack: true
                                                        emptyText: qsTr("无创建参数")
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                visible: index < root.selectedDeviceCommands.length - 1
                                                Layout.fillWidth: true
                                                Layout.leftMargin: 10
                                                Layout.rightMargin: 8
                                                Layout.preferredHeight: 1
                                                color: root.pageTheme.colors.borderOverlay
                                            }
                                        }
                                    }
                            }

                            AppComponents.SubtleCardSelectionTransition {
                                id: commandCardSelectionTransition

                                anchors.fill: parent
                                selectionColor: root.pageTheme.colors.highlightText
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

        function openForDevice(device, deviceTemplate, fieldSpecs) {
            active = true
            item.openForDevice(device, deviceTemplate, fieldSpecs)
        }

        sourceComponent: Component {
            DeviceEditDialog {
                id: createDevicePopup
                parent: root
                pageTheme: root.pageTheme
                deviceManager: root.deviceManager
                manualDeviceTypes: root.manualDeviceTypes
                availableGroupNames: root.deviceGroupNames
                preferredDeviceType: root.deviceDisplayMode === "type" ? root.selectedDeviceType : ""
                templateProtocolsText: root.protocolsText(createDevicePopup.deviceTemplate
                    ? createDevicePopup.deviceTemplate.supportedProtocols : [])
                onDeviceCreated: root.selectedDeviceType = createdDeviceType
                onClosed: createDevicePopupLoader.active = false
            }
        }
    }

    ResourceSyncDialog {
        id: resourceSyncDialog
        parent: root
        pageTheme: root.pageTheme
        resourceSyncManager: root.appRuntime ? root.appRuntime.resourceSyncManager : null
        deviceModel: root.deviceModel
    }

    DeviceGroupPickerDialog {
        id: addToGroupsDialog
        parent: root
        pageTheme: root.pageTheme
        availableGroupNames: root.deviceGroupNames
        selectedDeviceCount: root.batchSelectedDeviceIds.length
        onAccepted: {
            for (var index = 0; index < root.devices.length; ++index) {
                var device = root.devices[index]
                if (root.batchSelectedDeviceIds.indexOf(String(device.id)) < 0)
                    continue
                var names = (device.groupNames || []).slice(0)
                for (var groupIndex = 0; groupIndex < addToGroupsDialog.groupNames.length; ++groupIndex) {
                    if (names.indexOf(addToGroupsDialog.groupNames[groupIndex]) < 0)
                        names.push(addToGroupsDialog.groupNames[groupIndex])
                }
                device.groupNames = names
            }
            root.selectingDevices = false
        }
    }

    Base.AppDialog {
        id: groupPowerDialog
        objectName: "deviceGroupPowerDialog"

        property string groupName: ""
        property var targetDevices: []
        property bool powerOn: false

        parent: root
        width: Math.min(460, Math.max(320, parent ? parent.width - 96 : 420))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        title: powerOn ? qsTr("整组开机") : qsTr("整组关机")
        message: powerOn
            ? qsTr("确定向“%1”组中支持开机的 %2 台设备发送开机指令？").arg(groupName).arg(targetDevices.length)
            : qsTr("确定向“%1”组中支持关机的 %2 台设备发送关机指令？这些设备上正在运行的任务将被中断。")
                .arg(groupName).arg(targetDevices.length)
        rejectText: qsTr("取消")
        acceptText: title
        acceptButtonVariant: powerOn ? UiStyle.ButtonVariant.Primary : UiStyle.ButtonVariant.Danger
        acceptEnabled: root.deviceManager && targetDevices.length > 0
            && root.powerControlDeviceId.length === 0 && !root.groupPowerBusy
        onAccepted: root.setGroupPower(groupName, targetDevices, powerOn)
    }

    Base.AppDialog {
        id: powerDialog
        objectName: "devicePowerDialog"

        property string deviceId: ""
        property string deviceName: ""
        property bool powerOn: false

        parent: root
        width: Math.min(420, Math.max(320, parent ? parent.width - 96 : 380))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        title: powerOn ? qsTr("设备开机") : qsTr("设备关机")
        message: powerOn
            ? qsTr("确定向 %1 发送开机指令？").arg(deviceName)
            : qsTr("确定关闭 %1？该设备上正在运行的任务将被中断。").arg(deviceName)
        rejectText: qsTr("取消")
        acceptText: powerOn ? qsTr("开机") : qsTr("关机")
        acceptButtonVariant: powerOn ? UiStyle.ButtonVariant.Primary : UiStyle.ButtonVariant.Danger
        onAccepted: root.setDevicePower(deviceId, deviceName, powerOn)
    }

    Loader {
        id: removeDevicePopupLoader

        active: false

        function openForDevice(device) {
            active = true
            item.openForDevice(device)
        }

        sourceComponent: Component {
            Base.AppDialog {
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
        }

        width: Math.min(420, Math.max(320, parent ? parent.width - 96 : 380))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        title: qsTr("删除设备")
        message: qsTr("确定删除 %1？关联的时间线指令和投影映射也会被移除。").arg(deviceName)
        rejectText: qsTr("取消")
        acceptText: qsTr("删除")
        acceptButtonVariant: UiStyle.ButtonVariant.Danger
        onAccepted: commit()
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

        function openForCommand(device, command) {
            active = true
            item.openForCommand(device, command)
        }

        sourceComponent: Component {
            DeviceCommandDialog {
                id: addCommandPopup
                parent: root
                onClosed: addCommandPopupLoader.active = false

                onCommandAccepted: {
                    if (addCommandPopup.editing)
                        return

                    Qt.callLater(function() {
                        root.selectedCommandIndex = root.selectedDeviceCommands.length - 1
                    })
                }
            }
        }
    }
}
