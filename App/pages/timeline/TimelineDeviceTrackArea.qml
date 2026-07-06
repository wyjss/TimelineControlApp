import QtQuick 2.14
import "qrc:/UiCore/qml/components/base" as Base
import "qrc:/UiCore/qml/components/base/internal/AppThemeUtils.js" as ThemeUtils

Item {
    id: root

    property QtObject theme
    property var ruler
    property var devices: []
    property var commandModel: null
    property var commandList: commandModel && commandModel.commands ? commandModel.commands : []
    property string selectedDeviceId: ""
    property int rowHeight: 56
    property int rowSpacing: 4
    property int labelWidth: 224
    property int moveAnimationDuration: 220

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
            return qsTr("设备")

        var name = String(device.name || "").trim()
        return name.length > 0 ? name : String(device.id || qsTr("设备"))
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

    function commandBelongsToDevice(command, deviceId) {
        return command
            && String(command.targetDeviceId || "") === String(deviceId || "")
    }

    function commandSameSlot(left, right, deviceId) {
        return commandBelongsToDevice(left, deviceId)
            && commandBelongsToDevice(right, deviceId)
            && commandStartMs(left) === commandStartMs(right)
    }

    function commandStackIndex(command, deviceId) {
        var commandId = String(command && command.id || "")
        var stackIndex = 0
        for (var index = 0; index < commandList.length; ++index) {
            var other = commandList[index]
            if (!commandSameSlot(other, command, deviceId))
                continue

            if (other === command || (commandId.length > 0 && String(other.id || "") === commandId))
                return stackIndex

            ++stackIndex
        }
        return 0
    }

    function commandStackCount(command, deviceId) {
        var count = 0
        for (var index = 0; index < commandList.length; ++index) {
            if (commandSameSlot(commandList[index], command, deviceId))
                ++count
        }
        return Math.max(1, count)
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
                easing.type: Easing.OutQuad
            }
        }

        moveDisplaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: root.moveAnimationDuration
                easing.type: Easing.OutQuad
            }
        }

        addDisplaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: root.moveAnimationDuration
                easing.type: Easing.OutQuad
            }
        }

        removeDisplaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: root.moveAnimationDuration
                easing.type: Easing.OutQuad
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

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: trackRow.selected
                    ? Qt.rgba(96 / 255, 165 / 255, 250 / 255, 0.10)
                    : (trackMouse.containsMouse ? Qt.rgba(148 / 255, 163 / 255, 184 / 255, 0.06) : "transparent")
                border.width: trackRow.selected ? 1 : 0
                border.color: "#60a5fa"
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: root.colorValue("border", "#334155")
                opacity: 0.16
            }

            Rectangle {
                x: root.labelWidth
                y: 0
                width: 1
                height: parent.height
                color: root.colorValue("border", "#334155")
                opacity: 0.38
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: parent.height - 18
                radius: 2
                color: trackRow.selected ? "#60a5fa" : root.colorValue("border", "#334155")
                opacity: trackRow.selected ? 1 : (trackMouse.containsMouse ? 0.45 : 0.16)
            }

            MouseArea {
                id: trackMouse

                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.trackSelected(trackRow.targetDeviceId)
            }

            Column {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(80, root.labelWidth - 28)
                spacing: 4
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
                    text: root.deviceMeta(trackRow.trackData).length > 0
                        ? root.deviceMeta(trackRow.trackData)
                        : trackRow.targetDeviceId
                    theme: root.theme
                    styleRole: "bodyS"
                    textTone: "secondary"
                    elide: Text.ElideRight
                }
            }

            Item {
                x: root.labelWidth
                y: 0
                width: Math.max(0, parent.width - root.labelWidth)
                height: parent.height
                clip: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: Math.round(parent.height / 2)
                    height: 1
                    color: root.colorValue("border", "#334155")
                    opacity: 0.20
                }

                Repeater {
                    model: root.commandModel

                    delegate: Item {
                        id: commandBlock

                        property var commandData: typeof model !== "undefined" && model.command !== undefined
                            ? model.command
                            : (typeof command !== "undefined" ? command : null)
                        readonly property bool belongsToTrack: root.commandBelongsToDevice(commandData, trackRow.targetDeviceId)
                        readonly property real durationMs: root.commandDurationMs(commandData)
                        readonly property bool instantCommand: durationMs <= 0
                        readonly property color commandColor: root.commandColor(commandData)
                        readonly property color stateColor: commandData && commandData.stateColor
                            ? commandData.stateColor
                            : "#dbeafe"
                        readonly property string commandText: String(commandData && commandData.commandName
                            ? commandData.commandName
                            : qsTr("指令"))
                        readonly property int stackIndex: root.commandStackIndex(commandData, trackRow.targetDeviceId)
                        readonly property int stackCount: root.commandStackCount(commandData, trackRow.targetDeviceId)
                        readonly property real stackOffsetY: (stackIndex - (stackCount - 1) / 2) * 8

                        x: root.timeToX(root.commandStartMs(commandData))
                           - root.labelWidth
                           - (instantCommand ? width / 2 : 0)
                        y: 0
                        width: belongsToTrack
                            ? (instantCommand ? 22 : Math.max(40, root.durationToWidth(durationMs)))
                            : 0
                        height: parent.height
                        visible: belongsToTrack && x + width > 0 && x < parent.width

                        MouseArea {
                            id: commandMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                mouse.accepted = true
                                root.commandSelected(commandBlock.commandData)
                            }
                        }

                        Rectangle {
                            visible: commandBlock.instantCommand
                            x: Math.round(parent.width / 2)
                            y: 8
                            width: 1
                            height: parent.height - 16
                            color: commandBlock.commandColor
                            opacity: commandMouse.containsMouse ? 0.9 : 0.52
                        }

                        Rectangle {
                            visible: commandBlock.instantCommand
                            width: commandMouse.containsMouse ? 14 : 12
                            height: width
                            x: Math.round((parent.width - width) / 2)
                            y: Math.round(parent.height / 2 - height / 2 + commandBlock.stackOffsetY)
                            radius: width / 2
                            color: commandBlock.commandColor
                            border.width: 1
                            border.color: commandBlock.stateColor
                            opacity: 0.96
                        }

                        Rectangle {
                            visible: !commandBlock.instantCommand
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: commandBlock.stackOffsetY
                            width: parent.width
                            height: commandMouse.containsMouse ? 26 : 24
                            radius: height / 2
                            color: commandBlock.commandColor
                            opacity: commandMouse.containsMouse ? 0.96 : 0.86
                            border.width: commandMouse.containsMouse
                                || Number(commandBlock.commandData && commandBlock.commandData.state !== undefined ? commandBlock.commandData.state : 0) !== 0
                                ? 1
                                : 0
                            border.color: commandBlock.stateColor
                        }

                        Rectangle {
                            visible: !commandBlock.instantCommand
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: commandBlock.stackOffsetY
                            width: 2
                            height: 28
                            radius: 1
                            color: "#f8fafc"
                            opacity: 0.62
                        }

                        Base.AppText {
                            visible: !commandBlock.instantCommand && parent.width >= 56
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: commandBlock.stackOffsetY
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            text: commandBlock.commandText
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
    }

    Rectangle {
        x: ruler ? Math.round(ruler.currentTimeX) : 0
        y: 0
        width: 1
        height: parent.height
        color: "#ef4444"
        opacity: 0.58
        visible: ruler && x >= root.labelWidth && x <= parent.width
        z: 10
    }
}
