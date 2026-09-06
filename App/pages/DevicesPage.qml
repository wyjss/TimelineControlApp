import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/components/form" as Form
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
    property string deviceSearchText: ""
    property string deviceStatusFilter: "all"
    property bool compactDevices: false
    property string deviceDisplayMode: "template"
    property string selectedTemplateName: deviceTemplates.length > 0 ? String(deviceTemplates[0].name) : ""
    property string selectedDeviceType: deviceTypes.length > 0 ? String(deviceTypes[0]) : ""
    readonly property var selectedTemplate: findTemplate(selectedTemplateName)
    readonly property var groupItems: deviceDisplayMode === "type" ? deviceTypes : deviceTemplates
    readonly property var filteredDevices: buildFilteredDevices()
    readonly property bool selectedDeviceInCurrentView: selectedDevice
        && selectedDevice.id !== undefined
        && filteredDevices.some(function(device) {
            return String(device.id) === String(selectedDevice.id)
        })

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
    onFilteredDevicesChanged: Qt.callLater(ensureSelectedDeviceForView)

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
        var query = deviceSearchText.trim().toLowerCase()
        var result = []
        for (var index = 0; index < devices.length; ++index) {
            var device = devices[index]
            if (query.length > 0
                    && (String(device.name || "") + " " + deviceAddress(device)).toLowerCase().indexOf(query) < 0)
                continue
            if (deviceStatusFilter !== "all" && !!device.online !== (deviceStatusFilter === "online"))
                continue
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
            || selectedDevice.commitCommandDraft === undefined) {
            return
        }

        addCommandPopupLoader.openForDevice(selectedDevice)
    }

    function editCommand(command) {
        if (!selectedDeviceInCurrentView || !selectedDevice || !command)
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

    function groupIconName(groupData) {
        if (deviceDisplayMode === "type")
            return String(groupData || "")

        var deviceType = String(groupData.deviceType || "")
        return deviceType.length > 0 ? deviceType : String(groupData.name || "")
    }

    function groupDescription(groupData) {
        if (deviceDisplayMode === "type")
            return qsTr("%1 台设备").arg(deviceCountForGroup(groupData))

        var deviceType = String(groupData.deviceType || "")
        var protocols = protocolsText(groupData.supportedProtocols, " · ")
        return deviceType.length > 0 && protocols.length > 0
            ? deviceType + " · " + protocols
            : deviceType + protocols
    }

    function groupFootnote(groupData) {
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

    function deviceProtocols(device) {
        return protocolsText(device && device.supportedProtocols ? device.supportedProtocols : [])
    }

    function protocolsText(protocols, separator) {
        return (protocols || []).map(function(protocol) {
            return String(protocol).toLowerCase() === "internal" ? qsTr("无协议") : String(protocol)
        }).join(separator || ", ")
    }

    function groupSelected(groupData) {
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
            var nextValue = deviceDisplayMode === "type"
                ? String(devices[index].deviceType || "")
                : String(devices[index].templateName || "")
            if (nextValue === groupValue)
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
                borderOverride: root.pageTheme.colors.borderOverlay

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.pageTheme.density.panePadding
                    spacing: root.pageTheme.density.paneSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.pageTheme.density.controlGap

                        Base.AppText {
                            Layout.fillWidth: true
                            text: root.deviceDisplayMode === "type" ? qsTr("设备类型") : qsTr("设备模板")
                            styleRole: UiStyle.TypographyRole.SectionTitle
                        }

                        Base.AppText {
                            text: root.deviceDisplayMode === "type"
                                ? qsTr("%1 个类型").arg(root.groupItems.length)
                                : qsTr("%1 个模板").arg(root.deviceTemplates.length)
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                        }
                    }

                    Base.AppSegmentedControl {
                        Layout.fillWidth: true
                        surfaceTone: UiStyle.SurfaceTone.Section
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
                                                size: 32
                                                name: root.groupIconName(modelData)
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
                borderOverride: root.pageTheme.colors.borderOverlay

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.pageTheme.density.panePadding
                    spacing: root.pageTheme.density.paneSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.pageTheme.density.paneSpacing

                        Base.AppText {
                            text: qsTr("设备实例")
                            styleRole: UiStyle.TypographyRole.SectionTitle
                        }

                        Base.AppText {
                            text: qsTr("%1 台").arg(root.filteredDevices.length)
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.pageTheme.density.controlGap

                        Base.AppTextField {
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
                            text: root.compactDevices ? qsTr("卡片") : qsTr("紧凑")
                            variant: UiStyle.ButtonVariant.Ghost
                            onClicked: root.compactDevices = !root.compactDevices
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
                                        height: root.compactDevices ? 96 : 180

                                        Base.AppCard {
                                            id: deviceRow

                                        readonly property bool selected: modelData.id === root.deviceValue("id", "")
                                        readonly property bool online: modelData.online
                                        readonly property var deviceConfig: modelData.configValues || ({})
                                        readonly property int screenColumns: Math.max(0, Number(deviceConfig.screenColumns || 0))
                                        readonly property int screenRows: Math.max(0, Number(deviceConfig.screenRows || 0))
                                        readonly property bool hasScreenLayout: screenColumns > 0 && screenRows > 0

                                        anchors.right: parent.right
                                        width: deviceCardFlow.cardWidth
                                        height: parent.height
                                        opacity: modelData.filteredOut ? 0.46 : 1
                                        text: modelData.name
                                        padding: 0
                                        contentSpacing: 0
                                        checkable: true
                                        checked: selected
                                        emphasizedSelection: false
                                        selectionTransition: deviceCardSelectionTransition
                                        animateScale: false
                                        onClicked: root.selectDevice(modelData.id)

                                        Behavior on opacity {
                                            NumberAnimation { duration: 120 }
                                        }

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
                                                            strokeWidth: 0

                                                            AppComponents.DeviceIcon {
                                                                anchors.centerIn: parent
                                                                size: 20
                                                                name: String(modelData.deviceType || "")
                                                            }
                                                        }

                                                        Base.AppText {
                                                            Layout.fillWidth: true
                                                            text: modelData.name
                                                            styleRole: UiStyle.TypographyRole.BodyM
                                                            elide: Text.ElideRight
                                                        }

                                                        Rectangle {
                                                            Layout.preferredWidth: 8
                                                            Layout.preferredHeight: 8
                                                            radius: 4
                                                            color: deviceRow.online
                                                                ? root.pageTheme.colors.successFill
                                                                : root.pageTheme.colors.dangerFill
                                                        }

                                                        Base.AppText {
                                                            text: deviceRow.online ? qsTr("在线") : qsTr("离线")
                                                            styleRole: UiStyle.TypographyRole.BodyS
                                                            textTone: deviceRow.online
                                                                ? UiStyle.TextTone.Success
                                                                : UiStyle.TextTone.Danger
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

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 32
                                                color: deviceRow.selected
                                                    ? Qt.darker(root.pageTheme.colors.highlightSoft, 1.14)
                                                    : root.pageTheme.colors.backgroundWindowVariant

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

                                                    Base.AppText {
                                                        Layout.maximumWidth: parent.width / 2
                                                        text: root.deviceProtocols(modelData).replace(/, /g, " · ")
                                                        styleRole: UiStyle.TypographyRole.BodyS
                                                        textTone: UiStyle.TextTone.Secondary
                                                        elide: Text.ElideRight
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
                borderOverride: root.pageTheme.colors.borderOverlay

                Base.AppScrollPane {
                    anchors.fill: parent
                    anchors.margins: root.pageTheme.density.panePadding
                    contentSpacing: root.pageTheme.density.controlGap
                    fillContentWidth: true

                    Base.AppSurface {
                        Layout.fillWidth: true
                        sizeToContent: true
                        surfaceTone: UiStyle.SurfaceTone.Section
                        strokeWidth: 1
                        borderOverride: root.pageTheme.colors.borderOverlay
                        padding: root.pageTheme.density.panePaddingCompact

                        ColumnLayout {
                            width: parent ? parent.width : 0
                            spacing: root.pageTheme.density.controlGap

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.deviceDisplayMode === "type" ? qsTr("类型详情") : qsTr("模板详情")
                                styleRole: UiStyle.TypographyRole.SectionTitle
                                elide: Text.ElideRight
                            }

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
                        strokeWidth: 1
                        borderOverride: root.pageTheme.colors.borderOverlay
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
                                    text: qsTr("编辑")
                                    enabled: root.selectedDeviceInCurrentView
                                    onClicked: root.requestEditSelectedDevice()
                                }

                                Base.AppButton {
                                    variant: UiStyle.ButtonVariant.Danger
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
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        sizeToContent: true
                        surfaceTone: UiStyle.SurfaceTone.Section
                        strokeWidth: 1
                        borderOverride: root.pageTheme.colors.borderOverlay
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

                                Base.AppSurface {
                                    visible: root.selectedDeviceInCurrentView
                                    Layout.preferredHeight: 28
                                    sizeToContent: true
                                    surfaceTone: UiStyle.SurfaceTone.Ghost
                                    shapeRole: UiStyle.ShapeRole.Pill
                                    strokeWidth: 1
                                    borderOverride: root.pageTheme.colors.borderOverlay
                                    padding: 10

                                    Base.AppText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("%1 条指令").arg(root.selectedDeviceCommands.length)
                                        styleRole: UiStyle.TypographyRole.BodyS
                                        textTone: UiStyle.TextTone.Accent
                                        elide: Text.ElideRight
                                    }
                                }

                                Base.AppButton {
                                    raised: true
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
                                            opacity: commandData && commandData.filteredOut ? 0.46 : 1

                                            Behavior on opacity {
                                                NumberAnimation { duration: 120 }
                                            }

                                            Base.AppCard {
                                                id: commandRow

                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 40
                                                text: root.commandName(commandEntry.commandData)
                                                padding: 0
                                                surfaceTone: UiStyle.SurfaceTone.Ghost
                                                shapeRole: UiStyle.ShapeRole.Control
                                                checkable: true
                                                checked: commandEntry.selected
                                                selectionTransition: commandCardSelectionTransition
                                                animateScale: false
                                                onClicked: root.selectCommandIndex(index)

                                                Item {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 40

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 10
                                                        anchors.rightMargin: 6
                                                        spacing: root.pageTheme.density.controlGap

                                                        Base.AppText {
                                                            Layout.preferredWidth: 88
                                                            text: root.commandName(commandEntry.commandData)
                                                            styleRole: UiStyle.TypographyRole.BodyM
                                                            elide: Text.ElideRight
                                                        }

                                                        Base.AppText {
                                                            Layout.fillWidth: true
                                                            text: commandEntry.executionParametersText
                                                            styleRole: UiStyle.TypographyRole.BodyS
                                                            textTone: UiStyle.TextTone.Info
                                                            elide: Text.ElideRight
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
            Base.AppDialog {
                id: createDevicePopup
                parent: root
                onClosed: createDevicePopupLoader.active = false

        property var deviceTemplate: null
        property var editingDevice: null
        property var fieldSpecs: []
        property string deviceName: ""
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
                if (deviceManager.updateDevice(editingDevice, deviceName, buildConfigValues()))
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
                root.selectedDeviceType = deviceType
                close()
            }
        }

        width: Math.min(560, Math.max(420, parent ? parent.width - 96 : 520))
        maximumDialogHeight: Math.min(620, Math.max(360, parent ? parent.height - 96 : 480))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        title: editing ? qsTr("编辑设备") : qsTr("创建设备")
        message: deviceTemplate
            ? String(deviceTemplate.name) + " / " + root.protocolsText(deviceTemplate.supportedProtocols)
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
                text: createDevicePopup.deviceName
                placeholderText: qsTr("设备名称")
                onTextChanged: createDevicePopup.deviceName = text
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
                visible: createDevicePopup.editing || createDevicePopup.templateHasDeviceType
                Layout.fillWidth: true
                enabled: false
                text: createDevicePopup.deviceType
            }

            RowLayout {
                visible: !createDevicePopup.editing && !createDevicePopup.templateHasDeviceType
                Layout.fillWidth: true
                spacing: root.pageTheme.density.controlGap

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
            textTone: UiStyle.TextTone.Danger
            elide: Text.ElideRight
        }

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
