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
    property var devices: []
    property string deviceIdFilter: ""
    property string selectedCommandId: ""
    property bool editingEnabled: false
    property real timelineOffsetX: 0
    property int instantCommandMinWidth: 56
    property int instantCommandMaxWidth: 180
    readonly property var visibleCommands: filterCommands()
    readonly property int count: visibleCommands.length
    readonly property int instantLabelHeight: implicitHeight > 48
        ? Math.min(24, Math.floor((height - 8) / 3)) : 24

    // 密集指令保留三层标签空间，普通轨道使用紧凑高度。
    implicitHeight: visibleCommands.some(function(command) {
        return instantCommandLayout(command).lane !== 1
    }) ? 80 : 48

    signal commandSelected(var command)
    signal commandMoveRequested(var command, real startTimeMs)

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

    function commandStartMs(command) {
        return command && command.startTimeMs !== undefined && command.startTimeMs !== null
            ? Number(command.startTimeMs)
            : 0
    }

    function formatTime(ms) {
        var totalSeconds = Math.floor(Math.max(0, Number(ms || 0)) / 1000)
        var hours = Math.floor(totalSeconds / 3600)
        var minutes = Math.floor(totalSeconds / 60) % 60
        var seconds = totalSeconds % 60
        return (hours < 10 ? "0" : "") + hours + ":"
            + (minutes < 10 ? "0" : "") + minutes + ":"
            + (seconds < 10 ? "0" : "") + seconds
    }

    function commandFilteredOut(command) {
        if (command && command.filteredOut)
            return true

        var deviceId = String(command && command.targetDeviceId || "")
        for (var index = 0; index < devices.length; ++index) {
            var device = devices[index]
            if (String(device.id || "") === deviceId)
                return device.filteredOut
        }
        return false
    }

    function commandColor(command) {
        if (commandFilteredOut(command))
            return colorValue("neutralBorder", "#45576b")

        var targetCommand = command ? command.targetCommand : null
        switch (String(targetCommand ? targetCommand.protocol : "")) {
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

    function instantCommandDisplayWidth(command) {
        var text = String(command && command.commandName ? command.commandName : qsTr("指令"))
        return Math.min(instantCommandMaxWidth,
                        Math.max(instantCommandMinWidth,
                                 Math.ceil(commandFontMetrics.advanceWidth(text)) + 32))
    }

    function commandInfo(command) {
        if (!command)
            return ""

        var parts = [String(command.commandName || qsTr("指令"))]
        var deviceText = String(command.targetDeviceId || "")
        for (var index = 0; index < devices.length; ++index) {
            if (String(devices[index].id || "") === String(command.targetDeviceId || "")) {
                deviceText = String(devices[index].name || deviceText)
                break
            }
        }
        if (deviceText.length > 0)
            parts.push(deviceText)
        parts.push(formatTime(commandStartMs(command)))
        if (String(command.stateText || "").length > 0)
            parts.push(String(command.stateText))

        var values = command.executionInputValues || {}
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

    Base.AppText {
        id: commandMeasureText

        visible: false
        styleRole: UiStyle.TypographyRole.BodyM
    }

    FontMetrics {
        id: commandFontMetrics

        font: commandMeasureText.font
    }

    Repeater {
        model: root.visibleCommands

        delegate: Item {
            id: commandBlock
            objectName: "timelineCommand_" + String(commandData.id || "")

            property var commandData: modelData
            readonly property bool filteredOut: root.commandFilteredOut(commandData)
            readonly property color commandColor: root.commandColor(commandData)
            readonly property color stateColor: filteredOut
                ? root.colorValue("neutralBorder", "#45576b")
                : (commandData && commandData.stateColor
                ? commandData.stateColor
                : root.colorValue("neutralText", "#cbd5e1"))
            readonly property string commandText: String(commandData && commandData.commandName
                ? commandData.commandName
                : qsTr("指令"))
            readonly property bool selected: commandMouse.previewing || String(commandData && commandData.id || "")
                === root.selectedCommandId
            readonly property var instantLayout: root.instantCommandLayout(commandData)
            readonly property bool overflowCommand: instantLayout.overflowCount > 0
            readonly property string displayText: overflowCommand && !commandMouse.previewing
                ? commandText + " +" + String(instantLayout.overflowCount)
                : commandText
            // 拖动只预览时间位置，保留原标签排布，松开后再提交模型。
            readonly property real anchorX: root.timeToX(commandMouse.previewing
                ? commandMouse.previewStartTimeMs : root.commandStartMs(commandData))
            readonly property bool instantLabelOnLeft: instantLayout.onLeft
            readonly property real stackOffsetY: (instantLayout.lane - 1) * root.instantLabelHeight

            x: anchorX - (instantLabelOnLeft ? width - 6 : 6)
            y: 0
            width: instantLayout.width
            height: root.height
            z: commandMouse.previewing ? 4 : (selected ? 3 : (commandMouse.containsMouse ? 2 : 1))
            visible: commandMouse.previewing || (instantLayout.visible && x + width > 0 && x < root.width)
            opacity: filteredOut ? 0.48 : 1

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }

            MouseArea {
                id: commandMouse
                objectName: "timelineCommandHitArea"

                property bool dragArmed: false
                property bool dragged: false
                property bool dragCanceled: false
                property real pressX: 0
                property real pressStartTimeMs: 0
                property real pressScrollX: 0
                property real pressPixelsPerSecond: 1
                property real pressWidth: 0
                property real previewStartTimeMs: 0
                readonly property bool previewing: dragArmed && dragged
                readonly property bool dragContextValid: root.editingEnabled && visible && activeFocus
                    && (!root.ApplicationWindow.window || root.ApplicationWindow.window.active)
                    && root.ruler && root.ruler.scrollX === pressScrollX
                    && root.ruler.safePixelsPerSecond === pressPixelsPerSecond
                    && root.width === pressWidth
                    && root.commandStartMs(commandBlock.commandData) === pressStartTimeMs

                function cancelDrag() {
                    if (dragArmed) {
                        dragCanceled = true
                        dragArmed = false
                    }
                }

                onDragContextValidChanged: if (!dragContextValid) cancelDrag()
                onCanceled: cancelDrag()
                Keys.onPressed: {
                    if (event.key === Qt.Key_Escape && dragArmed) {
                        cancelDrag()
                        event.accepted = true
                    }
                }
                Keys.onReleased: {
                    if (event.key === Qt.Key_Control && dragArmed) {
                        cancelDrag()
                        event.accepted = true
                    }
                }

                x: instantCommandPill.x
                y: instantCommandPill.y
                width: instantCommandPill.width
                height: instantCommandPill.height
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                preventStealing: dragArmed
                cursorShape: dragArmed ? Qt.SizeHorCursor : Qt.ArrowCursor
                ToolTip.visible: previewing || containsMouse
                ToolTip.delay: previewing ? 0 : 500
                ToolTip.text: previewing
                    ? root.formatTime(previewStartTimeMs) + "." + ("00" + previewStartTimeMs % 1000).slice(-3)
                    : commandBlock.overflowCommand
                    ? commandBlock.instantLayout.mergedCommands.map(function(command) {
                        return "• " + root.commandInfo(command)
                    }).join("\n")
                    : root.commandInfo(commandBlock.commandData)
                onPressed: {
                    dragged = false
                    dragCanceled = false
                    if (!root.editingEnabled || !root.ruler || !(mouse.modifiers & Qt.ControlModifier))
                        return

                    pressX = mapToItem(root, mouse.x, mouse.y).x
                    pressStartTimeMs = root.commandStartMs(commandBlock.commandData)
                    previewStartTimeMs = pressStartTimeMs
                    pressScrollX = root.ruler.scrollX
                    pressPixelsPerSecond = root.ruler.safePixelsPerSecond
                    pressWidth = root.width
                    forceActiveFocus()
                    dragArmed = dragContextValid
                }
                onPositionChanged: {
                    if (!dragArmed)
                        return

                    var deltaX = mapToItem(root, mouse.x, mouse.y).x - pressX
                    if (!dragged && Math.abs(deltaX) < Qt.styleHints.startDragDistance)
                        return
                    dragged = true
                    previewStartTimeMs = Math.max(0, Math.min(root.ruler.durationMs,
                        Math.round(pressStartTimeMs + deltaX / pressPixelsPerSecond * 1000)))
                }
                onReleased: {
                    var moveRequested = previewing && dragContextValid
                        && (mouse.modifiers & Qt.ControlModifier)
                    var deltaX = mapToItem(root, mouse.x, mouse.y).x - pressX
                    var nextStartTimeMs = moveRequested ? Math.max(0, Math.min(root.ruler.durationMs,
                        Math.round(pressStartTimeMs + deltaX / pressPixelsPerSecond * 1000))) : pressStartTimeMs
                    dragArmed = false
                    if (moveRequested)
                        root.commandMoveRequested(commandBlock.commandData, nextStartTimeMs)
                }
                onClicked: {
                    mouse.accepted = true
                    if (!dragged && !dragCanceled)
                        root.commandSelected(commandBlock.commandData)
                }
            }

            Rectangle {
                x: commandBlock.instantLabelOnLeft ? parent.width - 6 : 6
                y: 8
                width: 1
                height: parent.height - 16
                color: commandBlock.commandColor
                opacity: commandMouse.containsMouse || commandBlock.selected ? 0.9 : 0.52
            }

            Rectangle {
                x: commandBlock.instantLabelOnLeft ? parent.width - 14 : 6
                y: Math.round(parent.height / 2 + commandBlock.stackOffsetY)
                width: 8
                height: 1
                color: commandBlock.commandColor
                opacity: 0.76
            }

            Rectangle {
                id: instantCommandPill

                x: commandBlock.instantLabelOnLeft ? 0 : 14
                y: Math.round(parent.height / 2 - height / 2 + commandBlock.stackOffsetY)
                width: parent.width - 14
                height: root.instantLabelHeight
                radius: 4
                color: Qt.rgba(commandBlock.commandColor.r,
                               commandBlock.commandColor.g,
                               commandBlock.commandColor.b,
                               commandBlock.selected ? 0.42 : (commandMouse.containsMouse ? 0.34 : 0.24))
                border.width: commandMouse.containsMouse || commandBlock.selected ? 1 : 0
                border.color: commandBlock.selected
                    ? root.colorValue("inverseText", "#f8fafc")
                    : commandBlock.stateColor
            }

            Rectangle {
                width: 8
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
                anchors.fill: instantCommandPill
                anchors.leftMargin: 9
                anchors.rightMargin: 9
                text: commandBlock.displayText
                styleRole: UiStyle.TypographyRole.BodyM
                textTone: commandBlock.filteredOut
                    ? UiStyle.TextTone.Neutral
                    : UiStyle.TextTone.Primary
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
    }
}
