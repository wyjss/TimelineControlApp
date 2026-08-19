import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/theme" as Theme
import "timeline" as Timeline

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
    property var timelineCommandModel: appRuntime && appRuntime.timelineCommandModel ? appRuntime.timelineCommandModel : null
    property var timelineController: appRuntime && appRuntime.timelineController ? appRuntime.timelineController : null
    property var deviceManager: appRuntime && appRuntime.deviceManager ? appRuntime.deviceManager : null
    property var deviceModel: appRuntime && appRuntime.deviceModel ? appRuntime.deviceModel : null
    property var pcPreviewGenerator: typeof pcTimelinePreviewGenerator !== "undefined"
        ? pcTimelinePreviewGenerator
        : null
    readonly property int preStartTimelineDurationMs: 24 * 60 * 60 * 1000
    readonly property int timelineDurationMs: timelineController ? timelineController.durationMs : preStartTimelineDurationMs
    readonly property int timelineTrackLabelWidth: 224
    readonly property var devices: deviceModel ? deviceModel.devices : []
    readonly property var deviceCommands: selectedTimelineDevice && selectedTimelineDevice.commands ? selectedTimelineDevice.commands : []
    readonly property var timelineCommands: timelineCommandModel && timelineCommandModel.commands ? timelineCommandModel.commands : []
    readonly property var visibleTimelineCommands: buildVisibleTimelineCommands()
    readonly property string selectedTimelineCommandId: timelineCommandModel ? timelineCommandModel.selectedCommandId : ""
    readonly property bool timelineStopped: !timelineController || timelineController.state === 0
    readonly property var selectedCommand: selectedCommandIndex >= 0
        && selectedCommandIndex < deviceCommands.length
        ? deviceCommands[selectedCommandIndex]
        : null
    readonly property int timelineCurrentTimeMs: timelineController ? timelineController.currentTimeMs : fallbackTimelineCurrentTimeMs
    property int fallbackTimelineCurrentTimeMs: 0
    property real timelineScrollX: 0
    property real timelineTimeScale: 1.0
    property string selectedTimelineDeviceId: ""
    property var selectedTimelineDevice: null
    property int selectedCommandIndex: -1
    property string timelineCommandListMode: "all"
    property string executionStatusText: ""

    onDevicesChanged: ensureSelectedTimelineDevice()
    onSelectedTimelineDeviceIdChanged: {
        updateSelectedTimelineDevice()
        selectedCommandIndex = -1
        ensureSelectedCommand()
    }
    onDeviceCommandsChanged: ensureSelectedCommand()

    Component.onCompleted: {
        ensureSelectedTimelineDevice()
        ensureSelectedCommand()
    }

    function deviceForId(deviceId) {
        var normalizedDeviceId = String(deviceId || "")
        for (var index = 0; index < devices.length; ++index) {
            if (String(devices[index].id || "") === normalizedDeviceId)
                return devices[index]
        }

        return null
    }

    function ensureSelectedTimelineDevice() {
        if (devices.length === 0) {
            selectedTimelineDeviceId = ""
            selectedTimelineDevice = null
            return
        }

        if (!deviceForId(selectedTimelineDeviceId)) {
            selectTimelineDevice(String(devices[0].id || ""))
            return
        }

        updateSelectedTimelineDevice()
    }

    function updateSelectedTimelineDevice() {
        selectedTimelineDevice = deviceForId(selectedTimelineDeviceId)
    }

    function selectTimelineDevice(deviceId) {
        selectedTimelineDeviceId = String(deviceId || "")
        if (deviceModel && selectedTimelineDeviceId.length > 0)
            deviceModel.selectDevice(selectedTimelineDeviceId)
    }

    function ensureSelectedCommand() {
        if (deviceCommands.length === 0) {
            selectedCommandIndex = -1
            return
        }

        if (selectedCommandIndex < 0 || selectedCommandIndex >= deviceCommands.length)
            selectedCommandIndex = 0
    }

    function selectCommandIndex(commandIndex) {
        selectedCommandIndex = commandIndex >= 0 && commandIndex < deviceCommands.length
            ? commandIndex
            : -1
    }

    function addSelectedCommandAtCurrentTime() {
        if (!timelineStopped)
            return

        if (!timelineCommandModel || !selectedTimelineDevice || !selectedCommand) {
            executionStatusText = qsTr("请先选择设备指令")
            return
        }

        var startTimeMs = Math.max(0, Math.round(timelineCurrentTimeMs))
        var executionFields = selectedCommand.executionInputFields || []
        if (executionFields.length > 0) {
            addTimelineCommandPopup.openForCommand(selectedTimelineDevice, selectedCommand, startTimeMs)
            return
        }

        addTimelineCommand(selectedTimelineDevice, selectedCommand, startTimeMs, {})
    }

    function addTimelineCommand(targetDevice, targetCommand, startTimeMs, executionValues) {
        if (!timelineStopped || !timelineCommandModel)
            return

        var extraParams = {
            "targetDeviceName": deviceName(targetDevice),
            "targetDeviceAddress": deviceAddress(targetDevice)
        }
        if (executionValues && Object.keys(executionValues).length > 0)
            extraParams.executionInputFields = executionValues

        timelineCommandModel.addDeviceCommand(startTimeMs,
                                              String(targetDevice.id || ""),
                                              targetCommand,
                                              extraParams)
        executionStatusText = qsTr("已在 %2 ms 添加 %1").arg(commandName(targetCommand)).arg(startTimeMs)
    }

    function buildVisibleTimelineCommands() {
        var result = []
        for (var index = 0; index < timelineCommands.length; ++index) {
            var command = timelineCommands[index]
            if (timelineCommandListMode === "device"
                && String(command.targetDeviceId || "") !== selectedTimelineDeviceId)
                continue

            result.push(command)
        }
        return result
    }

    function selectTimelineCommand(command) {
        if (!command)
            return

        if (timelineCommandModel)
            timelineCommandModel.selectedCommandId = String(command.id || "")
        if (String(command.targetDeviceId || "").length > 0)
            selectTimelineDevice(String(command.targetDeviceId || ""))
        setTimelineCurrentTimeMs(command.startTimeMs)
    }

    function editTimelineCommand(command) {
        if (!timelineStopped || !timelineCommandModel || !command)
            return

        addTimelineCommandPopup.openForTimelineCommand(command)
    }

    function setTimelineCurrentTimeMs(currentTimeMs) {
        if (!timelineStopped)
            return

        var normalizedTimeMs = Math.max(0, Math.round(Number(currentTimeMs || 0)))
        if (timelineController)
            timelineController.seek(normalizedTimeMs)
        else
            fallbackTimelineCurrentTimeMs = normalizedTimeMs
    }

    function deviceName(device) {
        if (!device)
            return qsTr("未分配")

        var name = String(device.name || "").trim()
        return name.length > 0 ? name : String(device.id || qsTr("设备"))
    }

    function deviceAddress(device) {
        if (!device)
            return qsTr("无地址")

        var values = device.configValues || {}
        var ip = String(values.ip || "").trim()
        var port = String(values.port || "").trim()
        var address = ip.length > 0 && port.length > 0 ? ip + ":" + port : ip
        if (address.length === 0)
            address = String(values.serialPort || "").trim()
        return address.length > 0 ? address : qsTr("未分配")
    }

    function deviceMeta(device) {
        if (!device)
            return ""

        var parts = []
        var protocolText = String((device.supportedProtocols || []).join(", ")).trim()
        var typeText = (device.supportsProtocol !== undefined && device.supportsProtocol("pc"))
            ? "PC"
            : String(device.deviceType || "").trim()
        var statusText = String(device.status || "").trim()
        if (typeText.length > 0)
            parts.push(typeText)
        if (protocolText.length > 0)
            parts.push(protocolText)
        if (statusText.length > 0)
            parts.push(statusText)
        return parts.join(" / ")
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

    function commandFieldValue(command, key, fallback) {
        var fields = command ? command.creationInputFields || [] : []
        for (var index = 0; index < fields.length; ++index) {
            if (String(fields[index].key || "") === key)
                return fields[index].value
        }
        return fallback
    }

    function commandSummary(command) {
        var protocol = commandProtocol(command).toLowerCase()
        if (protocol === "http" || protocol === "pc") {
            var address = String(commandFieldValue(command, "ip", "") || "").trim()
            var port = String(commandFieldValue(command, "port", "") || "").trim()
            var path = String(commandFieldValue(command, "apiPath", "") || "").trim()
            var method = String(commandFieldValue(command, "httpMethod", "") || "").trim()
            if (address.length > 0 && port.length > 0)
                address += ":" + port
            var httpSummary = [method, address, path].filter(function(part) { return part.length > 0 }).join(" / ")
            return httpSummary.length > 0 ? httpSummary : commandProtocol(command)
        }

        if (protocol === "serial") {
            var serialPort = String(commandFieldValue(command, "serialPort", "") || "").trim()
            var baudRate = String(commandFieldValue(command, "baudRate", "") || "").trim()
            var serialPayload = String(commandFieldValue(command, "serialPayload", "") || "").trim()
            var serialSummary = [serialPort, baudRate, serialPayload].filter(function(part) { return part.length > 0 }).join(" / ")
            return serialSummary.length > 0 ? serialSummary : commandProtocol(command)
        }

        if (protocol === "dmx512") {
            var channel = String(commandFieldValue(command, "channel", "") || "").trim()
            var value = String(commandFieldValue(command, "value", "") || "").trim()
            var dmxSummary = [channel.length > 0 ? qsTr("通道 %1").arg(channel) : "",
                              value.length > 0 ? qsTr("值 %1").arg(value) : ""]
                .filter(function(part) { return part.length > 0 }).join(" / ")
            return dmxSummary.length > 0 ? dmxSummary : commandProtocol(command)
        }

        return commandProtocol(command)
    }

    function formatTimelineMs(ms) {
        var totalMs = Math.max(0, Math.round(Number(ms || 0)))
        var totalSeconds = Math.floor(totalMs / 1000)
        var minutes = Math.floor(totalSeconds / 60)
        var seconds = totalSeconds % 60
        return qsTr("%1:%2").arg(minutes).arg(seconds < 10 ? "0" + seconds : seconds)
    }

    function timelineCommandMeta(command) {
        if (!command)
            return ""

        var device = deviceForId(String(command.targetDeviceId || ""))
        return [formatTimelineMs(command.startTimeMs), deviceName(device)]
            .filter(function(part) { return String(part || "").length > 0 }).join(" / ")
    }

    function timelineCommandExecutionSummary(command) {
        var values = command && command.commandParams
            ? command.commandParams.executionInputFields || {}
            : {}
        var parts = []
        Object.keys(values).forEach(function(key) {
            var value = values[key]
            if (value === undefined || value === null || String(value).length === 0)
                return
            if (typeof value === "boolean")
                value = value ? qsTr("是") : qsTr("否")
            parts.push(String(value))
        })
        return parts.join(" / ")
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pageTheme.density.panePadding
        anchors.topMargin: 0
        spacing: 14

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            columnSpacing: 14
            rowSpacing: 14

            Base.AppSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 520
                sizeToContent: false
                surfaceTone: UiStyle.SurfaceTone.Surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Base.AppText {
                        text: qsTr("控制轨")
                        styleRole: UiStyle.TypographyRole.SectionTitle
                    }

                    Timeline.TimelineRuler {
                        id: timelineRuler

                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        durationMs: root.timelineDurationMs
                        currentTimeMs: root.timelineCurrentTimeMs
                        scrollX: root.timelineScrollX
                        trackLeftX: root.timelineTrackLabelWidth
                        startTimeX: root.timelineTrackLabelWidth + 20
                        timeScale: root.timelineTimeScale
                        currentTimeDragEnabled: root.timelineStopped
                        onScrollXChangeRequested: function(nextScrollX) {
                            root.timelineScrollX = nextScrollX
                        }
                        onCurrentTimeMsChangeRequested: function(nextCurrentTimeMs) {
                            root.setTimelineCurrentTimeMs(nextCurrentTimeMs)
                        }
                        onTimeScaleChangeRequested: function(nextTimeScale) {
                            root.timelineTimeScale = nextTimeScale
                        }
                    }

                    Timeline.TimelineDeviceTrackArea {
                        id: deviceTrackArea

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 220
                        ruler: timelineRuler
                        devices: root.devices
                        commandModel: root.timelineCommandModel
                        childTracksByParentId: root.timelineCommandModel
                            ? root.timelineCommandModel.childTracksByParentId
                            : ({})
                        labelWidth: root.timelineTrackLabelWidth
                        selectedDeviceId: root.selectedTimelineDeviceId
                        onTrackSelected: function(targetDeviceId) {
                            root.selectTimelineDevice(targetDeviceId)
                        }
                    }
                }
            }

            Base.AppSurface {
                Layout.preferredWidth: 340
                Layout.fillHeight: true
                sizeToContent: false
                surfaceTone: UiStyle.SurfaceTone.Surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    Base.AppText {
                        text: qsTr("执行")
                        styleRole: UiStyle.TypographyRole.SectionTitle
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Base.AppText {
                            Layout.fillWidth: true
                            text: qsTr("指令")
                            styleRole: UiStyle.TypographyRole.BodyM
                            textTone: UiStyle.TextTone.Primary
                            elide: Text.ElideRight
                        }

                        Base.AppText {
                            text: qsTr("%1").arg(root.deviceCommands.length)
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 176
                        Layout.preferredHeight: 260
                        sizeToContent: false
                        surfaceTone: UiStyle.SurfaceTone.Section

                        ListView {
                            id: commandList

                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            spacing: 6
                            model: root.deviceCommands
                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            delegate: Base.AppCard {
                                id: commandRow

                                readonly property var commandData: modelData
                                readonly property bool selected: index === root.selectedCommandIndex

                                width: commandList.width
                                height: 56
                                text: root.commandName(commandRow.commandData)
                                surfaceTone: UiStyle.SurfaceTone.Ghost
                                leftPadding: 18
                                rightPadding: 12
                                topPadding: 7
                                bottomPadding: 7
                                checkable: true
                                checked: selected
                                emphasizedSelection: true
                                selectionTransition: commandCardSelectionTransition
                                animateScale: false
                                onClicked: root.selectCommandIndex(index)

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Base.AppText {
                                            Layout.fillWidth: true
                                            text: root.commandName(commandRow.commandData)
                                            styleRole: UiStyle.TypographyRole.BodyM
                                            colorOverride: commandRow.selected
                                                ? root.pageTheme.colors.inverseText
                                                : undefined
                                            elide: Text.ElideRight
                                        }

                                        Base.AppText {
                                            Layout.maximumWidth: 120
                                            text: root.executionParameterNames(commandRow.commandData)
                                            visible: text.length > 0
                                            styleRole: UiStyle.TypographyRole.BodyS
                                            textTone: UiStyle.TextTone.Info
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: root.commandSummary(commandRow.commandData)
                                        styleRole: UiStyle.TypographyRole.BodyS
                                        textTone: UiStyle.TextTone.Secondary
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        Base.AppCardSelectionTransition {
                            id: commandCardSelectionTransition

                            anchors.fill: commandList
                            clip: true
                        }

                        Base.AppText {
                            anchors.centerIn: parent
                            visible: root.deviceCommands.length === 0
                            text: qsTr("暂无指令")
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                        }
                    }

                    Base.AppButton {
                        Layout.fillWidth: true
                        text: qsTr("添加所选")
                        iconName: "workflow"
                        enabled: root.timelineStopped && root.timelineCommandModel
                            && root.selectedTimelineDevice && root.selectedCommand
                        onClicked: root.addSelectedCommandAtCurrentTime()
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        text: root.executionStatusText
                        visible: root.executionStatusText.length > 0
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Accent
                        elide: Text.ElideRight
                    }
                }
            }

            Base.AppSurface {
                Layout.preferredWidth: 304
                Layout.fillHeight: true
                sizeToContent: false
                surfaceTone: UiStyle.SurfaceTone.Surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Base.AppText {
                            Layout.fillWidth: true
                            text: qsTr("时间线指令")
                            styleRole: UiStyle.TypographyRole.SectionTitle
                            elide: Text.ElideRight
                        }

                        Base.AppText {
                            text: qsTr("%1").arg(root.visibleTimelineCommands.length)
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                        }
                    }

                    Base.AppSegmentedControl {
                        Layout.fillWidth: true
                        options: [
                            { "label": qsTr("全部"), "value": "all" },
                            { "label": qsTr("设备"), "value": "device" }
                        ]
                        value: root.timelineCommandListMode
                        onValueSelected: function(nextValue) {
                            root.timelineCommandListMode = String(nextValue || "all")
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 220
                        sizeToContent: false
                        surfaceTone: UiStyle.SurfaceTone.Section

                        ListView {
                            id: timelineCommandList

                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            spacing: 6
                            model: root.visibleTimelineCommands
                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            delegate: Base.AppCard {
                                id: timelineCommandRow

                                readonly property var commandData: modelData
                                readonly property bool selected: String(commandData.id || "") === root.selectedTimelineCommandId
                                readonly property string executionSummary: root.timelineCommandExecutionSummary(commandData)

                                width: timelineCommandList.width
                                height: executionSummary.length > 0 ? 74 : 56
                                text: String(timelineCommandRow.commandData.commandName || qsTr("指令"))
                                surfaceTone: UiStyle.SurfaceTone.Ghost
                                leftPadding: 12
                                rightPadding: 12
                                topPadding: 7
                                bottomPadding: 7
                                checkable: true
                                checked: selected
                                emphasizedSelection: true
                                selectionTransition: timelineCommandCardSelectionTransition
                                animateScale: false
                                onClicked: root.selectTimelineCommand(timelineCommandRow.commandData)

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 8

                                    Rectangle {
                                        visible: !timelineCommandRow.selected
                                        Layout.preferredWidth: 3
                                        Layout.fillHeight: true
                                        radius: 2
                                        color: String(timelineCommandRow.commandData && timelineCommandRow.commandData.stateColor
                                            ? timelineCommandRow.commandData.stateColor
                                            : root.pageTheme.colors.border)
                                        opacity: timelineCommandRow.hovered ? 0.44 : 0.18
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Base.AppText {
                                            Layout.fillWidth: true
                                            text: String(timelineCommandRow.commandData.commandName || qsTr("指令"))
                                            styleRole: UiStyle.TypographyRole.BodyM
                                            colorOverride: timelineCommandRow.selected
                                                ? root.pageTheme.colors.inverseText
                                                : undefined
                                            elide: Text.ElideRight
                                        }

                                        Base.AppText {
                                            Layout.fillWidth: true
                                            text: root.timelineCommandMeta(timelineCommandRow.commandData)
                                                + " / "
                                                + String(timelineCommandRow.commandData && timelineCommandRow.commandData.stateText
                                                    ? timelineCommandRow.commandData.stateText
                                                    : qsTr("待执行"))
                                            styleRole: UiStyle.TypographyRole.BodyS
                                            textTone: UiStyle.TextTone.Secondary
                                            elide: Text.ElideRight
                                        }

                                        Base.AppText {
                                            Layout.fillWidth: true
                                            visible: timelineCommandRow.executionSummary.length > 0
                                            text: timelineCommandRow.executionSummary
                                            styleRole: UiStyle.TypographyRole.BodyS
                                            textTone: UiStyle.TextTone.Accent
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Base.AppButton {
                                        visible: timelineCommandRow.selected
                                        text: qsTr("编辑")
                                        enabled: root.timelineStopped
                                        onClicked: root.editTimelineCommand(timelineCommandRow.commandData)
                                    }

                                    Base.AppButton {
                                        variant: UiStyle.ButtonVariant.Danger
                                        visible: timelineCommandRow.selected
                                        text: qsTr("删除")
                                        enabled: root.timelineStopped
                                        onClicked: {
                                            if (root.timelineCommandModel)
                                                root.timelineCommandModel.removeCommand(timelineCommandRow.commandData)
                                        }
                                    }
                                }
                            }
                        }

                        Base.AppCardSelectionTransition {
                            id: timelineCommandCardSelectionTransition

                            anchors.fill: timelineCommandList
                            clip: true
                        }

                        Base.AppText {
                            anchors.centerIn: parent
                            visible: root.visibleTimelineCommands.length === 0
                            text: qsTr("暂无时间线指令")
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 188
                        visible: root.pcPreviewGenerator && root.pcPreviewGenerator.pcDevice
                        sizeToContent: false
                        surfaceTone: UiStyle.SurfaceTone.Section

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: qsTr("PC 预览")
                                    styleRole: UiStyle.TypographyRole.BodyM
                                }

                                Base.AppText {
                                    text: root.pcPreviewGenerator && root.pcPreviewGenerator.busy
                                        ? qsTr("生成中…")
                                        : qsTr("%1 ms").arg(root.pcPreviewGenerator
                                            ? root.pcPreviewGenerator.previewTimeMs
                                            : 0)
                                    styleRole: UiStyle.TypographyRole.BodyS
                                    textTone: UiStyle.TextTone.Secondary
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Image {
                                    anchors.fill: parent
                                    source: root.pcPreviewGenerator
                                        ? root.pcPreviewGenerator.previewUrl
                                        : ""
                                    fillMode: Image.PreserveAspectFit
                                    cache: false
                                }

                                BusyIndicator {
                                    anchors.centerIn: parent
                                    running: visible
                                    visible: root.pcPreviewGenerator && root.pcPreviewGenerator.busy
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Base.AppDialog {
        id: addTimelineCommandPopup

        parent: root

        property var targetDevice: null
        property var targetCommand: null
        property var editingTimelineCommand: null
        property var editDraft: null
        property int targetStartTimeMs: 0
        property bool validationVisible: false
        readonly property bool editing: editingTimelineCommand !== null
        readonly property var executionFields: targetCommand
            ? targetCommand.executionInputFields || []
            : []
        readonly property bool formValid: executionFieldForm.valid

        function openForCommand(nextDevice, nextCommand, nextStartTimeMs) {
            open()

            Qt.callLater(function() {
                clearEditDraft()
                editingTimelineCommand = null
                targetDevice = nextDevice
                targetCommand = nextCommand
                targetStartTimeMs = nextStartTimeMs
                validationVisible = false
                executionFieldForm.values = {}
                executionFieldForm.resetValues()
            })
        }

        function clearEditDraft() {
            var draft = editDraft
            editDraft = null
            if (timelineCommandModel && draft)
                timelineCommandModel.deleteEditDraft(draft)
        }

        function openForTimelineCommand(command) {
            if (!timelineCommandModel || !command)
                return

            open()

            Qt.callLater(function() {
                clearEditDraft()
                editingTimelineCommand = command
                editDraft = timelineCommandModel.createEditDraft(command)
                if (!editDraft) {
                    close()
                    return
                }

                targetDevice = root.deviceForId(String(command.targetDeviceId || ""))
                targetCommand = editDraft
                targetStartTimeMs = Number(command.startTimeMs || 0)
                validationVisible = false
                executionFieldForm.values = command.commandParams
                    ? command.commandParams.executionInputFields || ({})
                    : ({})
            })
        }

        function commit() {
            validationVisible = true
            if (!formValid || !targetDevice || !targetCommand)
                return

            if (editing) {
                if (timelineCommandModel.updateCommand(editingTimelineCommand,
                                                       targetStartTimeMs,
                                                       executionFieldForm.valueMap()))
                    close()
                return
            }

            root.addTimelineCommand(targetDevice,
                                    targetCommand,
                                    targetStartTimeMs,
                                    executionFieldForm.valueMap())
            close()
        }

        width: Math.min(560, Math.max(420, parent ? parent.width - 96 : 520))
        maximumDialogHeight: Math.min(580, Math.max(360, parent ? parent.height - 96 : 460))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        title: editing ? qsTr("编辑执行指令") : qsTr("执行参数")
        message: targetCommand ? root.commandName(targetCommand) : ""
        rejectText: qsTr("取消")
        acceptText: editing ? qsTr("保存") : qsTr("添加")
        acceptIconName: "workflow"
        acceptEnabled: root.timelineStopped && formValid
        closeOnAccepted: false
        onAccepted: commit()
        onClosed: {
            clearEditDraft()
            editingTimelineCommand = null
            targetDevice = null
            targetCommand = null
        }

        Base.AppDialogSection {
            Layout.fillWidth: true
            visible: addTimelineCommandPopup.editing
            title: qsTr("开始时间")
            compact: true
            bodyFillHeight: false

            Base.AppNumberField {
                Layout.fillWidth: true
                value: addTimelineCommandPopup.targetStartTimeMs
                integerMode: true
                minimum: 0
                maximum: Math.max(root.timelineDurationMs,
                                  addTimelineCommandPopup.targetStartTimeMs)
                suffix: "ms"
                onValueEdited: addTimelineCommandPopup.targetStartTimeMs = nextValue
            }
        }

        Base.AppText {
            Layout.fillWidth: true
            text: executionFieldForm.firstInvalidReason()
            visible: addTimelineCommandPopup.validationVisible && text.length > 0
            styleRole: UiStyle.TypographyRole.BodyS
            textTone: UiStyle.TextTone.Danger
            elide: Text.ElideRight
        }

        DeviceFieldForm {
            id: executionFieldForm

            Layout.fillWidth: true
            fields: addTimelineCommandPopup.executionFields
            writeBack: false
            showErrors: addTimelineCommandPopup.validationVisible
            emptyText: qsTr("无执行参数")
        }
    }
}
