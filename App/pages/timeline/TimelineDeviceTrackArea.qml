import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import "qrc:/UICore/qml/components/base" as Base

Item {
    id: root

    property QtObject theme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : null
    property var ruler
    property var devices: []
    property var commandModel: null
    property var commandList: commandModel && commandModel.commands ? commandModel.commands : []
    property var childTracksByParentId: ({})
    property var expandedParentTrackIds: ({})
    property string selectedDeviceId: ""
    property string selectedCommandId: ""
    property int rowHeight: 56
    property int childRowHeight: 30
    property int rowSpacing: 4
    property int labelWidth: 224
    property int instantCommandMinWidth: 56
    property int instantCommandMaxWidth: 132
    property int moveAnimationDuration: 220

    signal trackSelected(string targetDeviceId)
    signal commandSelected(var command)

    implicitHeight: Math.max(220, devices.length * (rowHeight + rowSpacing) - rowSpacing)
    clip: true

    function colorValue(name, fallback) {
        return theme && theme.colors && theme.colors[name] !== undefined
            ? theme.colors[name]
            : fallback
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
        var protocolText = (device.supportedProtocols || []).map(function(protocol) {
            return String(protocol).toLowerCase() === "internal" ? qsTr("无协议") : String(protocol)
        }).join(", ").trim()
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
            && (commandDurationMs(left) <= 0) === (commandDurationMs(right) <= 0)
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

    function instantCommandDisplayWidth(command) {
        var text = String(command && command.commandName ? command.commandName : qsTr("指令"))
        return Math.min(instantCommandMaxWidth,
                        Math.max(instantCommandMinWidth,
                                 Math.ceil(instantCommandFontMetrics.advanceWidth(text)) + 28))
    }

    function instantCommandLayout(command, deviceId, contentWidth) {
        var commands = []
        for (var index = 0; index < commandList.length; ++index) {
            var item = commandList[index]
            if (commandBelongsToDevice(item, deviceId) && commandDurationMs(item) <= 0)
                commands.push({ "command": item, "order": index })
        }
        commands.sort(function(left, right) {
            return commandStartMs(left.command) - commandStartMs(right.command)
                || left.order - right.order
        })

        var layouts = {}
        var laneEnd = [-Number.MAX_VALUE, -Number.MAX_VALUE, -Number.MAX_VALUE]
        var laneCommandKey = ["", "", ""]
        var laneOrder = [1, 0, 2]
        for (index = 0; index < commands.length; ++index) {
            item = commands[index].command
            var key = String(item.id || commands[index].order)
            var anchorX = timeToX(commandStartMs(item)) - labelWidth
            var commandWidth = instantCommandDisplayWidth(item)
            var onLeft = anchorX + commandWidth > contentWidth
                && anchorX - commandWidth >= 0
            var leftX = onLeft ? anchorX - commandWidth + 6 : anchorX - 6
            var rightX = leftX + commandWidth
            var lane = -1
            for (var laneIndex = 0; laneIndex < laneOrder.length; ++laneIndex) {
                var candidate = laneOrder[laneIndex]
                if (leftX >= laneEnd[candidate] + 6) {
                    lane = candidate
                    break
                }
            }

            if (lane >= 0) {
                layouts[key] = {
                    "lane": lane,
                    "visible": true,
                    "overflowCount": 0,
                    "onLeft": onLeft,
                    "width": commandWidth
                }
                laneEnd[lane] = rightX
                laneCommandKey[lane] = key
            } else {
                var overflowKey = laneCommandKey[2]
                layouts[key] = {
                    "lane": 2,
                    "visible": false,
                    "overflowCount": 0,
                    "onLeft": onLeft,
                    "width": commandWidth
                }
                layouts[overflowKey].overflowCount += 1
                laneEnd[2] = Math.max(laneEnd[2], rightX)
            }
        }

        key = String(command && command.id || commandList.indexOf(command))
        return layouts[key] || {
            "lane": 1,
            "visible": true,
            "overflowCount": 0,
            "onLeft": false,
            "width": instantCommandMinWidth
        }
    }

    function childTracksForParent(parentTrackId) {
        var tracks = childTracksByParentId
            ? childTracksByParentId[String(parentTrackId || "")]
            : null
        return tracks && tracks.length !== undefined ? tracks : []
    }

    function parentTrackExpanded(parentTrackId) {
        return expandedParentTrackIds
            && expandedParentTrackIds[String(parentTrackId || "")] === true
    }

    function toggleParentTrack(parentTrackId) {
        var normalizedParentTrackId = String(parentTrackId || "")
        var nextExpandedIds = {}
        for (var trackId in expandedParentTrackIds)
            nextExpandedIds[trackId] = expandedParentTrackIds[trackId]
        nextExpandedIds[normalizedParentTrackId] = !parentTrackExpanded(normalizedParentTrackId)
        expandedParentTrackIds = nextExpandedIds
    }

    function rebuildTrackModel() {
        trackModel.clear()
        for (var index = 0; index < root.devices.length; ++index)
            trackModel.append({ "sourceIndex": index })

        Qt.callLater(positionSelectedTrack)
    }

    function positionSelectedTrack() {
        for (var index = 0; index < trackModel.count; ++index) {
            var sourceIndex = Number(trackModel.get(index).sourceIndex)
            var device = sourceIndex >= 0 && sourceIndex < root.devices.length
                ? root.devices[sourceIndex]
                : null
            if (device && String(device.id || "") === root.selectedDeviceId) {
                trackList.positionViewAtIndex(index, ListView.Contain)
                return
            }
        }
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
    onSelectedDeviceIdChanged: Qt.callLater(positionSelectedTrack)
    Component.onCompleted: rebuildTrackModel()

    ListModel {
        id: trackModel

        dynamicRoles: true
    }

    Base.AppText {
        id: instantCommandMeasureText

        visible: false
        styleRole: UiStyle.TypographyRole.BodyS
    }

    FontMetrics {
        id: instantCommandFontMetrics

        font: instantCommandMeasureText.font
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
            readonly property var childTracks: root.childTracksForParent(targetDeviceId)
            readonly property bool expanded: childTracks.length > 0
                && root.parentTrackExpanded(targetDeviceId)

            width: trackList.width
            height: root.rowHeight + (expanded ? childTracks.length * root.childRowHeight : 0)

            Rectangle {
                width: parent.width
                height: root.rowHeight
                radius: 6
                color: trackRow.selected
                    ? root.colorValue("highlightSoft", "#162d4a")
                    : (trackMouse.containsMouse
                        ? root.colorValue("backgroundWindowVariant", "#131d28")
                        : "transparent")
                border.width: trackRow.selected ? 1 : 0
                border.color: root.colorValue("highlightText", "#78afff")
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
                y: 9
                width: 3
                height: root.rowHeight - 18
                radius: 2
                color: trackRow.selected
                    ? root.colorValue("highlightText", "#78afff")
                    : root.colorValue("border", "#334155")
                opacity: trackRow.selected ? 1 : (trackMouse.containsMouse ? 0.45 : 0.16)
            }

            MouseArea {
                id: trackMouse

                width: parent.width
                height: root.rowHeight
                hoverEnabled: true
                onClicked: {
                    root.trackSelected(trackRow.targetDeviceId)
                    if (mouse.x < root.labelWidth && trackRow.childTracks.length > 0)
                        root.toggleParentTrack(trackRow.targetDeviceId)
                }
            }

            Base.AppText {
                x: 10
                y: Math.round((root.rowHeight - height) / 2)
                visible: trackRow.childTracks.length > 0
                text: trackRow.expanded ? "▾" : "›"
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
                z: 2
            }

            Column {
                x: trackRow.childTracks.length > 0 ? 28 : 14
                y: Math.round((root.rowHeight - height) / 2)
                width: Math.max(80, root.labelWidth - x - 14)
                spacing: 4
                z: 2

                Base.AppText {
                    width: parent.width
                    text: root.deviceName(trackRow.trackData)
                    styleRole: UiStyle.TypographyRole.BodyM
                    textTone: UiStyle.TextTone.Primary
                    elide: Text.ElideRight
                }

                Base.AppText {
                    width: parent.width
                    text: root.deviceMeta(trackRow.trackData).length > 0
                        ? root.deviceMeta(trackRow.trackData)
                        : trackRow.targetDeviceId
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    elide: Text.ElideRight
                }
            }

            Item {
                x: root.labelWidth
                y: 0
                width: Math.max(0, parent.width - root.labelWidth)
                height: root.rowHeight
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
                            : root.colorValue("neutralText", "#cbd5e1")
                        readonly property string commandText: String(commandData && commandData.commandName
                            ? commandData.commandName
                            : qsTr("指令"))
                        readonly property bool selected: String(commandData && commandData.id || "")
                            === root.selectedCommandId
                        readonly property int stackIndex: root.commandStackIndex(commandData, trackRow.targetDeviceId)
                        readonly property int stackCount: root.commandStackCount(commandData, trackRow.targetDeviceId)
                        readonly property var instantLayout: instantCommand
                            ? root.instantCommandLayout(commandData, trackRow.targetDeviceId, parent.width)
                            : ({ "lane": 1, "visible": true, "overflowCount": 0, "onLeft": false, "width": 0 })
                        readonly property bool overflowCommand: instantCommand
                            && instantLayout.overflowCount > 0
                        readonly property string displayText: overflowCommand
                            ? "+" + String(instantLayout.overflowCount + 1)
                            : commandText
                        readonly property real anchorX: root.timeToX(root.commandStartMs(commandData))
                            - root.labelWidth
                        readonly property bool instantLabelOnLeft: instantCommand
                            && instantLayout.onLeft
                        readonly property real stackOffsetY: instantCommand
                            ? (instantLayout.lane - 1) * 18
                            : (stackIndex - (stackCount - 1) / 2) * 8

                        x: instantCommand
                            ? anchorX - (instantLabelOnLeft ? width - 6 : 6)
                            : anchorX
                        y: 0
                        width: belongsToTrack
                            ? (instantCommand ? instantLayout.width : Math.max(40, root.durationToWidth(durationMs)))
                            : 0
                        height: parent.height
                        z: selected ? 3 : (commandMouse.containsMouse ? 2 : 1)
                        visible: belongsToTrack && instantLayout.visible && x + width > 0 && x < parent.width

                        MouseArea {
                            id: commandMouse

                            x: commandBlock.instantCommand ? instantCommandPill.x : 0
                            y: commandBlock.instantCommand
                                ? instantCommandPill.y
                                : Math.round(parent.height / 2 - height / 2 + commandBlock.stackOffsetY)
                            width: commandBlock.instantCommand ? instantCommandPill.width : parent.width
                            height: commandBlock.instantCommand ? instantCommandPill.height : 26
                            hoverEnabled: true
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 500
                            ToolTip.text: commandBlock.overflowCommand
                                ? qsTr("重叠区域内合并 %1 条指令")
                                    .arg(commandBlock.instantLayout.overflowCount + 1)
                                : qsTr("%1 · %2 ms")
                                    .arg(commandBlock.commandText)
                                    .arg(root.commandStartMs(commandBlock.commandData))
                            onClicked: {
                                mouse.accepted = true
                                root.commandSelected(commandBlock.commandData)
                            }
                        }

                        Rectangle {
                            visible: commandBlock.instantCommand
                            x: commandBlock.instantLabelOnLeft ? parent.width - 6 : 6
                            y: 8
                            width: 1
                            height: parent.height - 16
                            color: commandBlock.commandColor
                            opacity: commandMouse.containsMouse || commandBlock.selected ? 0.9 : 0.52
                        }

                        Rectangle {
                            visible: commandBlock.instantCommand
                            x: commandBlock.instantLabelOnLeft ? parent.width - 14 : 6
                            y: Math.round(parent.height / 2 + commandBlock.stackOffsetY)
                            width: 8
                            height: 1
                            color: commandBlock.commandColor
                            opacity: 0.76
                        }

                        Rectangle {
                            id: instantCommandPill

                            visible: commandBlock.instantCommand
                            x: commandBlock.instantLabelOnLeft ? 0 : 14
                            y: Math.round(parent.height / 2 - height / 2 + commandBlock.stackOffsetY)
                            width: parent.width - 14
                            height: 16
                            radius: 4
                            color: commandBlock.commandColor
                            opacity: commandMouse.containsMouse || commandBlock.selected ? 0.96 : 0.84
                            border.width: commandMouse.containsMouse || commandBlock.selected ? 1 : 0
                            border.color: commandBlock.selected
                                ? root.colorValue("inverseText", "#f8fafc")
                                : commandBlock.stateColor
                        }

                        Rectangle {
                            visible: commandBlock.instantCommand
                            width: commandMouse.containsMouse || commandBlock.selected ? 10 : 8
                            height: width
                            x: (commandBlock.instantLabelOnLeft ? parent.width - 6 : 6) - width / 2
                            y: Math.round(parent.height / 2 - height / 2 + commandBlock.stackOffsetY)
                            radius: 2
                            rotation: 45
                            color: commandBlock.commandColor
                            border.width: 1
                            border.color: commandBlock.stateColor
                            opacity: 0.96
                        }

                        Base.AppText {
                            id: instantCommandText

                            visible: commandBlock.instantCommand
                            anchors.fill: instantCommandPill
                            anchors.leftMargin: 7
                            anchors.rightMargin: 7
                            text: commandBlock.displayText
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Inverse
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            visible: !commandBlock.instantCommand
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: commandBlock.stackOffsetY
                            width: parent.width
                            height: commandMouse.containsMouse || commandBlock.selected ? 26 : 24
                            radius: height / 2
                            color: commandBlock.commandColor
                            opacity: commandMouse.containsMouse || commandBlock.selected ? 0.96 : 0.86
                            border.width: commandMouse.containsMouse || commandBlock.selected
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
                            color: root.colorValue("inverseText", "#f8fafc")
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
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Inverse
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Repeater {
                model: trackRow.expanded ? trackRow.childTracks : []

                delegate: Item {
                    id: childTrackRow

                    property var childTrackData: modelData || ({})

                    x: 0
                    y: root.rowHeight + index * root.childRowHeight
                    width: trackRow.width
                    height: root.childRowHeight

                    Rectangle {
                        anchors.fill: parent
                        color: root.colorValue("backgroundSection", "#172033")
                        opacity: 0.28
                    }

                    Rectangle {
                        x: root.labelWidth
                        width: 1
                        height: parent.height
                        color: root.colorValue("border", "#334155")
                        opacity: 0.38
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: root.colorValue("border", "#334155")
                        opacity: 0.12
                    }

                    Rectangle {
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: String(childTrackRow.childTrackData.color || "#16a34a")
                    }

                    Base.AppText {
                        x: 28
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(40, root.labelWidth - x - 12)
                        text: String(childTrackRow.childTrackData.title || qsTr("子轨"))
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Secondary
                        elide: Text.ElideMiddle
                    }

                    Item {
                        id: childTrackContent

                        x: root.labelWidth
                        width: Math.max(0, parent.width - root.labelWidth)
                        height: parent.height
                        clip: true

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 1
                            color: root.colorValue("border", "#334155")
                            opacity: 0.14
                        }

                        Repeater {
                            model: childTrackRow.childTrackData.segments || []

                            delegate: Rectangle {
                                property var segmentData: modelData || ({})
                                readonly property real startTimeMs: Math.max(0, Number(segmentData.startTimeMs || 0))
                                readonly property real sourceEndTimeMs: Number(segmentData.endTimeMs)
                                readonly property real endTimeMs: sourceEndTimeMs < 0 && root.ruler
                                    ? root.ruler.durationMs
                                    : Math.max(startTimeMs, sourceEndTimeMs)
                                readonly property real startX: root.timeToX(startTimeMs) - root.labelWidth
                                readonly property real endX: root.timeToX(endTimeMs) - root.labelWidth

                                x: Math.max(0, startX)
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(1, Math.min(parent.width, endX) - x)
                                height: 14
                                radius: 3
                                color: String(segmentData.color || childTrackRow.childTrackData.color || "#16a34a")
                                opacity: 0.82
                                visible: endTimeMs > startTimeMs && endX > 0 && startX < parent.width
                            }
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
        color: root.colorValue("dangerFill", "#f85149")
        opacity: 0.58
        visible: ruler && x >= root.labelWidth && x <= parent.width
        z: 10
    }
}
