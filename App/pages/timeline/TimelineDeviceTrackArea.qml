import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import "qrc:/UICore/qml/components/base" as Base
import "../../components" as AppComponents

Item {
    id: root

    property QtObject theme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : null
    property var ruler
    property var devices: []
    property var commandModel: null
    property var childTracksByParentId: ({})
    property var expandedParentTrackIds: ({})
    property string selectedDeviceId: ""
    property string selectedCommandId: ""
    property int rowHeight: 48
    property int childRowHeight: 30
    property int rowSpacing: 0
    property int labelWidth: 224
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

    Repeater {
        model: root.ruler ? root.ruler.labelTicks : []

        delegate: Rectangle {
            x: Math.round(modelData.x)
            width: 1
            height: root.height
            color: root.colorValue("subtleText", "#94a3b8")
            opacity: 0.08
        }
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
            objectName: "timelineTrack_" + targetDeviceId

            readonly property int sourceTrackIndex: index >= 0 && index < trackModel.count
                ? Number(trackModel.get(index).sourceIndex)
                : -1
            property var trackData: sourceTrackIndex >= 0 && sourceTrackIndex < root.devices.length
                ? root.devices[sourceTrackIndex]
                : ({})
            readonly property string targetDeviceId: String(trackData.id || "")
            readonly property bool selected: root.trackSelectedState(trackData)
            readonly property bool online: Boolean(trackData.online)
            readonly property bool filteredOut: trackData && trackData.filteredOut
            readonly property var childTracks: root.childTracksForParent(targetDeviceId)
            readonly property bool expanded: childTracks.length > 0
                && root.parentTrackExpanded(targetDeviceId)

            readonly property int mainRowHeight: Math.max(root.rowHeight, trackCommands.implicitHeight)

            width: trackList.width
            height: trackRow.mainRowHeight + (expanded ? childTracks.length * root.childRowHeight : 0)

            Rectangle {
                width: parent.width
                height: trackRow.mainRowHeight
                color: root.colorValue("subtleText", "#94a3b8")
                opacity: index % 2 === 1 ? 0.045 : 0
            }

            Rectangle {
                width: parent.width
                height: trackRow.mainRowHeight
                color: root.colorValue("inverseText", "#f8fafc")
                opacity: trackMouse.containsMouse ? 0.04 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }
            }

            Rectangle {
                width: parent.width
                height: trackRow.mainRowHeight
                color: root.colorValue("highlightFill", "#2f6feb")
                opacity: trackRow.selected ? 0.14 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }
            }

            Rectangle {
                width: root.labelWidth
                height: trackRow.mainRowHeight
                color: root.colorValue("highlightFill", "#2f6feb")
                opacity: trackRow.selected ? 0.22 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: root.colorValue("subtleText", "#94a3b8")
                opacity: 0.08
            }

            Rectangle {
                x: root.labelWidth
                y: 0
                width: 1
                height: parent.height
                color: root.colorValue("subtleText", "#94a3b8")
                opacity: 0.12
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 2
                y: 0
                width: 2
                height: trackRow.mainRowHeight
                radius: 2
                color: root.colorValue("highlightText", "#78afff")
                opacity: trackRow.selected ? 1 : 0
            }

            MouseArea {
                id: trackMouse

                width: parent.width
                height: trackRow.mainRowHeight
                hoverEnabled: true
                onClicked: {
                    root.trackSelected(trackRow.targetDeviceId)
                    if (mouse.x < root.labelWidth && trackRow.childTracks.length > 0)
                        root.toggleParentTrack(trackRow.targetDeviceId)
                }
            }

            Base.AppText {
                x: 10
                y: Math.round((trackRow.mainRowHeight - height) / 2)
                visible: trackRow.childTracks.length > 0
                text: trackRow.expanded ? "▾" : "›"
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
                z: 2
            }

            Row {
                x: trackRow.childTracks.length > 0 ? 28 : 14
                y: Math.round((trackRow.mainRowHeight - height) / 2)
                width: Math.max(80, root.labelWidth - x - 14)
                spacing: 8
                opacity: trackRow.filteredOut ? 0.42 : 1
                z: 2

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }

                Rectangle {
                    id: onlineIndicator

                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: trackRow.filteredOut
                        ? root.colorValue("neutralBorder", "#45576b")
                        : (trackRow.online
                        ? root.colorValue("successFill", "#22c55e")
                        : root.colorValue("dangerFill", "#ef4444"))
                }

                AppComponents.DeviceIcon {
                    id: deviceTypeIcon

                    anchors.verticalCenter: parent.verticalCenter
                    size: 20
                    name: String(trackRow.trackData.deviceType || "")
                }

                Base.AppText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(40, parent.width
                        - deviceTypeIcon.width - onlineIndicator.width - parent.spacing * 2)
                    text: root.deviceName(trackRow.trackData)
                    styleRole: UiStyle.TypographyRole.BodyM
                    textTone: trackRow.filteredOut
                        ? UiStyle.TextTone.Secondary
                        : UiStyle.TextTone.Primary
                    elide: Text.ElideRight
                }
            }

            TimelineCommandHorizontalList {
                id: trackCommands

                x: root.labelWidth
                y: 0
                width: Math.max(0, parent.width - root.labelWidth)
                height: trackRow.mainRowHeight
                clip: true
                theme: root.theme
                ruler: root.ruler
                commands: root.commandModel && root.commandModel.commands
                    ? root.commandModel.commands
                    : []
                devices: root.devices
                deviceIdFilter: trackRow.targetDeviceId
                selectedCommandId: root.selectedCommandId
                timelineOffsetX: root.labelWidth
                onCommandSelected: function(command) {
                    root.commandSelected(command)
                }
            }

            Repeater {
                model: trackRow.expanded ? trackRow.childTracks : []

                delegate: Item {
                    id: childTrackRow

                    property var childTrackData: modelData || ({})

                    x: 0
                    y: trackRow.mainRowHeight + index * root.childRowHeight
                    width: trackRow.width
                    height: root.childRowHeight
                    opacity: trackRow.filteredOut ? 0.42 : 1

                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: root.colorValue("backgroundWindow", "#12161a")
                        opacity: 0.20
                    }

                    Rectangle {
                        x: root.labelWidth
                        width: 1
                        height: parent.height
                        color: root.colorValue("subtleText", "#94a3b8")
                        opacity: 0.12
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: root.colorValue("subtleText", "#94a3b8")
                        opacity: 0.06
                    }

                    Rectangle {
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: trackRow.filteredOut
                            ? root.colorValue("neutralBorder", "#45576b")
                            : String(childTrackRow.childTrackData.color || "#16a34a")
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
                                color: trackRow.filteredOut
                                    ? root.colorValue("neutralBorder", "#45576b")
                                    : String(segmentData.color
                                             || childTrackRow.childTrackData.color
                                             || "#16a34a")
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
        opacity: 0.90
        visible: ruler && x >= root.labelWidth && x <= parent.width
        z: 10
    }
}
