import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base

Base.AppSurface {
    id: root
    objectName: "timelinePlayQueue"

    property QtObject theme: null
    property var timelineManager: null
    property var timelines: []
    property bool expanded: true
    readonly property int playbackState: timelineManager ? timelineManager.playbackState : 0
    readonly property bool queuePlayback: !!timelineManager && !!timelineManager.queuePlayback
    readonly property int activeIndex: timelineManager ? timelineManager.playQueueIndex : -1
    readonly property bool stopped: playbackState === 0
    readonly property bool running: queuePlayback && playbackState === 1
    readonly property bool paused: queuePlayback && playbackState === 2
    readonly property string stateText: running ? qsTr("播放中")
        : (paused ? qsTr("已暂停") : (queuePlayback && playbackState === 3 ? qsTr("已完成") : qsTr("待播放")))
    readonly property real totalDurationMs: {
        var duration = 0
        for (var index = 0; index < timelines.length; ++index)
            duration += Number(timelines[index].commandModel
                ? timelines[index].commandModel.realDurationMs : timelines[index].durationMs || 0)
        return duration
    }

    signal editRequested()
    signal removeRequested(string timelineId)
    signal moveRequested(string timelineId, int offset)

    implicitHeight: content.implicitHeight + 24
    sizeToContent: false
    surfaceTone: UiStyle.SurfaceTone.Surface

    function formatDuration(ms) {
        var seconds = Math.max(0, Math.floor(Number(ms || 0) / 1000))
        var hours = Math.floor(seconds / 3600)
        var minutes = Math.floor(seconds / 60) % 60
        return (hours > 0 ? (hours < 10 ? "0" : "") + hours + ":" : "")
            + (minutes < 10 ? "0" : "") + minutes + ":"
            + (seconds % 60 < 10 ? "0" : "") + seconds % 60
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("播放队列")
                styleRole: UiStyle.TypographyRole.SectionTitle
            }
            Base.AppText {
                text: qsTr("%1 项").arg(root.timelines.length)
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }
            Base.AppButton {
                objectName: "queueExpandButton"
                text: root.expanded ? "⌃" : "⌄"
                size: UiStyle.ButtonSize.Small
                minWidth: 28
                variant: UiStyle.ButtonVariant.Ghost
                Accessible.name: root.expanded ? qsTr("收起队列") : qsTr("展开队列")
                ToolTip.visible: hovered
                ToolTip.text: Accessible.name
                onClicked: root.expanded = !root.expanded
            }
            Base.AppButton {
                objectName: "queueMenuButton"
                text: "⋮"
                size: UiStyle.ButtonSize.Small
                minWidth: 28
                variant: UiStyle.ButtonVariant.Ghost
                Accessible.name: qsTr("队列操作")
                onClicked: queueMenu.popup()

                Menu {
                    id: queueMenu
                    objectName: "queueMenu"
                    MenuItem {
                        text: qsTr("编排队列")
                        enabled: root.stopped
                        onTriggered: root.editRequested()
                    }
                    MenuItem {
                        text: qsTr("清空队列")
                        enabled: root.stopped
                        onTriggered: root.timelineManager.setPlayQueue([])
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Base.AppText {
                objectName: "queueStateLabel"
                Layout.fillWidth: true
                text: root.stateText
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: root.running ? UiStyle.TextTone.Success
                    : (root.paused ? UiStyle.TextTone.Warning : UiStyle.TextTone.Secondary)
                elide: Text.ElideRight
            }
            Base.AppButton {
                objectName: "queuePlayButton"
                text: root.running ? qsTr("暂停")
                    : (root.paused ? qsTr("继续播放") : qsTr("播放队列"))
                iconName: root.running ? "pause" : "play"
                size: UiStyle.ButtonSize.Small
                variant: UiStyle.ButtonVariant.Primary
                enabled: !!root.timelineManager && root.timelines.length > 0
                    && (root.queuePlayback || root.stopped || root.playbackState === 3)
                onClicked: {
                    if (root.running)
                        root.timelineManager.pausePlayback()
                    else if (root.paused)
                        root.timelineManager.resumePlayback()
                    else
                        root.timelineManager.startPlayback(root.timelineManager.playQueue, 0)
                }
            }
            Base.AppButton {
                objectName: "queueStopButton"
                text: qsTr("停止")
                size: UiStyle.ButtonSize.Small
                variant: UiStyle.ButtonVariant.Secondary
                enabled: root.queuePlayback && !root.stopped
                ToolTip.visible: hovered
                ToolTip.text: qsTr("停止本次播放及其触发节目，保留队列")
                onClicked: root.timelineManager.stopPlayback()
            }
        }

        Base.AppText {
            objectName: "queueCurrentLabel"
            Layout.fillWidth: true
            visible: root.activeIndex >= 0 && root.activeIndex < root.timelines.length
            text: visible ? qsTr("%1 / %2 · %3").arg(root.activeIndex + 1)
                .arg(root.timelines.length).arg(root.timelines[root.activeIndex].name) : ""
            styleRole: UiStyle.TypographyRole.BodyS
            textTone: UiStyle.TextTone.Secondary
            elide: Text.ElideRight
        }

        ListView {
            id: queueList
            objectName: "playQueueList"
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(3, count) * 44
            visible: root.expanded
            model: root.timelines
            currentIndex: root.activeIndex
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: {
                if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain)
            }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Item {
                id: queueRow
                readonly property bool active: index === root.activeIndex
                width: queueList.width
                height: 44

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    radius: root.theme.shape.controlRadius
                    color: queueRow.active ? root.theme.colors.highlightSoft
                        : root.theme.colors.backgroundSection
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 6
                    spacing: 6

                    Base.AppText {
                        Layout.preferredWidth: 22
                        text: String(index + 1)
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: queueRow.active ? UiStyle.TextTone.Accent : UiStyle.TextTone.Secondary
                    }
                    Base.AppText {
                        objectName: "queueItemName_" + index
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: String(modelData.name || qsTr("未命名时间轴"))
                        styleRole: UiStyle.TypographyRole.BodyS
                        elide: Text.ElideRight
                        ToolTip.visible: nameHover.hovered
                        ToolTip.text: text
                        HoverHandler { id: nameHover }
                    }
                    Base.AppText {
                        text: queueRow.active ? root.stateText
                            : (root.queuePlayback && !root.stopped && modelData.state === 3 ? qsTr("已完成")
                               : root.formatDuration(modelData.commandModel
                                   ? modelData.commandModel.realDurationMs : modelData.durationMs))
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: queueRow.active ? UiStyle.TextTone.Accent : UiStyle.TextTone.Secondary
                    }
                    Base.AppButton {
                        objectName: "queueItemMenuButton_" + index
                        text: "⋮"
                        size: UiStyle.ButtonSize.Small
                        minWidth: 28
                        variant: UiStyle.ButtonVariant.Ghost
                        Accessible.name: qsTr("%1 的队列操作").arg(modelData.name)
                        onClicked: itemMenu.popup()

                        Menu {
                            id: itemMenu
                            objectName: "queueItemMenu_" + index
                            MenuItem {
                                text: qsTr("上移")
                                enabled: root.stopped && index > 0
                                onTriggered: root.moveRequested(modelData.id, -1)
                            }
                            MenuItem {
                                text: qsTr("下移")
                                enabled: root.stopped && index < root.timelines.length - 1
                                onTriggered: root.moveRequested(modelData.id, 1)
                            }
                            MenuItem {
                                text: qsTr("移出队列")
                                enabled: root.stopped
                                onTriggered: root.removeRequested(modelData.id)
                            }
                        }
                    }
                }
            }
        }

        Base.AppText {
            Layout.fillWidth: true
            visible: root.expanded
            text: qsTr("按顺序播放 · 总时长 %1").arg(root.formatDuration(root.totalDurationMs))
            styleRole: UiStyle.TypographyRole.BodyS
            textTone: UiStyle.TextTone.Secondary
            elide: Text.ElideRight
        }
    }
}
