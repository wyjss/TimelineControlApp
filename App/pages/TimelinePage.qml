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
    property var appRuntime: typeof app !== "undefined" ? app : null
    property var timelineManager: appRuntime && appRuntime.timelineManager ? appRuntime.timelineManager : null
    property var timelineCommandModel: appRuntime && appRuntime.timelineCommandModel ? appRuntime.timelineCommandModel : null
    property var deviceManager: appRuntime && appRuntime.deviceManager ? appRuntime.deviceManager : null
    property var deviceModel: appRuntime && appRuntime.deviceModel ? appRuntime.deviceModel : null
    readonly property int timelineDurationMs: timelineManager ? timelineManager.durationMs : 1800000
    readonly property var devices: deviceModel ? deviceModel.devices : []
    readonly property var availableCommands: buildAvailableCommands()
    readonly property var selectedCommand: commandForId(selectedCommandId)
    property int timelineCurrentTimeMs: 0
    property real timelineScrollX: 0
    property real timelineTimeScale: 1.0
    property string selectedTimelineDeviceId: ""
    property var selectedTimelineDevice: null
    property string selectedCommandId: ""
    property string executionStatusText: ""

    onDevicesChanged: ensureSelectedTimelineDevice()
    onSelectedTimelineDeviceIdChanged: {
        updateSelectedTimelineDevice()
        ensureSelectedCommand()
    }
    onAvailableCommandsChanged: ensureSelectedCommand()

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

    function buildAvailableCommands() {
        if (!selectedTimelineDevice)
            return []

        var protocol = String(selectedTimelineDevice.protocol || "").trim().toLowerCase()
        if (protocol === "pc") {
            return [
                {
                    "id": "pc-play-video",
                    "name": qsTr("Play Video"),
                    "summary": qsTr("start playback on selected PC"),
                    "protocol": "pc",
                    "durationMs": 0,
                    "params": { "action": "play" }
                },
                {
                    "id": "pc-pause-video",
                    "name": qsTr("Pause Video"),
                    "summary": qsTr("pause current playback"),
                    "protocol": "pc",
                    "durationMs": 0,
                    "params": { "action": "pause" }
                },
                {
                    "id": "pc-stop-video",
                    "name": qsTr("Stop Video"),
                    "summary": qsTr("stop current playback"),
                    "protocol": "pc",
                    "durationMs": 0,
                    "params": { "action": "stop" }
                },
                {
                    "id": "pc-show-projection",
                    "name": qsTr("Show Projection"),
                    "summary": qsTr("enable mapped projection output"),
                    "protocol": "pc",
                    "durationMs": 1000,
                    "params": { "action": "showProjection" }
                }
            ]
        }

        if (protocol === "serial") {
            return [
                {
                    "id": "serial-send",
                    "name": qsTr("Send Payload"),
                    "summary": qsTr("write payload to serial device"),
                    "protocol": "serial",
                    "durationMs": 0,
                    "params": { "payload": "" }
                },
                {
                    "id": "serial-query",
                    "name": qsTr("Query Status"),
                    "summary": qsTr("request current device status"),
                    "protocol": "serial",
                    "durationMs": 0,
                    "params": { "payload": "STATUS" }
                }
            ]
        }

        if (protocol === "dmx512") {
            return [
                {
                    "id": "dmx-blackout",
                    "name": qsTr("Blackout"),
                    "summary": qsTr("set fixture output to zero"),
                    "protocol": "dmx512",
                    "durationMs": 500,
                    "params": { "value": 0 }
                },
                {
                    "id": "dmx-full-on",
                    "name": qsTr("Full On"),
                    "summary": qsTr("set fixture output to full"),
                    "protocol": "dmx512",
                    "durationMs": 500,
                    "params": { "value": 255 }
                }
            ]
        }

        return [
            {
                "id": "device-execute",
                "name": qsTr("Execute"),
                "summary": qsTr("run default device command"),
                "protocol": protocol.length > 0 ? protocol : "generic",
                "durationMs": 0,
                "params": {}
            }
        ]
    }

    function commandForId(commandId) {
        var normalizedCommandId = String(commandId || "")
        for (var index = 0; index < availableCommands.length; ++index) {
            if (String(availableCommands[index].id || "") === normalizedCommandId)
                return availableCommands[index]
        }

        return null
    }

    function ensureSelectedCommand() {
        if (availableCommands.length === 0) {
            selectedCommandId = ""
            return
        }

        if (!commandForId(selectedCommandId))
            selectedCommandId = String(availableCommands[0].id || "")
    }

    function selectCommand(commandId) {
        selectedCommandId = String(commandId || "")
    }

    function addSelectedCommandAtCurrentTime() {
        if (!timelineManager || !selectedTimelineDevice || !selectedCommand) {
            executionStatusText = qsTr("Select a device and command first")
            return
        }

        var commandParams = {}
        for (var key in selectedCommand) {
            if (key !== "id" && key !== "name")
                commandParams[key] = selectedCommand[key]
        }

        commandParams.templateId = String(selectedCommand.id || "")
        commandParams.targetDeviceName = deviceName(selectedTimelineDevice)
        commandParams.targetDeviceAddress = deviceAddress(selectedTimelineDevice)

        var startTimeMs = Math.max(0, Math.round(timelineCurrentTimeMs))
        timelineManager.addCommand(startTimeMs,
                                   String(selectedTimelineDevice.id || ""),
                                   String(selectedCommand.name || qsTr("Command")),
                                   commandParams)
        executionStatusText = qsTr("Added %1 at %2 ms").arg(String(selectedCommand.name || qsTr("Command"))).arg(startTimeMs)
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

    function executeTimeline() {
        executionStatusText = qsTr("Timeline execution is ready")
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 32
        anchors.rightMargin: 32
        anchors.topMargin: 64
        anchors.bottomMargin: 44
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
            columns: 2
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
                        startTimeX: width / 2
                        timeScale: root.timelineTimeScale
                        onScrollXChangeRequested: function(nextScrollX) {
                            root.timelineScrollX = nextScrollX
                        }
                        onCurrentTimeMsChangeRequested: function(nextCurrentTimeMs) {
                            root.timelineCurrentTimeMs = nextCurrentTimeMs
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
                        Layout.preferredHeight: 176
                        sizeToContent: false
                        theme: root.pageTheme
                        surfaceTone: "surface"

                        ListView {
                            id: deviceList

                            anchors.fill: parent
                            anchors.margins: 10
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            spacing: 8
                            model: root.devices

                            delegate: Base.AppSurface {
                                id: deviceRow

                                readonly property var deviceData: modelData
                                readonly property bool selected: String(deviceData.id || "") === root.selectedTimelineDeviceId

                                width: deviceList.width
                                height: 62
                                sizeToContent: false
                                theme: root.pageTheme
                                surfaceTone: "section"
                                active: selected
                                interactive: true
                                strokeWidth: selected ? 2 : 1
                                borderOverride: selected ? "#7cb4ff" : undefined

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.selectTimelineDevice(String(deviceRow.deviceData.id || ""))
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 8
                                    anchors.bottomMargin: 8
                                    spacing: 2

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: root.deviceName(deviceRow.deviceData)
                                        theme: root.pageTheme
                                        styleRole: "bodyM"
                                        textTone: "primary"
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

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 76
                        sizeToContent: false
                        theme: root.pageTheme
                        surfaceTone: "surface"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            Base.AppText {
                                text: qsTr("Target Device")
                                theme: root.pageTheme
                                styleRole: "bodyS"
                                textTone: "secondary"
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.selectedTimelineDevice ? root.deviceName(root.selectedTimelineDevice) : qsTr("Unassigned")
                                theme: root.pageTheme
                                styleRole: "bodyM"
                                elide: Text.ElideRight
                            }
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
                            text: qsTr("%1").arg(root.availableCommands.length)
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 198
                        sizeToContent: false
                        theme: root.pageTheme
                        surfaceTone: "surface"

                        ListView {
                            id: commandList

                            anchors.fill: parent
                            anchors.margins: 10
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            spacing: 8
                            model: root.availableCommands

                            delegate: Base.AppSurface {
                                id: commandRow

                                readonly property var commandData: modelData
                                readonly property bool selected: String(commandData.id || "") === root.selectedCommandId

                                width: commandList.width
                                height: 58
                                sizeToContent: false
                                theme: root.pageTheme
                                surfaceTone: "section"
                                active: selected
                                interactive: true
                                strokeWidth: selected ? 2 : 1
                                borderOverride: selected ? "#7cb4ff" : undefined

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.selectCommand(String(commandRow.commandData.id || ""))
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 8
                                    anchors.bottomMargin: 8
                                    spacing: 2

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: String(commandRow.commandData.name || qsTr("Command"))
                                        theme: root.pageTheme
                                        styleRole: "bodyM"
                                        textTone: "primary"
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: String(commandRow.commandData.summary || "")
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
                            visible: root.availableCommands.length === 0
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
                        enabled: root.timelineManager && root.selectedTimelineDevice && root.selectedCommand
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

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
        }
    }

}
