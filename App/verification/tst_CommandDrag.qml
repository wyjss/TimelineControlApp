import QtQuick 2.14
import QtQuick.Controls 2.14
import QtTest 1.2
import "qrc:/UICore/qml/theme" as Theme
import "../pages" as Pages
import "../pages/timeline" as Timeline

TestCase {
    id: testCase
    name: "CommandDrag"
    when: windowShown && testWindow.visible

    ApplicationWindow {
        id: testWindow
        width: 1600
        height: 900
        visible: true
        property QtObject appTheme: Theme.AppTheme {}
    }

    Component {
        id: fixtureComponent
        Item {
            id: fixture
            width: 1200
            height: 760
            property real startTimeMs: 1234
            property alias page: page
            property alias model: commandModel
            property alias manager: manager

            QtObject {
                id: commandModel
                property var commands: [{ id: "move", targetDeviceId: "one", commandName: "播放视频", alias: "播放视频",
                    startTimeMs: fixture.startTimeMs,
                    executionInputValues: { file: "sample.mp4", play: true },
                    targetCommand: { protocol: "pc" }, state: 3, errorMessage: "原执行结果" }]
                property string selectedCommandId: ""
                property var childTracksByParentId: ({})
                property int realDurationMs: 60000
                property int updates: 0
                function updateCommand(command, time, values) {
                    command = commands.filter(function(item) { return item.id === command.id })[0]
                    if (!command)
                        return false
                    ++updates
                    command.startTimeMs = time
                    command.executionInputValues = values
                    command.state = 0
                    command.errorMessage = ""
                    // 模拟真实模型在改时后通知列表刷新，验证释放后的组件重建。
                    commands = commands.slice()
                    return true
                }
            }

            QtObject {
                id: manager
                property int playbackState: 0
                property var timelineModel: null
                property int seeks: 0
                property string seekId: ""
                function seekTimeline(id, time) {
                    ++seeks
                    seekId = id
                    currentTimeline.currentTimeMs = time
                    return true
                }
                property QtObject currentTimeline: QtObject {
                    property string id: "main"
                    property int state: 2
                    property string name: "拖拽检查"
                    property var commandModel: fixture.model
                    property var crossConditionModel: null
                    property int durationMs: 60000
                    property int currentTimeMs: 0
                    signal seekPreviewRequested(real timeMs)
                }
            }

            Pages.TimelineEditorPage {
                id: page
                anchors.fill: parent
                appRuntime: null
                pcPreviewGenerator: null
                controlTrackOnly: true
                timelineManager: manager
                deviceModel: QtObject {
                    property var devices: [{ id: "one", name: "测试设备", deviceType: "PC",
                        commands: [], online: true, filteredOut: false }]
                    function selectDevice(deviceId) {}
                }
            }
        }
    }

    Component {
        id: overviewComponent
        Timeline.TimelineCommandHorizontalList {
            id: overview
            width: 1000
            height: 48
            commands: [{ id: "overview", commandName: "概览指令", alias: "概览指令", startTimeMs: 3000 }]
            ruler: Timeline.TimelineRuler { parent: overview; visible: false; width: 1000; durationMs: 60000 }
        }
    }

    Component {
        id: quickTestResultComponent
        QtObject {
            property string alias: ""
            property int state: 1
            property string errorMessage: ""
            readonly property string stateText: state === 1 ? "执行中" : (state === 2 ? "成功" : "失败")
        }
    }

    Component {
        id: testRuntimeComponent
        QtObject {
            id: runtimeStub
            property var calls: []
            function testDeviceCommand(deviceId, command, values) {
                calls = calls.concat([{deviceId: deviceId, command: command, values: values}])
                return quickTestResultComponent.createObject(runtimeStub)
            }
        }
    }

    SignalSpy { id: selectionSpy; signalName: "timelineCommandSelected" }
    SignalSpy { id: moveSpy; signalName: "commandMoveRequested" }
    SignalSpy { id: previewSpy; signalName: "seekPreviewRequested" }

    function init() {
        testWindow.requestActivate()
        tryCompare(testWindow, "active", true)
    }

    function cleanup() {
        keyRelease(Qt.Key_Control)
        selectionSpy.target = null
        moveSpy.target = null
        previewSpy.target = null
    }

    function pressCommand(fixture, commandId, modifiers) {
        wait(30)
        var block = findChild(fixture.page, "timelineCommand_" + commandId)
        verify(block && block.visible)
        var hit = findChild(block, "timelineCommandHitArea")
        var point = hit.mapToItem(fixture.page, hit.width / 2, hit.height / 2)
        point.x = Math.round(point.x)
        point.y = Math.round(point.y)
        if (modifiers & Qt.ControlModifier)
            keyPress(Qt.Key_Control)
        mousePress(fixture.page, point.x, point.y, Qt.LeftButton, modifiers)
        return point
    }

    function test_move_data() {
        // 当前刻度尺在 1 倍缩放时每秒 24 像素，96 像素对应 4 秒。
        return [
            { tag: "instant", start: 1234, scale: 1, scroll: 0, delta: 96, expected: 5234 },
            { tag: "zero-bound", start: 1234, scale: 1, scroll: 0, delta: -96, expected: 0 },
            { tag: "zoom-scroll", start: 21234, scale: 2, scroll: 100, delta: 96, expected: 29234 },
            { tag: "paused", start: 21234, scale: 1, scroll: 0, delta: 96, expected: 25234, paused: true }
        ]
    }

    function test_move(data) {
        var fixture = createTemporaryObject(fixtureComponent, testWindow.contentItem,
            { startTimeMs: data.start })
        verify(fixture)
        fixture.page.timelineTimeScale = data.scale
        fixture.page.timelineScrollX = data.scroll
        fixture.page.fallbackTimelineCurrentTimeMs = 7654
        if (data.paused) {
            fixture.manager.currentTimeline.currentTimeMs = 20000
            fixture.manager.playbackState = 2
        }
        var currentTimeMs = data.paused ? 20000 : 7654
        selectionSpy.target = fixture.page
        selectionSpy.clear()
        var command = fixture.model.commands[0]
        var point = pressCommand(fixture, "move", Qt.ControlModifier)
        var block = findChild(fixture.page, "timelineCommand_move")
        var originalX = block.anchorX
        mouseMove(fixture.page, point.x + data.delta / 4, point.y, 20, Qt.LeftButton)
        mouseMove(fixture.page, point.x + data.delta / 2, point.y, 20, Qt.LeftButton)
        compare(fixture.model.updates, 0)
        compare(command.startTimeMs, data.start)
        verify(block.anchorX !== originalX, "Dragging must preview the new position")
        compare(fixture.page.timelineScrollX, data.scroll)
        compare(fixture.page.timelineCurrentTimeMs, currentTimeMs)
        mouseRelease(fixture.page, point.x + data.delta, point.y, Qt.LeftButton, Qt.ControlModifier)
        compare(fixture.model.updates, 1)
        compare(command.startTimeMs, data.expected)
        compare(command.durationMs, undefined)
        compare(command.executionInputValues, { file: "sample.mp4", play: true })
        compare(command.state, 0)
        compare(fixture.model.selectedCommandId, "move")
        compare(selectionSpy.count, 1)
        compare(fixture.page.timelineScrollX, data.scroll)
        compare(fixture.page.timelineCurrentTimeMs, currentTimeMs)
        wait(30)
        block = findChild(fixture.page, "timelineCommand_move")
        var committedX = block.anchorX
        fixture.page.timelineScrollX = data.scroll + 16
        compare(block.anchorX, committedX - 16)
    }

    function test_clickAndNoChange_data() {
        return [
            { tag: "click", control: false, excursion: 0 },
            { tag: "ctrl-click", control: true, excursion: 0 },
            { tag: "below-threshold", control: true, excursion: 1 },
            { tag: "return-to-start", control: true, excursion: 64 },
            { tag: "no-ctrl", control: false, excursion: 64 }
        ]
    }

    function test_clickAndNoChange(data) {
        var fixture = createTemporaryObject(fixtureComponent, testWindow.contentItem)
        verify(fixture)
        fixture.page.fallbackTimelineCurrentTimeMs = 7654
        var command = fixture.model.commands[0]
        var modifiers = data.control ? Qt.ControlModifier : Qt.NoModifier
        var point = pressCommand(fixture, "move", modifiers)
        if (data.excursion) {
            mouseMove(fixture.page, point.x + data.excursion, point.y, 20, Qt.LeftButton)
            mouseMove(fixture.page, point.x, point.y, 20, Qt.LeftButton)
        }
        mouseRelease(fixture.page, point.x, point.y, Qt.LeftButton, modifiers)
        compare(fixture.model.updates, 0)
        compare(command.startTimeMs, 1234)
        compare(command.state, 3)
        compare(command.errorMessage, "原执行结果")
        if (data.excursion < Qt.styleHints.startDragDistance)
            compare(fixture.model.selectedCommandId, "move")
        compare(fixture.page.timelineCurrentTimeMs, 7654)
    }

    function test_selectAndLocate_data() {
        return [
            {tag: "stopped", playback: 0, timelineState: 0, canLocate: true},
            {tag: "paused", playback: 2, timelineState: 2, canLocate: true},
            {tag: "running", playback: 1, timelineState: 2, canLocate: false},
            {tag: "completed", playback: 3, timelineState: 3, canLocate: false},
            {tag: "paused-waiting", playback: 2, timelineState: 1, canLocate: false},
            {tag: "paused-completed", playback: 2, timelineState: 3, canLocate: false}
        ]
    }

    function test_selectAndLocate(data) {
        var fixture = createTemporaryObject(fixtureComponent, testWindow.contentItem,
                                             {width: 1600})
        verify(fixture)
        fixture.page.controlTrackOnly = false
        fixture.page.fallbackTimelineCurrentTimeMs = 7654
        fixture.manager.currentTimeline.currentTimeMs = 7654
        fixture.manager.currentTimeline.state = data.timelineState
        fixture.manager.playbackState = data.playback
        var command = fixture.model.commands[0]
        var point = pressCommand(fixture, "move", Qt.NoModifier)
        mouseRelease(fixture.page, point.x, point.y)
        compare(fixture.model.selectedCommandId, "move")
        compare(fixture.page.timelineCurrentTimeMs, 7654)
        compare(fixture.manager.seeks, 0)
        compare(command.state, 3)
        compare(command.errorMessage, "原执行结果")

        fixture.model.selectedCommandId = ""
        var label = findChild(fixture.page, "commandNameLabel")
        verify(label && label.visible)
        mouseClick(label, 5, label.height / 2)
        compare(fixture.model.selectedCommandId, "move")
        compare(fixture.page.timelineCurrentTimeMs, 7654)
        compare(fixture.manager.seeks, 0)
        compare(command.state, 3)
        compare(command.errorMessage, "原执行结果")

        var locate = findChild(fixture.page, "locateTimelineCommand_move")
        verify(locate)
        tryCompare(locate, "visible", true)
        compare(locate.enabled, data.canLocate)
        mouseClick(locate)
        compare(fixture.page.timelineCurrentTimeMs, data.canLocate ? 1234 : 7654)
        compare(fixture.manager.seeks, data.canLocate && data.playback === 2 ? 1 : 0)
        compare(fixture.manager.playbackState, data.playback)
        compare(fixture.model.updates, 0)
    }

    function test_contextMenuTest_data() {
        return [
            {tag: "track-stopped", list: false, playback: 0},
            {tag: "track-running", list: false, playback: 1},
            {tag: "track-paused", list: false, playback: 2},
            {tag: "track-completed", list: false, playback: 3},
            {tag: "list-stopped", list: true, playback: 0},
            {tag: "list-running", list: true, playback: 1},
            {tag: "list-paused", list: true, playback: 2},
            {tag: "list-completed", list: true, playback: 3},
            {tag: "track-paused-waiting", list: false, playback: 2, timelineState: 1},
            {tag: "track-paused-completed", list: false, playback: 2, timelineState: 3},
            {tag: "list-paused-waiting", list: true, playback: 2, timelineState: 1},
            {tag: "list-paused-completed", list: true, playback: 2, timelineState: 3},
            {tag: "track-ctrl-right", list: false, playback: 2, control: true}
        ]
    }

    function test_contextMenuTest(data) {
        var fixture = createTemporaryObject(fixtureComponent, testWindow.contentItem, {width: 1600})
        verify(fixture)
        fixture.page.controlTrackOnly = false
        fixture.page.appRuntime = createTemporaryObject(testRuntimeComponent, fixture)
        fixture.page.fallbackTimelineCurrentTimeMs = 7654
        fixture.manager.currentTimeline.currentTimeMs = 7654
        fixture.manager.playbackState = data.playback
        if (data.timelineState !== undefined)
            fixture.manager.currentTimeline.state = data.timelineState
        var command = fixture.model.commands[0]
        var other = {id: "other", targetDeviceId: "one", alias: "另一条指令", startTimeMs: 6000,
            executionInputValues: {file: "other.mp4", play: false}, targetCommand: {protocol: "pc"}, state: 2}
        fixture.model.commands = [command, other]
        fixture.model.selectedCommandId = "other"
        selectionSpy.target = fixture.page
        selectionSpy.clear()
        wait(30)
        var target = data.list ? findChild(fixture.page, "locateTimelineCommand_move").parent
            : findChild(findChild(fixture.page, "timelineCommand_move"), "timelineCommandHitArea")
        var menuOwner = target
        while (menuOwner && typeof menuOwner.commandTestRequested !== "function")
            menuOwner = menuOwner.parent
        var menu = findChild(menuOwner, "timelineCommandContextMenu")
        verify(menu)
        var modifiers = data.control ? Qt.ControlModifier : Qt.NoModifier
        mouseClick(target, 5, target.height / 2, Qt.RightButton, modifiers)
        tryCompare(menu, "opened", true)
        compare(menu.timelineCommand, command)
        compare(fixture.page.appRuntime.calls.length, 0)
        compare(selectionSpy.count, 1)
        compare(fixture.model.selectedCommandId, "move")
        compare(fixture.page.timelineCurrentTimeMs, 7654)
        keyClick(Qt.Key_Escape)
        tryCompare(menu, "visible", false)
        compare(fixture.page.appRuntime.calls.length, 0)
        compare(fixture.model.selectedCommandId, "move")

        mouseClick(target, 5, target.height / 2, Qt.RightButton, modifiers)
        tryCompare(menu, "opened", true)
        verify(menu.itemAt(0).enabled)
        mouseClick(menu.itemAt(0))
        tryCompare(menu, "visible", false)
        compare(fixture.page.appRuntime.calls.length, 1)
        var call = fixture.page.appRuntime.calls[0]
        compare(call.deviceId, command.targetDeviceId)
        compare(call.command, command.targetCommand)
        compare(call.values, command.executionInputValues)
        var previousResult = fixture.page.quickTestCommand
        verify(previousResult !== command)
        compare(previousResult.alias, command.alias)
        var status = findChild(fixture.page, "timelineQuickTestStatus")
        verify(status.visible && status.text.indexOf("执行中") >= 0)
        previousResult.errorMessage = "设备未响应"
        previousResult.state = 3
        verify(status.text.indexOf("设备未响应") >= 0)

        target = data.list ? findChild(fixture.page, "locateTimelineCommand_other").parent
            : findChild(findChild(fixture.page, "timelineCommand_other"), "timelineCommandHitArea")
        mouseClick(target, 5, target.height / 2, Qt.RightButton)
        tryCompare(menu, "opened", true)
        compare(menu.timelineCommand, other)
        mouseClick(menu.itemAt(0))
        tryCompare(menu, "visible", false)
        compare(fixture.page.appRuntime.calls.length, 2)
        compare(fixture.page.appRuntime.calls[1].values, other.executionInputValues)
        previousResult.state = 2
        verify(status.text.indexOf("另一条指令") >= 0 && status.text.indexOf("执行中") >= 0)
        fixture.page.quickTestCommand.state = 2
        verify(status.text.indexOf("成功") >= 0)
        compare(command.state, 3)
        compare(command.errorMessage, "原执行结果")
        compare(other.state, 2)
        compare(fixture.model.selectedCommandId, "other")
        compare(selectionSpy.count, 3)
        compare(fixture.page.timelineCurrentTimeMs, 7654)
        compare(fixture.manager.playbackState, data.playback)
        compare(fixture.manager.seeks, 0)
        compare(fixture.model.updates, 0)

        target = data.list ? findChild(fixture.page, "locateTimelineCommand_move").parent
            : findChild(findChild(fixture.page, "timelineCommand_move"), "timelineCommandHitArea")
        mouseClick(target, 5, target.height / 2, Qt.RightButton)
        tryCompare(menu, "opened", true)
        compare(fixture.model.selectedCommandId, "move")
        compare(fixture.page.timelineCurrentTimeMs, 7654)
        var locate = menu.itemAt(1)
        var canLocate = data.playback === 0
            || (data.playback === 2 && fixture.manager.currentTimeline.state === 2)
        compare(locate.enabled, canLocate)
        if (canLocate) {
            fixture.manager.playbackState = 1
            compare(locate.enabled, false)
            fixture.manager.playbackState = data.playback
            compare(locate.enabled, true)
        }
        mouseClick(locate)
        if (!canLocate) {
            compare(menu.visible, true)
            keyClick(Qt.Key_Escape)
        }
        tryCompare(menu, "visible", false)
        compare(fixture.page.timelineCurrentTimeMs, canLocate ? 1234 : 7654)
        compare(fixture.manager.seeks, canLocate && data.playback === 2 ? 1 : 0)
        compare(fixture.manager.playbackState, data.playback)
        compare(fixture.page.appRuntime.calls.length, 2)
        compare(fixture.model.updates, 0)
    }

    function test_cancel_data() {
        return [ { tag: "control" }, { tag: "escape" }, { tag: "running" },
            { tag: "completed" }, { tag: "timeline" }, { tag: "hidden" },
            { tag: "scroll" }, { tag: "resize" }, { tag: "focus" }, { tag: "zoom" } ]
    }

    function test_cancel(data) {
        var fixture = createTemporaryObject(fixtureComponent, testWindow.contentItem)
        verify(fixture)
        var command = fixture.model.commands[0]
        var point = pressCommand(fixture, "move", Qt.ControlModifier)
        mouseMove(fixture.page, point.x + 64, point.y, 20, Qt.LeftButton)
        verify(findChild(fixture.page, "timelineCommandHitArea").previewing)
        switch (data.tag) {
        case "control": keyRelease(Qt.Key_Control); break
        case "escape": keyClick(Qt.Key_Escape, Qt.ControlModifier); break
        case "running": fixture.manager.playbackState = 1; break
        case "completed": fixture.manager.playbackState = 3; break
        case "timeline": fixture.manager.currentTimeline = null; break
        case "hidden": fixture.page.visible = false; break
        case "scroll": fixture.page.timelineScrollX += 16; break
        case "resize": fixture.width += 20; break
        case "focus": fixture.page.forceActiveFocus(); break
        case "zoom": fixture.page.timelineTimeScale = 2; break
        }
        wait(30)
        mouseRelease(fixture.page, point.x + 64, point.y, Qt.LeftButton,
            data.tag === "control" ? Qt.NoModifier : Qt.ControlModifier)
        compare(fixture.model.updates, 0)
        compare(command.startTimeMs, 1234)
        compare(command.state, 3)
    }

    function test_denseCommands() {
        var fixture = createTemporaryObject(fixtureComponent, testWindow.contentItem)
        verify(fixture)
        var commands = []
        for (var index = 0; index < 4; ++index)
            commands.push({ id: "dense" + index, targetDeviceId: "one", commandName: "播放视频", alias: "播放视频",
                startTimeMs: 3000, executionInputValues: {}, targetCommand: { protocol: "pc" } })
        fixture.model.commands = commands
        var point = pressCommand(fixture, "dense2", Qt.ControlModifier)
        var block = findChild(fixture.page, "timelineCommand_dense2")
        compare(block.instantLayout.overflowCount, 1)
        var lane = block.instantLayout.lane
        mouseMove(fixture.page, point.x + 240, point.y, 20, Qt.LeftButton)
        compare(block.instantLayout.lane, lane)
        compare(block.displayText, "播放视频")
        verify(block.visible)
        compare(fixture.model.updates, 0)
        mouseRelease(fixture.page, point.x + 240, point.y, Qt.LeftButton, Qt.ControlModifier)
        compare(fixture.model.updates, 1)
        compare(commands[2].startTimeMs, 13000)
        compare(commands[0].startTimeMs, 3000)
        compare(commands[1].startTimeMs, 3000)
        compare(commands[3].startTimeMs, 3000)
        wait(30)
        verify(findChild(fixture.page, "timelineCommand_dense3").visible)
    }

    function test_pausedSeek_data() {
        return [
            {tag: "forward", start: 20000, scroll: 0, delta: 96, expected: 24000},
            {tag: "backward", start: 20000, scroll: 0, delta: -240, expected: 10000},
            {tag: "zero", start: 2000, scroll: 0, delta: -96, expected: 0},
            {tag: "end", start: 58000, scroll: 800, delta: 96, expected: 60000}
        ]
    }

    function test_pausedSeek(data) {
        var fixture = createTemporaryObject(fixtureComponent, testWindow.contentItem)
        verify(fixture)
        previewSpy.target = fixture.manager.currentTimeline
        previewSpy.clear()
        fixture.manager.currentTimeline.currentTimeMs = data.start
        fixture.manager.playbackState = 2
        fixture.page.timelineScrollX = data.scroll
        wait(30)
        var ruler = findChild(fixture.page, "timelineRuler")
        verify(ruler && ruler.currentTimeDragEnabled)
        var point = ruler.mapToItem(fixture.page, ruler.currentTimeX, ruler.height - 10)
        mousePress(fixture.page, point.x, point.y)
        mouseMove(fixture.page, point.x + data.delta, point.y, 20, Qt.LeftButton)
        compare(fixture.manager.seeks, 0)
        compare(fixture.page.timelineCurrentTimeMs, data.start)
        compare(ruler.displayedCurrentTimeMs, data.expected)
        compare(previewSpy.count, 1)
        compare(previewSpy.signalArguments[0][0], data.expected)
        mouseMove(fixture.page, point.x + data.delta, point.y, 20, Qt.LeftButton)
        compare(previewSpy.count, 1)
        mouseRelease(fixture.page, point.x + data.delta, point.y)
        compare(fixture.manager.seeks, 1)
        compare(fixture.manager.seekId, "main")
        compare(fixture.page.timelineCurrentTimeMs, data.expected)
        compare(ruler.displayedCurrentTimeMs, data.expected)
        compare(fixture.manager.playbackState, 2)
        compare(previewSpy.count, 1)
    }

    function test_pausedSeekCancel_data() {
        return [{tag: "escape"}, {tag: "running"}, {tag: "timeline"}, {tag: "hidden"}]
    }

    function test_pausedSeekCancel(data) {
        var fixture = createTemporaryObject(fixtureComponent, testWindow.contentItem)
        verify(fixture)
        previewSpy.target = fixture.manager.currentTimeline
        previewSpy.clear()
        fixture.manager.currentTimeline.currentTimeMs = 20000
        fixture.manager.playbackState = 2
        wait(30)
        var ruler = findChild(fixture.page, "timelineRuler")
        var point = ruler.mapToItem(fixture.page, ruler.currentTimeX, ruler.height - 10)
        mousePress(fixture.page, point.x, point.y)
        mouseMove(fixture.page, point.x + 96, point.y, 20, Qt.LeftButton)
        compare(ruler.displayedCurrentTimeMs, 24000)
        switch (data.tag) {
        case "escape": keyClick(Qt.Key_Escape); break
        case "running": fixture.manager.playbackState = 1; break
        case "timeline": fixture.manager.currentTimeline.id = "other"; break
        case "hidden": fixture.page.visible = false; break
        }
        compare(previewSpy.count, 1)
        compare(previewSpy.signalArguments[0][0], 24000)
        mouseRelease(fixture.page, point.x + 96, point.y)
        compare(fixture.manager.seeks, 0)
        compare(fixture.page.timelineCurrentTimeMs, 20000)
        compare(ruler.displayedCurrentTimeMs, 20000)
        compare(previewSpy.count, 1)
    }

    function test_stoppedSeekDrag() {
        var fixture = createTemporaryObject(fixtureComponent, testWindow.contentItem)
        verify(fixture)
        previewSpy.target = fixture.manager.currentTimeline
        previewSpy.clear()
        fixture.page.fallbackTimelineCurrentTimeMs = 20000
        wait(30)
        var ruler = findChild(fixture.page, "timelineRuler")
        var point = ruler.mapToItem(fixture.page, ruler.currentTimeX, ruler.height - 10)
        mousePress(fixture.page, point.x, point.y)
        mouseMove(fixture.page, point.x + 96, point.y, 20, Qt.LeftButton)
        compare(fixture.page.timelineCurrentTimeMs, 24000)
        compare(fixture.manager.seeks, 0)
        compare(previewSpy.count, 1)
        compare(previewSpy.signalArguments[0][0], 24000)
        mouseRelease(fixture.page, point.x + 96, point.y)
        compare(fixture.page.timelineCurrentTimeMs, 24000)
        compare(fixture.manager.playbackState, 0)
        compare(previewSpy.count, 1)
    }

    function test_pausedSeekInput() {
        var fixture = createTemporaryObject(fixtureComponent, testWindow.contentItem)
        verify(fixture)
        fixture.manager.currentTimeline.currentTimeMs = 20000
        fixture.manager.playbackState = 2
        wait(30)
        var ruler = findChild(fixture.page, "timelineRuler")
        var field = findChild(ruler, "timelineCurrentTimeField")
        verify(field && !field.readOnly)
        field.text = "00:12.345"
        field.editingFinished()
        compare(fixture.manager.seeks, 1)
        compare(fixture.page.timelineCurrentTimeMs, 12345)
        fixture.manager.playbackState = 1
        verify(field.readOnly && !ruler.currentTimeDragEnabled)
        field.text = "00:30.000"
        field.editingFinished()
        fixture.page.setTimelineCurrentTimeMs(40000)
        compare(fixture.manager.seeks, 1)
        compare(fixture.page.timelineCurrentTimeMs, 12345)
        compare(field.text, "00:12.345")
        fixture.manager.playbackState = 2
        mouseDoubleClickSequence(ruler, ruler.timeToX(30000), ruler.height - 10)
        compare(fixture.manager.seeks, 2)
        compare(fixture.page.timelineCurrentTimeMs, 30000)
        fixture.manager.currentTimeline.state = 1
        verify(!ruler.currentTimeDragEnabled)
        fixture.manager.currentTimeline.state = 3
        verify(!ruler.currentTimeDragEnabled)
    }

    function test_overviewReadOnly() {
        var overview = createTemporaryObject(overviewComponent, testWindow.contentItem)
        verify(overview)
        moveSpy.target = overview
        moveSpy.clear()
        wait(30)
        var hit = findChild(overview, "timelineCommandHitArea")
        var point = hit.mapToItem(overview, hit.width / 2, hit.height / 2)
        keyPress(Qt.Key_Control)
        mouseDrag(overview, point.x, point.y, 64, 0, Qt.LeftButton, Qt.ControlModifier)
        compare(moveSpy.count, 0)
        compare(overview.commands[0].startTimeMs, 3000)
    }
}
