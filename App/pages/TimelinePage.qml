import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UiCore/qml/components/base" as Base
import "qrc:/UiCore/qml/theme" as Theme
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
    readonly property int pageMargin: pageTheme && pageTheme.density ? pageTheme.density.pageMargin : 20
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
    readonly property bool timelineRunning: timelineController && timelineController.state === 1
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

    function setTimelineCurrentTimeMs(currentTimeMs) {
        if (timelineRunning)
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

    function executeTimeline() {
        if (appRuntime)
            appRuntime.startTimeline()
        executionStatusText = qsTr("时间线已开始执行")
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
                text: qsTr("时间线")
                theme: root.pageTheme
                styleRole: "titleL"
            }

            Item {
                Layout.fillWidth: true
            }

            Base.AppButton {
                text: qsTr("预览移动")
                theme: root.pageTheme
                iconName: "resources"
                enabled: root.devices.length > 1
                onClicked: deviceTrackArea.previewMoveAnimation()
            }

            Base.AppButton {
                text: qsTr("执行")
                theme: root.pageTheme
                iconName: "background-task"
                onClicked: root.executeTimeline()
            }
        }

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
                theme: root.pageTheme
                surfaceTone: "section"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Base.AppText {
                        text: qsTr("控制轨")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    Timeline.TimelineRuler {
                        id: timelineRuler

                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        theme: root.pageTheme
                        durationMs: root.timelineDurationMs
                        currentTimeMs: root.timelineCurrentTimeMs
                        scrollX: root.timelineScrollX
                        startTimeX: root.timelineTrackLabelWidth + Math.max(0, width - root.timelineTrackLabelWidth) / 2
                        timeScale: root.timelineTimeScale
                        dragEnabled: !root.timelineRunning
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
                        theme: root.pageTheme
                        ruler: timelineRuler
                        devices: root.devices
                        commandModel: root.timelineCommandModel
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
                theme: root.pageTheme
                surfaceTone: "section"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    Base.AppText {
                        text: qsTr("执行")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Base.AppText {
                            Layout.fillWidth: true
                            text: qsTr("指令")
                            theme: root.pageTheme
                            styleRole: "bodyM"
                            textTone: "primary"
                            elide: Text.ElideRight
                        }

                        Base.AppText {
                            text: qsTr("%1").arg(root.deviceCommands.length)
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 176
                        Layout.preferredHeight: 260
                        sizeToContent: false
                        theme: root.pageTheme
                        surfaceTone: "surface"

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

                            delegate: Item {
                                id: commandRow

                                readonly property var commandData: modelData
                                readonly property bool selected: index === root.selectedCommandIndex

                                width: commandList.width
                                height: 56

                                Base.AppSurface {
                                    anchors.fill: parent
                                    theme: root.pageTheme
                                    surfaceTone: commandRow.selected ? "highlight" : "ghost"
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
                                    color: commandRow.selected ? "#60a5fa" : "#334155"
                                    opacity: commandRow.selected ? 1 : (commandMouse.containsMouse ? 0.44 : 0.18)
                                }

                                MouseArea {
                                    id: commandMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: root.selectCommandIndex(index)
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 18
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 7
                                    anchors.bottomMargin: 7
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Base.AppText {
                                            Layout.fillWidth: true
                                            text: root.commandName(commandRow.commandData)
                                            theme: root.pageTheme
                                            styleRole: "bodyM"
                                            colorOverride: commandRow.selected ? "#f8fafc" : undefined
                                            elide: Text.ElideRight
                                        }

                                        Base.AppText {
                                            Layout.maximumWidth: 120
                                            text: root.executionParameterNames(commandRow.commandData)
                                            visible: text.length > 0
                                            theme: root.pageTheme
                                            styleRole: "bodyS"
                                            colorOverride: "#ef4444"
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: root.commandSummary(commandRow.commandData)
                                        theme: root.pageTheme
                                        styleRole: "bodyS"
                                        textTone: "secondary"
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        Base.AppText {
                            anchors.centerIn: parent
                            visible: root.deviceCommands.length === 0
                            text: qsTr("暂无指令")
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }
                    }

                    Base.AppButton {
                        Layout.fillWidth: true
                        text: qsTr("添加所选")
                        theme: root.pageTheme
                        iconName: "workflow"
                        enabled: root.timelineCommandModel && root.selectedTimelineDevice && root.selectedCommand
                        onClicked: root.addSelectedCommandAtCurrentTime()
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        text: root.executionStatusText
                        visible: root.executionStatusText.length > 0
                        theme: root.pageTheme
                        styleRole: "bodyS"
                        textTone: "accent"
                        elide: Text.ElideRight
                    }
                }
            }

            Base.AppSurface {
                Layout.preferredWidth: 304
                Layout.fillHeight: true
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

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
                            theme: root.pageTheme
                            styleRole: "sectionTitle"
                            elide: Text.ElideRight
                        }

                        Base.AppText {
                            text: qsTr("%1").arg(root.visibleTimelineCommands.length)
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }
                    }

                    Base.AppSegmentedControl {
                        Layout.fillWidth: true
                        theme: root.pageTheme
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
                        theme: root.pageTheme
                        surfaceTone: "surface"

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

                            delegate: Item {
                                id: timelineCommandRow

                                readonly property var commandData: modelData
                                readonly property bool selected: String(commandData.id || "") === root.selectedTimelineCommandId

                                width: timelineCommandList.width
                                height: 56

                                Base.AppSurface {
                                    anchors.fill: parent
                                    theme: root.pageTheme
                                    surfaceTone: timelineCommandRow.selected ? "highlight" : "ghost"
                                    active: timelineCommandRow.selected
                                    hoveredState: timelineCommandMouse.containsMouse
                                    interactive: true
                                    strokeWidth: timelineCommandRow.selected || timelineCommandMouse.containsMouse ? 1 : 0
                                    borderOverride: timelineCommandRow.selected ? "#60a5fa" : "#334155"
                                    hoverOverlayOpacity: 0.08
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: parent.height - 18
                                    radius: 2
                                    color: timelineCommandRow.selected
                                        ? "#60a5fa"
                                        : String(timelineCommandRow.commandData && timelineCommandRow.commandData.stateColor
                                            ? timelineCommandRow.commandData.stateColor
                                            : "#334155")
                                    opacity: timelineCommandRow.selected ? 1 : (timelineCommandMouse.containsMouse ? 0.44 : 0.18)
                                }

                                MouseArea {
                                    id: timelineCommandMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: root.selectTimelineCommand(timelineCommandRow.commandData)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 18
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 7
                                    anchors.bottomMargin: 7
                                    spacing: 8

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Base.AppText {
                                            Layout.fillWidth: true
                                            text: String(timelineCommandRow.commandData.commandName || qsTr("指令"))
                                            theme: root.pageTheme
                                            styleRole: "bodyM"
                                            colorOverride: timelineCommandRow.selected ? "#f8fafc" : undefined
                                            elide: Text.ElideRight
                                        }

                                        Base.AppText {
                                            Layout.fillWidth: true
                                            text: root.timelineCommandMeta(timelineCommandRow.commandData)
                                                + " / "
                                                + String(timelineCommandRow.commandData && timelineCommandRow.commandData.stateText
                                                    ? timelineCommandRow.commandData.stateText
                                                    : qsTr("待执行"))
                                            theme: root.pageTheme
                                            styleRole: "bodyS"
                                            textTone: "secondary"
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Base.AppButton {
                                        visible: timelineCommandRow.selected
                                        text: qsTr("删除")
                                        theme: root.pageTheme
                                        enabled: !root.timelineRunning
                                        onClicked: {
                                            if (root.timelineCommandModel)
                                                root.timelineCommandModel.removeCommand(timelineCommandRow.commandData)
                                        }
                                    }
                                }
                            }
                        }

                        Base.AppText {
                            anchors.centerIn: parent
                            visible: root.visibleTimelineCommands.length === 0
                            text: qsTr("暂无时间线指令")
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 188
                        visible: root.pcPreviewGenerator && root.pcPreviewGenerator.pcDevice
                        sizeToContent: false
                        theme: root.pageTheme
                        surfaceTone: "surface"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: qsTr("PC 预览")
                                    theme: root.pageTheme
                                    styleRole: "bodyM"
                                }

                                Base.AppText {
                                    text: root.pcPreviewGenerator && root.pcPreviewGenerator.busy
                                        ? qsTr("生成中…")
                                        : qsTr("%1 ms").arg(root.pcPreviewGenerator
                                            ? root.pcPreviewGenerator.previewTimeMs
                                            : 0)
                                    theme: root.pageTheme
                                    styleRole: "bodyS"
                                    textTone: "secondary"
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

    Base.AppPopup {
        id: addTimelineCommandPopup

        property var targetDevice: null
        property var targetCommand: null
        property int targetStartTimeMs: 0
        property bool validationVisible: false
        readonly property var executionFields: targetCommand ? targetCommand.executionInputFields || [] : []
        readonly property bool formValid: executionFieldForm.valid

        function openForCommand(nextDevice, nextCommand, nextStartTimeMs) {
            targetDevice = nextDevice
            targetCommand = nextCommand
            targetStartTimeMs = nextStartTimeMs
            validationVisible = false
            executionFieldForm.values = {}
            executionFieldForm.resetValues()
            open()
        }

        function commit() {
            validationVisible = true
            if (!formValid || !targetDevice || !targetCommand)
                return

            root.addTimelineCommand(targetDevice,
                                    targetCommand,
                                    targetStartTimeMs,
                                    executionFieldForm.valueMap())
            close()
        }

        modal: true
        focus: true
        width: Math.min(560, Math.max(420, parent ? parent.width - 96 : 520))
        height: Math.min(520, Math.max(320, parent ? parent.height - 96 : 420))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        padding: 18
        spacing: 14
        theme: root.pageTheme
        surfaceTone: "section"
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Base.AppText {
                    Layout.fillWidth: true
                    text: qsTr("执行参数")
                    theme: root.pageTheme
                    styleRole: "titleM"
                    elide: Text.ElideRight
                }

                Base.AppText {
                    Layout.fillWidth: true
                    text: addTimelineCommandPopup.targetCommand
                        ? root.commandName(addTimelineCommandPopup.targetCommand)
                        : ""
                    theme: root.pageTheme
                    styleRole: "bodyS"
                    textTone: "secondary"
                    elide: Text.ElideRight
                }
            }

            Base.AppButton {
                text: qsTr("取消")
                theme: root.pageTheme
                onClicked: addTimelineCommandPopup.close()
            }

            Base.AppButton {
                text: qsTr("添加")
                theme: root.pageTheme
                iconName: "workflow"
                onClicked: addTimelineCommandPopup.commit()
            }
        }

        Base.AppText {
            Layout.fillWidth: true
            text: executionFieldForm.firstInvalidReason()
            visible: addTimelineCommandPopup.validationVisible && text.length > 0
            theme: root.pageTheme
            styleRole: "bodyS"
            colorOverride: "#ef4444"
            elide: Text.ElideRight
        }

        Base.AppScrollPane {
            Layout.fillWidth: true
            Layout.fillHeight: true
            theme: root.pageTheme
            contentSpacing: 12
            fillContentWidth: true

            DeviceFieldForm {
                id: executionFieldForm

                Layout.fillWidth: true
                fields: addTimelineCommandPopup.executionFields
                writeBack: false
                showErrors: addTimelineCommandPopup.validationVisible
                theme: root.pageTheme
                emptyText: qsTr("无执行参数")
            }
        }
    }

}
