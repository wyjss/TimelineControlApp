import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import "qrc:/UICore/qml/components/base" as Base

Item {
    id: root

    property QtObject theme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : null
    property var ruler: null
    property var commands: []
    property string deviceIdFilter: ""
    property string selectedCommandId: ""
    property real timelineOffsetX: 0
    property int instantCommandMinWidth: 56
    property int instantCommandMaxWidth: 132
    readonly property var visibleCommands: filterCommands()
    readonly property int count: visibleCommands.length

    signal commandSelected(var command)

    function colorValue(name, fallback) {
        return theme && theme.colors && theme.colors[name] !== undefined
            ? theme.colors[name]
            : fallback
    }

    function filterCommands() {
        if (deviceIdFilter.length === 0)
            return commands || []

        return (commands || []).filter(function(command) {
            return String(command && command.targetDeviceId || "") === deviceIdFilter
        })
    }

    function timeToX(ms) {
        return (ruler ? ruler.timeToX(ms) : 0) - timelineOffsetX
    }

    function durationToWidth(ms) {
        var pixelsPerSecond = ruler ? ruler.effectivePixelsPerSecond : 1
        return Math.max(1, ms / 1000 * pixelsPerSecond)
    }

    function commandStartMs(command) {
        return command && command.startTimeMs !== undefined && command.startTimeMs !== null
            ? Number(command.startTimeMs)
            : 0
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

        switch (String(commandParams.protocol)) {
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

    function commandSameSlot(left, right) {
        return commandStartMs(left) === commandStartMs(right)
            && (commandDurationMs(left) <= 0) === (commandDurationMs(right) <= 0)
    }

    function commandStackIndex(command) {
        var commandId = String(command && command.id || "")
        var stackIndex = 0
        for (var index = 0; index < visibleCommands.length; ++index) {
            var other = visibleCommands[index]
            if (!commandSameSlot(other, command))
                continue
            if (other === command || (commandId.length > 0 && String(other.id || "") === commandId))
                return stackIndex
            ++stackIndex
        }
        return 0
    }

    function commandStackCount(command) {
        var count = 0
        for (var index = 0; index < visibleCommands.length; ++index) {
            if (commandSameSlot(visibleCommands[index], command))
                ++count
        }
        return Math.max(1, count)
    }

    function instantCommandDisplayWidth(command) {
        var text = String(command && command.commandName ? command.commandName : qsTr("指令"))
        return Math.min(instantCommandMaxWidth,
                        Math.max(instantCommandMinWidth,
                                 Math.ceil(commandFontMetrics.advanceWidth(text)) + 28))
    }

    function commandInfo(command) {
        if (!command)
            return ""

        var commandParams = command.commandParams || {}
        var parts = [String(command.commandName || qsTr("指令"))]
        var deviceText = String(commandParams.targetDeviceName || command.targetDeviceId || "")
        if (deviceText.length > 0)
            parts.push(deviceText)
        parts.push(qsTr("%1 ms").arg(commandStartMs(command)))
        if (String(command.stateText || "").length > 0)
            parts.push(String(command.stateText))

        var values = commandParams.executionInputFields || {}
        var valueParts = []
        Object.keys(values).forEach(function(key) {
            var value = values[key]
            if (value === undefined || value === null || String(value).length === 0)
                return
            if (typeof value === "boolean")
                value = value ? qsTr("是") : qsTr("否")
            valueParts.push(String(value))
        })
        if (valueParts.length > 0)
            parts.push(valueParts.join(" / "))
        return parts.join(" · ")
    }

    function instantCommandLayout(command) {
        var instantCommands = []
        for (var index = 0; index < visibleCommands.length; ++index) {
            var item = visibleCommands[index]
            if (commandDurationMs(item) <= 0)
                instantCommands.push({ "command": item, "order": index })
        }
        instantCommands.sort(function(left, right) {
            return commandStartMs(left.command) - commandStartMs(right.command)
                || left.order - right.order
        })

        var layouts = {}
        var laneEnd = [-Number.MAX_VALUE, -Number.MAX_VALUE, -Number.MAX_VALUE]
        var laneCommandKey = ["", "", ""]
        var laneOrder = [1, 0, 2]
        for (index = 0; index < instantCommands.length; ++index) {
            item = instantCommands[index].command
            var key = String(item.id || instantCommands[index].order)
            var anchorX = timeToX(commandStartMs(item))
            var commandWidth = instantCommandDisplayWidth(item)
            var onLeft = anchorX + commandWidth > root.width && anchorX - commandWidth >= 0
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
                    "mergedCommands": [item],
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
                    "mergedCommands": [item],
                    "onLeft": onLeft,
                    "width": commandWidth
                }
                var overflowLayout = layouts[overflowKey]
                overflowLayout.mergedCommands.push(item)
                overflowLayout.overflowCount = overflowLayout.mergedCommands.length - 1
                if (overflowLayout.overflowCount === 1) {
                    var overflowAnchorX = timeToX(commandStartMs(overflowLayout.mergedCommands[0]))
                    overflowLayout.width += 20
                    overflowLayout.onLeft = overflowAnchorX + overflowLayout.width > root.width
                        && overflowAnchorX - overflowLayout.width >= 0
                    var overflowLeftX = overflowLayout.onLeft
                        ? overflowAnchorX - overflowLayout.width + 6
                        : overflowAnchorX - 6
                    laneEnd[2] = overflowLeftX + overflowLayout.width
                }
                laneEnd[2] = Math.max(laneEnd[2], rightX)
            }
        }

        key = String(command && command.id || visibleCommands.indexOf(command))
        return layouts[key] || {
            "lane": 1,
            "visible": true,
            "overflowCount": 0,
            "mergedCommands": command ? [command] : [],
            "onLeft": false,
            "width": instantCommandMinWidth
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        y: Math.round(parent.height / 2)
        height: 1
        color: root.colorValue("border", "#334155")
        opacity: 0.20
    }

    Base.AppText {
        id: commandMeasureText

        visible: false
        styleRole: UiStyle.TypographyRole.BodyS
    }

    FontMetrics {
        id: commandFontMetrics

        font: commandMeasureText.font
    }

    Repeater {
        model: root.visibleCommands

        delegate: Item {
            id: commandBlock

            property var commandData: modelData
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
            readonly property int stackIndex: root.commandStackIndex(commandData)
            readonly property int stackCount: root.commandStackCount(commandData)
            readonly property var instantLayout: instantCommand
                ? root.instantCommandLayout(commandData)
                : ({ "lane": 1, "visible": true, "overflowCount": 0, "onLeft": false, "width": 0 })
            readonly property bool overflowCommand: instantCommand && instantLayout.overflowCount > 0
            readonly property string displayText: overflowCommand
                ? commandText + " +" + String(instantLayout.overflowCount)
                : commandText
            readonly property real anchorX: root.timeToX(root.commandStartMs(commandData))
            readonly property bool instantLabelOnLeft: instantCommand && instantLayout.onLeft
            readonly property real stackOffsetY: instantCommand
                ? (instantLayout.lane - 1) * 18
                : (stackIndex - (stackCount - 1) / 2) * 8

            x: instantCommand
                ? anchorX - (instantLabelOnLeft ? width - 6 : 6)
                : anchorX
            y: 0
            width: instantCommand
                ? instantLayout.width
                : Math.max(40, root.durationToWidth(durationMs))
            height: root.height
            z: selected ? 3 : (commandMouse.containsMouse ? 2 : 1)
            visible: instantLayout.visible && x + width > 0 && x < root.width

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
                    ? commandBlock.instantLayout.mergedCommands.map(function(command) {
                        return "• " + root.commandInfo(command)
                    }).join("\n")
                    : root.commandInfo(commandBlock.commandData)
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
                    || Number(commandBlock.commandData && commandBlock.commandData.state !== undefined
                        ? commandBlock.commandData.state
                        : 0) !== 0
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
