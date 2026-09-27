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
    property var timelineManager: appRuntime && appRuntime.timelineManager ? appRuntime.timelineManager : null
    property var currentTimeline: timelineManager ? timelineManager.currentTimeline : null
    property var timelineCommandModel: currentTimeline ? currentTimeline.commandModel : null
    readonly property var filteredDeviceModel: timelineManager ? timelineManager.filteredDeviceModel : null
    readonly property var filteredCommandModel: timelineManager ? timelineManager.filteredCommandModel : null
    property var deviceRows: []
    property var commandRows: []
    property var deviceManager: appRuntime && appRuntime.deviceManager ? appRuntime.deviceManager : null
    property var deviceModel: appRuntime && appRuntime.deviceModel ? appRuntime.deviceModel : null
    property var fenceManager: appRuntime && appRuntime.fenceManager ? appRuntime.fenceManager : null
    property var crossConditionModel: currentTimeline && currentTimeline.crossConditionModel
        ? currentTimeline.crossConditionModel
        : null
    property var pcPreviewGenerator: typeof pcTimelinePreviewGenerator !== "undefined"
        ? pcTimelinePreviewGenerator
        : null
    property bool controlTrackOnly: false
    readonly property int preStartTimelineDurationMs: 24 * 60 * 60 * 1000
    readonly property int timelineDurationMs: timelineStopped
        ? Math.max(preStartTimelineDurationMs,
                   timelineCommandModel ? timelineCommandModel.realDurationMs : 0)
        : (currentTimeline ? currentTimeline.durationMs : 0)
    readonly property int overviewDurationMs: timelineCommandModel
        ? Math.max(0, Number(timelineCommandModel.realDurationMs || 0))
        : 0
    readonly property int timelineTrackLabelWidth: 200
    readonly property var devices: deviceModel ? deviceModel.devices : []
    readonly property var deviceCommands: selectedTimelineDevice && selectedTimelineDevice.commands ? selectedTimelineDevice.commands : []
    readonly property string selectedTimelineCommandId: timelineCommandModel ? timelineCommandModel.selectedCommandId : ""
    readonly property bool timelineStopped: !timelineManager || timelineManager.playbackState === 0
    readonly property bool commandEditingEnabled: timelineStopped || timelineManager.playbackState === 2
    readonly property bool currentTimeEditingEnabled: timelineStopped
        || (timelineManager.playbackState === 2 && currentTimeline && currentTimeline.state === 2)
    readonly property var selectedCommand: selectedCommandIndex >= 0
        && selectedCommandIndex < deviceCommands.length
        ? deviceCommands[selectedCommandIndex]
        : null
    readonly property int timelineCurrentTimeMs: timelineStopped || !currentTimeline
        ? fallbackTimelineCurrentTimeMs
        : currentTimeline.currentTimeMs
    property int fallbackTimelineCurrentTimeMs: 0

    Binding {
        Component.onCompleted: target = root.ApplicationWindow.window
            && ("timelineStartTimeMs" in root.ApplicationWindow.window)
            ? root.ApplicationWindow.window : null
        property: "timelineStartTimeMs"
        value: root.timelineStopped ? root.fallbackTimelineCurrentTimeMs : 0
        Component.onDestruction: {
            if (target)
                target.timelineStartTimeMs = 0
        }
    }

    property real timelineScrollX: 0
    property real timelineTimeScale: 1.0
    property string selectedTimelineDeviceId: ""
    property var selectedTimelineDevice: null
    property int selectedCommandIndex: -1
    property string timelineCommandListMode: "all"
    property string executionStatusText: ""
    property var quickTestCommand: null
    readonly property string quickTestStatusText: quickTestCommand
        ? qsTr("测试 %1：%2").arg(quickTestCommand.alias)
            .arg(quickTestCommand.state === 3 && quickTestCommand.errorMessage.length > 0
                ? qsTr("失败：%1").arg(quickTestCommand.errorMessage) : quickTestCommand.stateText)
        : ""

    signal closeRequested()
    signal deviceTrackSelected()
    signal timelineCommandSelected()
    signal commandTestRequested(var command)

    onCommandTestRequested: {
        if (!appRuntime || !command)
            return
        var result = appRuntime.testDeviceCommand(String(command.targetDeviceId || ""),
                                                  command.targetCommand,
                                                  command.executionInputValues || {})
        result.alias = command.alias
        quickTestCommand = result
    }

    onDeviceRowsChanged: ensureSelectedTimelineDevice()
    onFilteredDeviceModelChanged: refreshDeviceRows()
    onFilteredCommandModelChanged: refreshCommandRows()

    Connections {
        target: root.filteredDeviceModel
        function onRowsInserted() { root.refreshDeviceRows() }
        function onRowsRemoved() { root.refreshDeviceRows() }
        function onRowsMoved() { root.refreshDeviceRows() }
        function onModelReset() { root.refreshDeviceRows() }
        function onLayoutChanged() { root.refreshDeviceRows() }
        function onDataChanged() { root.refreshDeviceRows() }
    }

    Connections {
        target: root.filteredCommandModel
        function onRowsInserted() { root.refreshCommandRows() }
        function onRowsRemoved() { root.refreshCommandRows() }
        function onRowsMoved() { root.refreshCommandRows() }
        function onModelReset() { root.refreshCommandRows() }
        function onLayoutChanged() { root.refreshCommandRows() }
        function onDataChanged() { root.refreshCommandRows() }
    }
    onSelectedTimelineDeviceIdChanged: {
        updateSelectedTimelineDevice()
        selectedCommandIndex = -1
        ensureSelectedCommand()
    }
    onDeviceCommandsChanged: ensureSelectedCommand()
    onSelectedCommandIndexChanged: executionStatusText = ""

    Component.onCompleted: {
        refreshDeviceRows()
        refreshCommandRows()
        ensureSelectedTimelineDevice()
        ensureSelectedCommand()
        if (pcPreviewGenerator)
            pcPreviewGenerator.seek(fallbackTimelineCurrentTimeMs)
    }

    onCurrentTimelineChanged: {
        refreshCommandRows()
        fallbackTimelineCurrentTimeMs = 0
        if (pcPreviewGenerator)
            pcPreviewGenerator.seek(0)
    }

    // 仅从代理读取显示行；保留原对象供现有布局和编辑接口使用。
    function refreshDeviceRows() {
        var rows = []
        var count = filteredDeviceModel ? filteredDeviceModel.rowCount() : 0
        var changed = count !== deviceRows.length
        for (var row = 0; row < count; ++row) {
            var modelIndex = filteredDeviceModel.index(row, 0)
            var device = filteredDeviceModel.data(modelIndex, Qt.DisplayRole)
            // 与 DeviceFilterModel::MatchesFilterRole 对应。
            var matches = filteredDeviceModel.data(modelIndex, Qt.UserRole + 2)
            rows.push({ "item": device, "matchesFilter": matches })
            if (!changed && (deviceRows[row].item !== device
                             || deviceRows[row].matchesFilter !== matches))
                changed = true
        }
        if (changed)
            deviceRows = rows
    }

    function refreshCommandRows() {
        var rows = []
        var count = filteredCommandModel ? filteredCommandModel.rowCount() : 0
        var changed = count !== commandRows.length
        var selectedVisible = false
        for (var row = 0; row < count; ++row) {
            var modelIndex = filteredCommandModel.index(row, 0)
            var command = filteredCommandModel.data(modelIndex, Qt.DisplayRole)
            // 与 TimelineCommandFilterModel::MatchesFilterRole 对应。
            var matches = filteredCommandModel.data(modelIndex, Qt.UserRole + 2)
            rows.push({ "command": command, "matchesFilter": matches })
            if (!changed && (commandRows[row].command !== command
                             || commandRows[row].matchesFilter !== matches))
                changed = true
            if (command.id === selectedTimelineCommandId)
                selectedVisible = true
        }
        if (changed)
            commandRows = rows
        if (timelineCommandModel && filteredCommandModel
                && filteredCommandModel.sourceModel === timelineCommandModel
                && selectedTimelineCommandId.length > 0 && !selectedVisible)
            timelineCommandModel.selectedCommandId = ""
    }

    function deviceForId(deviceId) {
        var normalizedDeviceId = String(deviceId || "")
        for (var index = 0; index < deviceRows.length; ++index) {
            var device = deviceRows[index].item
            if (String(device.id || "") === normalizedDeviceId)
                return device
        }

        return null
    }

    function ensureSelectedTimelineDevice() {
        if (deviceRows.length === 0) {
            selectedTimelineDeviceId = ""
            selectedTimelineDevice = null
            return
        }

        if (!deviceForId(selectedTimelineDeviceId)) {
            selectTimelineDevice(String(deviceRows[0].item.id || ""))
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
        if (!commandEditingEnabled)
            return

        if (!timelineCommandModel || !selectedTimelineDevice || !selectedCommand) {
            executionStatusText = qsTr("请先选择设备指令")
            return
        }

        var startTimeMs = Math.max(0, Math.round(timelineCurrentTimeMs))
        addTimelineCommandPopup.openForCommand(selectedTimelineDevice, selectedCommand, startTimeMs)
    }

    function addTimelineCommand(targetDevice, targetCommand, startTimeMs, executionValues, alias) {
        if (!commandEditingEnabled || !timelineCommandModel)
            return

        timelineCommandModel.addDeviceCommand(startTimeMs,
                                              String(targetDevice.id || ""),
                                              targetCommand,
                                              executionValues || {},
                                              alias)
        executionStatusText = qsTr("已在 %2 添加 %1").arg(alias || targetCommand.name).arg(formatTimelineMs(startTimeMs))
    }

    function selectTimelineCommand(command, positionView) {
        if (!command)
            return

        if (timelineCommandModel)
            timelineCommandModel.selectedCommandId = String(command.id || "")
        if (String(command.targetDeviceId || "").length > 0)
            selectTimelineDevice(String(command.targetDeviceId || ""))
        if (positionView !== false)
            positionControlTrackAtTime(command.startTimeMs)
        timelineCommandSelected()
    }

    function editTimelineCommand(command) {
        if (!commandEditingEnabled || !timelineCommandModel || !command)
            return

        addTimelineCommandPopup.openForTimelineCommand(command)
    }

    function requestRemoveTimelineCommand(command) {
        if (commandEditingEnabled && timelineCommandModel && command)
            removeTimelineCommandPopup.openForCommand(command)
    }

    function setTimelineCurrentTimeMs(currentTimeMs) {
        if (!currentTimeEditingEnabled)
            return

        var normalizedTimeMs = Math.max(0, Math.round(Number(currentTimeMs || 0)))
        if (!timelineStopped) {
            timelineManager.seekTimeline(currentTimeline.id, normalizedTimeMs)
            return
        }
        fallbackTimelineCurrentTimeMs = normalizedTimeMs
        if (pcPreviewGenerator)
            pcPreviewGenerator.seek(normalizedTimeMs)
    }

    function positionControlTrackAtTime(currentTimeMs) {
        var viewportWidth = timelineRuler.width - timelineRuler.resolvedTrackLeftX
        if (viewportWidth <= 0)
            return

        var timeMs = Math.max(0, Number(currentTimeMs || 0))
        var contentX = timelineRuler.resolvedStartTimeX
            + timeMs / 1000 * timelineRuler.safePixelsPerSecond
        var viewportCenterX = timelineRuler.resolvedTrackLeftX + viewportWidth / 2
        timelineScrollX = timelineRuler.clampScrollX(contentX - viewportCenterX)
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
        var protocolText = (device.supportedProtocols || []).map(function(protocol) {
            return String(protocol).toLowerCase() === "internal" ? qsTr("无协议") : String(protocol)
        }).join(", ").trim()
        var typeText = (device.supportsProtocol !== undefined && device.supportsProtocol("pc"))
            ? "PC"
            : String(device.deviceType || "").trim()
        var statusText = device.online ? qsTr("在线") : qsTr("离线")
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

    function formatTimelineMs(ms) {
        var totalMs = Math.max(0, Math.round(Number(ms || 0)))
        var totalSeconds = Math.floor(totalMs / 1000)
        var hours = Math.floor(totalSeconds / 3600)
        var minutes = Math.floor(totalSeconds / 60) % 60
        var seconds = totalSeconds % 60
        var milliseconds = totalMs % 1000
        var millisecondsText = milliseconds < 10
            ? "00" + milliseconds
            : (milliseconds < 100 ? "0" + milliseconds : String(milliseconds))
        return (hours > 0 ? (hours < 10 ? "0" + hours : hours) + ":" : "")
            + qsTr("%1:%2.%3")
            .arg(minutes < 10 ? "0" + minutes : minutes)
            .arg(seconds < 10 ? "0" + seconds : seconds)
            .arg(millisecondsText)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.controlTrackOnly ? 0 : root.pageTheme.density.panePaddingCompact
        anchors.topMargin: 0
        spacing: root.pageTheme.density.controlGap

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.controlTrackOnly ? 1 : 2
            columnSpacing: root.pageTheme.density.controlGap
            rowSpacing: root.pageTheme.density.controlGap

            Base.AppSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: root.controlTrackOnly ? 420 : 520
                sizeToContent: false
                surfaceTone: UiStyle.SurfaceTone.Surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.pageTheme.density.panePadding

                        Base.AppButton {
                            objectName: "backToTimelineListButton"
                            visible: root.controlTrackOnly
                            size: UiStyle.ButtonSize.Small
                            minWidth: 32
                            variant: UiStyle.ButtonVariant.Ghost
                            iconSymbol: "←"
                            Accessible.name: qsTr("返回时间轴列表")
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("关闭控制轨，返回时间轴列表")
                            onClicked: root.closeRequested()
                        }

                        Base.AppText {
                            Layout.fillWidth: true
                            text: root.controlTrackOnly && root.currentTimeline
                                ? qsTr("控制轨 · %1").arg(root.currentTimeline.name)
                                : qsTr("控制轨")
                            elide: Text.ElideRight
                            styleRole: UiStyle.TypographyRole.SectionTitle
                        }
                    }

                    Timeline.TimelineExternalTriggerEditor {
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        devices: root.devices
                        fences: root.fenceManager ? root.fenceManager.fences : []
                        conditionModel: root.crossConditionModel
                        timelineModel: root.timelineManager
                            ? root.timelineManager.timelineModel
                            : null
                        currentTimeline: root.currentTimeline
                        dialogParent: root
                        editable: root.timelineStopped
                    }

                    Timeline.TimelineRuler {
                        id: timelineRuler
                        objectName: "timelineRuler"

                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        durationMs: root.timelineDurationMs
                        currentTimeMs: root.timelineCurrentTimeMs
                        scrollX: root.timelineScrollX
                        trackLeftX: root.timelineTrackLabelWidth
                        startTimeX: root.timelineTrackLabelWidth + 20
                        timeScale: root.timelineTimeScale
                        currentTimeDragEnabled: root.currentTimeEditingEnabled
                        commitCurrentTimeOnRelease: !root.timelineStopped
                        timelineId: root.currentTimeline ? String(root.currentTimeline.id || "") : ""
                        onScrollXChangeRequested: function(nextScrollX) {
                            root.timelineScrollX = nextScrollX
                        }
                        onCurrentTimePreviewRequested: function(timeMs) {
                            if (root.currentTimeline)
                                root.currentTimeline.seekPreviewRequested(timeMs)
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
                        deviceRows: root.deviceRows
                        commandRows: root.commandRows
                        childTracksByParentId: root.timelineCommandModel
                            ? root.timelineCommandModel.childTracksByParentId
                            : ({})
                        labelWidth: root.timelineTrackLabelWidth
                        selectedDeviceId: root.selectedTimelineDeviceId
                        selectedCommandId: root.selectedTimelineCommandId
                        editingEnabled: root.commandEditingEnabled
                        locatingEnabled: root.currentTimeEditingEnabled
                        onTrackSelected: function(targetDeviceId) {
                            root.selectTimelineDevice(targetDeviceId)
                            root.deviceTrackSelected()
                        }
                        onCommandSelected: function(command) {
                            root.selectTimelineCommand(command)
                        }
                        onCommandTestRequested: root.commandTestRequested(command)
                        onLocateRequested: root.setTimelineCurrentTimeMs(command.startTimeMs)
                        onCommandMoveRequested: function(command, startTimeMs) {
                            if (!root.commandEditingEnabled || !root.timelineCommandModel || !command)
                                return
                            if (startTimeMs !== Number(command.startTimeMs)
                                    && !root.timelineCommandModel.updateCommand(command, startTimeMs,
                                                                               command.executionInputValues))
                                return
                            root.selectTimelineCommand(command, false)
                        }
                    }

                    Base.AppText {
                        objectName: "timelineQuickTestStatus"
                        Layout.fillWidth: true
                        visible: !root.controlTrackOnly && text.length > 0
                        text: root.quickTestStatusText
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: root.quickTestCommand && root.quickTestCommand.state === 3
                            ? UiStyle.TextTone.Danger : UiStyle.TextTone.Secondary
                        wrapMode: Text.WordWrap
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        sizeToContent: false
                        surfaceTone: UiStyle.SurfaceTone.Ghost
                        strokeWidth: 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Base.AppText {
                                Layout.preferredWidth: 40
                                text: qsTr("总览")
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                            }

                            Item {
                                id: timelineOverview

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 1
                                    color: root.pageTheme.colors.border
                                    opacity: 0.7
                                }

                                Repeater {
                                    model: root.commandRows

                                    delegate: Item {
                                        readonly property var commandData: modelData.command
                                        readonly property bool filteredOut: !modelData.matchesFilter
                                        readonly property real startRatio: root.overviewDurationMs > 0
                                            ? Math.max(0, Number(commandData.startTimeMs || 0))
                                                / root.overviewDurationMs
                                            : 0
                                        readonly property color markerColor: {
                                            var protocol = String(commandData && commandData.targetCommand
                                                ? commandData.targetCommand.protocol
                                                : "")
                                            switch (protocol) {
                                            case "dmx512": return "#2563eb"
                                            case "http": return "#0891b2"
                                            case "pc": return "#16a34a"
                                            case "serial": return "#d97706"
                                            default: return "#7c5cff"
                                            }
                                        }
                                        readonly property bool selected: String(commandData.id || "")
                                            === root.selectedTimelineCommandId

                                        x: Math.min(parent.width - width,
                                                    Math.round(parent.width * startRatio))
                                        y: 2 + index % 3 * 9
                                        width: 10
                                        height: 8
                                        z: 1

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 7
                                            height: 7
                                            radius: 2
                                            rotation: 45
                                            color: parent.markerColor
                                            opacity: parent.filteredOut
                                                ? 0.36
                                                : (parent.selected ? 1 : 0.82)
                                            border.width: parent.selected ? 1 : 0
                                            border.color: root.pageTheme.colors.inverseText
                                        }
                                    }
                                }

                                Rectangle {
                                    readonly property real startRatio: root.overviewDurationMs > 0
                                        ? Math.min(root.overviewDurationMs,
                                                   timelineRuler.visibleStartMs)
                                            / root.overviewDurationMs
                                        : 0
                                    readonly property real endRatio: root.overviewDurationMs > 0
                                        ? Math.min(root.overviewDurationMs,
                                                   timelineRuler.visibleEndMs)
                                            / root.overviewDurationMs
                                        : 0

                                    x: Math.round(parent.width * startRatio)
                                    width: Math.max(2, Math.round(parent.width
                                                                 * (endRatio - startRatio)))
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    visible: root.overviewDurationMs > 0
                                    color: "transparent"
                                    border.width: 1
                                    border.color: root.pageTheme.colors.highlightText
                                    opacity: 0.45
                                }

                                Rectangle {
                                    x: root.overviewDurationMs > 0
                                        ? Math.round(parent.width * root.timelineCurrentTimeMs
                                                     / root.overviewDurationMs)
                                        : 0
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 1
                                    visible: root.overviewDurationMs > 0
                                        && x >= 0 && x <= parent.width
                                    color: root.pageTheme.colors.dangerFill
                                    z: 2
                                }

                                MouseArea {
                                    function seek(positionX) {
                                        if (/*!root.timelineStopped
                                                || */root.overviewDurationMs <= 0)
                                            return
                                        var timeMs = Math.round(Math.max(0,
                                            Math.min(width, positionX)) / width
                                            * root.overviewDurationMs)
                                        // 取消时间跳转
                                        //root.setTimelineCurrentTimeMs(timeMs)
                                        root.positionControlTrackAtTime(timeMs)
                                    }

                                    anchors.fill: parent
                                    // 在不关联时间后，可以一直启用
                                    //enabled: root.timelineStopped
                                    cursorShape: pressed
                                        ? Qt.SizeHorCursor
                                        : Qt.PointingHandCursor
                                    z: 3
                                    onPressed: seek(mouse.x)
                                    onPositionChanged: {
                                        if (pressed)
                                            seek(mouse.x)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Base.AppSurface {
                visible: !root.controlTrackOnly
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
                            text: qsTr("%1").arg(timelineCommandVerticalList.count)
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

                        Timeline.TimelineCommandVerticalList {
                            id: timelineCommandVerticalList

                            anchors.fill: parent
                            theme: root.pageTheme
                            commandRows: root.commandRows
                            devices: root.devices
                            deviceIdFilter: root.timelineCommandListMode === "device"
                                ? root.selectedTimelineDeviceId
                                : ""
                            selectedCommandId: root.selectedTimelineCommandId
                            editingEnabled: root.commandEditingEnabled
                            locatingEnabled: root.currentTimeEditingEnabled
                            onCommandSelected: function(command) {
                                root.selectTimelineCommand(command)
                            }
                            onCommandTestRequested: root.commandTestRequested(command)
                            onLocateRequested: function(command) {
                                if (!root.currentTimeEditingEnabled)
                                    return
                                root.selectTimelineCommand(command)
                                root.setTimelineCurrentTimeMs(command.startTimeMs)
                            }
                            onEditRequested: function(command) {
                                root.editTimelineCommand(command)
                            }
                            onRemoveRequested: function(command) {
                                removeTimelineCommandPopup.openForCommand(command)
                            }
                        }
                    }
                }
            }
        }
    }

    Base.AppDialog {
        id: removeTimelineCommandPopup
        objectName: "removeTimelineCommandPopup"

        parent: root

        property var timelineCommand: null

        function openForCommand(command) {
            timelineCommand = command
            open()
        }

        width: Math.min(420, Math.max(320, parent ? parent.width - 96 : 380))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        title: qsTr("删除时间线指令")
        message: timelineCommand
            ? qsTr("确定删除“%1”？设备：%2，执行时间：%3。")
                .arg(timelineCommand.alias || qsTr("指令"))
                .arg(root.deviceName(root.deviceForId(String(timelineCommand.targetDeviceId || ""))))
                .arg(root.formatTimelineMs(timelineCommand.startTimeMs))
            : ""
        rejectText: qsTr("取消")
        acceptText: qsTr("删除")
        acceptButtonVariant: UiStyle.ButtonVariant.Danger
        acceptEnabled: root.commandEditingEnabled
        onAccepted: {
            if (root.commandEditingEnabled && root.timelineCommandModel && timelineCommand)
                root.timelineCommandModel.removeCommand(timelineCommand)
        }
        onClosed: timelineCommand = null
    }

    Base.AppDialog {
        id: addTimelineCommandPopup
        objectName: "addTimelineCommandPopup"

        parent: root

        property var targetDevice: null
        property var targetCommand: null
        property var editingTimelineCommand: null
        property var testTimelineCommand: null
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
                editingTimelineCommand = null
                testTimelineCommand = null
                targetDevice = nextDevice
                targetCommand = nextCommand
                commandAliasField.text = nextCommand.name
                targetStartTimeMs = nextStartTimeMs
                validationVisible = false
                executionFieldForm.values = {}
                executionFieldForm.resetValues()
            })
        }

        function openForTimelineCommand(command) {
            if (!timelineCommandModel || !command)
                return

            open()

            Qt.callLater(function() {
                editingTimelineCommand = command
                testTimelineCommand = null
                targetCommand = command.targetCommand
                if (!targetCommand) {
                    close()
                    return
                }

                targetDevice = root.deviceForId(String(command.targetDeviceId || ""))
                targetStartTimeMs = Number(command.startTimeMs || 0)
                commandAliasField.text = command.alias
                validationVisible = false
                executionFieldForm.values = command.executionInputValues || ({})
            })
        }

        function commit() {
            validationVisible = true
            if (!root.commandEditingEnabled || !formValid || !targetDevice || !targetCommand)
                return

            if (editing) {
                if (timelineCommandModel.updateCommand(editingTimelineCommand,
                                                       targetStartTimeMs,
                                                       executionFieldForm.valueMap())) {
                    editingTimelineCommand.alias = commandAliasField.text
                    close()
                }
                return
            }

            root.addTimelineCommand(targetDevice,
                                    targetCommand,
                                    targetStartTimeMs,
                                    executionFieldForm.valueMap(),
                                    commandAliasField.text)
            close()
        }

        width: Math.min(560, Math.max(420, parent ? parent.width - 96 : 520))
        maximumDialogHeight: Math.min(580, Math.max(360, parent ? parent.height - 96 : 460))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        title: editing ? qsTr("编辑执行指令") : qsTr("添加时间轴指令")
        message: targetCommand ? qsTr("设备指令：%1").arg(root.commandName(targetCommand)) : ""
        rejectText: qsTr("取消")
        acceptText: editing ? qsTr("保存") : qsTr("添加")
        acceptIconName: "workflow"
        acceptEnabled: root.commandEditingEnabled && formValid
        closeOnAccepted: false
        onAccepted: commit()
        onClosed: {
            editingTimelineCommand = null
            testTimelineCommand = null
            targetDevice = null
            targetCommand = null
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("别名")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Primary
            }

            Base.AppTextField {
                id: commandAliasField
                objectName: "timelineCommandAlias"
                Layout.fillWidth: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: addTimelineCommandPopup.editing
            spacing: 6

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("开始时间")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Primary
            }

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

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Base.AppButton {
                objectName: "testTimelineCommandButton"
                text: qsTr("测试")
                enabled: root.appRuntime
                    && addTimelineCommandPopup.targetDevice
                    && addTimelineCommandPopup.targetCommand
                    && addTimelineCommandPopup.formValid
                onClicked: {
                    addTimelineCommandPopup.validationVisible = true
                    addTimelineCommandPopup.testTimelineCommand = root.appRuntime.testDeviceCommand(
                        String(addTimelineCommandPopup.targetDevice.id || ""),
                        addTimelineCommandPopup.targetCommand,
                        executionFieldForm.valueMap())
                }
            }

            Base.AppText {
                objectName: "timelineCommandTestStatus"
                Layout.fillWidth: true
                text: {
                    var command = addTimelineCommandPopup.testTimelineCommand
                    if (!command)
                        return ""
                    return command.state === 3 && command.errorMessage.length > 0
                        ? qsTr("失败：%1").arg(command.errorMessage)
                        : command.stateText
                }
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: addTimelineCommandPopup.testTimelineCommand
                    && addTimelineCommandPopup.testTimelineCommand.state === 3
                    ? UiStyle.TextTone.Danger
                    : UiStyle.TextTone.Secondary
                wrapMode: Text.WordWrap
            }
        }
    }
}
