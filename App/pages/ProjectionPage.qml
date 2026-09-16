import QtQuick 2.14
import QtQuick.Controls 2.14
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

    readonly property var timelineManager: appRuntime ? appRuntime.timelineManager : null
    readonly property var timelineModel: timelineManager ? timelineManager.timelineModel : null
    readonly property var currentTimeline: timelineManager ? timelineManager.currentTimeline : null
    readonly property var commandModel: currentTimeline ? currentTimeline.commandModel : null
    readonly property var deviceModel: appRuntime ? appRuntime.deviceModel : null
    readonly property bool editingEnabled: !!currentTimeline && timelineManager.playbackState === 0
        && currentTimeline.state === 0
    readonly property var timelines: {
        var result = []
        if (timelineModel) {
            for (var i = 0; i < timelineModel.count; ++i) {
                var timeline = timelineModel.timelineAt(i)
                result.push({ "label": timeline.name, "value": timeline.id })
            }
        }
        return result
    }
    readonly property var pcDevices: {
        var result = []
        var devices = deviceModel ? deviceModel.devices : []
        for (var i = 0; i < devices.length; ++i) {
            var device = devices[i]
            if (device.deviceType !== "电脑" && device.templateName !== "电脑"
                    && device.supportedProtocols.indexOf("pc") < 0)
                continue
            var config = device.configValues
            var loadCommand = null
            var commands = device.commands
            for (var j = 0; j < commands.length; ++j) {
                if (commands[j].commandType === "openVideo") {
                    loadCommand = commands[j]
                    break
                }
            }
            result.push({ "id": device.id, "name": device.name, "address": config.ip || "",
                "width": Math.max(1, Number(config.virtualScreenWidth || 1920)),
                "height": Math.max(1, Number(config.virtualScreenHeight || 1080)),
                "loadCommand": loadCommand })
        }
        return result
    }
    property var videoSizes: ({})
    property string statusText: ""
    readonly property string selectedTimelineId: currentTimeline ? currentTimeline.id : ""
    readonly property string selectedCommandId: selectedCommand ? selectedCommand.id : ""
    property string searchText: ""
    property var videoItem: null
    property var sourceEditor: null
    property var outputEditor: null
    readonly property var timelineCommands: {
        var result = []
        var commands = commandModel ? commandModel.commands : []
        for (var i = 0; i < commands.length; ++i) {
            var command = commands[i]
            if (!command.targetCommand || command.targetCommand.commandType !== "openVideo"
                    || !pcDevices.some(function(pc) { return pc.id === command.targetDeviceId }))
                continue
            var values = {}
            var videoOptions = []
            var fields = command.targetCommand.executionInputFields
            for (var j = 0; j < fields.length; ++j) {
                values[fields[j].key] = fields[j].value
                if (fields[j].key === "videoFile")
                    videoOptions = fields[j].options
            }
            Object.assign(values, command.executionInputValues)
            var play = command.executionInputValues.play !== undefined ? command.executionInputValues.play : true
            var videoOption = videoOptions.filter(function(option) {
                return option && typeof option === "object" && String(option.value) === String(values.videoFile)
            })[0]
            result.push(Object.assign(values, {
                "id": command.id, "command": command, "pcId": command.targetDeviceId,
                "name": command.commandName,
                "videoOptions": videoOptions, "videoName": videoOption ? String(videoOption.label) : videoName(values.videoFile),
                "startTimeMs": command.startTimeMs,
                "play": play === true || play === "true" || play === 1
            }))
        }
        return result
    }
    readonly property var selectedCommand: {
        for (var i = 0; i < timelineCommands.length; ++i) {
            if (commandModel && timelineCommands[i].id === commandModel.selectedCommandId)
                return timelineCommands[i]
        }
        return timelineCommands.length ? timelineCommands[0] : null
    }
    readonly property var selectedPc: {
        for (var i = 0; i < pcDevices.length; ++i) {
            if (selectedCommand && pcDevices[i].id === selectedCommand.pcId)
                return pcDevices[i]
        }
        return null
    }
    readonly property string timelineName: currentTimeline ? currentTimeline.name : ""
    readonly property var videoSize: selectedCommand ? videoSizes[selectedCommand.videoFile] : null
    readonly property int videoWidth: videoSize ? videoSize.width
        : Math.max(1920, selectedCommand ? Number(selectedCommand.videoSrcX || 0) + Number(selectedCommand.videoSrcW || 0) : 0)
    readonly property int videoHeight: videoSize ? videoSize.height
        : Math.max(1080, selectedCommand ? Number(selectedCommand.videoSrcY || 0) + Number(selectedCommand.videoSrcH || 0) : 0)
    readonly property int canvasWidth: selectedPc ? selectedPc.width : 1920
    readonly property int canvasHeight: selectedPc ? selectedPc.height : 1080
    readonly property var sourceRect: ({
        "x": selectedCommand ? selectedCommand.videoSrcX || 0 : 0,
        "y": selectedCommand ? selectedCommand.videoSrcY || 0 : 0,
        "w": selectedCommand ? selectedCommand.videoSrcW || videoWidth : videoWidth,
        "h": selectedCommand ? selectedCommand.videoSrcH || videoHeight : videoHeight
    })
    readonly property var outputRect: ({
        "x": selectedCommand ? Number(selectedCommand.videoWindowX || 0) : 0,
        "y": selectedCommand ? Number(selectedCommand.videoWindowY || 0) : 0,
        "w": selectedCommand ? Number(selectedCommand.videoWindowW || 1920) : 1920,
        "h": selectedCommand ? Number(selectedCommand.videoWindowH || 1080) : 1080
    })

    onSelectedTimelineIdChanged: {
        searchText = ""
        statusText = ""
    }
    onSelectedCommandIdChanged: {
        statusText = ""
        if (videoItem)
            videoItem.pause()
        if (sourceEditor)
            sourceEditor.cancelPreview()
        if (outputEditor)
            outputEditor.cancelPreview()
    }

    function commandsForPc(pc) {
        var query = searchText.trim().toLowerCase()
        return timelineCommands.filter(function(command) {
            return command.pcId === pc.id && (!query
                || (pc.name + " " + pc.address + " " + command.name + " " + command.videoName + " "
                    + (command.videoFile || "")).toLowerCase().indexOf(query) >= 0)
        }).sort(function(left, right) { return left.startTimeMs - right.startTimeMs })
    }

    function updateCommand(values) {
        if (!editingEnabled || !selectedCommand || !commandModel)
            return
        var item = selectedCommand
        var changed = false
        for (var key in values)
            changed = changed || item[key] !== values[key]
        if (!changed)
            return
        var parameters = Object.assign({}, item.command.executionInputValues)
        Object.assign(parameters, values)
        delete parameters.startTimeMs
        if (!commandModel.updateCommand(item.command,
                values.startTimeMs !== undefined ? values.startTimeMs : item.startTimeMs, parameters)) {
            statusText = qsTr("自动同步失败，指令可能已被删除")
            return
        }
        statusText = qsTr("已自动同步时间线；方案文件请通过全局保存")
    }

    function addCommand(pcId) {
        root.forceActiveFocus()
        if (!editingEnabled || !commandModel)
            return
        var pc = pcDevices.filter(function(device) { return device.id === pcId })[0]
        if (!pc || !pc.loadCommand)
            return
        var values = {}
        var fields = pc.loadCommand.executionInputFields
        for (var i = 0; i < fields.length; ++i)
            values[fields[i].key] = fields[i].value
        values.play = false
        var command = commandModel.addDeviceCommand(0, pc.id, pc.loadCommand, values)
        if (!command) {
            statusText = qsTr("添加指令失败")
            return
        }
        searchText = ""
        commandModel.selectedCommandId = command.id
        statusText = qsTr("已添加指令，请选择视频")
    }

    function selectCommand(commandId) {
        // 失焦提交可能重建指令项，切换逻辑保留在页面中。
        root.forceActiveFocus()
        if (commandModel)
            commandModel.selectedCommandId = commandId
    }

    function removeCommand(commandId) {
        root.forceActiveFocus()
        if (!editingEnabled || !commandModel)
            return
        var item = timelineCommands.filter(function(command) { return command.id === commandId })[0]
        if (!item || !commandModel.removeCommand(item.command)) {
            statusText = qsTr("删除指令失败")
            return
        }
        statusText = ""
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

    function videoName(value) {
        var name = String(value || "").replace(/^\$/, "").split(/[\\/]/).pop()
        try {
            name = decodeURIComponent(name)
        } catch (error) {}
        return name || qsTr("未选择视频")
    }

    Menu {
        id: commandMenu
        objectName: "videoCommandActions_" + commandId
        property string commandId: ""

        function openForCommand(id) {
            root.forceActiveFocus()
            commandId = id
            popup()
        }

        MenuItem {
            objectName: "cloneVideoCommandAction"
            text: qsTr("克隆到…")
            enabled: root.editingEnabled
            onTriggered: cloneDialog.openForCommand(commandMenu.commandId)
        }
        MenuItem {
            text: qsTr("删除指令")
            enabled: root.editingEnabled
            onTriggered: root.removeCommand(commandMenu.commandId)
        }
    }

    VideoCommandCloneDialog {
        id: cloneDialog
        parent: root
        timelineManager: root.timelineManager
        pcDevices: root.pcDevices
        onCommandCloned: {
            var commandId = command.id
            var pcId = command.targetDeviceId
            root.searchText = ""
            root.commandModel.selectedCommandId = commandId
            root.statusText = qsTr("已克隆到 %1；方案文件请通过全局保存").arg(root.selectedPc.name)
            for (var j = 0; j < pcGroupRepeater.count; ++j) {
                if (pcGroupRepeater.itemAt(j).pc.id === pcId)
                    pcGroupRepeater.itemAt(j).expanded = true
            }
            Qt.callLater(function() {
                if (root.selectedCommandId !== commandId)
                    return
                for (var i = 0; i < pcGroupRepeater.count; ++i) {
                    var group = pcGroupRepeater.itemAt(i)
                    if (group.pc.id !== pcId)
                        continue
                    group.commandRows.parent.forceLayout()
                    group.forceLayout()
                    pcGroups.forceLayout()
                    var index = group.commands.findIndex(function(item) { return item.id === commandId })
                    var row = group.commandRows.itemAt(index)
                    if (row)
                        commandScroll.contentY = Math.max(0, Math.min(row.mapToItem(pcGroups, 0, 0).y,
                            commandScroll.contentHeight - commandScroll.height))
                }
            })
        }
    }

    Component {
        id: videoPlayer
        Media.FfmpegVideoFrameItem {
            source: root.selectedCommand && root.selectedCommand.videoFile
                ? root.selectedCommand.command.targetCommand.resolvedParams({ "videoFile": root.selectedCommand.videoFile }).videoFile
                : ""
            onVideoSizeChanged: {
                if (root.selectedCommand && root.selectedCommand.videoFile
                        && videoSize.width > 0 && videoSize.height > 0) {
                    var sizes = Object.assign({}, root.videoSizes)
                    sizes[root.selectedCommand.videoFile] = { "width": videoSize.width, "height": videoSize.height }
                    root.videoSizes = sizes
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 16

        Base.AppSurface {
            id: commandNavigation
            objectName: "videoCommandNavigation"
            Layout.preferredWidth: root.width < 1200 ? 280 : 304
            Layout.fillHeight: true
            sizeToContent: false
            readonly property color selectionFill: Qt.tint(root.pageTheme.colors.backgroundSection,
                Qt.rgba(root.pageTheme.colors.highlightText.r, root.pageTheme.colors.highlightText.g,
                        root.pageTheme.colors.highlightText.b, 0.10))

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.pageTheme.density.panePadding
                spacing: root.pageTheme.density.paneSpacing

                RowLayout {
                    spacing: root.pageTheme.density.controlGap
                    Base.AppIcon {
                        name: "workflow"
                        color: root.pageTheme.colors.subtleText
                    }
                    Base.AppText {
                        text: qsTr("指令导航")
                        styleRole: UiStyle.TypographyRole.SectionTitle
                    }
                }
                Base.AppSelect {
                    id: timelineSelect
                    objectName: "videoTimelineSelect"
                    Layout.fillWidth: true
                    controlHeight: root.pageTheme.density.controlHeightMd + root.pageTheme.density.panePadding
                    optionHeight: root.pageTheme.density.controlHeightMd
                    options: root.timelines
                    value: root.selectedTimelineId
                    enabled: root.timelines.length > 0
                    contentItem: Column {
                        leftPadding: timelineSelect.contentPaddingX
                        rightPadding: timelineSelect.contentPaddingX + timelineSelect.indicatorWidth
                        topPadding: root.pageTheme.density.controlGap
                        spacing: root.pageTheme.density.controlGap / 2
                        Base.AppText {
                            text: qsTr("当前时间线")
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                        }
                        Base.AppText {
                            width: parent.width - parent.leftPadding - parent.rightPadding
                            text: timelineSelect.currentLabel || qsTr("暂无时间线")
                            styleRole: UiStyle.TypographyRole.BodyM
                            elide: Text.ElideRight
                        }
                    }
                    onValueSelected: {
                        root.forceActiveFocus()
                        if (root.timelineManager)
                            root.timelineManager.setCurrentTimelineId(String(nextValue))
                    }
                }
                Base.AppTextField {
                    objectName: "videoCommandSearch"
                    Layout.fillWidth: true
                    placeholderText: qsTr("搜索设备或指令")
                    leadingContent: Base.AppIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "../assets/icons/video-navigation-search.svg"
                        color: root.pageTheme.colors.subtleText
                    }
                    text: root.searchText
                    onTextEdited: root.searchText = text
                }
                RowLayout {
                    Layout.fillWidth: true
                    Base.AppText {
                        Layout.fillWidth: true
                        text: qsTr("设备与指令")
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Secondary
                    }
                    Base.AppButton {
                        objectName: "toggleVideoGroups"
                        text: qsTr("全部折叠")
                        size: UiStyle.ButtonSize.Small
                        variant: UiStyle.ButtonVariant.Ghost
                        onClicked: {
                            for (var i = 0; i < pcGroupRepeater.count; ++i)
                                pcGroupRepeater.itemAt(i).expanded = false
                        }
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
                        spacing: root.pageTheme.density.paneSpacing

                        Repeater {
                            id: pcGroupRepeater
                            model: root.currentTimeline ? root.pcDevices : []
                            delegate: Column {
                                id: pcGroup
                                width: pcGroups.width
                                spacing: root.pageTheme.density.controlGap / 2
                                property var pc: modelData
                                property alias commandRows: commandRepeater
                                property bool expanded: true
                                readonly property var commands: root.commandsForPc(pc)

                                RowLayout {
                                    width: parent.width
                                    spacing: 4
                                    Base.AppButton {
                                        id: deviceButton
                                        objectName: "videoPcGroup_" + pcGroup.pc.id
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        implicitWidth: 0
                                        size: UiStyle.ButtonSize.Small
                                        variant: UiStyle.ButtonVariant.Ghost
                                        animateScale: false
                                        text: pcGroup.pc.name
                                        contentItem: RowLayout {
                                            spacing: root.pageTheme.density.controlGap
                                            Base.AppIcon {
                                                size: root.pageTheme.metrics.iconSizeSm
                                                symbol: "›"
                                                rotation: pcGroup.expanded ? 90 : 0
                                                color: root.pageTheme.colors.subtleText
                                            }
                                            Base.AppIcon {
                                                source: "../assets/icons/电脑.png"
                                                tintSource: false
                                            }
                                            Base.AppText {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 0
                                                text: deviceButton.text
                                                styleRole: UiStyle.TypographyRole.BodyM
                                                overrideWeight: root.pageTheme.typography.weightStrong
                                                elide: Text.ElideRight
                                            }
                                            Base.AppBadge {
                                                text: String(pcGroup.commands.length)
                                                implicitHeight: root.pageTheme.density.controlHeightSm - root.pageTheme.density.controlGap
                                                leftPadding: root.pageTheme.density.controlGap
                                                rightPadding: leftPadding
                                            }
                                        }
                                        onClicked: pcGroup.expanded = !pcGroup.expanded
                                        ToolTip.visible: hovered
                                        ToolTip.text: text
                                    }
                                    Base.AppButton {
                                        objectName: "addVideoCommand_" + pcGroup.pc.id
                                        text: "+"
                                        size: UiStyle.ButtonSize.Small
                                        variant: UiStyle.ButtonVariant.Ghost
                                        Layout.preferredWidth: root.pageTheme.density.controlHeightSm
                                        Accessible.name: qsTr("为 %1 添加加载视频指令").arg(pcGroup.pc.name)
                                        enabled: root.editingEnabled && !!pcGroup.pc.loadCommand
                                        onClicked: {
                                            pcGroup.expanded = true
                                            root.addCommand(pcGroup.pc.id)
                                            commandScroll.contentY = Math.max(0, Math.min(pcGroup.y,
                                                commandScroll.contentHeight - commandScroll.height))
                                        }
                                        ToolTip.visible: hovered
                                        ToolTip.text: pcGroup.pc.loadCommand ? Accessible.name : qsTr("设备未配置加载视频指令")
                                    }
                                }
                                Column {
                                    width: parent.width
                                    visible: pcGroup.expanded
                                    spacing: 0
                                    Repeater {
                                        id: commandRepeater
                                        model: pcGroup.commands
                                        delegate: Item {
                                            id: commandRow
                                            width: parent.width
                                            height: root.pageTheme.density.controlHeightLg + root.pageTheme.density.panePadding
                                            property var command: modelData
                                            Rectangle {
                                                x: root.pageTheme.metrics.iconSizeSm / 2
                                                width: root.pageTheme.density.dividerThickness
                                                height: index === pcGroup.commands.length - 1 ? parent.height / 2 : parent.height
                                                color: root.pageTheme.colors.controlBorder
                                                opacity: 0.5
                                            }
                                            Rectangle {
                                                x: root.pageTheme.metrics.iconSizeSm / 2
                                                y: parent.height / 2
                                                width: root.pageTheme.density.controlGap
                                                height: root.pageTheme.density.dividerThickness
                                                color: root.pageTheme.colors.controlBorder
                                                opacity: 0.5
                                            }
                                            AbstractButton {
                                                id: commandCard
                                                objectName: "videoCommand_" + commandRow.command.id
                                                x: root.pageTheme.density.paneSpacing * 2
                                                y: root.pageTheme.density.dividerThickness * 2
                                                width: parent.width - x
                                                height: parent.height - y * 2
                                                text: commandRow.command.videoName
                                                checkable: true
                                                autoExclusive: true
                                                checked: commandRow.command.id === root.selectedCommandId
                                                focusPolicy: Qt.TabFocus
                                                hoverEnabled: true
                                                padding: root.pageTheme.density.controlGap
                                                topPadding: root.pageTheme.density.controlGap / 2
                                                bottomPadding: topPadding
                                                rightPadding: commandMenuButton.width + padding
                                                background: Rectangle {
                                                    radius: root.pageTheme.shape.controlRadius
                                                    color: commandCard.checked
                                                        ? (commandCard.hovered ? Qt.lighter(commandNavigation.selectionFill, 1.12) : commandNavigation.selectionFill)
                                                        : (commandCard.hovered ? root.pageTheme.colors.backgroundSectionOverlay : "transparent")
                                                    border.width: commandCard.visualFocus ? root.pageTheme.density.dividerThickness : 0
                                                    border.color: root.pageTheme.colors.highlightText
                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        anchors.topMargin: root.pageTheme.density.controlGap
                                                        anchors.bottomMargin: root.pageTheme.density.controlGap
                                                        width: root.pageTheme.density.dividerThickness * 2
                                                        radius: width / 2
                                                        color: root.pageTheme.colors.highlightText
                                                        visible: commandCard.checked
                                                    }
                                                }
                                                onClicked: root.selectCommand(commandRow.command.id)
                                                contentItem: RowLayout {
                                                    spacing: root.pageTheme.density.controlGap
                                                    Base.AppIcon {
                                                        source: "../assets/icons/video-navigation-command.svg"
                                                        color: commandCard.checked ? root.pageTheme.colors.neutralText : root.pageTheme.colors.subtleText
                                                    }
                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        spacing: root.pageTheme.density.controlGap / 2
                                                        Base.AppText {
                                                            Layout.fillWidth: true
                                                            text: commandCard.text
                                                            elide: Text.ElideRight
                                                            styleRole: UiStyle.TypographyRole.BodyM
                                                        }
                                                        Base.AppText {
                                                            Layout.fillWidth: true
                                                            text: root.formatTime(commandRow.command.startTimeMs)
                                                            elide: Text.ElideRight
                                                            styleRole: UiStyle.TypographyRole.BodyS
                                                            colorOverride: commandCard.checked ? root.pageTheme.colors.neutralText : root.pageTheme.colors.subtleText
                                                        }
                                                    }
                                                }
                                                ToolTip.visible: hovered
                                                ToolTip.text: text
                                            }
                                            AbstractButton {
                                                id: commandMenuButton
                                                objectName: "videoCommandMenu_" + commandRow.command.id
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: root.pageTheme.density.controlHeightSm
                                                height: width
                                                focusPolicy: Qt.TabFocus
                                                hoverEnabled: true
                                                text: "⋯"
                                                Accessible.name: qsTr("%1 的指令操作").arg(commandCard.text)
                                                onClicked: commandMenu.openForCommand(commandRow.command.id)
                                                contentItem: Base.AppText {
                                                    text: commandMenuButton.text
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                background: Rectangle {
                                                    radius: root.pageTheme.shape.controlRadius
                                                    color: commandMenuButton.hovered || commandMenuButton.visualFocus
                                                        ? root.pageTheme.colors.backgroundSectionOverlay : "transparent"
                                                }
                                            }
                                        }
                                    }
                                    Base.AppText {
                                        width: parent.width
                                        height: visible ? 40 : 0
                                        visible: pcGroup.commands.length === 0
                                        text: root.searchText.length ? qsTr("无匹配指令")
                                            : (pcGroup.pc.loadCommand ? qsTr("暂无指令，点击 + 添加") : qsTr("设备未配置加载视频指令"))
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        styleRole: UiStyle.TypographyRole.BodyS
                                        textTone: UiStyle.TextTone.Secondary
                                    }
                                }
                            }
                        }
                        Base.AppText {
                            width: parent.width
                            visible: !root.currentTimeline || root.pcDevices.length === 0
                            text: !root.currentTimeline ? qsTr("请先在时间线页面创建时间线")
                                : qsTr("请先在设备页面添加 PC 设备")
                            wrapMode: Text.WordWrap
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.pageTheme.density.dividerThickness
                    color: root.pageTheme.colors.borderOverlay
                }
                Base.AppText {
                    text: qsTr("%1 台设备 · %2 条指令").arg(root.pcDevices.length).arg(root.timelineCommands.length)
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
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
                                enabled: root.editingEnabled && root.selectedCommand !== null
                                onClicked: root.removeCommand(root.selectedCommandId)
                            }
                            Base.AppButton {
                                text: qsTr("返回时间线")
                                onClicked: {
                                    root.forceActiveFocus()
                                    if (root.appRuntime && root.appRuntime.shell)
                                        root.appRuntime.shell.activeNavigationKey = "timeline"
                                }
                            }
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: commandInfo.implicitHeight + 24
                        sizeToContent: false
                        surfaceTone: UiStyle.SurfaceTone.Section
                        enabled: root.editingEnabled && root.selectedCommand !== null

                        GridLayout {
                            id: commandInfo
                            anchors.fill: parent
                            anchors.margins: 12
                            columns: editorContent.width < 820 ? 2 : 3
                            columnSpacing: 16
                            rowSpacing: 10
                            Base.AppSelect {
                                objectName: "videoFileSelect"
                                Layout.fillWidth: true
                                Layout.minimumWidth: 120
                                options: root.selectedCommand ? root.selectedCommand.videoOptions : []
                                value: root.selectedCommand ? root.selectedCommand.videoFile || "" : ""
                                placeholderText: value ? String(value)
                                    : (optionCount ? qsTr("选择视频") : qsTr("暂无可选视频"))
                                enabled: optionCount > 0
                                onValueSelected: {
                                    root.forceActiveFocus()
                                    if (String(nextValue) !== String(value)) {
                                        root.updateCommand({
                                            "videoFile": String(nextValue),
                                            "videoSrcX": 0, "videoSrcY": 0, "videoSrcW": 0, "videoSrcH": 0
                                        })
                                    }
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
                        enabled: root.editingEnabled

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
                                            Repeater {
                                                // 参考框使用完整指令列表，避免左侧搜索影响画布。
                                                model: !panel.isSource && root.selectedCommand
                                                    ? root.timelineCommands.filter(function(command) {
                                                        return command.pcId === root.selectedCommand.pcId
                                                            && command.startTimeMs <= root.selectedCommand.startTimeMs
                                                            && command.id !== root.selectedCommandId
                                                    }) : []
                                                delegate: Rectangle {
                                                    objectName: "videoOutputReference_" + modelData.id
                                                    x: Math.round(Number(modelData.videoWindowX || 0) / panel.pixelWidth * parent.width)
                                                    y: Math.round(Number(modelData.videoWindowY || 0) / panel.pixelHeight * parent.height)
                                                    width: Math.max(1, Math.round(Number(modelData.videoWindowW || 1920) / panel.pixelWidth * parent.width))
                                                    height: Math.max(1, Math.round(Number(modelData.videoWindowH || 1080) / panel.pixelHeight * parent.height))
                                                    color: "transparent"
                                                    border.color: "#e9b44c"
                                                    border.width: 2
                                                }
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
                                                onSelectionRequested: root.forceActiveFocus()
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
                                        Base.AppButton {
                                            objectName: panel.isSource ? "" : "correctVideoOutputAspect"
                                            visible: !panel.isSource
                                            text: qsTr("修正比例")
                                            enabled: root.sourceRect.w > 0 && root.sourceRect.h > 0
                                            onClicked: {
                                                root.forceActiveFocus()
                                                var ratio = root.sourceRect.w / root.sourceRect.h
                                                var nextWidth = Math.min(root.outputRect.w, root.canvasWidth, root.canvasHeight * ratio)
                                                root.setRectangle(false, { "w": nextWidth, "h": nextWidth / ratio })
                                            }
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
                    text: root.statusText || (root.currentTimeline && !root.editingEnabled
                        ? qsTr("时间线运行或暂停中，停止后可编辑")
                        : (root.selectedCommand && root.selectedPc
                            ? qsTr("正在编辑：%1 / %2").arg(root.selectedPc.name).arg(root.selectedCommand.name)
                            : qsTr("未选择指令")))
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    elide: Text.ElideRight
                    ToolTip.visible: statusHover.containsMouse
                    ToolTip.text: text
                    MouseArea { id: statusHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                }
                Base.AppText {
                    text: root.selectedCommand ? qsTr("自动同步时间线") : ""
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                }
            }
        }
    }
}
