import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Dialogs 1.3
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import TimelineControl.Media 1.0 as Media
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/theme" as Theme

Item {
    id: root

    focus: true

    Theme.AppTheme { id: fallbackTheme }
    property QtObject pageTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme : fallbackTheme
    property var appRuntime: typeof app !== "undefined" ? app : null

    // 首版仅保存页面内的编辑状态，尚未接入 TimelineCommand。
    property var timelines: [
        { "label": qsTr("主展厅 · 日常演示"), "value": "main" },
        { "label": qsTr("主展厅 · 迎宾演示"), "value": "welcome" }
    ]
    property var pcDevices: [
        { "id": "pc-01", "name": qsTr("PC-01 · 主屏"), "address": "192.168.1.101", "width": 3840, "height": 2160 },
        { "id": "pc-02", "name": qsTr("PC-02 · 侧屏"), "address": "192.168.1.102", "width": 1920, "height": 1080 }
    ]
    property var commandItems: [
        { "id": "command-1", "timelineId": "main", "pcId": "pc-01", "name": qsTr("开场视频"), "startTimeMs": 5000, "play": true },
        { "id": "command-2", "timelineId": "main", "pcId": "pc-01", "name": qsTr("循环背景"), "startTimeMs": 90000, "play": true },
        { "id": "command-3", "timelineId": "main", "pcId": "pc-02", "name": qsTr("欢迎画面"), "startTimeMs": 5000, "play": true },
        { "id": "command-4", "timelineId": "main", "pcId": "pc-02", "name": qsTr("片尾画面"), "startTimeMs": 180000, "play": false },
        { "id": "command-5", "timelineId": "welcome", "pcId": "pc-01", "name": qsTr("迎宾视频"), "startTimeMs": 0, "play": true }
    ]
    property string selectedTimelineId: "main"
    property string selectedCommandId: "command-1"
    property int nextCommandIndex: 6
    property string searchText: ""
    property var videoItem: null
    property var sourceEditor: null
    property var outputEditor: null
    readonly property var timelineCommands: commandItems.filter(function(command) {
        return command.timelineId === root.selectedTimelineId
    })
    readonly property var selectedCommand: {
        for (var i = 0; i < timelineCommands.length; ++i) {
            if (timelineCommands[i].id === selectedCommandId)
                return timelineCommands[i]
        }
        return null
    }
    readonly property var selectedPc: {
        for (var i = 0; i < pcDevices.length; ++i) {
            if (selectedCommand && pcDevices[i].id === selectedCommand.pcId)
                return pcDevices[i]
        }
        return null
    }
    readonly property string timelineName: {
        for (var i = 0; i < timelines.length; ++i) {
            if (timelines[i].value === selectedTimelineId)
                return timelines[i].label
        }
        return ""
    }
    readonly property int videoWidth: selectedCommand ? selectedCommand.videoWidth || 1920 : 1920
    readonly property int videoHeight: selectedCommand ? selectedCommand.videoHeight || 1080 : 1080
    readonly property int canvasWidth: selectedPc ? selectedPc.width : 1920
    readonly property int canvasHeight: selectedPc ? selectedPc.height : 1080
    readonly property var sourceRect: ({
        "x": selectedCommand ? selectedCommand.videoSrcX || 0 : 0,
        "y": selectedCommand ? selectedCommand.videoSrcY || 0 : 0,
        "w": selectedCommand ? selectedCommand.videoSrcW || videoWidth : videoWidth,
        "h": selectedCommand ? selectedCommand.videoSrcH || videoHeight : videoHeight
    })
    readonly property var outputRect: ({
        "x": selectedCommand && selectedCommand.videoWindowX !== undefined ? selectedCommand.videoWindowX : Math.round(canvasWidth / 4),
        "y": selectedCommand && selectedCommand.videoWindowY !== undefined ? selectedCommand.videoWindowY : Math.round(canvasHeight / 4),
        "w": selectedCommand ? selectedCommand.videoWindowW || Math.round(canvasWidth / 2) : 960,
        "h": selectedCommand ? selectedCommand.videoWindowH || Math.round(canvasHeight / 2) : 540
    })

    onSelectedTimelineIdChanged: {
        searchText = ""
        var commands = commandItems.filter(function(command) { return command.timelineId === root.selectedTimelineId })
        selectedCommandId = commands.length ? commands[0].id : ""
    }
    onSelectedCommandIdChanged: {
        if (videoItem)
            videoItem.pause()
        if (sourceEditor)
            sourceEditor.cancelPreview()
        if (outputEditor)
            outputEditor.cancelPreview()
    }
    Component.onCompleted: {
        if (appRuntime && appRuntime.settings) {
            var source = String(appRuntime.settings.value("projectionVideoSource", "")).trim()
            if (source.length)
                updateCommand({ "videoFile": source })
        }
    }

    function commandsForPc(pc) {
        var query = searchText.trim().toLowerCase()
        return timelineCommands.filter(function(command) {
            return command.pcId === pc.id && (!query
                || (pc.name + " " + pc.address + " " + command.name + " "
                    + (command.videoFile || "")).toLowerCase().indexOf(query) >= 0)
        }).sort(function(left, right) { return left.startTimeMs - right.startTimeMs })
    }

    function updateCommand(values) {
        if (!selectedCommand)
            return
        var changed = false
        for (var key in values)
            changed = changed || selectedCommand[key] !== values[key]
        if (!changed)
            return
        var next = commandItems.slice()
        var index = next.indexOf(selectedCommand)
        next[index] = Object.assign({}, selectedCommand, { "dirty": true }, values)
        commandItems = next
    }

    function addCommand(pcId) {
        root.forceActiveFocus()
        searchText = ""
        var command = {
            "id": "command-" + nextCommandIndex++, "timelineId": selectedTimelineId,
            "pcId": pcId, "name": qsTr("加载视频 %1").arg(nextCommandIndex - 1),
            "startTimeMs": 0, "play": false, "dirty": true
        }
        commandItems = commandItems.concat([command])
        selectedCommandId = command.id
    }

    function removeCommand(commandId) {
        root.forceActiveFocus()
        var row = 0
        for (var i = 0; i < timelineCommands.length; ++i) {
            if (timelineCommands[i].id === commandId)
                row = i
        }
        commandItems = commandItems.filter(function(command) { return command.id !== commandId })
        if (selectedCommandId === commandId)
            selectedCommandId = timelineCommands.length
                ? timelineCommands[Math.min(row, timelineCommands.length - 1)].id : ""
    }

    function setRectangle(source, values) {
        if (!selectedCommand)
            return
        var rect = Object.assign({}, source ? sourceRect : outputRect, values)
        var boundW = source ? videoWidth : canvasWidth
        var boundH = source ? videoHeight : canvasHeight
        rect.w = Math.max(1, Math.min(boundW, Math.round(rect.w)))
        rect.h = Math.max(1, Math.min(boundH, Math.round(rect.h)))
        rect.x = Math.max(0, Math.min(boundW - rect.w, Math.round(rect.x)))
        rect.y = Math.max(0, Math.min(boundH - rect.h, Math.round(rect.y)))
        var prefix = source ? "videoSrc" : "videoWindow"
        var updated = {}
        updated[prefix + "X"] = rect.x
        updated[prefix + "Y"] = rect.y
        updated[prefix + "W"] = rect.w
        updated[prefix + "H"] = rect.h
        updateCommand(updated)
    }

    function formatTime(timeMs) {
        var ms = Math.max(0, Math.round(timeMs))
        return ("0" + Math.floor(ms / 3600000)).slice(-2) + ":"
            + ("0" + Math.floor(ms / 60000) % 60).slice(-2) + ":"
            + ("0" + Math.floor(ms / 1000) % 60).slice(-2) + "."
            + ("00" + ms % 1000).slice(-3)
    }

    FileDialog {
        id: videoFileDialog
        title: qsTr("选择视频")
        selectExisting: true
        nameFilters: [qsTr("视频文件 (*.mp4 *.mov *.mkv *.avi *.wmv *.webm *.m4v)"), qsTr("所有文件 (*)")]
        onAccepted: root.updateCommand({
            "videoFile": fileUrl.toString(), "videoWidth": 1920, "videoHeight": 1080,
            "videoSrcX": 0, "videoSrcY": 0, "videoSrcW": 0, "videoSrcH": 0
        })
    }

    Component {
        id: videoPlayer
        Media.FfmpegVideoFrameItem {
            source: root.selectedCommand ? root.selectedCommand.videoFile || "" : ""
            onVideoSizeChanged: {
                if (root.selectedCommand && root.selectedCommand.videoFile
                        && source.toString() === String(root.selectedCommand.videoFile)
                        && videoSize.width > 0 && videoSize.height > 0) {
                    root.updateCommand({ "videoWidth": videoSize.width, "videoHeight": videoSize.height,
                                         "dirty": !!root.selectedCommand.dirty })
                    root.setRectangle(true, root.sourceRect)
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 16

        Base.AppSurface {
            Layout.preferredWidth: root.width < 1200 ? 256 : 280
            Layout.fillHeight: true
            sizeToContent: false

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                Base.AppText {
                    text: qsTr("时间线")
                    styleRole: UiStyle.TypographyRole.SectionTitle
                }
                Base.AppSelect {
                    objectName: "videoTimelineSelect"
                    Layout.fillWidth: true
                    options: root.timelines
                    value: root.selectedTimelineId
                    onValueSelected: {
                        root.forceActiveFocus()
                        root.selectedTimelineId = String(nextValue)
                    }
                }
                Base.AppTextField {
                    objectName: "videoCommandSearch"
                    Layout.fillWidth: true
                    placeholderText: qsTr("搜索指令或设备")
                    text: root.searchText
                    onTextEdited: root.searchText = text
                }
                RowLayout {
                    Layout.fillWidth: true
                    Base.AppText {
                        Layout.fillWidth: true
                        text: qsTr("加载视频指令")
                        styleRole: UiStyle.TypographyRole.BodyM
                    }
                    Base.AppText {
                        text: String(root.timelineCommands.length)
                        textTone: UiStyle.TextTone.Secondary
                    }
                }
                Flickable {
                    id: commandScroll
                    objectName: "videoCommandScroll"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: pcGroups.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}

                    Column {
                        id: pcGroups
                        width: parent.width
                        spacing: 16

                        Repeater {
                            model: root.pcDevices
                            delegate: Column {
                                id: pcGroup
                                width: pcGroups.width
                                spacing: 6
                                property var pc: modelData
                                property bool expanded: true
                                readonly property var commands: root.commandsForPc(pc)

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: root.pageTheme.colors.borderOverlay
                                }
                                RowLayout {
                                    width: parent.width
                                    spacing: 4
                                    Base.AppButton {
                                        objectName: "videoPcGroup_" + pcGroup.pc.id
                                        Layout.fillWidth: true
                                        contentAlignment: "left"
                                        text: pcGroup.pc.name
                                        iconSymbol: pcGroup.expanded ? "⌄" : "›"
                                        onClicked: pcGroup.expanded = !pcGroup.expanded
                                    }
                                    Base.AppButton {
                                        objectName: "addVideoCommand_" + pcGroup.pc.id
                                        text: qsTr("添加")
                                        iconSymbol: "+"
                                        enabled: root.selectedTimelineId.length > 0
                                        onClicked: {
                                            pcGroup.expanded = true
                                            root.addCommand(pcGroup.pc.id)
                                            commandScroll.contentY = Math.max(0, Math.min(pcGroup.y,
                                                commandScroll.contentHeight - commandScroll.height))
                                        }
                                        ToolTip.visible: hovered
                                        ToolTip.text: qsTr("为 %1 添加加载视频指令").arg(pcGroup.pc.name)
                                    }
                                }
                                Base.AppText {
                                    x: 12
                                    text: pcGroup.pc.address
                                    styleRole: UiStyle.TypographyRole.BodyS
                                    textTone: UiStyle.TextTone.Secondary
                                }
                                Column {
                                    width: parent.width
                                    visible: pcGroup.expanded
                                    spacing: 6
                                    Repeater {
                                        model: pcGroup.commands
                                        delegate: Base.AppCard {
                                            objectName: "videoCommand_" + modelData.id
                                            width: parent.width
                                            height: 66
                                            property var command: modelData
                                            text: command.name
                                            checkable: true
                                            checked: command.id === root.selectedCommandId
                                            emphasizedSelection: true
                                            padding: 10
                                            contentSpacing: 5
                                            onClicked: {
                                                root.forceActiveFocus()
                                                root.selectedCommandId = command.id
                                            }
                                            Base.AppText {
                                                Layout.fillWidth: true
                                                text: command.name + (command.dirty ? " ·" : "")
                                                elide: Text.ElideRight
                                                styleRole: UiStyle.TypographyRole.BodyM
                                            }
                                            Base.AppText {
                                                Layout.fillWidth: true
                                                text: root.formatTime(command.startTimeMs) + qsTr(" · 加载视频")
                                                elide: Text.ElideRight
                                                styleRole: UiStyle.TypographyRole.BodyS
                                                textTone: UiStyle.TextTone.Secondary
                                            }
                                        }
                                    }
                                    Base.AppText {
                                        width: parent.width
                                        height: visible ? 40 : 0
                                        visible: pcGroup.commands.length === 0
                                        text: root.searchText.length ? qsTr("无匹配指令") : qsTr("暂无指令，点击上方添加")
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        styleRole: UiStyle.TypographyRole.BodyS
                                        textTone: UiStyle.TextTone.Secondary
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 1
            spacing: 10

            Flickable {
                id: editorScroll
                objectName: "videoEditorScroll"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                Layout.preferredHeight: 1
                clip: true
                contentHeight: editorContent.height
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}

                ColumnLayout {
                    id: editorContent
                    width: editorScroll.width - 10
                    spacing: 14

                    GridLayout {
                        Layout.fillWidth: true
                        columns: editorContent.width < 720 ? 1 : 2
                        columnSpacing: 12
                        rowSpacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.selectedCommand ? root.selectedCommand.name : qsTr("加载视频")
                                styleRole: UiStyle.TypographyRole.SectionTitle
                                elide: Text.ElideRight
                            }
                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.timelineName + (root.selectedPc ? " / " + root.selectedPc.name : "")
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                                elide: Text.ElideRight
                            }
                        }
                        RowLayout {
                            spacing: 8
                            Base.AppButton {
                                objectName: "deleteVideoCommand"
                                text: qsTr("删除指令")
                                variant: UiStyle.ButtonVariant.Danger
                                enabled: root.selectedCommand !== null
                                onClicked: root.removeCommand(root.selectedCommandId)
                            }
                            Base.AppButton {
                                text: qsTr("返回时间线")
                                onClicked: {
                                    if (root.appRuntime && root.appRuntime.shell)
                                        root.appRuntime.shell.activeNavigationKey = "timeline"
                                }
                            }
                            Base.AppButton {
                                objectName: "saveVideoCommand"
                                text: qsTr("保存修改")
                                variant: UiStyle.ButtonVariant.Primary
                                enabled: root.selectedCommand !== null
                                onClicked: {
                                    root.forceActiveFocus()
                                    root.updateCommand({ "dirty": false })
                                }
                            }
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: commandInfo.implicitHeight + 24
                        sizeToContent: false
                        surfaceTone: UiStyle.SurfaceTone.Section
                        enabled: root.selectedCommand !== null

                        GridLayout {
                            id: commandInfo
                            anchors.fill: parent
                            anchors.margins: 12
                            columns: editorContent.width < 820 ? 2 : 3
                            columnSpacing: 16
                            rowSpacing: 10
                            Base.AppTextField {
                                objectName: "videoCommandName"
                                Layout.fillWidth: true
                                Layout.minimumWidth: 120
                                text: root.selectedCommand ? root.selectedCommand.name : ""
                                placeholderText: qsTr("指令名称")
                                onEditingFinished: {
                                    if (text.trim().length)
                                        root.updateCommand({ "name": text.trim() })
                                    else
                                        text = Qt.binding(function() { return root.selectedCommand ? root.selectedCommand.name : "" })
                                }
                            }
                            RowLayout {
                                spacing: 8
                                Base.AppText { text: qsTr("触发时间") }
                                Base.AppTextField {
                                    objectName: "videoCommandTime"
                                    Layout.preferredWidth: 138
                                    text: root.formatTime(root.selectedCommand ? root.selectedCommand.startTimeMs : 0)
                                    validator: RegularExpressionValidator { regularExpression: /\d{2}:[0-5]\d:[0-5]\d\.\d{3}/ }
                                    onEditingFinished: {
                                        if (acceptableInput) {
                                            var parts = text.split(/[:.]/)
                                            root.updateCommand({ "startTimeMs": Number(parts[0]) * 3600000
                                                + Number(parts[1]) * 60000 + Number(parts[2]) * 1000 + Number(parts[3]) })
                                        } else {
                                            text = Qt.binding(function() {
                                                return root.formatTime(root.selectedCommand ? root.selectedCommand.startTimeMs : 0)
                                            })
                                        }
                                    }
                                }
                            }
                            Base.AppCheckBox {
                                objectName: "videoCommandPlay"
                                text: qsTr("立即播放")
                                checked: root.selectedCommand ? !!root.selectedCommand.play : false
                                onClicked: root.updateCommand({ "play": checked })
                            }
                        }
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 70
                        visible: root.selectedCommand === null
                        text: qsTr("选择一条加载视频指令，或在左侧设备旁添加指令")
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                        textTone: UiStyle.TextTone.Secondary
                    }

                    GridLayout {
                        id: editorGrid
                        Layout.fillWidth: true
                        columns: editorContent.width < 800 ? 1 : 2
                        columnSpacing: 16
                        rowSpacing: 16
                        visible: root.selectedCommand !== null

                        Repeater {
                            model: 2
                            delegate: Base.AppSurface {
                                id: panel
                                objectName: isSource ? "videoSourcePanel" : "videoOutputPanel"
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: Math.max(530, root.height - 190)
                                sizeToContent: false
                                readonly property bool isSource: index === 0
                                readonly property int pixelWidth: isSource ? root.videoWidth : root.canvasWidth
                                readonly property int pixelHeight: isSource ? root.videoHeight : root.canvasHeight
                                readonly property var geometry: isSource ? root.sourceRect : root.outputRect

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 10

                                    RowLayout {
                                        Layout.fillWidth: true
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            Base.AppText {
                                                text: panel.isSource ? qsTr("视频源") : qsTr("目标窗口")
                                                styleRole: UiStyle.TypographyRole.SectionTitle
                                            }
                                            Base.AppText {
                                                Layout.fillWidth: true
                                                text: (panel.isSource ? "" : qsTr("虚拟画布 "))
                                                    + panel.pixelWidth + " × " + panel.pixelHeight
                                                styleRole: UiStyle.TypographyRole.BodyS
                                                textTone: UiStyle.TextTone.Secondary
                                                elide: Text.ElideRight
                                            }
                                        }
                                        Base.AppButton {
                                            visible: panel.isSource
                                            text: qsTr("选择视频")
                                            onClicked: videoFileDialog.open()
                                        }
                                    }
                                    Base.AppTextField {
                                        Layout.fillWidth: true
                                        readOnly: true
                                        text: panel.isSource
                                            ? (root.selectedCommand && root.selectedCommand.videoFile
                                                ? decodeURIComponent(root.selectedCommand.videoFile.split("/").pop()) : qsTr("未选择视频"))
                                            : (root.selectedPc ? root.selectedPc.name : "")
                                    }

                                    Item {
                                        id: canvasHost
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumHeight: 180

                                        Rectangle {
                                            id: previewCanvas
                                            objectName: panel.isSource ? "videoSourceCanvas" : "videoOutputCanvas"
                                            anchors.centerIn: parent
                                            width: Math.min(parent.width - 12, (parent.height - 12) * panel.pixelWidth / panel.pixelHeight)
                                            height: width * panel.pixelHeight / panel.pixelWidth
                                            color: root.pageTheme.colors.backgroundCanvas
                                            border.width: 1
                                            border.color: root.pageTheme.colors.controlBorder

                                            Canvas {
                                                anchors.fill: parent
                                                property color gridColor: root.pageTheme.colors.borderOverlay
                                                onGridColorChanged: requestPaint()
                                                onWidthChanged: requestPaint()
                                                onHeightChanged: requestPaint()
                                                onPaint: {
                                                    var ctx = getContext("2d")
                                                    ctx.clearRect(0, 0, width, height)
                                                    ctx.strokeStyle = gridColor
                                                    ctx.lineWidth = 1
                                                    ctx.beginPath()
                                                    for (var i = 1; i < 16; ++i) {
                                                        ctx.moveTo(i * width / 16, 0)
                                                        ctx.lineTo(i * width / 16, height)
                                                    }
                                                    for (var j = 1; j < 9; ++j) {
                                                        ctx.moveTo(0, j * height / 9)
                                                        ctx.lineTo(width, j * height / 9)
                                                    }
                                                    ctx.stroke()
                                                }
                                            }
                                            Loader {
                                                anchors.fill: parent
                                                active: panel.isSource
                                                visible: item && item.hasFrame
                                                sourceComponent: videoPlayer
                                                onLoaded: root.videoItem = item
                                            }
                                            Base.AppText {
                                                anchors.centerIn: parent
                                                width: parent.width - 24
                                                visible: panel.isSource && (!root.videoItem || !root.videoItem.hasFrame)
                                                text: root.videoItem && root.videoItem.errorString.length
                                                    ? root.videoItem.errorString : qsTr("选择视频，拖动矩形调整源区域")
                                                horizontalAlignment: Text.AlignHCenter
                                                wrapMode: Text.WordWrap
                                                textTone: UiStyle.TextTone.Secondary
                                                z: 2
                                            }
                                            ShaderEffectSource {
                                                objectName: panel.isSource ? "videoSourceTexture" : "videoOutputTexture"
                                                visible: !panel.isSource && root.videoItem && root.videoItem.hasFrame
                                                x: editableRect.x
                                                y: editableRect.y
                                                width: editableRect.width
                                                height: editableRect.height
                                                sourceItem: panel.isSource ? null : root.videoItem
                                                sourceRect: root.sourceEditor && root.videoItem ? Qt.rect(
                                                    root.sourceEditor.visualRectX * root.videoItem.width,
                                                    root.sourceEditor.visualRectY * root.videoItem.height,
                                                    root.sourceEditor.visualRectW * root.videoItem.width,
                                                    root.sourceEditor.visualRectH * root.videoItem.height) : Qt.rect(0, 0, 1, 1)
                                                live: true
                                            }
                                            ProjectionEditableRect {
                                                id: editableRect
                                                objectName: panel.isSource ? "videoSourceRect" : "videoOutputRect"
                                                rectX: panel.geometry.x / panel.pixelWidth
                                                rectY: panel.geometry.y / panel.pixelHeight
                                                rectW: panel.geometry.w / panel.pixelWidth
                                                rectH: panel.geometry.h / panel.pixelHeight
                                                minRectW: 1 / panel.pixelWidth
                                                minRectH: 1 / panel.pixelHeight
                                                title: panel.isSource ? qsTr("源区域") : (root.selectedCommand ? root.selectedCommand.name : "")
                                                selected: true
                                                fillOpacity: panel.isSource ? 0 : 0.06
                                                handleFill: root.pageTheme.colors.backgroundCanvas
                                                onGeometryCommitted: root.setRectangle(panel.isSource, {
                                                    "x": committedX * panel.pixelWidth, "y": committedY * panel.pixelHeight,
                                                    "w": committedW * panel.pixelWidth, "h": committedH * panel.pixelHeight
                                                })
                                                Component.onCompleted: {
                                                    if (panel.isSource)
                                                        root.sourceEditor = editableRect
                                                    else
                                                        root.outputEditor = editableRect
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        Base.AppButton {
                                            visible: panel.isSource
                                            iconSymbol: root.videoItem && root.videoItem.playing ? "Ⅱ" : "▶"
                                            enabled: root.videoItem && root.videoItem.hasFrame
                                            onClicked: root.videoItem.playing ? root.videoItem.pause() : root.videoItem.play()
                                        }
                                        Base.AppSliderControl {
                                            Layout.fillWidth: true
                                            visible: panel.isSource
                                            enabled: root.videoItem && root.videoItem.duration > 0
                                            from: 0
                                            to: root.videoItem ? Math.max(1, root.videoItem.duration) : 1
                                            value: root.videoItem ? root.videoItem.position : 0
                                            showValueLabel: false
                                            stepSize: 100
                                            onValueEdited: root.videoItem.seek(Math.round(nextValue))
                                        }
                                        Base.AppText {
                                            Layout.fillWidth: !panel.isSource
                                            text: panel.isSource ? root.formatTime(root.videoItem ? root.videoItem.position : 0)
                                                : qsTr("拖动调整位置，拖拽边角调整大小")
                                            styleRole: UiStyle.TypographyRole.BodyS
                                            textTone: UiStyle.TextTone.Secondary
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                        color: root.pageTheme.colors.borderOverlay
                                    }
                                    Base.AppText {
                                        text: panel.isSource ? qsTr("源矩形") : qsTr("目标矩形")
                                        styleRole: UiStyle.TypographyRole.BodyM
                                    }
                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: panel.width < 540 ? 2 : 4
                                        columnSpacing: 8
                                        rowSpacing: 8
                                        Repeater {
                                            model: ["x", "y", "w", "h"]
                                            delegate: RowLayout {
                                                id: coordinateRow
                                                Layout.fillWidth: true
                                                spacing: 6
                                                property string coordinate: "x"
                                                Component.onCompleted: coordinate = modelData
                                                Base.AppText { text: coordinateRow.coordinate.toUpperCase() }
                                                Base.AppNumberField {
                                                    objectName: (panel.isSource ? "source_" : "output_") + coordinateRow.coordinate
                                                    Layout.fillWidth: true
                                                    Layout.minimumWidth: 64
                                                    value: panel.geometry[coordinateRow.coordinate]
                                                    integerMode: true
                                                    minimum: coordinateRow.coordinate === "w" || coordinateRow.coordinate === "h" ? 1 : 0
                                                    maximum: coordinateRow.coordinate === "x" ? panel.pixelWidth - panel.geometry.w
                                                        : coordinateRow.coordinate === "y" ? panel.pixelHeight - panel.geometry.h
                                                        : coordinateRow.coordinate === "w" ? panel.pixelWidth : panel.pixelHeight
                                                    suffix: "px"
                                                    onValueEdited: {
                                                        var values = {}
                                                        values[coordinateRow.coordinate] = nextValue
                                                        root.setRectangle(panel.isSource, values)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Base.AppButton {
                                            objectName: panel.isSource ? "useFullVideo" : "fillVideoCanvas"
                                            text: panel.isSource ? qsTr("使用完整视频") : qsTr("填满画布")
                                            onClicked: root.setRectangle(panel.isSource, {
                                                "x": 0, "y": 0, "w": panel.pixelWidth, "h": panel.pixelHeight
                                            })
                                        }
                                        Base.AppButton {
                                            objectName: panel.isSource ? "" : "centerVideoOutput"
                                            visible: !panel.isSource
                                            text: qsTr("居中")
                                            onClicked: root.setRectangle(false, {
                                                "x": (panel.pixelWidth - panel.geometry.w) / 2,
                                                "y": (panel.pixelHeight - panel.geometry.h) / 2
                                            })
                                        }
                                        Item { Layout.fillWidth: true }
                                        Base.AppText {
                                            text: qsTr("适应画布")
                                            styleRole: UiStyle.TypographyRole.BodyS
                                            textTone: UiStyle.TextTone.Secondary
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Base.AppText {
                    Layout.fillWidth: true
                    text: root.selectedCommand && root.selectedPc
                        ? qsTr("正在编辑：%1 / %2").arg(root.selectedPc.name).arg(root.selectedCommand.name)
                        : qsTr("未选择指令")
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    elide: Text.ElideRight
                }
                Base.AppText {
                    text: root.selectedCommand ? (root.selectedCommand.dirty ? qsTr("已修改") : qsTr("已保存")) : ""
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: root.selectedCommand && root.selectedCommand.dirty ? UiStyle.TextTone.Accent : UiStyle.TextTone.Secondary
                }
            }
        }
    }
}
