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
                property var commands: [{ id: "move", targetDeviceId: "one", commandName: "播放视频",
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
                property QtObject currentTimeline: QtObject {
                    property string name: "拖拽检查"
                    property var commandModel: fixture.model
                    property var crossConditionModel: null
                    property int durationMs: 60000
                    property int currentTimeMs: 0
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
            commands: [{ id: "overview", commandName: "概览指令", startTimeMs: 3000 }]
            ruler: Timeline.TimelineRuler { parent: overview; visible: false; width: 1000; durationMs: 60000 }
        }
    }

    SignalSpy { id: selectionSpy; signalName: "timelineCommandSelected" }
    SignalSpy { id: moveSpy; signalName: "commandMoveRequested" }

    function init() {
        testWindow.requestActivate()
        tryCompare(testWindow, "active", true)
    }

    function cleanup() {
        keyRelease(Qt.Key_Control)
        selectionSpy.target = null
        moveSpy.target = null
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
            { tag: "zoom-scroll", start: 21234, scale: 2, scroll: 100, delta: 96, expected: 29234 }
        ]
    }

    function test_move(data) {
        var fixture = createTemporaryObject(fixtureComponent, testWindow.contentItem,
            { startTimeMs: data.start })
        verify(fixture)
        fixture.page.timelineTimeScale = data.scale
        fixture.page.timelineScrollX = data.scroll
        fixture.page.fallbackTimelineCurrentTimeMs = 7654
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
        compare(fixture.page.timelineCurrentTimeMs, 7654)
        mouseRelease(fixture.page, point.x + data.delta, point.y, Qt.LeftButton, Qt.ControlModifier)
        compare(fixture.model.updates, 1)
        compare(command.startTimeMs, data.expected)
        compare(command.durationMs, undefined)
        compare(command.executionInputValues, { file: "sample.mp4", play: true })
        compare(command.state, 0)
        compare(fixture.model.selectedCommandId, "move")
        compare(selectionSpy.count, 1)
        compare(fixture.page.timelineScrollX, data.scroll)
        compare(fixture.page.timelineCurrentTimeMs, 7654)
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
        if (data.excursion < Qt.styleHints.startDragDistance) {
            compare(fixture.model.selectedCommandId, "move")
            compare(fixture.page.timelineCurrentTimeMs, 1234)
        } else if (data.control) {
            compare(fixture.page.timelineCurrentTimeMs, 7654)
        }
    }

    function test_cancel_data() {
        return [ { tag: "control" }, { tag: "escape" }, { tag: "running" },
            { tag: "paused" }, { tag: "timeline" }, { tag: "hidden" },
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
        case "paused": fixture.manager.playbackState = 2; break
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
            commands.push({ id: "dense" + index, targetDeviceId: "one", commandName: "播放视频",
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
