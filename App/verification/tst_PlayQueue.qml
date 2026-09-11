import QtQuick 2.14
import QtQuick.Controls 2.14
import QtTest 1.2
import "qrc:/UICore/qml/theme" as Theme
import "../pages" as Pages

TestCase {
    id: testCase
    name: "PlayQueue"
    when: windowShown && testWindow.visible

    ApplicationWindow {
        id: testWindow
        width: 1800
        height: 900
        visible: true
        property QtObject appTheme: Theme.AppTheme {}
    }

    Component {
        id: managerComponent
        QtObject {
            id: manager
            property int playbackState: 0
            property bool queuePlayback: false
            property var playbackTimeline: null
            property int playQueueIndex: -1
            property var playQueue: []
            property var startedIds: []
            property int startTimeMs: -1
            property var currentTimeline: first
            property QtObject first: QtObject {
                property string id: "a"
                property string name: "开场"
                property int state: 0
                property int currentTimeMs: 0
                readonly property int durationMs: commandModel.realDurationMs
                property QtObject commandModel: manager.commands
            }
            property QtObject second: QtObject {
                property string id: "b"
                property string name: "主秀"
                property int state: 0
                property int currentTimeMs: 0
                readonly property int durationMs: commandModel.realDurationMs
                property QtObject commandModel: manager.commands
            }
            property QtObject third: QtObject {
                property string id: "c"
                property string name: "名称很长的互动环节时间轴"
                property int state: 0
                property int currentTimeMs: 0
                readonly property int durationMs: commandModel.realDurationMs
                property QtObject commandModel: manager.commands
            }
            property QtObject fourth: QtObject {
                property string id: "d"
                property string name: "谢幕"
                property int state: 0
                property int currentTimeMs: 0
                readonly property int durationMs: commandModel.realDurationMs
                property QtObject commandModel: manager.commands
            }
            property QtObject timelineModel: QtObject {
                property int count: timelines.length
                property var timelines: [manager.first, manager.second, manager.third, manager.fourth]
                function timelineAt(index) { return timelines[index] }
            }
            property QtObject commands: QtObject {
                property var commands: []
                property int realDurationMs: 60000
                property string selectedCommandId: ""
                property var childTracksByParentId: ({})
            }
            function setCurrentTimelineId(id) {
                for (var index = 0; index < timelineModel.count; ++index) {
                    if (timelineModel.timelines[index].id === id)
                        currentTimeline = timelineModel.timelines[index]
                }
            }
            function setPlayQueue(ids) {
                if (playbackState !== 0)
                    return false
                playQueue = ids.slice()
                return true
            }
            function startPlayback(ids, time) {
                startedIds = ids.slice()
                startTimeMs = time
                playQueueIndex = 0
                queuePlayback = true
                playbackTimeline = timelineModel.timelines.filter(function(timeline) {
                    return timeline.id === ids[0]
                })[0]
                playbackState = 1
                return true
            }
            function pausePlayback() { playbackState = 2 }
            function resumePlayback() { playbackState = 1 }
            function stopPlayback() {
                playbackState = 0
                playQueueIndex = -1
                queuePlayback = false
                playbackTimeline = null
            }
        }
    }

    Component {
        id: pageComponent
        Pages.TimelinePage {
            id: page
            height: 660
            timelineManager: managerComponent.createObject(page)
        }
    }

    function test_queueLayout_data() {
        return [{ tag: "narrow", pageWidth: 1180 }, { tag: "wide", pageWidth: 1700 }]
    }

    function test_queueLayout(data) {
        var page = createTemporaryObject(pageComponent, testWindow.contentItem,
                                         { width: data.pageWidth })
        verify(page)
        var manager = page.timelineManager
        wait(40)
        var dock = findChild(page, "playQueueDock")
        verify(!dock.visible)
        var grid = findChild(page, "timelineGrid")
        var emptyHeight = grid.height
        var addButton = findChild(page, "addTimelineToQueue_a")
        var badge = findChild(page, "timelineQueueBadge_a")
        verify(badge && !badge.visible)
        verify(addButton && addButton.visible)
        compare(addButton.text, "加入队列")
        mouseClick(addButton)
        tryCompare(dock, "visible", true)
        compare(manager.playQueue.join(","), "a")
        compare(addButton.text, "移除队列")
        verify(badge.visible)
        verify(addButton.enabled)
        mouseClick(addButton)
        compare(manager.playQueue.length, 0)
        compare(addButton.text, "加入队列")
        verify(!badge.visible)
        tryCompare(dock, "visible", false)
        for (var state = 1; state <= 3; ++state) {
            manager.playbackState = state
            verify(!addButton.visible)
        }
        manager.stopPlayback()
        verify(addButton.visible)

        manager.setPlayQueue(["b", "c", "d", "a"])
        wait(40)
        verify(badge.visible)
        verify(badge.mapToItem(addButton, 0, badge.height).y <= 0)
        var unselectedBadge = findChild(page, "timelineQueueBadge_b")
        verify(unselectedBadge.visible)
        mouseClick(unselectedBadge)
        compare(manager.currentTimeline.id, "b")
        manager.setCurrentTimelineId("a")
        var panel = findChild(dock, "timelinePlayQueue")
        var sidebar = findChild(page, "timelineSidebar")
        verify(panel && panel.visible)
        compare(dock.width, sidebar.width)
        verify(dock.width >= 320 && dock.width <= 340)
        verify(grid.height < emptyHeight)
        var bottom = dock.mapToItem(sidebar, 0, dock.height).y
        verify(Math.abs(bottom - sidebar.height) <= 1)
        var dockY = dock.y
        grid.positionViewAtEnd()
        compare(dock.y, dockY)
        var list = findChild(panel, "playQueueList")
        compare(list.count, 4)
        compare(list.height, 132)
        var label = findChild(panel, "queueItemName_1")
        verify(label.width > 30)
        verify(label.mapToItem(panel, label.width, 0).x <= panel.width)
        var expandedHeight = dock.height
        mouseClick(findChild(panel, "queueExpandButton"))
        tryCompare(list, "visible", false)
        tryVerify(function() { return dock.height < expandedHeight })
        verify(findChild(panel, "queuePlayButton").visible)
        mouseClick(findChild(panel, "queueExpandButton"))

        page.controlTrackVisible = true
        wait(40)
        verify(!sidebar.visible)
        var entry = findChild(page, "editorQueueButton")
        verify(entry.visible)
        mouseClick(entry)
        var popup = findChild(page, "queueMonitorPopup")
        tryCompare(popup, "opened", true)
        verify(popup.x >= 0 && popup.x + popup.width <= page.width)
        verify(popup.height > 100)
        verify(popup.y >= 0 && popup.y + popup.height <= page.height)
        manager.setPlayQueue([])
        tryCompare(popup, "visible", false)
        verify(!entry.visible)
        page.controlTrackVisible = false
        wait(40)
        verify(!dock.visible)
        compare(grid.height, emptyHeight)
    }

    function test_singlePlaybackKeepsQueueIdle() {
        var page = createTemporaryObject(pageComponent, testWindow.contentItem,
                                         { width: 1180 })
        verify(page)
        var manager = page.timelineManager
        manager.playbackTimeline = manager.first
        manager.playbackState = 1
        manager.first.state = 2
        wait(40)
        verify(!findChild(page, "playQueueDock").visible)
        manager.stopPlayback()
        manager.setPlayQueue(["a", "b"])
        manager.playbackTimeline = manager.first
        manager.playbackState = 1
        manager.setCurrentTimelineId("b")
        wait(40)
        compare(page.primaryRunningTimeline.id, "a")
        compare(page.parallelRunningCount, 0)
        var panel = findChild(page, "timelinePlayQueue")
        var play = findChild(panel, "queuePlayButton")
        var stop = findChild(panel, "queueStopButton")
        for (var state = 1; state <= 3; ++state) {
            manager.playbackState = state
            manager.first.state = state === 3 ? 3 : 2
            verify(findChild(page, "timelineQueueBadge_a").visible)
            verify(findChild(page, "timelineQueueBadge_b").visible)
            verify(!findChild(page, "addTimelineToQueue_b").visible)
            compare(findChild(panel, "queueStateLabel").text, "待播放")
            compare(play.text, "播放队列")
            compare(play.enabled, state === 3)
            verify(!stop.enabled)
            verify(!findChild(panel, "queueCurrentLabel").visible)
            compare(findChild(panel, "playQueueList").currentIndex, -1)
            if (state !== 3) {
                mouseClick(play)
                mouseClick(stop)
                compare(manager.playbackState, state)
                compare(manager.startedIds.length, 0)
            }
            compare(manager.playQueue.join(","), "a,b")
        }
        mouseClick(play)
        compare(manager.startedIds.join(","), "a,b")
        verify(manager.queuePlayback)
        compare(findChild(panel, "queueStateLabel").text, "播放中")
    }

    function test_queueControls() {
        var page = createTemporaryObject(pageComponent, testWindow.contentItem,
                                         { width: 1180 })
        verify(page)
        var manager = page.timelineManager
        manager.setPlayQueue(["b", "c", "d", "a"])
        wait(40)
        var panel = findChild(page, "timelinePlayQueue")
        verify(panel)
        var list = findChild(panel, "playQueueList")
        var play = findChild(panel, "queuePlayButton")
        var stop = findChild(panel, "queueStopButton")
        page.editor.setTimelineCurrentTimeMs(30000)
        mouseClick(play)
        compare(manager.startedIds.join(","), "b,c,d,a")
        compare(manager.startTimeMs, 0)
        compare(manager.currentTimeline.id, "a")
        compare(manager.playbackState, 1)
        verify(stop.enabled)
        mouseClick(play)
        compare(manager.playbackState, 2)
        mouseClick(play)
        compare(manager.playbackState, 1)
        manager.playQueueIndex = 3
        wait(40)
        compare(list.currentIndex, 3)
        verify(list.contentY > 0)
        var itemMenuButton = findChild(panel, "queueItemMenuButton_3")
        mouseClick(itemMenuButton)
        var itemMenu = itemMenuButton.data[0]
        verify(itemMenu, "Missing active item menu")
        tryCompare(itemMenu, "opened", true)
        verify(!itemMenu.itemAt(0).enabled && !itemMenu.itemAt(2).enabled)
        itemMenu.close()
        manager.playQueueIndex = -1
        manager.playbackState = 3
        compare(findChild(panel, "queueStateLabel").text, "已完成")
        verify(panel.visible && play.enabled)
        mouseClick(play)
        compare(manager.playbackState, 1)
        mouseClick(stop)
        compare(manager.playQueue.join(","), "b,c,d,a")
        compare(manager.playbackState, 0)

        list.positionViewAtBeginning()
        wait(40)
        mouseClick(findChild(panel, "queueItemMenuButton_0"))
        itemMenu = findChild(panel, "queueItemMenuButton_0").data[0]
        tryCompare(itemMenu, "opened", true)
        mouseClick(itemMenu.itemAt(1))
        compare(manager.playQueue.join(","), "c,b,d,a")
        wait(40)
        mouseClick(findChild(panel, "queueItemMenuButton_0"))
        itemMenu = findChild(panel, "queueItemMenuButton_0").data[0]
        tryCompare(itemMenu, "opened", true)
        mouseClick(itemMenu.itemAt(2))
        compare(manager.playQueue.join(","), "b,d,a")
        wait(40)
        mouseClick(findChild(panel, "queueMenuButton"))
        var menu = findChild(panel, "queueMenuButton").data[0]
        tryCompare(menu, "opened", true)
        mouseClick(menu.itemAt(1))
        compare(manager.playQueue.length, 0)
        tryCompare(findChild(page, "playQueueDock"), "visible", false)
    }
}
