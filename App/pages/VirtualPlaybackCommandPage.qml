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
    readonly property var selectedPc: {
        for (var index = 0; index < pcDevices.length; ++index) {
            if (String(pcDevices[index].id || "") === selectedPcId)
                return pcDevices[index]
        }
        return null
    }
    readonly property var selectedCommands: buildSelectedCommands()
    property var selectedCommand: null
    readonly property var selectedVideos: commandVideos(selectedCommand)
    readonly property var selectedVideo: {
        for (var index = 0; index < selectedVideos.length; ++index) {
            if (String(selectedVideos[index].id || "") === selectedVideoId)
                return selectedVideos[index]
        }
        return null
    }
    readonly property real baseWidth: 1920
    readonly property real baseHeight: 1080
    property string selectedPcId: ""
    property string selectedVideoId: ""

    onPcDevicesChanged: ensureSelectedPc()
    onSelectedPcIdChanged: {
        selectedCommand = null
        selectedVideoId = ""
        ensureSelectedCommand()
    }
    onSelectedCommandChanged: selectedVideoId = ""
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

    function buildSelectedCommands() {
        var result = []
        var commands = selectedPc && selectedPc.commands ? selectedPc.commands : []
        for (var index = 0; index < commands.length; ++index) {
            if (commands[index] && String(commands[index].commandType || "") === "virtualPlayback")
                result.push(commands[index])
        }
        return result
    }

    function commandField(command, key) {
        var fields = command && command.creationInputFields ? command.creationInputFields : []
        for (var index = 0; index < fields.length; ++index) {
            if (String(fields[index].key || "") === key)
                return fields[index]
        }
        return null
    }

    function commandVideos(command) {
        var field = commandField(command, "videos")
        return field && field.value ? field.value : []
    }

    function pcName(device) {
        var name = device ? String(device.name || "").trim() : ""
        return name.length > 0 ? name : String(device && device.id ? device.id : qsTr("PC设备"))
    }

    function pcAddress(device) {
        var values = device && device.configValues ? device.configValues : {}
        var ip = String(values.ip || "").trim()
        var port = String(values.port || "").trim()
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

    function ensureSelectedCommand() {
        var commands = selectedCommands || []
        for (var index = 0; index < commands.length; ++index) {
            if (commands[index] === selectedCommand)
                return
        }
        selectedCommand = commands.length > 0 ? commands[0] : null
    }

    function setSelectedVideos(videos) {
        var field = commandField(selectedCommand, "videos")
        if (field)
            field.value = videos
    }

    function addCommand() {
        if (!selectedPc || selectedPc.createCommandForType === undefined)
            return

        var index = selectedCommands.length + 1
        var command = selectedPc.createCommandForType("virtualPlayback")
        if (!command)
            return

        command.name = qsTr("虚拟播放 %1").arg(index)
        selectedCommand = command
    }

    function removeSelectedCommand() {
        if (!selectedPc || !selectedCommand)
            return

        var commands = selectedPc.commands || []
        for (var index = 0; index < commands.length; ++index) {
            if (commands[index] === selectedCommand) {
                selectedCommand = null
                selectedPc.removeCommandAt(index)
                return
            }
        }
    }

    function colorAt(index) {
        var colors = ["#60a5fa", "#fb7185", "#34d399", "#fbbf24", "#a78bfa", "#22d3ee"]
        return colors[index % colors.length]
    }

    function addVideo() {
        if (!selectedCommand)
            return

        var index = 1
        for (var videoIndex = 0; videoIndex < selectedVideos.length; ++videoIndex)
            index = Math.max(index, Number(selectedVideos[videoIndex].index || 0) + 1)
        var slot = (index - 1) % 9
        var width = 560
        var video = {
            "id": "virtual-video-" + Date.now() + "-" + index,
            "index": index,
            "name": qsTr("视频 %1").arg(index),
            "url": "",
            "color": colorAt(index - 1),
            "x": 80 + (slot % 3) * 600,
            "y": 60 + Math.floor(slot / 3) * 340,
            "width": width,
            "height": width * baseHeight / baseWidth
        }
        setSelectedVideos(selectedVideos.concat([video]))
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
        setSelectedVideos(next)
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
        setSelectedVideos(next)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pageMargin
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("虚拟播放指令")
                theme: root.pageTheme
                styleRole: "titleL"
                elide: Text.ElideRight
            }

            Base.AppText {
                text: qsTr("1920 × 1080")
                theme: root.pageTheme
                styleRole: "bodyS"
                textTone: "secondary"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Base.AppSurface {
                Layout.preferredWidth: 260
                Layout.fillHeight: true
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true

                        Base.AppText {
                            Layout.fillWidth: true
                            text: qsTr("PC设备")
                            theme: root.pageTheme
                            styleRole: "bodyM"
                            elide: Text.ElideRight
                        }

                        Base.AppText {
                            text: String(root.pcDevices.length)
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }
                    }

                    ListView {
                        id: pcList

                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(contentHeight, 176)
                        Layout.minimumHeight: 48
                        clip: true
                        spacing: 6
                        model: root.pcDevices

                        delegate: Base.AppSurface {
                            width: ListView.view.width
                            height: 54
                            sizeToContent: false
                            theme: root.pageTheme
                            surfaceTone: String(modelData.id || "") === root.selectedPcId ? "highlight" : "ghost"
                            active: String(modelData.id || "") === root.selectedPcId
                            interactive: true

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 10
                                spacing: 2

                                Base.AppText {
                                    width: parent.width
                                    text: root.pcName(modelData)
                                    theme: root.pageTheme
                                    styleRole: "bodyM"
                                    elide: Text.ElideRight
                                }

                                Base.AppText {
                                    width: parent.width
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

                        Base.AppText {
                            anchors.centerIn: parent
                            visible: root.pcDevices.length === 0
                            text: qsTr("暂无PC设备")
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: "#334155"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Base.AppText {
                            Layout.fillWidth: true
                            text: qsTr("播放指令")
                            theme: root.pageTheme
                            styleRole: "bodyM"
                            elide: Text.ElideRight
                        }

                        Base.AppButton {
                            text: qsTr("新增")
                            theme: root.pageTheme
                            iconName: "workflow"
                            enabled: root.selectedPcId.length > 0
                            onClicked: root.addCommand()
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: root.selectedCommands

                        delegate: Base.AppSurface {
                            width: ListView.view.width
                            height: 58
                            sizeToContent: false
                            theme: root.pageTheme
                            surfaceTone: modelData === root.selectedCommand ? "highlight" : "ghost"
                            active: modelData === root.selectedCommand
                            interactive: true

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 10
                                spacing: 3

                                Base.AppText {
                                    width: parent.width
                                    text: String(modelData.name || "")
                                    theme: root.pageTheme
                                    styleRole: "bodyM"
                                    elide: Text.ElideRight
                                }

                                Base.AppText {
                                    width: parent.width
                                    text: qsTr("%1 个视频").arg(root.commandVideos(modelData).length)
                                    theme: root.pageTheme
                                    styleRole: "bodyS"
                                    textTone: "secondary"
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.selectedCommand = modelData
                                }
                            }
                        }

                        Base.AppText {
                            anchors.centerIn: parent
                            visible: root.selectedCommands.length === 0
                            text: root.selectedPcId.length > 0 ? qsTr("暂无播放指令") : qsTr("请选择PC设备")
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                Base.AppSurface {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    sizeToContent: false
                    theme: root.pageTheme
                    surfaceTone: "section"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.selectedCommand ? String(root.selectedCommand.name || "") : qsTr("未选择指令")
                                theme: root.pageTheme
                                styleRole: "sectionTitle"
                                elide: Text.ElideRight
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: qsTr("%1 个视频").arg(root.selectedVideos.length)
                                theme: root.pageTheme
                                styleRole: "bodyS"
                                textTone: "secondary"
                                elide: Text.ElideRight
                            }
                        }

                        Base.AppButton {
                            text: qsTr("删除指令")
                            theme: root.pageTheme
                            enabled: root.selectedCommand !== null
                            onClicked: root.removeSelectedCommand()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 360
                        Layout.minimumHeight: 300
                        sizeToContent: false
                        theme: root.pageTheme
                        surfaceTone: "canvas"

                        Item {
                            id: stageWrap

                            anchors.fill: parent
                            anchors.margins: 18
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
                                    color: "#0b1118"
                                    border.width: 1
                                    border.color: "#475569"
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 1
                                    height: parent.height
                                    color: "#1e293b"
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 1
                                    color: "#1e293b"
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
                                        z: selected ? root.selectedVideos.length : index
                                        width: Number(videoData.width || 384) * stage.scaleValue
                                        height: Number(videoData.height || 216) * stage.scaleValue

                                        Rectangle {
                                            anchors.fill: parent
                                            color: videoBox.frameColor
                                            opacity: videoBox.selected ? 0.25 : 0.16
                                            border.width: videoBox.selected ? 3 : 2
                                            border.color: videoBox.frameColor
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            width: Math.min(parent.width, videoName.implicitWidth + 16)
                                            height: Math.min(26, parent.height)
                                            color: "#b30b1118"

                                            Base.AppText {
                                                id: videoName

                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                text: String(videoBox.videoData.name || "")
                                                theme: root.pageTheme
                                                styleRole: "bodyS"
                                                colorOverride: "#f8fafc"
                                                verticalAlignment: Text.AlignVCenter
                                                elide: Text.ElideRight
                                            }
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
                                            visible: videoBox.selected
                                            color: videoBox.frameColor
                                            border.width: 1
                                            border.color: "#f8fafc"

                                            MouseArea {
                                                anchors.fill: parent
                                                acceptedButtons: Qt.LeftButton
                                                property real startWidth: 0
                                                property real startX: 0

                                                onPressed: {
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
                                    text: root.selectedCommand ? qsTr("暂无视频") : qsTr("暂无可编辑内容")
                                    theme: root.pageTheme
                                    styleRole: "bodyM"
                                    textTone: "secondary"
                                }
                            }
                        }
                    }

                    Base.AppSurface {
                        Layout.preferredWidth: 292
                        Layout.fillHeight: true
                        sizeToContent: false
                        theme: root.pageTheme
                        surfaceTone: "section"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: qsTr("视频")
                                    theme: root.pageTheme
                                    styleRole: "sectionTitle"
                                    elide: Text.ElideRight
                                }

                                Base.AppButton {
                                    text: qsTr("添加")
                                    iconName: "scene"
                                    theme: root.pageTheme
                                    enabled: root.selectedCommand !== null
                                    onClicked: root.addVideo()
                                }
                            }

                            ListView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(contentHeight, 260)
                                Layout.minimumHeight: 72
                                clip: true
                                spacing: 6
                                model: root.selectedVideos

                                delegate: Base.AppSurface {
                                    id: videoListItem

                                    readonly property string videoId: String(modelData.id || "")
                                    readonly property string videoUrl: String(modelData.url || "").trim()

                                    width: ListView.view.width
                                    height: 58
                                    sizeToContent: false
                                    theme: root.pageTheme
                                    surfaceTone: videoId === root.selectedVideoId ? "highlight" : "ghost"
                                    active: videoId === root.selectedVideoId
                                    interactive: true

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 9

                                        Rectangle {
                                            Layout.preferredWidth: 5
                                            Layout.fillHeight: true
                                            color: modelData.color || "#60a5fa"
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
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
                                                text: videoListItem.videoUrl.length > 0 ? videoListItem.videoUrl : qsTr("URL未填写")
                                                theme: root.pageTheme
                                                styleRole: "bodyS"
                                                textTone: videoListItem.videoUrl.length > 0 ? "secondary" : "primary"
                                                colorOverride: videoListItem.videoUrl.length > 0 ? undefined : "#ff9eb2"
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.selectedVideoId = videoListItem.videoId
                                    }
                                }

                                Base.AppText {
                                    anchors.centerIn: parent
                                    visible: root.selectedVideos.length === 0
                                    text: root.selectedCommand ? qsTr("暂无视频") : qsTr("未选择指令")
                                    theme: root.pageTheme
                                    styleRole: "bodyS"
                                    textTone: "secondary"
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                visible: root.selectedVideo !== null
                                color: "#334155"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.selectedVideo !== null
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: 12
                                        Layout.preferredHeight: 12
                                        color: root.selectedVideo ? root.selectedVideo.color : "transparent"
                                    }

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: root.selectedVideo ? String(root.selectedVideo.name || "") : ""
                                        theme: root.pageTheme
                                        styleRole: "bodyM"
                                        elide: Text.ElideRight
                                    }
                                }

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: qsTr("视频URL")
                                    theme: root.pageTheme
                                    styleRole: "bodyS"
                                    textTone: "secondary"
                                }

                                Base.AppTextField {
                                    readonly property string videoId: root.selectedVideo
                                        ? String(root.selectedVideo.id || "")
                                        : ""

                                    Layout.fillWidth: true
                                    theme: root.pageTheme
                                    text: root.selectedVideo ? String(root.selectedVideo.url || "") : ""
                                    placeholderText: qsTr("请输入视频URL")
                                    onEditingFinished: {
                                        if (videoId.length > 0)
                                            root.updateVideo(videoId, { "url": text })
                                    }
                                }

                                Base.AppText {
                                    Layout.fillWidth: true
                                    visible: root.selectedVideo && String(root.selectedVideo.url || "").trim().length === 0
                                    text: qsTr("URL必填")
                                    theme: root.pageTheme
                                    styleRole: "bodyS"
                                    colorOverride: "#ff9eb2"
                                }

                                Base.AppButton {
                                    Layout.fillWidth: true
                                    text: qsTr("删除视频")
                                    theme: root.pageTheme
                                    enabled: root.selectedVideo !== null
                                    onClicked: root.removeSelectedVideo()
                                }
                            }

                            Item {
                                Layout.fillHeight: true
                            }
                        }
                    }
                }
            }
        }
    }
}
