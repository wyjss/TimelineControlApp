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
            for (var index = 0; index < timelineModel.count; ++index) {
                var timeline = timelineModel.timelineAt(index)
                items.push({
                    "id": timeline.id,
                    "name": timeline.name,
                    "index": index,
                    "timeline": timeline
                })
            }
        }
        timelines = items
    }

    function isTimelineQueued(timelineId) {
        return queueNumber(timelineId) > 0
    }

    function queueNumber(timelineId) {
        return queuedTimelineIds.indexOf(String(timelineId || "")) + 1
    }

    function timelineStateText(timeline) {
        switch (Number(timeline ? timeline.state : 0)) {
        case 1: return qsTr("等待中")
        case 2: return qsTr("运行中")
        case 3: return qsTr("已完成")
        default: return qsTr("已停止")
        }
    }

    function timelineStateSurfaceTone(timeline) {
        switch (Number(timeline ? timeline.state : 0)) {
        case 1: return UiStyle.SurfaceTone.Warning
        case 2: return UiStyle.SurfaceTone.Highlight
        case 3: return UiStyle.SurfaceTone.Success
        default: return UiStyle.SurfaceTone.Neutral
        }
    }

    function timelineStateTextTone(timeline) {
        switch (Number(timeline ? timeline.state : 0)) {
        case 1: return UiStyle.TextTone.Warning
        case 2: return UiStyle.TextTone.Accent
        case 3: return UiStyle.TextTone.Success
        default: return UiStyle.TextTone.Secondary
        }
    }

    function formatTimelineTime(ms) {
        var totalMs = Math.max(0, Math.round(Number(ms || 0)))
        var totalSeconds = Math.floor(totalMs / 1000)
        var hours = Math.floor(totalSeconds / 3600)
        var minutes = Math.floor(totalSeconds / 60) % 60
        var seconds = totalSeconds % 60
        var milliseconds = totalMs % 1000
        var timeText = (hours > 0 ? (hours < 10 ? "0" : "") + hours + ":" : "")
            + (minutes < 10 ? "0" : "") + minutes + ":"
            + (seconds < 10 ? "0" : "") + seconds + "."
        return timeText + (milliseconds < 10 ? "00" : (milliseconds < 100 ? "0" : ""))
            + milliseconds
    }

    function toggleTimelineQueued(timelineId) {
        if (!timelineManager)
            return

        var id = String(timelineId || "")
        var timelineIds = queuedTimelineIds.slice()
        var index = timelineIds.indexOf(id)
        if (index >= 0)
            timelineIds.splice(index, 1)
        else
            timelineIds.push(id)
        timelineManager.setPlayQueue(timelineIds)
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
        anchors.margins: root.pageTheme.density.panePadding
        spacing: root.pageTheme.density.paneSpacing

        Base.AppSurface {
            Layout.preferredWidth: 236
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

                Base.AppText {
                    visible: root.queuedTimelineCount > 0
                    Layout.fillWidth: true
                    text: qsTr("播放队列 %1 项").arg(root.queuedTimelineCount)
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Accent
                }

                GridView {
                    id: timelineGrid

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    cellWidth: width
                    cellHeight: 176
                    model: root.timelines.length + 1
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Item {
                        id: timelineCell

                        readonly property bool addItem: index === root.timelines.length
                        readonly property var timelineData: addItem ? null : root.timelines[index]
                        readonly property string timelineId: timelineData ? String(timelineData.id || "") : ""
                        readonly property bool queued: !addItem && root.isTimelineQueued(timelineId)
                        readonly property int queueNumber: root.queueNumber(timelineId)
                        readonly property bool current: !addItem
                            && root.currentTimeline === timelineData.timeline
                        readonly property var commandModel: !addItem
                            ? timelineData.timeline.commandModel
                            : null
                        readonly property int commandCount: commandModel && commandModel.commands
                            ? commandModel.commands.length
                            : 0
                        readonly property int realDurationMs: commandModel
                            ? Number(commandModel.realDurationMs || 0)
                            : 0
                        readonly property int currentTimeMs: !addItem
                            ? (current ? root.timelineCurrentTimeMs : Number(timelineData.timeline.currentTimeMs || 0))
                            : 0
                        readonly property bool playing: !addItem && timelineData.timeline.state === 2
                        readonly property bool completed: !addItem && timelineData.timeline.state === 3
                        readonly property real playProgress: completed
                            ? 1
                            : (realDurationMs > 0
                               ? Math.max(0, Math.min(1, currentTimeMs / realDurationMs))
                               : 0)

                        width: timelineGrid.cellWidth
                        height: timelineGrid.cellHeight

                        Base.AppCard {
                            id: timelineCard

                            anchors.fill: parent
                            anchors.margins: 6
                            text: timelineCell.addItem
                                ? qsTr("新建时间轴")
                                : String(timelineCell.timelineData.name || qsTr("未命名时间轴"))
                            checkable: false
                            checked: timelineCell.current
                            emphasizedSelection: true
                            animateScale: false
                            enabled: !timelineCell.addItem || root.timelineStopped
                            onCheckedChanged: {
                                if (checked !== timelineCell.current)
                                    checked = Qt.binding(function() { return timelineCell.current })
                            }
                            onClicked: {
                                if (timelineCell.addItem)
                                    createTimelinePopupLoader.openForCreate()
                                else
                                    root.selectTimeline(timelineCell.timelineData)
                            }
                            onDoubleClicked: {
                                if (!timelineCell.addItem)
                                    root.openTimelineControl(timelineCell.timelineData)
                            }

                            Base.AppText {
                                visible: timelineCell.addItem
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.Wrap
                                text: "+"
                                styleRole: UiStyle.TypographyRole.TitleL
                                textTone: UiStyle.TextTone.Accent
                            }

                            ColumnLayout {
                                visible: !timelineCell.addItem
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 7

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: String(timelineCell.timelineData
                                            && timelineCell.timelineData.name
                                            ? timelineCell.timelineData.name
                                            : qsTr("未命名时间轴"))
                                        styleRole: UiStyle.TypographyRole.TitleM
                                        textTone: UiStyle.TextTone.Primary
                                        elide: Text.ElideRight
                                    }

                                    Base.AppBadge {
                                        text: root.timelineStateText(timelineCell.timelineData
                                            ? timelineCell.timelineData.timeline
                                            : null)
                                        surfaceTone: root.timelineStateSurfaceTone(timelineCell.timelineData
                                            ? timelineCell.timelineData.timeline
                                            : null)
                                        textTone: root.timelineStateTextTone(timelineCell.timelineData
                                            ? timelineCell.timelineData.timeline
                                            : null)
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 5

                                    Base.AppText {
                                        text: root.formatTimelineTime(timelineCell.currentTimeMs)
                                        styleRole: UiStyle.TypographyRole.BodyM
                                        textTone: UiStyle.TextTone.Accent
                                    }

                                    Base.AppText {
                                        text: "/"
                                        styleRole: UiStyle.TypographyRole.BodyS
                                        textTone: UiStyle.TextTone.Secondary
                                    }

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: root.formatTimelineTime(timelineCell.realDurationMs)
                                        styleRole: UiStyle.TypographyRole.BodyS
                                        textTone: UiStyle.TextTone.Secondary
                                        elide: Text.ElideRight
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 6
                                    visible: timelineCell.timelineData
                                        && timelineCell.timelineData.timeline.state !== 0

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: height / 2
                                        color: root.pageTheme.colors.backgroundWindowVariant
                                    }

                                    Rectangle {
                                        width: parent.width * timelineCell.playProgress
                                        height: parent.height
                                        radius: height / 2
                                        color: timelineCell.completed
                                            ? root.pageTheme.colors.successFill
                                            : root.pageTheme.colors.highlightFill
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    color: root.pageTheme.colors.borderOverlay
                                    opacity: 0.55
                                }

                                Base.AppText {
                                    Layout.fillWidth: true
                                    Layout.rightMargin: timelineCell.queued || timelineCard.hovered ? 58 : 0
                                    text: timelineCell.queued
                                        ? qsTr("%1 条指令 · 播放队列 %2")
                                            .arg(timelineCell.commandCount)
                                            .arg(timelineCell.queueNumber)
                                        : qsTr("%1 条指令").arg(timelineCell.commandCount)
                                    styleRole: UiStyle.TypographyRole.BodyS
                                    textTone: UiStyle.TextTone.Secondary
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Base.AppButton {
                            z: 2
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.bottomMargin: 12
                            anchors.rightMargin: 42
                            width: 28
                            height: 28
                            visible: !timelineCell.addItem && (timelineCard.hovered || hovered)
                            text: "×"
                            size: UiStyle.ButtonSize.Small
                            minWidth: 28
                            variant: UiStyle.ButtonVariant.Danger
                            enabled: root.timelineStopped && root.timelines.length > 1
                            opacity: enabled ? 1 : 0.35
                            onClicked: removeTimelinePopupLoader.openForTimeline(timelineCell.timelineData)
                        }

                        Item {
                            z: 2
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: 14
                            anchors.bottomMargin: 14
                            width: 22
                            height: 22
                            visible: !timelineCell.addItem
                                && (timelineCard.hovered || queueTimelineMouse.containsMouse || timelineCell.queued)

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: timelineCell.queued
                                    ? root.pageTheme.colors.highlightFill
                                    : root.pageTheme.colors.disabledFill
                                border.width: 1
                                border.color: timelineCell.queued
                                    ? root.pageTheme.colors.highlightText
                                    : root.pageTheme.colors.controlBorder
                            }

                            Base.AppText {
                                anchors.centerIn: parent
                                visible: timelineCell.queued
                                text: String(timelineCell.queueNumber)
                                styleRole: UiStyle.TypographyRole.BodyS
                                colorOverride: root.pageTheme.colors.inverseText
                            }

                            MouseArea {
                                id: queueTimelineMouse

                                anchors.fill: parent
                                enabled: root.timelineStopped
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleTimelineQueued(timelineCell.timelineId)
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
                    Layout.preferredHeight: 124
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
