import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/theme" as Theme

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
    property var timelines: []
    readonly property bool timelineStopped: !timelineManager || timelineManager.playbackState === 0
    readonly property var queuedTimelineIds: timelineManager
        ? timelineManager.playQueue
        : []
    readonly property int queuedTimelineCount: queuedTimelineIds.length
    readonly property bool editing: ApplicationWindow.window
        ? ApplicationWindow.window.timelineEditing
        : false


    Connections {
        target: root.timelineManager
        function onCurrentTimelineChanged() {
            editorTimelineSelector.value = root.timelineManager.currentTimeline
                ? root.timelineManager.currentTimeline.id
                : ""
        }
    }

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

    function editTimeline(timeline) {
        if (!timelineManager || !timeline)
            return
        if (!timelineManager.setCurrentTimelineId(String(timeline.id || "")))
            return

        if (ApplicationWindow.window)
            ApplicationWindow.window.timelineEditing = true
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: root.editing ? 1 : 0

        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.pageTheme.density.panePadding
                spacing: 10

                Base.AppText {
                    visible: root.queuedTimelineCount > 0
                    Layout.alignment: Qt.AlignRight
                    text: qsTr("已选 %1 项").arg(root.queuedTimelineCount)
                    styleRole: UiStyle.TypographyRole.BodyM
                    textTone: UiStyle.TextTone.Accent
                }

                GridView {
                    id: timelineGrid

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    cellWidth: 190
                    cellHeight: 190
                    model: root.timelines.length + 1
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Item {
                        id: timelineCell

                        readonly property bool addItem: index === root.timelines.length
                        readonly property var timelineData: addItem ? null : root.timelines[index]
                        readonly property string timelineId: timelineData ? String(timelineData.id || "") : ""
                        readonly property bool checked: !addItem && root.isTimelineQueued(timelineId)
                        readonly property int queueNumber: root.queueNumber(timelineId)
                        readonly property bool current: !addItem
                            && root.timelineManager
                            && root.timelineManager.currentTimeline === timelineData.timeline
                        readonly property bool playing: !addItem && timelineData.timeline.state === 2
                        readonly property bool completed: !addItem && timelineData.timeline.state === 3
                        readonly property real playProgress: completed
                            ? 1
                            : (playing && timelineData.timeline.durationMs > 0
                               ? Math.max(0, Math.min(1, timelineData.timeline.currentTimeMs
                                                     / timelineData.timeline.durationMs))
                               : 0)

                        width: timelineGrid.cellWidth
                        height: timelineGrid.cellHeight

                        Base.AppCard {
                            id: timelineCard

                            anchors.fill: parent
                            anchors.margins: 8
                            text: timelineCell.addItem
                                ? qsTr("新建时间轴")
                                : String(timelineCell.timelineData.name || qsTr("未命名时间轴"))
                            checkable: false
                            checked: timelineCell.checked
                            emphasizedSelection: true
                            enabled: !timelineCell.addItem || root.timelineStopped
                            onCheckedChanged: {
                                if (checked !== timelineCell.checked)
                                    checked = Qt.binding(function() { return timelineCell.checked })
                            }
                            onClicked: {
                                if (timelineCell.addItem)
                                    createTimelinePopupLoader.openForCreate()
                                else
                                    root.editTimeline(timelineCell.timelineData)
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.Wrap
                                text: timelineCell.addItem ? "+" : String(timelineCell.timelineData.name || qsTr("未命名时间轴"))
                                styleRole: timelineCell.addItem ? UiStyle.TypographyRole.TitleL : UiStyle.TypographyRole.TitleM
                                textTone: timelineCell.addItem ? UiStyle.TextTone.Accent : UiStyle.TextTone.Primary
                            }
                        }

                        Item {
                            z: 2
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            anchors.bottomMargin: 10
                            height: 4
                            visible: timelineCell.playing || timelineCell.completed

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: root.pageTheme.colors.backgroundWindowVariant
                            }

                            Rectangle {
                                width: parent.width * timelineCell.playProgress
                                height: parent.height
                                radius: height / 2
                                color: root.pageTheme.colors.highlightFill
                            }
                        }

                        Base.AppButton {
                            variant: UiStyle.ButtonVariant.Danger
                            z: 2
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 14
                            anchors.rightMargin: 14
                            width: 28
                            height: 28
                            visible: !timelineCell.addItem && (timelineCard.hovered || hovered)
                            text: "×"
                            size: UiStyle.ButtonSize.Small
                            minWidth: 28
                            enabled: root.timelineStopped && root.timelines.length > 1
                            opacity: enabled ? 1 : 0.35
                            onClicked: removeTimelinePopupLoader.openForTimeline(timelineCell.timelineData)
                        }

                        Item {
                            z: 2
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: 16
                            anchors.bottomMargin: 16
                            width: 22
                            height: 22
                            visible: !timelineCell.addItem
                                && (timelineCard.hovered || queueTimelineMouse.containsMouse || timelineCell.checked)

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: timelineCell.checked
                                    ? root.pageTheme.colors.highlightFill
                                    : root.pageTheme.colors.disabledFill
                                border.width: 1
                                border.color: timelineCell.checked
                                    ? root.pageTheme.colors.highlightText
                                    : root.pageTheme.colors.controlBorder
                            }

                            Base.AppText {
                                anchors.centerIn: parent
                                visible: timelineCell.checked
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

        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        spacing: 12

                        Base.AppButton {
                            Layout.preferredWidth: 36
                            variant: UiStyle.ButtonVariant.Ghost
                            iconSymbol: "←"
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("返回")
                            onClicked: {
                                if (ApplicationWindow.window)
                                    ApplicationWindow.window.timelineEditing = false
                            }
                        }

                        Base.AppSelect {
                            id: editorTimelineSelector

                            Layout.preferredWidth: 210
                            options: root.timelines
                            textRole: "name"
                            valueRole: "id"
                            value: root.timelineManager && root.timelineManager.currentTimeline
                                ? root.timelineManager.currentTimeline.id
                                : ""
                            enabled: root.timelineManager !== null && root.timelineStopped
                            onValueSelected: {
                                if (root.timelineManager)
                                    root.timelineManager.setCurrentTimelineId(String(nextValue))
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: root.editing
                    source: "TimelineEditorPage.qml"
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
