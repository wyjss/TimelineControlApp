import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UiCore/qml/components/base" as Base
import "qrc:/UiCore/qml/theme" as Theme

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
    property var deviceModel: appRuntime && appRuntime.deviceModel ? appRuntime.deviceModel : null
    readonly property var devices: deviceModel ? deviceModel.devices : []
    readonly property var pcDevices: buildPcDevices()
    readonly property var selectedCommands: commandsByPc[selectedPcId] || []
    readonly property var selectedCommand: commandForId(selectedCommandId)
    readonly property var selectedVideos: selectedCommand && selectedCommand.videos ? selectedCommand.videos : []
    readonly property real baseWidth: 1920
    readonly property real baseHeight: 1080
    property string selectedPcId: ""
    property string selectedCommandId: ""
    property string selectedVideoId: ""
    property var commandsByPc: ({})
    property int nextCommandIndex: 1

    onPcDevicesChanged: ensureSelectedPc()
    onSelectedPcIdChanged: {
        selectedVideoId = ""
        ensureSelectedCommand()
    }
    onSelectedCommandsChanged: ensureSelectedCommand()

    Component.onCompleted: ensureSelectedPc()

    function buildPcDevices() {
        var result = []
        for (var index = 0; index < devices.length; ++index) {
            var device = devices[index]
            if (device && device.supportsProtocol !== undefined && device.supportsProtocol("pc"))
                result.push(device)
        }
        return result
    }

    function pcName(device) {
        var name = device ? String(device.name || "").trim() : ""
        return name.length > 0 ? name : String(device && device.id ? device.id : qsTr("PC设备"))
    }

    function pcAddress(device) {
        var values = device && device.configValues ? device.configValues : {}
        var ip = String(values.ip || "").trim()
        var port = String(values.ipPort || values.port || "").trim()
        var address = ip.length > 0 && port.length > 0 ? ip + ":" + port : ip
        return address.length > 0 ? address : qsTr("未分配")
    }

    function ensureSelectedPc() {
        if (pcDevices.length === 0) {
            selectedPcId = ""
            return
        }

        for (var index = 0; index < pcDevices.length; ++index) {
            if (String(pcDevices[index].id || "") === selectedPcId)
                return
        }
        selectedPcId = String(pcDevices[0].id || "")
    }

    function commandForId(commandId) {
        var normalizedId = String(commandId || "")
        for (var index = 0; index < selectedCommands.length; ++index) {
            if (String(selectedCommands[index].id || "") === normalizedId)
                return selectedCommands[index]
        }
        return null
    }

    function ensureSelectedCommand() {
        if (selectedCommands.length === 0) {
            selectedCommandId = ""
            selectedVideoId = ""
            return
        }

        if (!commandForId(selectedCommandId)) {
            selectedCommandId = String(selectedCommands[0].id || "")
            selectedVideoId = ""
        }
    }

    function setCommandsForSelectedPc(commands) {
        var map = {}
        for (var key in commandsByPc)
            map[key] = commandsByPc[key]
        map[selectedPcId] = commands
        commandsByPc = map
    }

    function updateSelectedCommand(values) {
        var next = []
        for (var index = 0; index < selectedCommands.length; ++index) {
            var command = selectedCommands[index]
            if (String(command.id || "") !== selectedCommandId) {
                next.push(command)
                continue
            }

            var updated = {}
            for (var key in command)
                updated[key] = command[key]
            for (var valueKey in values)
                updated[valueKey] = values[valueKey]
            next.push(updated)
        }
        setCommandsForSelectedPc(next)
    }

    function addCommand() {
        if (selectedPcId.length === 0)
            return

        var index = nextCommandIndex
        nextCommandIndex += 1
        var command = {
            "id": "virtual-command-" + index,
            "name": qsTr("虚拟播放 %1").arg(index),
            "videos": [],
            "nextVideoIndex": 1
        }
        setCommandsForSelectedPc(selectedCommands.concat([command]))
        selectedCommandId = command.id
        selectedVideoId = ""
    }

    function removeSelectedCommand() {
        if (selectedCommandId.length === 0)
            return

        var row = 0
        var next = []
        for (var index = 0; index < selectedCommands.length; ++index) {
            if (String(selectedCommands[index].id || "") === selectedCommandId) {
                row = next.length
                continue
            }
            next.push(selectedCommands[index])
        }
        setCommandsForSelectedPc(next)
        selectedCommandId = next.length > 0 ? String(next[Math.min(row, next.length - 1)].id || "") : ""
        selectedVideoId = ""
    }

    function colorAt(index) {
        var colors = ["#60a5fa", "#fb7185", "#34d399", "#fbbf24", "#a78bfa", "#22d3ee"]
        return colors[index % colors.length]
    }

    function addVideo() {
        if (!selectedCommand)
            return

        var index = selectedCommand.nextVideoIndex || 1
        var width = 384
        var video = {
            "id": selectedCommand.id + "-video-" + index,
            "name": qsTr("视频 %1").arg(index),
            "url": "",
            "color": colorAt(index - 1),
            "x": 96 + (index - 1) * 36,
            "y": 72 + (index - 1) * 24,
            "width": width,
            "height": width * baseHeight / baseWidth
        }
        updateSelectedCommand({
            "videos": selectedVideos.concat([video]),
            "nextVideoIndex": index + 1
        })
        selectedVideoId = video.id
    }

    function removeSelectedVideo() {
        if (!selectedCommand || selectedVideoId.length === 0)
            return

        var row = 0
        var next = []
        for (var index = 0; index < selectedVideos.length; ++index) {
            if (String(selectedVideos[index].id || "") === selectedVideoId) {
                row = next.length
                continue
            }
            next.push(selectedVideos[index])
        }
        updateSelectedCommand({ "videos": next })
        selectedVideoId = next.length > 0 ? String(next[Math.min(row, next.length - 1)].id || "") : ""
    }

    function updateVideo(videoId, values) {
        var next = []
        for (var index = 0; index < selectedVideos.length; ++index) {
            var item = selectedVideos[index]
            if (String(item.id || "") !== videoId) {
                next.push(item)
                continue
            }

            var updated = {}
            for (var key in item)
                updated[key] = item[key]
            for (var valueKey in values)
                updated[valueKey] = values[valueKey]
            updated.width = Math.max(64, Math.min(baseWidth - updated.x, Number(updated.width)))
            updated.height = updated.width * baseHeight / baseWidth
            updated.x = Math.max(0, Math.min(baseWidth - updated.width, Number(updated.x)))
            updated.y = Math.max(0, Math.min(baseHeight - updated.height, Number(updated.y)))
            next.push(updated)
        }
        updateSelectedCommand({ "videos": next })
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pageMargin
        spacing: 14

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("虚拟播放指令")
            theme: root.pageTheme
            styleRole: "titleL"
            elide: Text.ElideRight
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            columnSpacing: 14
            rowSpacing: 14

            Base.AppSurface {
                Layout.preferredWidth: 250
                Layout.fillHeight: true
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 10

                    Base.AppText {
                        Layout.fillWidth: true
                        text: qsTr("PC设备")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                        elide: Text.ElideRight
                    }

                    Repeater {
                        model: root.pcDevices

                        delegate: Base.AppSurface {
                            Layout.fillWidth: true
                            sizeToContent: true
                            theme: root.pageTheme
                            surfaceTone: String(modelData.id || "") === root.selectedPcId ? "highlight" : "surface"
                            active: String(modelData.id || "") === root.selectedPcId
                            interactive: true
                            padding: 10

                            ColumnLayout {
                                width: parent.width
                                spacing: 2

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: root.pcName(modelData)
                                    theme: root.pageTheme
                                    styleRole: "bodyM"
                                    elide: Text.ElideRight
                                }

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: root.pcAddress(modelData)
                                    theme: root.pageTheme
                                    styleRole: "bodyS"
                                    textTone: "secondary"
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.selectedPcId = String(modelData.id || "")
                            }
                        }
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        visible: root.pcDevices.length === 0
                        text: qsTr("暂无PC设备")
                        theme: root.pageTheme
                        styleRole: "bodyS"
                        textTone: "secondary"
                        elide: Text.ElideRight
                    }
                }
            }

            Base.AppSurface {
                Layout.preferredWidth: 280
                Layout.fillHeight: true
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Base.AppText {
                            Layout.fillWidth: true
                            text: qsTr("虚拟播放指令")
                            theme: root.pageTheme
                            styleRole: "sectionTitle"
                            elide: Text.ElideRight
                        }

                        Base.AppButton {
                            text: qsTr("添加")
                            theme: root.pageTheme
                            iconName: "workflow"
                            enabled: root.selectedPcId.length > 0
                            onClicked: root.addCommand()
                        }
                    }

                    Repeater {
                        model: root.selectedCommands

                        delegate: Base.AppSurface {
                            Layout.fillWidth: true
                            sizeToContent: true
                            theme: root.pageTheme
                            surfaceTone: String(modelData.id || "") === root.selectedCommandId ? "highlight" : "surface"
                            active: String(modelData.id || "") === root.selectedCommandId
                            interactive: true
                            padding: 10

                            ColumnLayout {
                                width: parent.width
                                spacing: 2

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: String(modelData.name || "")
                                    theme: root.pageTheme
                                    styleRole: "bodyM"
                                    elide: Text.ElideRight
                                }

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: qsTr("%1 个视频").arg(modelData.videos ? modelData.videos.length : 0)
                                    theme: root.pageTheme
                                    styleRole: "bodyS"
                                    textTone: "secondary"
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.selectedCommandId = String(modelData.id || "")
                                    root.selectedVideoId = ""
                                }
                            }
                        }
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        visible: root.selectedPcId.length > 0 && root.selectedCommands.length === 0
                        text: qsTr("暂无虚拟播放指令")
                        theme: root.pageTheme
                        styleRole: "bodyS"
                        textTone: "secondary"
                        elide: Text.ElideRight
                    }
                }
            }

            Base.AppSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 520
                Layout.minimumHeight: 360
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Base.AppText {
                            Layout.fillWidth: true
                            text: root.selectedCommand ? String(root.selectedCommand.name || "") : qsTr("未选择指令")
                            theme: root.pageTheme
                            styleRole: "sectionTitle"
                            elide: Text.ElideRight
                        }

                        Base.AppButton {
                            text: qsTr("添加视频")
                            iconName: "scene"
                            theme: root.pageTheme
                            enabled: root.selectedCommand !== null
                            onClicked: root.addVideo()
                        }

                        Base.AppButton {
                            text: qsTr("移除视频")
                            theme: root.pageTheme
                            enabled: root.selectedVideoId.length > 0
                            onClicked: root.removeSelectedVideo()
                        }

                        Base.AppButton {
                            text: qsTr("移除指令")
                            theme: root.pageTheme
                            enabled: root.selectedCommand !== null
                            onClicked: root.removeSelectedCommand()
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 2
                        columnSpacing: 12

                        Base.AppSurface {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            sizeToContent: false
                            theme: root.pageTheme
                            surfaceTone: "surface"

                            Item {
                                id: stageWrap

                                anchors.fill: parent
                                anchors.margins: 14
                                clip: true
                                readonly property real scaleValue: Math.min(width / root.baseWidth, height / root.baseHeight)

                                Item {
                                    id: stage

                                    readonly property real scaleValue: stageWrap.scaleValue
                                    width: root.baseWidth * scaleValue
                                    height: root.baseHeight * scaleValue
                                    anchors.centerIn: parent

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#0f172a"
                                        border.width: 1
                                        border.color: "#334155"
                                    }

                                    Repeater {
                                        model: root.selectedVideos

                                        delegate: Item {
                                            id: videoBox

                                            property var videoData: modelData
                                            property string videoId: String(videoData.id || "")
                                            property color frameColor: videoData.color || "#60a5fa"
                                            readonly property bool selected: videoId === root.selectedVideoId

                                            x: Number(videoData.x || 0) * stage.scaleValue
                                            y: Number(videoData.y || 0) * stage.scaleValue
                                            width: Number(videoData.width || 384) * stage.scaleValue
                                            height: Number(videoData.height || 216) * stage.scaleValue

                                            Rectangle {
                                                anchors.fill: parent
                                                color: videoBox.frameColor
                                                opacity: videoBox.selected ? 0.24 : 0.16
                                                border.width: videoBox.selected ? 3 : 2
                                                border.color: videoBox.frameColor
                                            }

                                            Base.AppText {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.margins: 8
                                                text: String(videoBox.videoData.name || "")
                                                theme: root.pageTheme
                                                styleRole: "bodyS"
                                                colorOverride: "#f8fafc"
                                                elide: Text.ElideRight
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                acceptedButtons: Qt.LeftButton
                                                drag.target: videoBox
                                                drag.minimumX: 0
                                                drag.minimumY: 0
                                                drag.maximumX: stage.width - videoBox.width
                                                drag.maximumY: stage.height - videoBox.height
                                                onPressed: root.selectedVideoId = videoBox.videoId
                                                onReleased: root.updateVideo(videoBox.videoId, {
                                                    "x": videoBox.x / stage.scaleValue,
                                                    "y": videoBox.y / stage.scaleValue
                                                })
                                            }

                                            Rectangle {
                                                width: 14
                                                height: 14
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                color: videoBox.frameColor
                                                border.width: 1
                                                border.color: "#f8fafc"

                                                MouseArea {
                                                    anchors.fill: parent
                                                    acceptedButtons: Qt.LeftButton
                                                    property real startWidth: 0
                                                    property real startX: 0

                                                    onPressed: {
                                                        root.selectedVideoId = videoBox.videoId
                                                        startWidth = videoBox.width
                                                        startX = mapToItem(stage, mouse.x, mouse.y).x
                                                    }
                                                    onPositionChanged: {
                                                        var point = mapToItem(stage, mouse.x, mouse.y)
                                                        var nextWidth = Math.max(64 * stage.scaleValue, startWidth + point.x - startX)
                                                        nextWidth = Math.min(nextWidth, stage.width - videoBox.x)
                                                        var nextHeight = nextWidth * root.baseHeight / root.baseWidth
                                                        if (videoBox.y + nextHeight > stage.height) {
                                                            nextHeight = stage.height - videoBox.y
                                                            nextWidth = nextHeight * root.baseWidth / root.baseHeight
                                                        }
                                                        videoBox.width = nextWidth
                                                        videoBox.height = nextHeight
                                                    }
                                                    onReleased: root.updateVideo(videoBox.videoId, {
                                                        "width": videoBox.width / stage.scaleValue,
                                                        "height": videoBox.height / stage.scaleValue
                                                    })
                                                }
                                            }
                                        }
                                    }

                                    Base.AppText {
                                        anchors.centerIn: parent
                                        visible: root.selectedVideos.length === 0
                                        text: root.selectedCommand ? qsTr("暂无视频") : qsTr("请选择或添加指令")
                                        theme: root.pageTheme
                                        styleRole: "bodyM"
                                        textTone: "secondary"
                                    }
                                }
                            }
                        }

                        Base.AppSurface {
                            Layout.preferredWidth: 220
                            Layout.fillHeight: true
                            sizeToContent: false
                            theme: root.pageTheme
                            surfaceTone: "surface"

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: qsTr("视频")
                                    theme: root.pageTheme
                                    styleRole: "bodyM"
                                    elide: Text.ElideRight
                                }

                                Repeater {
                                    model: root.selectedVideos

                                    delegate: Base.AppSurface {
                                        id: videoListItem

                                        readonly property string videoId: String(modelData.id || "")
                                        readonly property string videoUrl: String(modelData.url || "")
                                        readonly property bool urlMissing: videoUrl.trim().length === 0

                                        Layout.fillWidth: true
                                        sizeToContent: true
                                        theme: root.pageTheme
                                        surfaceTone: videoId === root.selectedVideoId ? "highlight" : "ghost"
                                        active: videoId === root.selectedVideoId
                                        padding: 8

                                        ColumnLayout {
                                            width: parent.width
                                            spacing: 8

                                            Item {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: videoHeader.implicitHeight

                                                RowLayout {
                                                    id: videoHeader

                                                    anchors.fill: parent
                                                    spacing: 8

                                                    Rectangle {
                                                        Layout.preferredWidth: 12
                                                        Layout.preferredHeight: 12
                                                        radius: 6
                                                        color: modelData.color || "#60a5fa"
                                                    }

                                                    Base.AppText {
                                                        Layout.fillWidth: true
                                                        text: String(modelData.name || "")
                                                        theme: root.pageTheme
                                                        styleRole: "bodyS"
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: root.selectedVideoId = videoListItem.videoId
                                                }
                                            }

                                            Base.AppTextField {
                                                Layout.fillWidth: true
                                                theme: root.pageTheme
                                                text: videoListItem.videoUrl
                                                placeholderText: qsTr("视频URL")
                                                onActiveFocusChanged: {
                                                    if (activeFocus)
                                                        root.selectedVideoId = videoListItem.videoId
                                                }
                                                onEditingFinished: root.updateVideo(videoListItem.videoId, { "url": text })
                                            }

                                            Base.AppText {
                                                Layout.fillWidth: true
                                                visible: videoListItem.urlMissing
                                                text: qsTr("URL必填")
                                                theme: root.pageTheme
                                                styleRole: "bodyS"
                                                colorOverride: "#ef4444"
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }

                                Base.AppText {
                                    Layout.fillWidth: true
                                    visible: root.selectedVideos.length === 0
                                    text: qsTr("暂无视频")
                                    theme: root.pageTheme
                                    styleRole: "bodyS"
                                    textTone: "secondary"
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
