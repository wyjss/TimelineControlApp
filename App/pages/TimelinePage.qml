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
            for (var index = 0; index < timelineModel.count; ++index)
                items.push(timelineModel.timelineAt(index))
        }
        timelines = items
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
                        readonly property var timeline: addItem ? null : root.timelines[index]

                        width: timelineGrid.cellWidth
                        height: timelineGrid.cellHeight

                        Timeline.TimelineCard {
                            anchors.fill: parent
                            visible: !timelineCell.addItem
                            timeline: timelineCell.timeline
                            onOpenRequested: root.openTimelineControl(timelineCell.timeline)
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
