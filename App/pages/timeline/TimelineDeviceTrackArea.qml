import QtQuick 2.14
import "qrc:/UiCore/qml/components/base" as Base
import "qrc:/UiCore/qml/components/base/internal/AppThemeUtils.js" as ThemeUtils

Item {
    id: root

    property QtObject theme
    property var ruler
    property var devices: []
    property var commandModel: null
    property string selectedDeviceId: ""
    property int rowHeight: 64
    property int rowSpacing: 8
    property int labelWidth: 168
    property int moveAnimationDuration: 2500

    signal trackSelected(string targetDeviceId)
    signal commandSelected(var command)

    implicitHeight: Math.max(220, devices.length * (rowHeight + rowSpacing) - rowSpacing)
    clip: true

    function colorValue(name, fallback) {
        return ThemeUtils.colorValue(theme, name, fallback)
    }

    function timeToX(ms) {
        return ruler ? ruler.timeToX(ms) : 0
    }

    function durationToWidth(ms) {
        var pixelsPerSecond = ruler ? ruler.effectivePixelsPerSecond : 1
        return Math.max(1, ms / 1000 * pixelsPerSecond)
    }

    function commandStartMs(command) {
        if (!command)
            return 0

        if (command.startTimeMs !== undefined && command.startTimeMs !== null)
            return Number(command.startTimeMs)

        return 0
    }

    function commandDurationMs(command) {
        if (!command)
            return 0

        if (command.durationMs !== undefined && command.durationMs !== null)
            return Number(command.durationMs)

        var commandParams = command.commandParams || {}
        return commandParams.durationMs !== undefined && commandParams.durationMs !== null
            ? Number(commandParams.durationMs)
            : 0
    }

    function commandColor(command) {
        var commandParams = command && command.commandParams ? command.commandParams : {}
        if (commandParams.color !== undefined && String(commandParams.color).length > 0)
            return String(commandParams.color)

        var protocol = commandParams.protocol
        switch (String(protocol)) {
        case "dmx512":
            return "#2563eb"
        case "http":
            return "#0891b2"
        case "pc":
            return "#16a34a"
        case "serial":
            return "#d97706"
        default:
            return "#4f46e5"
        }
    }

    function trackSelectedState(trackData) {
        return trackData
            && trackData.id !== undefined
            && String(trackData.id) === root.selectedDeviceId
    }

    function deviceName(device) {
        if (!device)
            return qsTr("Device")

        var name = String(device.name || "").trim()
        return name.length > 0 ? name : String(device.id || qsTr("Device"))
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

    function commandBelongsToDevice(command, deviceId) {
        return command
            && String(command.targetDeviceId || "") === String(deviceId || "")
    }

    function rebuildTrackModel() {
        trackModel.clear()
        for (var index = 0; index < root.devices.length; ++index)
            trackModel.append({ "sourceIndex": index })
    }

    function randomIndex(maxExclusive) {
        return Math.floor(Math.random() * maxExclusive)
    }

    function previewMoveAnimation() {
        if (trackModel.count < 2)
            return

        var moveCount = trackModel.count > 2 ? 1 + randomIndex(2) : 1
        for (var index = 0; index < moveCount; ++index) {
            var from = randomIndex(trackModel.count)
            var to = randomIndex(trackModel.count)
            if (from === to)
                to = (to + 1) % trackModel.count

            trackModel.move(from, to, 1)
        }
    }

    onDevicesChanged: rebuildTrackModel()
    Component.onCompleted: rebuildTrackModel()

    ListModel {
        id: trackModel

        dynamicRoles: true
    }

    ListView {
        id: trackList

        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: trackModel
        spacing: root.rowSpacing

        move: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: root.moveAnimationDuration
                easing.type: Easing.OutCubic
            }
        }

        moveDisplaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: root.moveAnimationDuration
                easing.type: Easing.OutCubic
            }
        }

        addDisplaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: root.moveAnimationDuration
                easing.type: Easing.OutCubic
            }
        }

        removeDisplaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: root.moveAnimationDuration
                easing.type: Easing.OutCubic
            }
        }

        delegate: Item {
            id: trackRow

            readonly property int sourceTrackIndex: index >= 0 && index < trackModel.count
                ? Number(trackModel.get(index).sourceIndex)
                : -1
            property var trackData: sourceTrackIndex >= 0 && sourceTrackIndex < root.devices.length
                ? root.devices[sourceTrackIndex]
                : ({})
            readonly property string targetDeviceId: String(trackData.id || "")
            readonly property bool selected: root.trackSelectedState(trackData)

            width: trackList.width
            height: root.rowHeight

            Base.AppSurface {
                anchors.fill: parent
                sizeToContent: false
                theme: root.theme
                surfaceTone: "surface"
                active: trackRow.selected
                strokeWidth: trackRow.selected ? 2 : 1
                borderOverride: trackRow.selected ? "#7cb4ff" : undefined
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.trackSelected(trackRow.targetDeviceId)
            }

            Rectangle {
                x: root.labelWidth
                y: 0
                width: 1
                height: parent.height
                color: root.colorValue("border", "#334155")
                opacity: 0.45
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                y: Math.round(parent.height / 2)
                height: 1
                color: root.colorValue("border", "#334155")
                opacity: 0.22
            }

            Column {
                x: 12
                y: 8
                width: Math.max(80, root.labelWidth - 24)
                spacing: 3
                z: 2

                Base.AppText {
                    width: parent.width
                    text: root.deviceName(trackRow.trackData)
                    theme: root.theme
                    styleRole: "bodyM"
                    textTone: "primary"
                    elide: Text.ElideRight
                }

                Base.AppText {
                    width: parent.width
                    text: root.deviceMeta(trackRow.trackData)
                    theme: root.theme
                    styleRole: "bodyS"
                    textTone: "secondary"
                    elide: Text.ElideRight
                }

                Base.AppText {
                    width: parent.width
                    text: trackRow.targetDeviceId
                    theme: root.theme
                    styleRole: "bodyS"
                    textTone: "secondary"
                    elide: Text.ElideRight
                }
            }

            Repeater {
                model: root.commandModel

                delegate: Rectangle {
                    id: commandBlock

                    property var commandData: typeof model !== "undefined" && model.command !== undefined
                        ? model.command
                        : (typeof command !== "undefined" ? command : null)
                    readonly property bool belongsToTrack: root.commandBelongsToDevice(commandData, trackRow.targetDeviceId)

                    x: root.timeToX(root.commandStartMs(commandData))
                    y: 18
                    width: belongsToTrack ? Math.max(24, root.durationToWidth(root.commandDurationMs(commandData))) : 0
                    height: belongsToTrack ? 28 : 0
                    radius: 4
                    color: root.commandColor(commandData)
                    opacity: 0.9
                    visible: belongsToTrack

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            mouse.accepted = true
                            root.commandSelected(commandBlock.commandData)
                        }
                    }

                    Base.AppText {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        text: String(commandBlock.commandData.commandName || qsTr("Command"))
                        theme: root.theme
                        styleRole: "bodyS"
                        textTone: "inverse"
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    Rectangle {
        x: ruler ? Math.round(ruler.currentTimeX) : 0
        y: 0
        width: 1
        height: parent.height
        color: "#ef4444"
        opacity: 0.58
        visible: ruler && x >= 0 && x <= parent.width
        z: 10
    }
}
