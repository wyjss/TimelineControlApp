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
    readonly property int timelineTrackLabelWidth: 224
    readonly property var devices: deviceModel ? deviceModel.devices : []
    readonly property var deviceCommands: selectedTimelineDevice && selectedTimelineDevice.commands ? selectedTimelineDevice.commands : []
    readonly property var timelineCommands: timelineCommandModel && timelineCommandModel.commands ? timelineCommandModel.commands : []
    readonly property string selectedTimelineCommandId: timelineCommandModel ? timelineCommandModel.selectedCommandId : ""
    readonly property bool timelineStopped: !timelineManager || timelineManager.playbackState === 0
    readonly property var selectedCommand: selectedCommandIndex >= 0
        && selectedCommandIndex < deviceCommands.length
        ? deviceCommands[selectedCommandIndex]
        : null
    readonly property int timelineCurrentTimeMs: timelineStopped || !currentTimeline
        ? fallbackTimelineCurrentTimeMs
        : currentTimeline.currentTimeMs
    property int fallbackTimelineCurrentTimeMs: 0
    property real timelineScrollX: 0
    property real timelineTimeScale: 1.0
    property string selectedTimelineDeviceId: ""
    property var selectedTimelineDevice: null
    property int selectedCommandIndex: -1
    property string timelineCommandListMode: "all"
    property string executionStatusText: ""

    signal closeRequested()

    onDevicesChanged: ensureSelectedTimelineDevice()
    onSelectedTimelineDeviceIdChanged: {
        updateSelectedTimelineDevice()
        selectedCommandIndex = -1
        ensureSelectedCommand()
    }
    onDeviceCommandsChanged: ensureSelectedCommand()
    onSelectedCommandIndexChanged: executionStatusText = ""

    Component.onCompleted: {
        ensureSelectedTimelineDevice()
        ensureSelectedCommand()
        if (pcPreviewGenerator)
            pcPreviewGenerator.seek(fallbackTimelineCurrentTimeMs)
    }

    onCurrentTimelineChanged: {
        fallbackTimelineCurrentTimeMs = 0
        if (pcPreviewGenerator)
            pcPreviewGenerator.seek(0)
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

        timelineCommandModel.addDeviceCommand(startTimeMs,
                                              String(targetDevice.id || ""),
                                              targetCommand,
                                              executionValues || {})
        executionStatusText = qsTr("已在 %2 ms 添加 %1").arg(commandName(targetCommand)).arg(startTimeMs)
    }

    function selectTimelineCommand(command) {
        if (!command)
            return

        if (timelineCommandModel)
            timelineCommandModel.selectedCommandId = String(command.id || "")
        if (String(command.targetDeviceId || "").length > 0)
            selectTimelineDevice(String(command.targetDeviceId || ""))
        setTimelineCurrentTimeMs(command.startTimeMs)
        positionControlTrackAtTime(command.startTimeMs)
    }

    function editTimelineCommand(command) {
        if (!timelineStopped || !timelineCommandModel || !command)
            return

        addTimelineCommandPopup.openForTimelineCommand(command)
    }

    function requestRemoveTimelineCommand(command) {
        if (timelineStopped && timelineCommandModel && command)
            removeTimelineCommandPopup.openForCommand(command)
    }

    function setTimelineCurrentTimeMs(currentTimeMs) {
        if (!timelineStopped)
            return

        var normalizedTimeMs = Math.max(0, Math.round(Number(currentTimeMs || 0)))
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
        var minutes = Math.floor(totalSeconds / 60)
        var seconds = totalSeconds % 60
        var milliseconds = totalMs % 1000
        var millisecondsText = milliseconds < 10
            ? "00" + milliseconds
            : (milliseconds < 100 ? "0" + milliseconds : String(milliseconds))
        return qsTr("%1:%2.%3")
            .arg(minutes)
            .arg(seconds < 10 ? "0" + seconds : seconds)
            .arg(millisecondsText)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pageTheme.density.panePaddingCompact
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
                    anchors.margins: 18
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true

                        Base.AppText {
                            Layout.fillWidth: true
                            text: qsTr("控制轨")
                            styleRole: UiStyle.TypographyRole.SectionTitle
                        }

                        Base.AppButton {
                            visible: root.controlTrackOnly
                            size: UiStyle.ButtonSize.Small
                            variant: UiStyle.ButtonVariant.Ghost
                            iconSymbol: "×"
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("关闭控制轨")
                            onClicked: root.closeRequested()
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        sizeToContent: false
                        surfaceTone: UiStyle.SurfaceTone.SectionOverlay

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 8

                            Base.AppText {
                                Layout.preferredWidth: 140
                                text: root.selectedTimelineDevice
                                    ? qsTr("设备：%1").arg(root.deviceName(
                                        root.selectedTimelineDevice))
                                    : qsTr("未选择设备")
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                                elide: Text.ElideRight
                            }

                            Base.AppSelect {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 140
                                Layout.maximumWidth: 240
                                options: root.deviceCommands.map(function(command, index) {
                                    return {
                                        "label": root.commandName(command),
                                        "value": index
                                    }
                                })
                                value: root.selectedCommandIndex
                                placeholderText: qsTr("选择指令")
                                popupMinWidth: width
                                enabled: root.deviceCommands.length > 0
                                onValueSelected: root.selectCommandIndex(Number(nextValue))
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.executionStatusText.length > 0
                                    ? root.executionStatusText
                                    : qsTr("参数：%1").arg(root.selectedCommand
                                        ? (root.executionParameterNames(root.selectedCommand)
                                            || qsTr("无"))
                                        : qsTr("无"))
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: root.executionStatusText.length > 0
                                    ? UiStyle.TextTone.Accent
                                    : UiStyle.TextTone.Info
                                elide: Text.ElideRight
                            }

                            Base.AppButton {
                                text: qsTr("添加到当前时间")
                                iconName: "workflow"
                                enabled: root.timelineStopped && root.timelineCommandModel
                                    && root.selectedTimelineDevice && root.selectedCommand
                                onClicked: root.addSelectedCommandAtCurrentTime()
                            }
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
                        selectedCommandId: root.selectedTimelineCommandId
                        onTrackSelected: function(targetDeviceId) {
                            root.selectTimelineDevice(targetDeviceId)
                        }
                        onCommandSelected: function(command) {
                            root.selectTimelineCommand(command)
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        sizeToContent: false
                        surfaceTone: UiStyle.SurfaceTone.SectionOverlay

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
                                    model: root.timelineCommands

                                    delegate: Item {
                                        readonly property var commandData: modelData
                                        readonly property real startRatio: root.overviewDurationMs > 0
                                            ? Math.max(0, Number(commandData.startTimeMs || 0))
                                                / root.overviewDurationMs
                                            : 0
                                        readonly property real durationRatio: root.overviewDurationMs > 0
                                            ? Math.max(0, Number(commandData.durationMs || 0))
                                                / root.overviewDurationMs
                                            : 0
                                        readonly property bool instantCommand: durationRatio <= 0
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
                                        width: instantCommand
                                            ? 10
                                            : Math.max(10, Math.round(parent.width * durationRatio))
                                        height: 8
                                        z: 1

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: parent.instantCommand ? 7 : parent.width
                                            height: parent.instantCommand ? 7 : 6
                                            radius: parent.instantCommand ? 2 : 3
                                            rotation: parent.instantCommand ? 45 : 0
                                            color: parent.markerColor
                                            opacity: parent.commandData.filteredOut
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
                                    color: root.pageTheme.colors.highlightSoft
                                    border.width: 1
                                    border.color: root.pageTheme.colors.highlightText
                                    opacity: 0.7
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
                                        if (!root.timelineStopped
                                                || root.overviewDurationMs <= 0)
                                            return
                                        var timeMs = Math.round(Math.max(0,
                                            Math.min(width, positionX)) / width
                                            * root.overviewDurationMs)
                                        root.setTimelineCurrentTimeMs(timeMs)
                                        root.positionControlTrackAtTime(timeMs)
                                    }

                                    anchors.fill: parent
                                    enabled: root.timelineStopped
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
                            commands: root.timelineCommands
                            devices: root.devices
                            deviceIdFilter: root.timelineCommandListMode === "device"
                                ? root.selectedTimelineDeviceId
                                : ""
                            selectedCommandId: root.selectedTimelineCommandId
                            editingEnabled: root.timelineStopped
                            onCommandSelected: function(command) {
                                root.selectTimelineCommand(command)
                            }
                            onEditRequested: function(command) {
                                root.editTimelineCommand(command)
                            }
                            onRemoveRequested: function(command) {
                                removeTimelineCommandPopup.openForCommand(command)
                            }
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
        id: removeTimelineCommandPopup

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
                .arg(timelineCommand.commandName || qsTr("指令"))
                .arg(root.deviceName(root.deviceForId(String(timelineCommand.targetDeviceId || ""))))
                .arg(root.formatTimelineMs(timelineCommand.startTimeMs))
            : ""
        rejectText: qsTr("取消")
        acceptText: qsTr("删除")
        acceptButtonVariant: UiStyle.ButtonVariant.Danger
        onAccepted: {
            if (root.timelineCommandModel && timelineCommand)
                root.timelineCommandModel.removeCommand(timelineCommand)
        }
        onClosed: timelineCommand = null
    }

    Base.AppDialog {
        id: addTimelineCommandPopup

        parent: root

        property var targetDevice: null
        property var targetCommand: null
        property var editingTimelineCommand: null
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
                targetDevice = nextDevice
                targetCommand = nextCommand
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
                targetCommand = command.targetCommand
                if (!targetCommand) {
                    close()
                    return
                }

                targetDevice = root.deviceForId(String(command.targetDeviceId || ""))
                targetStartTimeMs = Number(command.startTimeMs || 0)
                validationVisible = false
                executionFieldForm.values = command.executionInputValues || ({})
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
