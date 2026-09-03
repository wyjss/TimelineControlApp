import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/theme" as Theme
import "timeline" as Timeline

Item {
    id: root

    focus: true

    Theme.AppTheme {
        id: fallbackTheme
    }

    property QtObject pageTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : fallbackTheme
    property var appRuntime: typeof app !== "undefined" ? app : null
    property var timelineManager: appRuntime && appRuntime.timelineManager
        ? appRuntime.timelineManager
        : null
    property var timelineModel: timelineManager && timelineManager.timelineModel
        ? timelineManager.timelineModel
        : null
    property var deviceModel: appRuntime && appRuntime.deviceModel
        ? appRuntime.deviceModel
        : null
    property var timelines: []
    property bool controlTrackVisible: false
    readonly property var currentTimeline: timelineManager ? timelineManager.currentTimeline : null
    readonly property var timelineCommandModel: currentTimeline ? currentTimeline.commandModel : null
    readonly property var timelineCommands: timelineCommandModel && timelineCommandModel.commands
        ? timelineCommandModel.commands
        : []
    readonly property var devices: deviceModel && deviceModel.devices ? deviceModel.devices : []
    readonly property string selectedTimelineCommandId: timelineCommandModel
        ? timelineCommandModel.selectedCommandId
        : ""
    readonly property int overviewDurationMs: timelineCommandModel
        ? Math.max(0, Number(timelineCommandModel.realDurationMs || 0))
        : 0
    readonly property int timelineCurrentTimeMs: timelineEditorLoader.item
        ? timelineEditorLoader.item.timelineCurrentTimeMs
        : (currentTimeline ? currentTimeline.currentTimeMs : 0)
    readonly property bool timelineStopped: !timelineManager || timelineManager.playbackState === 0
    readonly property var queuedTimelineIds: timelineManager
        ? timelineManager.playQueue
        : []
    readonly property int queuedTimelineCount: queuedTimelineIds.length
    readonly property int activeQueueIndex: timelineManager
        ? timelineManager.playQueueIndex
        : -1
    readonly property var primaryRunningTimeline: activeQueueIndex >= 0
        && activeQueueIndex < queuedTimelineIds.length
        ? timelineForId(queuedTimelineIds[activeQueueIndex])
        : null
    readonly property int runningTimelineCount: countTimelinesInState(2)
    readonly property int parallelRunningCount: Math.max(0, runningTimelineCount
        - (primaryRunningTimeline && Number(primaryRunningTimeline.state) === 2 ? 1 : 0))
    readonly property var queueEditorTimelines: orderedQueueTimelines()
    Connections {
        target: root.timelineModel
        function onTimelinesChanged() {
            root.rebuildTimelines()
        }
    }

    Component.onCompleted: rebuildTimelines()

    function rebuildTimelines() {
        var items = []
        if (timelineModel) {
            for (var index = 0; index < timelineModel.count; ++index)
                items.push(timelineModel.timelineAt(index))
        }
        timelines = items
    }

    function timelineForId(timelineId) {
        for (var index = 0; index < timelines.length; ++index) {
            if (String(timelines[index].id || "") === String(timelineId || ""))
                return timelines[index]
        }
        return null
    }

    function countTimelinesInState(state) {
        var count = 0
        for (var index = 0; index < timelines.length; ++index) {
            if (Number(timelines[index].state) === state)
                ++count
        }
        return count
    }

    function orderedQueueTimelines() {
        var items = []
        for (var queueIndex = 0; queueIndex < queuedTimelineIds.length; ++queueIndex) {
            var queuedTimeline = timelineForId(queuedTimelineIds[queueIndex])
            if (queuedTimeline)
                items.push(queuedTimeline)
        }
        for (var index = 0; index < timelines.length; ++index) {
            if (queuedTimelineIds.indexOf(String(timelines[index].id || "")) < 0)
                items.push(timelines[index])
        }
        return items
    }

    function queuePreviewText() {
        var names = []
        for (var index = 0; index < queuedTimelineIds.length; ++index) {
            var queuedTimeline = timelineForId(queuedTimelineIds[index])
            if (queuedTimeline)
                names.push(String(queuedTimeline.name || qsTr("未命名时间轴")))
        }
        return names.join("  →  ")
    }

    function toggleTimelineQueued(timelineId) {
        if (!timelineManager || !timelineStopped)
            return

        var ids = queuedTimelineIds.slice()
        var index = ids.indexOf(String(timelineId || ""))
        if (index >= 0)
            ids.splice(index, 1)
        else
            ids.push(String(timelineId || ""))
        timelineManager.setPlayQueue(ids)
    }

    function moveQueuedTimeline(timelineId, offset) {
        if (!timelineManager || !timelineStopped)
            return

        var ids = queuedTimelineIds.slice()
        var from = ids.indexOf(String(timelineId || ""))
        var to = from + offset
        if (from < 0 || to < 0 || to >= ids.length)
            return

        ids.splice(to, 0, ids.splice(from, 1)[0])
        timelineManager.setPlayQueue(ids)
    }

    function createTimeline(name) {
        if (!timelineManager || !timelineStopped || String(name || "").trim().length === 0)
            return -1
        var timeline = timelineManager.createTimeline(String(name).trim())
        return timeline ? timelineModel.count - 1 : -1
    }

    function removeTimeline(timeline) {
        if (!timelineManager || !timelineStopped || timelines.length <= 1 || !timeline)
            return
        timelineManager.removeTimeline(String(timeline.id || ""))
    }

    function selectTimeline(timeline) {
        if (!timelineManager || !timeline)
            return
        timelineManager.setCurrentTimelineId(String(timeline.id || ""))
    }

    function openTimelineControl(timeline) {
        selectTimeline(timeline)
        controlTrackVisible = true
        Qt.callLater(function() {
            if (timelineEditorLoader.item)
                timelineEditorLoader.item.positionControlTrackAtTime(
                    timelineEditorLoader.item.timelineCurrentTimeMs)
        })
    }

    function selectTimelineCommand(command) {
        if (timelineEditorLoader.item)
            timelineEditorLoader.item.selectTimelineCommand(command)
    }

    function editTimelineCommand(command) {
        if (timelineEditorLoader.item)
            timelineEditorLoader.item.editTimelineCommand(command)
    }

    function removeTimelineCommand(command) {
        if (timelineEditorLoader.item)
            timelineEditorLoader.item.requestRemoveTimelineCommand(command)
    }

    function seekOverviewAtX(positionX) {
        if (!timelineStopped || !timelineEditorLoader.item)
            return

        var timeMs = (overviewRuler.scrollX + positionX - overviewRuler.resolvedStartTimeX)
            / overviewRuler.safePixelsPerSecond * 1000
        var nextTimeMs = Math.max(0, Math.min(overviewDurationMs, Math.round(timeMs)))
        timelineEditorLoader.item.setTimelineCurrentTimeMs(nextTimeMs)
        if (controlTrackVisible)
            timelineEditorLoader.item.positionControlTrackAtTime(nextTimeMs)
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.pageTheme.density.panePaddingCompact
        spacing: root.pageTheme.density.controlGap

        Base.AppSurface {
            Layout.minimumWidth: 320
            Layout.preferredWidth: 360
            Layout.fillHeight: true
            sizeToContent: false
            surfaceTone: UiStyle.SurfaceTone.Surface

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true

                    Base.AppText {
                        Layout.fillWidth: true
                        text: qsTr("时间轴")
                        styleRole: UiStyle.TypographyRole.SectionTitle
                    }

                    Base.AppText {
                        text: qsTr("%1").arg(root.timelines.length)
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Secondary
                    }
                }

                Base.AppButton {
                    id: queueEditorButton

                    Layout.fillWidth: true
                    text: qsTr("播放顺序 · %1 项").arg(root.queuedTimelineCount)
                    iconName: "workflow"
                    contentAlignment: "start"
                    variant: root.queuedTimelineCount > 0
                        ? UiStyle.ButtonVariant.Tonal
                        : UiStyle.ButtonVariant.Ghost
                    onClicked: queueEditorPopup.opened
                        ? queueEditorPopup.close()
                        : queueEditorPopup.open()
                }

                Base.AppText {
                    visible: root.queuedTimelineCount > 0
                    Layout.fillWidth: true
                    text: root.queuePreviewText()
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    elide: Text.ElideRight
                }

                Base.AppSurface {
                    visible: root.runningTimelineCount > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? 42 : 0
                    sizeToContent: false
                    surfaceTone: UiStyle.SurfaceTone.SectionOverlay

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 7

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: root.pageTheme.colors.successFill
                        }

                        Base.AppText {
                            text: qsTr("正在运行 %1").arg(root.runningTimelineCount)
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Success
                        }

                        Base.AppText {
                            Layout.fillWidth: true
                            text: root.primaryRunningTimeline
                                ? qsTr("主序列：%1").arg(root.primaryRunningTimeline.name)
                                : qsTr("条件触发运行")
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                            elide: Text.ElideRight
                        }

                        Base.AppBadge {
                            visible: root.parallelRunningCount > 0
                            text: qsTr("并行 %1").arg(root.parallelRunningCount)
                            surfaceTone: UiStyle.SurfaceTone.Info
                            textTone: UiStyle.TextTone.Info
                        }
                    }
                }

                GridView {
                    id: timelineGrid

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    cellWidth: width
                    cellHeight: 206
                    model: root.timelines.length + 1
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Item {
                        id: timelineCell

                        readonly property bool addItem: index === root.timelines.length
                        readonly property var timeline: addItem ? null : root.timelines[index]

                        width: timelineGrid.cellWidth
                        height: timelineGrid.cellHeight

                        Timeline.TimelineCard {
                            anchors.fill: parent
                            visible: !timelineCell.addItem
                            timeline: timelineCell.timeline
                            displayIndex: index + 1
                            onOpenRequested: root.openTimelineControl(timelineCell.timeline)
                            onCloneRequested: cloneTimelinePopupLoader.openForTimeline(timelineCell.timeline)
                            onRemoveRequested: removeTimelinePopupLoader.openForTimeline(timelineCell.timeline)
                        }

                        Base.AppCard {
                            anchors.fill: parent
                            anchors.margins: 6
                            visible: timelineCell.addItem
                            text: qsTr("新建时间轴")
                            checkable: false
                            animateScale: false
                            enabled: root.timelineStopped
                            onClicked: createTimelinePopupLoader.openForCreate()

                            Base.AppText {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.Wrap
                                text: "+"
                                styleRole: UiStyle.TypographyRole.TitleL
                                textTone: UiStyle.TextTone.Accent
                            }
                        }
                    }
                }
            }
        }

        Loader {
            id: timelineEditorLoader

            visible: root.controlTrackVisible
            active: true
            source: "TimelineEditorPage.qml"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: visible ? 720 : 0
            onLoaded: item.controlTrackOnly = true
        }

        Connections {
            target: timelineEditorLoader.item

            function onCloseRequested() {
                root.controlTrackVisible = false
            }
        }

        Base.AppSurface {
            Layout.fillWidth: !root.controlTrackVisible
            Layout.fillHeight: true
            Layout.minimumWidth: 320
            Layout.preferredWidth: root.controlTrackVisible ? 400 : 760
            sizeToContent: false
            surfaceTone: UiStyle.SurfaceTone.Surface

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true

                    Base.AppText {
                        Layout.fillWidth: true
                        text: root.currentTimeline
                            ? String(root.currentTimeline.name || qsTr("未命名时间轴"))
                            : qsTr("时间轴")
                        styleRole: UiStyle.TypographyRole.SectionTitle
                        elide: Text.ElideRight
                    }

                    Base.AppText {
                        text: qsTr("%1 条指令").arg(root.timelineCommands.length)
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Secondary
                    }
                }

                Base.AppSurface {
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? 124 : 0
                    visible: !root.controlTrackVisible
                    sizeToContent: false
                    surfaceTone: UiStyle.SurfaceTone.Section

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44

                            Timeline.TimelineRuler {
                                id: overviewRuler

                                anchors.fill: parent
                                durationMs: root.overviewDurationMs
                                currentTimeMs: root.timelineCurrentTimeMs
                                scrollX: 0
                                trackLeftX: 0
                                startTimeX: 12
                                timeScale: maxTimeScale
                                dragEnabled: false
                                currentTimeDragEnabled: false
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.timelineStopped
                                cursorShape: pressed ? Qt.SizeHorCursor : Qt.PointingHandCursor
                                onPressed: root.seekOverviewAtX(mouse.x)
                                onPositionChanged: {
                                    if (pressed)
                                        root.seekOverviewAtX(mouse.x)
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.timelineStopped
                                cursorShape: pressed ? Qt.SizeHorCursor : Qt.PointingHandCursor
                                onPressed: root.seekOverviewAtX(mouse.x)
                                onPositionChanged: {
                                    if (pressed)
                                        root.seekOverviewAtX(mouse.x)
                                }
                            }

                            Timeline.TimelineCommandHorizontalList {
                                anchors.fill: parent
                                theme: root.pageTheme
                                ruler: overviewRuler
                                commands: root.timelineCommands
                                devices: root.devices
                                deviceIdFilter: ""
                                selectedCommandId: root.selectedTimelineCommandId
                                timelineOffsetX: 0
                                onCommandSelected: function(command) {
                                    root.selectTimelineCommand(command)
                                }
                            }

                            Rectangle {
                                x: Math.round(overviewRuler.currentTimeX)
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 1
                                color: root.pageTheme.colors.dangerFill
                                opacity: 0.7
                                visible: x >= 0 && x <= parent.width
                                z: 2
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Base.AppText {
                        Layout.fillWidth: true
                        text: qsTr("时间线指令")
                        styleRole: UiStyle.TypographyRole.BodyM
                    }

                    Base.AppText {
                        text: qsTr("%1").arg(verticalCommandList.count)
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Secondary
                    }
                }

                Base.AppSurface {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sizeToContent: false
                    surfaceTone: UiStyle.SurfaceTone.Section

                    Timeline.TimelineCommandVerticalList {
                        id: verticalCommandList

                        anchors.fill: parent
                        theme: root.pageTheme
                        commands: root.timelineCommands
                        devices: root.devices
                        deviceIdFilter: ""
                        selectedCommandId: root.selectedTimelineCommandId
                        editingEnabled: root.timelineStopped
                        showDeviceName: !root.controlTrackVisible
                        onCommandSelected: function(command) {
                            root.selectTimelineCommand(command)
                        }
                        onEditRequested: function(command) {
                            root.editTimelineCommand(command)
                        }
                        onRemoveRequested: function(command) {
                            root.removeTimelineCommand(command)
                        }
                    }
                }
            }
        }
    }

    Base.AppPopup {
        id: queueEditorPopup

        parent: root
        width: Math.min(360, root.width - 24)
        modal: false
        showModalOverlay: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onAboutToShow: {
            var position = queueEditorButton.mapToItem(root,
                                                       0,
                                                       queueEditorButton.height + 8)
            x = position.x
            y = position.y
        }

        RowLayout {
            Layout.fillWidth: true

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("播放顺序")
                styleRole: UiStyle.TypographyRole.SectionTitle
            }

            Base.AppButton {
                text: qsTr("清空")
                size: UiStyle.ButtonSize.Small
                variant: UiStyle.ButtonVariant.Ghost
                enabled: root.timelineStopped && root.queuedTimelineCount > 0
                onClicked: root.timelineManager.setPlayQueue([])
            }
        }

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("已选时间轴按编号顺序串行播放；条件触发的时间轴可以并行运行。")
            styleRole: UiStyle.TypographyRole.BodyS
            textTone: UiStyle.TextTone.Secondary
            wrapMode: Text.Wrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.pageTheme.colors.border
        }

        ListView {
            id: queueEditorList

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(280,
                Math.max(44, root.queueEditorTimelines.length * 42))
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.queueEditorTimelines
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: Item {
                readonly property var timelineData: modelData
                readonly property string timelineId: String(timelineData.id || "")
                readonly property int queueIndex: root.queuedTimelineIds.indexOf(timelineId)

                width: queueEditorList.width
                height: 42

                RowLayout {
                    anchors.fill: parent
                    spacing: 6

                    Base.AppBadge {
                        visible: queueIndex >= 0
                        Layout.preferredWidth: visible ? implicitWidth : 0
                        text: String(queueIndex + 1)
                        surfaceTone: UiStyle.SurfaceTone.Neutral
                        textTone: UiStyle.TextTone.Neutral
                    }

                    Base.AppCheckBox {
                        Layout.fillWidth: true
                        text: String(timelineData.name || qsTr("未命名时间轴"))
                        checked: queueIndex >= 0
                        enabled: root.timelineStopped
                        onClicked: root.toggleTimelineQueued(timelineId)
                    }

                    Base.AppButton {
                        visible: queueIndex >= 0
                        text: "↑"
                        size: UiStyle.ButtonSize.Small
                        minWidth: 28
                        variant: UiStyle.ButtonVariant.Ghost
                        enabled: root.timelineStopped && queueIndex > 0
                        onClicked: root.moveQueuedTimeline(timelineId, -1)
                    }

                    Base.AppButton {
                        visible: queueIndex >= 0
                        text: "↓"
                        size: UiStyle.ButtonSize.Small
                        minWidth: 28
                        variant: UiStyle.ButtonVariant.Ghost
                        enabled: root.timelineStopped
                            && queueIndex < root.queuedTimelineCount - 1
                        onClicked: root.moveQueuedTimeline(timelineId, 1)
                    }
                }
            }
        }
    }

    Loader {
        id: createTimelinePopupLoader

        active: false

        function openForCreate() {
            active = true
            item.openForCreate()
        }

        sourceComponent: Component {
            Base.AppDialog {
                id: createTimelinePopup
                parent: root
                onClosed: createTimelinePopupLoader.active = false

        property string timelineName: ""

        function openForCreate() {
            timelineName = qsTr("时间轴 %1").arg(root.timelines.length + 1)
            open()
            Qt.callLater(function() {
                createTimelineNameField.forceActiveFocus()
                createTimelineNameField.selectAll()
            })
        }

        function commit() {
            if (root.createTimeline(timelineName) >= 0)
                close()
        }

        width: Math.min(420, Math.max(320, parent ? parent.width - 96 : 380))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        title: qsTr("新建时间轴")
        rejectText: qsTr("取消")
        acceptText: qsTr("创建")
        acceptEnabled: timelineName.trim().length > 0
        initialFocusItem: createTimelineNameField
        closeOnAccepted: false
        onAccepted: commit()

        Base.AppTextField {
            id: createTimelineNameField

            Layout.fillWidth: true
            text: createTimelinePopup.timelineName
            placeholderText: qsTr("时间轴名称")
            onTextChanged: createTimelinePopup.timelineName = text
        }
            }
        }
    }

    Loader {
        id: cloneTimelinePopupLoader

        active: false

        function openForTimeline(timeline) {
            active = true
            item.openForTimeline(timeline)
        }

        sourceComponent: Component {
            Base.AppDialog {
                id: cloneTimelinePopup

                parent: root
                onClosed: cloneTimelinePopupLoader.active = false

                property var timelineData: null
                property string timelineName: ""

                function openForTimeline(timeline) {
                    timelineData = timeline
                    timelineName = qsTr("%1 副本").arg(timeline ? timeline.name : "")
                    open()
                    Qt.callLater(function() {
                        cloneTimelineNameField.forceActiveFocus()
                        cloneTimelineNameField.selectAll()
                    })
                }

                function commit() {
                    if (root.timelineManager && timelineData
                            && root.timelineManager.cloneTimeline(
                                String(timelineData.id || ""),
                                timelineName.trim()))
                        close()
                }

                width: Math.min(420, Math.max(320, parent ? parent.width - 96 : 380))
                x: parent ? Math.round((parent.width - width) / 2) : 0
                y: parent ? Math.round((parent.height - height) / 2) : 0
                title: qsTr("克隆时间轴")
                rejectText: qsTr("取消")
                acceptText: qsTr("克隆")
                acceptEnabled: root.timelineStopped && timelineName.trim().length > 0
                initialFocusItem: cloneTimelineNameField
                closeOnAccepted: false
                onAccepted: commit()

                Base.AppTextField {
                    id: cloneTimelineNameField

                    Layout.fillWidth: true
                    text: cloneTimelinePopup.timelineName
                    placeholderText: qsTr("时间轴名称")
                    onTextChanged: cloneTimelinePopup.timelineName = text
                }
            }
        }
    }

    Loader {
        id: removeTimelinePopupLoader

        active: false

        function openForTimeline(timeline) {
            active = true
            item.openForTimeline(timeline)
        }

        sourceComponent: Component {
            Base.AppDialog {
                id: removeTimelinePopup
                parent: root
                onClosed: removeTimelinePopupLoader.active = false

        property var timelineData: null

        function openForTimeline(timeline) {
            timelineData = timeline
            open()
        }

        function commit() {
            root.removeTimeline(timelineData)
        }

        width: Math.min(420, Math.max(320, parent ? parent.width - 96 : 380))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        title: qsTr("删除时间轴")
        message: qsTr("确定删除“%1”？其中的时间轴指令也会被删除。")
            .arg(removeTimelinePopup.timelineData ? removeTimelinePopup.timelineData.name : "")
        rejectText: qsTr("取消")
        acceptText: qsTr("删除")
        acceptButtonVariant: UiStyle.ButtonVariant.Danger
        onAccepted: commit()
            }
        }
    }
}
