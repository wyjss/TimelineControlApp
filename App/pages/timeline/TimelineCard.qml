import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/theme" as Theme

Item {
    id: root

    property var timeline: null

    signal openRequested()
    signal removeRequested()

    Theme.AppTheme {
        id: fallbackTheme
    }


    property QtObject appTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : fallbackTheme
    readonly property var appRuntime: typeof app !== "undefined" ? app : null
    readonly property var timelineManager: appRuntime && appRuntime.timelineManager
        ? appRuntime.timelineManager
        : null
    readonly property var commandModel: timeline ? timeline.commandModel : null
    readonly property var queuedTimelineIds: timelineManager ? timelineManager.playQueue : []
    readonly property string timelineId: timeline ? String(timeline.id || "") : ""
    readonly property bool current: timelineManager && timelineManager.currentTimeline === timeline
    readonly property bool stopped: !timelineManager || timelineManager.playbackState === 0
    readonly property bool queued: queueNumber > 0
    readonly property bool completed: timeline && timeline.state === 3
    readonly property int queueNumber: queuedTimelineIds.indexOf(timelineId) + 1
    readonly property int commandCount: commandModel && commandModel.commands
        ? commandModel.commands.length
        : 0
    readonly property int realDurationMs: commandModel
        ? Number(commandModel.realDurationMs || 0)
        : 0
    readonly property int currentTimeMs: timeline ? Number(timeline.currentTimeMs || 0) : 0
    readonly property real playProgress: completed
        ? 1
        : (realDurationMs > 0
           ? Math.max(0, Math.min(1, currentTimeMs / realDurationMs))
           : 0)

    function stateText() {
        switch (Number(timeline ? timeline.state : 0)) {
        case 1: return qsTr("等待中")
        case 2: return qsTr("运行中")
        case 3: return qsTr("已完成")
        default: return qsTr("已停止")
        }
    }

    function stateSurfaceTone() {
        switch (Number(timeline ? timeline.state : 0)) {
        case 1: return UiStyle.SurfaceTone.Warning
        case 2: return UiStyle.SurfaceTone.Highlight
        case 3: return UiStyle.SurfaceTone.Success
        default: return UiStyle.SurfaceTone.Neutral
        }
    }

    function stateTextTone() {
        switch (Number(timeline ? timeline.state : 0)) {
        case 1: return UiStyle.TextTone.Warning
        case 2: return UiStyle.TextTone.Accent
        case 3: return UiStyle.TextTone.Success
        default: return UiStyle.TextTone.Secondary
        }
    }

    function formatTime(ms) {
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

    function selectTimeline() {
        if (timelineManager && timeline)
            timelineManager.setCurrentTimelineId(timelineId)
    }

    function toggleQueued() {
        if (!timelineManager || !timeline)
            return

        var timelineIds = queuedTimelineIds.slice()
        var index = timelineIds.indexOf(timelineId)
        if (index >= 0)
            timelineIds.splice(index, 1)
        else
            timelineIds.push(timelineId)
        timelineManager.setPlayQueue(timelineIds)
    }

    Base.AppCard {
        id: timelineCard

        anchors.fill: parent
        anchors.margins: 6
        text: root.timeline && root.timeline.name
            ? String(root.timeline.name)
            : qsTr("未命名时间轴")
        checkable: false
        checked: root.current
        emphasizedSelection: true
        animateScale: false
        enabled: root.timeline !== null
        onCheckedChanged: {
            if (checked !== root.current)
                checked = Qt.binding(function() { return root.current })
        }
        onClicked: root.selectTimeline()
        onDoubleClicked: {
            root.selectTimeline()
            root.openRequested()
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 7

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Base.AppText {
                    Layout.fillWidth: true
                    text: timelineCard.text
                    styleRole: UiStyle.TypographyRole.TitleM
                    textTone: UiStyle.TextTone.Primary
                    elide: Text.ElideRight
                }

                Base.AppBadge {
                    text: root.stateText()
                    surfaceTone: root.stateSurfaceTone()
                    textTone: root.stateTextTone()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                Base.AppText {
                    text: root.formatTime(root.currentTimeMs)
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
                    text: root.formatTime(root.realDurationMs)
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    elide: Text.ElideRight
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                visible: root.timeline && root.timeline.state !== 0

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root.appTheme.colors.backgroundWindowVariant
                }

                Rectangle {
                    width: parent.width * root.playProgress
                    height: parent.height
                    radius: height / 2
                    color: root.completed
                        ? root.appTheme.colors.successFill
                        : root.appTheme.colors.highlightFill
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.appTheme.colors.borderOverlay
                opacity: 0.55
            }

            Base.AppText {
                Layout.fillWidth: true
                Layout.rightMargin: root.queued || timelineCard.hovered ? 58 : 0
                text: root.queued
                    ? qsTr("%1 条指令 · 播放队列 %2")
                        .arg(root.commandCount)
                        .arg(root.queueNumber)
                    : qsTr("%1 条指令").arg(root.commandCount)
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
        visible: timelineCard.hovered || hovered
        text: "×"
        size: UiStyle.ButtonSize.Small
        minWidth: 28
        variant: UiStyle.ButtonVariant.Danger
        enabled: root.stopped && root.timelineManager && root.timelineManager.timelineModel.count > 1
        opacity: enabled ? 1 : 0.35
        onClicked: root.removeRequested()
    }

    Item {
        z: 2
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 14
        anchors.bottomMargin: 14
        width: 22
        height: 22
        visible: timelineCard.hovered || queueTimelineMouse.containsMouse || root.queued

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: root.queued
                ? root.appTheme.colors.highlightFill
                : root.appTheme.colors.disabledFill
            border.width: 1
            border.color: root.queued
                ? root.appTheme.colors.highlightText
                : root.appTheme.colors.controlBorder
        }

        Base.AppText {
            anchors.centerIn: parent
            visible: root.queued
            text: String(root.queueNumber)
            styleRole: UiStyle.TypographyRole.BodyS
            colorOverride: root.appTheme.colors.inverseText
        }

        MouseArea {
            id: queueTimelineMouse

            anchors.fill: parent
            enabled: root.stopped
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleQueued()
        }
    }
}
