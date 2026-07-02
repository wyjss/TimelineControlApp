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
    readonly property int preStartTimelineDurationMs: 24 * 60 * 60 * 1000
    readonly property int timelineDurationMs: timelineController ? timelineController.durationMs : preStartTimelineDurationMs
    readonly property int timelineTrackLabelWidth: 224
    readonly property var devices: deviceModel ? deviceModel.devices : []
    readonly property var deviceCommands: selectedTimelineDevice && selectedTimelineDevice.commands ? selectedTimelineDevice.commands : []
    readonly property var timelineCommands: timelineCommandModel && timelineCommandModel.commands ? timelineCommandModel.commands : []
    readonly property var visibleTimelineCommands: buildVisibleTimelineCommands()
    readonly property string selectedTimelineCommandId: timelineCommandModel ? timelineCommandModel.selectedCommandId : ""
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
            selectedTimelineDeviceId = String(devices[0].id || "")
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
            executionStatusText = qsTr("Select a device command first")
            return
        }

        var extraParams = {
            "targetDeviceName": deviceName(selectedTimelineDevice),
            "targetDeviceAddress": deviceAddress(selectedTimelineDevice)
        }

        var startTimeMs = Math.max(0, Math.round(timelineCurrentTimeMs))
        timelineCommandModel.addDeviceCommand(startTimeMs,
                                              String(selectedTimelineDevice.id || ""),
                                              selectedCommand,
                                              extraParams)
        executionStatusText = qsTr("Added %1 at %2 ms").arg(commandName(selectedCommand)).arg(startTimeMs)
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
        var normalizedTimeMs = Math.max(0, Math.round(Number(currentTimeMs || 0)))
        if (timelineController)
            timelineController.seek(normalizedTimeMs)
        else
            fallbackTimelineCurrentTimeMs = normalizedTimeMs
    }

    function deviceName(device) {
        if (!device)
            return qsTr("Unassigned")

        var name = String(device.name || "").trim()
        return name.length > 0 ? name : String(device.id || qsTr("Device"))
    }

    function deviceAddress(device) {
        if (!device)
            return qsTr("No address")

        var address = String(device.address || "").trim()
        return address.length > 0 ? address : qsTr("Unassigned")
    }

    function deviceMeta(device) {
        if (!device)
            return ""

        var parts = []
        var protocolText = String(device.protocol || "").trim()
        var typeText = protocolText.toLowerCase() === "pc"
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
            return qsTr("Command")

        var name = String(command.name || "").trim()
        return name.length > 0 ? name : qsTr("Command")
    }

    function commandProtocol(command) {
        return command && command.protocol !== undefined && command.protocol !== null
            ? String(command.protocol)
            : ""
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
            var port = String(commandFieldValue(command, "ipPort", "") || "").trim()
            var path = String(commandFieldValue(command, "apiPath", "") || "").trim()
            var method = String(commandFieldValue(command, "httpMethod", "") || "").trim()
            if (address.length > 0 && port.length > 0)
                address += ":" + port
            var httpSummary = [method, address, path].filter(function(part) { return part.length > 0 }).join(" / ")
            return httpSummary.length > 0 ? httpSummary : commandProtocol(command)
        }

        if (protocol === "serial") {
            var payload = String(commandFieldValue(command, "payload", "") || "").trim()
            return payload.length > 0 ? payload : commandProtocol(command)
        }

        if (protocol === "dmx512") {
            var channel = String(commandFieldValue(command, "channel", "") || "").trim()
            var value = String(commandFieldValue(command, "value", "") || "").trim()
            var dmxSummary = [channel.length > 0 ? qsTr("CH %1").arg(channel) : "",
                              value.length > 0 ? qsTr("Value %1").arg(value) : ""]
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
        if (timelineController)
            timelineController.start()
        executionStatusText = qsTr("Timeline execution started")
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
                text: qsTr("Timeline")
                theme: root.pageTheme
                styleRole: "titleL"
            }

            Item {
                Layout.fillWidth: true
            }

            Base.AppButton {
                text: qsTr("Preview Move")
                theme: root.pageTheme
                iconName: "resources"
                enabled: root.devices.length > 1
                onClicked: deviceTrackArea.previewMoveAnimation()
            }

            Base.AppButton {
                text: qsTr("Execute")
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
                        text: qsTr("Control Track")
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
                        text: qsTr("Execution")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Base.AppText {
                            Layout.fillWidth: true
                            text: qsTr("Devices")
                            theme: root.pageTheme
                            styleRole: "bodyM"
                            textTone: "primary"
                            elide: Text.ElideRight
                        }

                        Base.AppText {
                            text: qsTr("%1").arg(root.devices.length)
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 156
                        Layout.preferredHeight: 220
                        sizeToContent: false
                        theme: root.pageTheme
                        surfaceTone: "surface"

                        ListView {
                            id: deviceList

                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            spacing: 6
                            model: root.devices
                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            delegate: Item {
                                id: deviceRow

                                readonly property var deviceData: modelData
                                readonly property bool selected: String(deviceData.id || "") === root.selectedTimelineDeviceId

                                width: deviceList.width
                                height: 58

                                Base.AppSurface {
                                    anchors.fill: parent
                                    theme: root.pageTheme
                                    surfaceTone: deviceRow.selected ? "highlight" : "ghost"
                                    active: deviceRow.selected
                                    hoveredState: deviceMouse.containsMouse
                                    interactive: true
                                    strokeWidth: deviceRow.selected || deviceMouse.containsMouse ? 1 : 0
                                    borderOverride: deviceRow.selected ? "#60a5fa" : "#334155"
                                    hoverOverlayOpacity: 0.08
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: parent.height - 18
                                    radius: 2
                                    color: deviceRow.selected ? "#60a5fa" : "#334155"
                                    opacity: deviceRow.selected ? 1 : (deviceMouse.containsMouse ? 0.44 : 0.18)
                                }

                                MouseArea {
                                    id: deviceMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: root.selectTimelineDevice(String(deviceRow.deviceData.id || ""))
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 18
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 7
                                    anchors.bottomMargin: 7
                                    spacing: 2

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: root.deviceName(deviceRow.deviceData)
                                        theme: root.pageTheme
                                        styleRole: "bodyM"
                                        colorOverride: deviceRow.selected ? "#f8fafc" : undefined
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: root.deviceAddress(deviceRow.deviceData) + " / " + root.deviceMeta(deviceRow.deviceData)
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
                            visible: root.devices.length === 0
                            text: qsTr("No devices")
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Base.AppText {
                            Layout.fillWidth: true
                            text: qsTr("Commands")
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

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: root.commandName(commandRow.commandData)
                                        theme: root.pageTheme
                                        styleRole: "bodyM"
                                        colorOverride: commandRow.selected ? "#f8fafc" : undefined
                                        elide: Text.ElideRight
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
                            text: qsTr("No commands")
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }
                    }

                    Base.AppButton {
                        Layout.fillWidth: true
                        text: qsTr("Add Selected")
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
                            text: qsTr("Timeline Commands")
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
                            { "label": qsTr("All"), "value": "all" },
                            { "label": qsTr("Device"), "value": "device" }
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
                                    color: timelineCommandRow.selected ? "#60a5fa" : "#334155"
                                    opacity: timelineCommandRow.selected ? 1 : (timelineCommandMouse.containsMouse ? 0.44 : 0.18)
                                }

                                MouseArea {
                                    id: timelineCommandMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: root.selectTimelineCommand(timelineCommandRow.commandData)
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 18
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 7
                                    anchors.bottomMargin: 7
                                    spacing: 2

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: String(timelineCommandRow.commandData.commandName || qsTr("Command"))
                                        theme: root.pageTheme
                                        styleRole: "bodyM"
                                        colorOverride: timelineCommandRow.selected ? "#f8fafc" : undefined
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: root.timelineCommandMeta(timelineCommandRow.commandData)
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
                            visible: root.visibleTimelineCommands.length === 0
                            text: qsTr("No timeline commands")
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }
                    }
                }
            }
        }
    }

}
