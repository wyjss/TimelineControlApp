import QtQuick 2.14
import QtQuick.Controls 2.14
import QtTest 1.2
import "qrc:/UICore/qml/theme" as Theme
import "../pages" as Pages
import "../pages/timeline" as Timeline

TestCase {
    id: testCase
    name: "PageLayouts"
    when: testWindow.visible

    ApplicationWindow {
        id: testWindow
        width: 1800
        height: 900
        visible: true
        property QtObject appTheme: Theme.AppTheme {}
    }

    QtObject {
        id: testDeviceModel
        property string selectedId: "one"
        property var deviceTypes: ["PC"]
        property var devices: [
            { "id": "one", "name": "Alpha", "deviceType": "PC", "templateName": "PC", "online": true, "filteredOut": false,
              "commands": [], "configValues": { "ip": "10.0.0.1", "screenColumns": 1, "screenRows": 1 } },
            { "id": "two", "name": "Beta", "deviceType": "PC", "templateName": "PC", "online": false, "filteredOut": false,
              "commands": [], "configValues": { "ip": "10.0.0.2", "screenColumns": 4, "screenRows": 2 } }
        ]
        readonly property var currentDevice: selectedId === "one" ? devices[0] : devices[1]
        function selectDevice(id) { selectedId = id }
    }

    QtObject {
        id: templateModel
        property var templates: [{ "name": "PC", "deviceType": "PC", "supportedProtocols": [], "configSpecs": [] }]
    }

    Component {
        id: devicesPageComponent
        Pages.DevicesPage {
            width: 1180
            height: 660
            deviceModel: testDeviceModel
            deviceTemplateModel: templateModel
        }
    }

    Component {
        id: timelinePageComponent
        Pages.TimelinePage { width: 1180; height: 660 }
    }


    Component {
        id: commandListComponent
        Timeline.TimelineCommandVerticalList {
            height: 260
            devices: testDeviceModel.devices
            commands: [{ "id": "first", "targetDeviceId": "one",
                         "commandName": "暂停播放", "startTimeMs": 13800 }]
        }
    }

    function test_commandListFits_data() {
        return [{ tag: "compact", listWidth: 296 },
                { tag: "wide", listWidth: 740 }]
    }

    function test_commandListFits(data) {
        var list = createTemporaryObject(commandListComponent, testWindow.contentItem,
                                        { width: data.listWidth, showDeviceName: true })
        verify(list)
        wait(30)
        var label = findChild(list, "commandNameLabel")
        verify(label)
        verify(label.width >= label.implicitWidth, "Command name is squeezed out")
        var position = label.mapToItem(list, 0, 0)
        verify(position.x + label.width <= list.width, "Command name exceeds the list")
        compare(list.formatTime(13800, true), "00:13.800")
        compare(list.formatTime(3613800, true), "01:00:13.800")
        compare(list.count, 1)
        var commands = []
        for (var index = 0; index < 30; ++index)
            commands.push({ id: "item" + index, commandName: "Command " + index,
                            targetDeviceId: "one", startTimeMs: index * 1000 })
        list.commands = commands
        list.selectedCommandId = "item29"
        wait(30)
        var rows = findChild(list, "timelineCommandList")
        compare(rows.currentIndex, 29)
        verify(rows.contentY > 0, "Selected command remains outside the viewport")
    }


    Component {
        id: triggerComponent
        Timeline.TimelineExternalTriggerEditor { height: implicitHeight }
    }

    function test_triggerSummaryFits_data() {
        return [{ tag: "one", count: 1 }, { tag: "three", count: 3 }]
    }

    function test_triggerSummaryFits(data) {
        var trigger = createTemporaryObject(triggerComponent, testWindow.contentItem,
                                            { width: 680 })
        verify(trigger)
        trigger.timelineConditions = [{ "locator": "新建定位器", "fence": "栅栏 1",
                                        "timeline": "时间轴 2", "heading": 0,
                                        "enabled": true, "touched": false, "active": false }]
        if (data.count === 3)
            trigger.timelineConditions = [trigger.timelineConditions[0],
                                          trigger.timelineConditions[0],
                                          trigger.timelineConditions[0]]
        trigger.width = 681
        trigger.width = 680
        wait(30)
        var ruleList = findChild(trigger, "triggerList")
        verify(ruleList.contentHeight <= ruleList.height, "Rule list is clipped vertically")
        var rule = findChild(trigger, "triggerRule")
        verify(rule)
        verify(rule.height <= rule.parent.height, "Rule is clipped vertically")
        var more = findChild(rule, "triggerMoreButton")
        verify(more)
        var position = more.mapToItem(trigger, 0, 0)
        verify(position.x + more.width <= trigger.width, "Rule controls exceed the panel")
    }

    Component {
        id: commandModelComponent
        QtObject {
            property var commands: []
            property int realDurationMs: 0
            property string selectedCommandId: ""
            property var childTracksByParentId: ({})
            property var addedCommands: []
            function addDeviceCommand(time, deviceId, command, values) {
                addedCommands = addedCommands.concat([{ time: time, deviceId: deviceId,
                                                        command: command, values: values }])
            }
        }
    }

    function test_commandPaletteActions() {
        var host = createTemporaryObject(timelinePageComponent, testWindow.contentItem,
                                         { controlTrackVisible: true })
        verify(host && host.editor)
        var page = host.editor
        page.timelineCommandModel = createTemporaryObject(commandModelComponent, host)
        page.selectedTimelineDevice = { id: "one", name: "测试电脑", commands: [
            { name: "加载视频", executionInputFields: [{ key: "file", label: "视频文件", type: "string" }] },
            { name: "播放视频", executionInputFields: [] },
            { name: "暂停播放", executionInputFields: [] },
            { name: "停止播放", executionInputFields: [] },
            { name: "关闭播放器", executionInputFields: [] },
            { name: "播放全景视频", executionInputFields: [] }
        ] }
        page.fallbackTimelineCurrentTimeMs = 13800
        host.width = 1181
        host.width = 1180
        wait(30)
        var palette = findChild(host, "deviceCommandList")
        verify(palette.height > 0)
        compare(palette.count, 6)
        compare(findChild(host, "commandAddTime").text, "00:13.800")
        compare(page.formatTimelineMs(3613800), "01:00:13.800")
        verify(!findChild(page, "commandPaletteScroll"))
        for (var index = 0; index < 6; ++index) {
            var button = findChild(host, "addDeviceCommand_" + index)
            verify(button && button.visible && button.enabled)
            var position = button.mapToItem(palette, 0, 0)
            verify(position.x >= 0 && position.x + button.width <= palette.width)
            verify(position.y + button.height <= palette.height, "Default commands require scrolling")
        }
        findChild(host, "addDeviceCommand_2").clicked()
        compare(page.timelineCommandModel.addedCommands.length, 1)
        compare(page.timelineCommandModel.addedCommands[0].time, 13800)
        compare(page.timelineCommandModel.addedCommands[0].deviceId, "one")
        compare(page.timelineCommandModel.addedCommands[0].command.name, "暂停播放")
        findChild(host, "addDeviceCommand_0").clicked()
        wait(30)
        var dialog = findChild(page, "addTimelineCommandPopup")
        verify(dialog.visible)
        compare(dialog.targetCommand.name, "加载视频")
        compare(dialog.targetStartTimeMs, 13800)
        compare(page.timelineCommandModel.addedCommands.length, 1)
        dialog.close()
        page.timelineManager = { playbackState: 1, currentTimeline: null, timelineModel: null }
        verify(!findChild(host, "addDeviceCommand_2").enabled)
        page.timelineManager = null
        findChild(host, "commandPanelTab_1").clicked()
        compare(host.commandPanelMode, "timeline")
        verify(!palette.visible)
        page.deviceTrackSelected()
        compare(host.commandPanelMode, "device")
        verify(palette.visible)
        page.selectTimelineCommand({ id: "existing", startTimeMs: 24000 })
        compare(host.commandPanelMode, "timeline")
        compare(page.timelineCommandModel.selectedCommandId, "existing")
        page.deviceTrackSelected()
        compare(findChild(host, "commandAddTime").text, page.formatTimelineMs(24000))
        page.selectedTimelineDevice = { id: "two", name: "无指令设备", commands: [] }
        wait(30)
        compare(palette.count, 0)
        compare(page.selectedCommandIndex, -1)
        compare(page.timelineCommandModel.addedCommands.length, 1)
    }

    function test_deviceFiltersAndSelection() {
        testDeviceModel.selectedId = "one"
        var page = createTemporaryObject(devicesPageComponent, testWindow.contentItem)
        verify(page)
        compare(page.filteredDevices.length, 2)
        page.deviceSearchText = "  bEtA  "
        wait(20)
        compare(page.filteredDevices.length, 1)
        compare(page.selectedDevice.id, "two")
        verify(page.selectedDeviceInCurrentView)
        page.deviceStatusFilter = "online"
        compare(page.filteredDevices.length, 0)
        verify(!page.selectedDeviceInCurrentView)
        compare(page.selectedDeviceCommands.length, 0)
        page.deviceSearchText = "10.0.0.1"
        wait(20)
        compare(page.filteredDevices.length, 1)
        compare(page.selectedDevice.id, "one")
        page.compactDevices = true
        wait(30)
        verify(page.selectedDeviceInCurrentView)
        page.deviceStatusFilter = "all"
        page.deviceSearchText = ""
        compare(page.filteredDevices.length, 2)
        page.setDeviceDisplayMode("type")
        compare(page.filteredDevices.length, 2)
    }

    function test_timelineEditorFits_data() {
        return [{ tag: "narrow", pageWidth: 1180, listVisible: false },
                { tag: "wide", pageWidth: 1700, listVisible: false }]
    }

    function test_timelineEditorFits(data) {
        var page = createTemporaryObject(timelinePageComponent, testWindow.contentItem, { width: data.pageWidth })
        verify(page)
        var layout = page.children[0]
        page.openTimelineControl(null)
        // 离屏环境通过尺寸变化立即提交 Layout，同时覆盖编辑后的窗口缩放。
        page.width = data.pageWidth - 1
        page.width = data.pageWidth
        wait(30)
        compare(layout.children[0].visible, data.listVisible)
        var editor = null
        for (var index = 0; index < layout.children.length; ++index) {
            var child = layout.children[index]
            if (!child.visible)
                continue
            verify(child.x >= 0)
            verify(child.x + child.width <= layout.width + 1, "Pane exceeds the workspace")
            if (child.item !== undefined)
                editor = child
        }
        verify(editor && editor.item)
        verify(editor.width >= 720, "Editor width: " + editor.width + ", workspace: " + layout.width)
        editor.item.closeRequested()
        compare(page.controlTrackVisible, false)
        wait(30)
        verify(layout.children[0].visible)
    }
}
