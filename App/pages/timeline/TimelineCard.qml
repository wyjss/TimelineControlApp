import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/theme" as Theme

Item {
    id: root

    property var timeline: null
    property int displayIndex: 0

    signal openRequested()
    signal cloneRequested()
    signal removeRequested()
    signal queueRequested()

    Theme.AppTheme {
        id: fallbackTheme
    }


    property QtObject appTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : fallbackTheme
    readonly property var appRuntime: typeof app !== "undefined" ? app : null
    property var timelineManager: appRuntime && appRuntime.timelineManager
        ? appRuntime.timelineManager
        : null
    readonly property var timelineModel: timelineManager ? timelineManager.timelineModel : null
    readonly property var deviceModel: appRuntime && appRuntime.deviceModel
        ? appRuntime.deviceModel
        : null
    readonly property var commandModel: timeline ? timeline.commandModel : null
    readonly property string timelineId: timeline ? String(timeline.id || "") : ""
    readonly property bool current: timelineManager && timelineManager.currentTimeline === timeline
    readonly property bool stopped: !timelineManager || timelineManager.playbackState === 0
    readonly property bool queued: timelineManager && timelineManager.playQueue
        ? timelineManager.playQueue.indexOf(timelineId) >= 0 : false
    readonly property bool waiting: timeline && timeline.state === 1
    readonly property bool running: timeline && timeline.state === 2
    readonly property bool completed: timeline && timeline.state === 3
    readonly property int realDurationMs: commandModel
        ? Number(commandModel.realDurationMs || 0)
        : 0
    readonly property var commands: commandModel && commandModel.commands
        ? commandModel.commands
        : []
    readonly property int remainingCommandCount: countCommandsByState(0)
    readonly property int failedCommandCount: countCommandsByState(3)
    readonly property int currentTimeMs: timeline ? Number(timeline.currentTimeMs || 0) : 0
    readonly property real playProgress: completed
        ? 1
        : (realDurationMs > 0
           ? Math.max(0, Math.min(1, currentTimeMs / realDurationMs))
           : 0)
    readonly property color stateAccentColor: waiting
        ? appTheme.colors.warningText
        : (running
            ? appTheme.colors.successText
            : (completed
                ? appTheme.colors.infoText
                : appTheme.colors.neutralText))
    readonly property color stateBorderColor: waiting
        ? appTheme.colors.warningBorder
        : (running
            ? appTheme.colors.successBorder
            : (completed
                ? appTheme.colors.infoBorder
                : appTheme.colors.controlBorder))
    readonly property color stateSoftColor: waiting
        ? appTheme.colors.warningSoft
        : (running
            ? appTheme.colors.successSoft
            : (completed
                ? appTheme.colors.infoSoft
                : appTheme.colors.neutralSoft))
    readonly property var triggerSourceInfo: resolveTriggerSource()

    function stateText() {
        switch (Number(timeline ? timeline.state : 0)) {
        case 1: return qsTr("待触发")
        case 2: return qsTr("运行中")
        case 3: return qsTr("已完成")
        default: return qsTr("已停止")
        }
    }

    function stateSurfaceTone() {
        switch (Number(timeline ? timeline.state : 0)) {
        case 1: return UiStyle.SurfaceTone.Warning
        case 2: return UiStyle.SurfaceTone.Success
        case 3: return UiStyle.SurfaceTone.Info
        default: return UiStyle.SurfaceTone.Neutral
        }
    }

    function stateTextTone() {
        switch (Number(timeline ? timeline.state : 0)) {
        case 1: return UiStyle.TextTone.Warning
        case 2: return UiStyle.TextTone.Success
        case 3: return UiStyle.TextTone.Info
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
        var timeText = (hours < 10 ? "0" : "") + hours + ":"
            + (minutes < 10 ? "0" : "") + minutes + ":"
            + (seconds < 10 ? "0" : "") + seconds + "."
        return timeText + (milliseconds < 10 ? "00" : (milliseconds < 100 ? "0" : ""))
            + milliseconds
    }

    function countCommandsByState(state) {
        var count = 0
        for (var index = 0; index < commands.length; ++index) {
            if (Number(commands[index].state) === state)
                ++count
        }
        return count
    }

    function deviceName(id) {
        var devices = deviceModel ? deviceModel.devices : []
        for (var index = 0; index < devices.length; ++index) {
            if (String(devices[index].id || "") === String(id || ""))
                return String(devices[index].name || id)
        }
        return String(id || "")
    }

    function resolveTriggerSource() {
        var count = 0
        var locatorName = ""
        if (timelineModel) {
            for (var timelineIndex = 0; timelineIndex < timelineModel.count; ++timelineIndex) {
                var sourceTimeline = timelineModel.timelineAt(timelineIndex)
                var conditions = sourceTimeline ? sourceTimeline.crossConditionModel : null
                if (!conditions)
                    continue

                for (var conditionIndex = 0; conditionIndex < conditions.count; ++conditionIndex) {
                    var condition = conditions.conditionAt(conditionIndex)
                    if (!condition || !condition.enabled
                            || String(condition.timeline || "") !== timelineId)
                        continue

                    ++count
                    if (locatorName.length === 0)
                        locatorName = deviceName(condition.locator)
                }
            }
        }

        if (count > 0) {
            return {
                "icon": "ϟ",
                "text": count === 1
                    ? qsTr("定位器 %1 · 过点触发").arg(locatorName)
                    : qsTr("定位器过点 · %1 条规则").arg(count)
            }
        }
        return {
            "icon": "—",
            "text": qsTr("未配置")
        }
    }

    function selectTimeline() {
        if (timelineManager && timeline)
            timelineManager.setCurrentTimelineId(timelineId)
    }

    Base.AppCard {
        id: timelineCard

        anchors.fill: parent
        anchors.margins: 5
        text: root.timeline && root.timeline.name
            ? String(root.timeline.name)
            : qsTr("未命名时间轴")
        surfaceTone: UiStyle.SurfaceTone.Section
        compact: true
        topPadding: root.queued ? queueBadge.height + 4 : padding
        surfaceOpacityScale: 1
        checkable: false
        checked: root.current
        emphasizedSelection: false
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
            spacing: root.appTheme.density.controlGap

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Base.AppSurface {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    sizeToContent: false
                    shapeRole: UiStyle.ShapeRole.Control
                    fillOverride: root.stateSoftColor
                    borderOverride: root.stateBorderColor

                    Base.AppText {
                        anchors.centerIn: parent
                        text: String(root.displayIndex)
                        styleRole: UiStyle.TypographyRole.SectionTitle
                        colorOverride: root.stateAccentColor
                    }
                }

                Base.AppText {
                    Layout.fillWidth: true
                    text: timelineCard.text
                    styleRole: UiStyle.TypographyRole.SectionTitle
                    elide: Text.ElideRight
                }

                Base.AppBadge {
                    text: root.stateText()
                    surfaceTone: root.stateSurfaceTone()
                    textTone: root.stateTextTone()
                    shapeRole: UiStyle.ShapeRole.Control
                    strokeWidth: 1
                }

                Base.AppButton {
                    objectName: "addTimelineToQueue_" + root.timelineId
                    visible: root.current && root.stopped
                    text: root.queued ? qsTr("移除队列") : qsTr("加入队列")
                    size: UiStyle.ButtonSize.Small
                    variant: UiStyle.ButtonVariant.Tonal
                    onClicked: root.queueRequested()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Base.AppText {
                    text: root.formatTime(root.currentTimeMs)
                    familyOverride: root.appTheme.typography.familyMono
                    styleRole: UiStyle.TypographyRole.BodyL
                    overrideWeight: Font.Medium
                    colorOverride: root.running
                        ? root.appTheme.colors.successText
                        : (root.completed
                            ? root.appTheme.colors.infoText
                            : root.appTheme.colors.subtleText)
                }

                Base.AppText {
                    text: "/"
                    familyOverride: root.appTheme.typography.familyMono
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                }

                Base.AppText {
                    Layout.fillWidth: true
                    text: root.formatTime(root.realDurationMs)
                    familyOverride: root.appTheme.typography.familyMono
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    elide: Text.ElideRight
                }

                RowLayout {
                    visible: root.timeline && Number(root.timeline.state) !== 0
                    spacing: 10

                    Base.AppText {
                        text: qsTr("剩余 %1").arg(root.remainingCommandCount)
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Secondary
                    }

                    Base.AppText {
                        visible: root.failedCommandCount > 0
                        text: qsTr("错误 %1").arg(root.failedCommandCount)
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Danger
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 9

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root.appTheme.colors.backgroundControl
                    border.width: 1
                    border.color: root.appTheme.colors.controlBorder
                }

                Rectangle {
                    width: parent.width * root.playProgress
                    height: parent.height
                    radius: height / 2
                    color: root.completed
                        ? root.appTheme.colors.infoText
                        : (root.running
                            ? root.appTheme.colors.successFill
                            : root.appTheme.colors.highlightFill)

                    Behavior on width {
                        NumberAnimation {
                            duration: root.appTheme.motion.durationFast
                            easing.type: root.appTheme.motion.easingStandard
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.appTheme.colors.borderOverlay
                visible: root.current
            }

            RowLayout {
                visible: root.current
                Layout.fillWidth: true
                spacing: 7

                Base.AppText {
                    text: root.triggerSourceInfo.icon
                    overridePixelSize: 18
                    colorOverride: root.stateAccentColor
                }

                Base.AppText {
                    text: qsTr("外部触发：")
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                }

                Base.AppText {
                    Layout.fillWidth: true
                    text: root.triggerSourceInfo.text
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    elide: Text.ElideRight
                }

                Base.AppButton {
                    text: "⋮"
                    size: UiStyle.ButtonSize.Small
                    minWidth: 28
                    variant: UiStyle.ButtonVariant.Ghost
                    opacity: timelineCard.hovered || hovered ? 1 : 0.35
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("更多操作")
                    onClicked: timelineMenu.popup()

                    Menu {
                        id: timelineMenu

                        MenuItem {
                            visible: root.waiting
                            height: visible ? implicitHeight : 0
                            text: qsTr("立即触发")
                            onTriggered: root.timelineManager.triggerTimeline(root.timelineId)
                        }

                        MenuSeparator {
                            visible: root.waiting
                            height: visible ? implicitHeight : 0
                        }

                        MenuItem {
                            text: qsTr("克隆")
                            enabled: root.stopped && root.timelineManager
                            onTriggered: root.cloneRequested()
                        }

                        MenuSeparator {}

                        MenuItem {
                            text: qsTr("删除")
                            enabled: root.stopped && root.timelineManager
                                && root.timelineManager.timelineModel.count > 1
                            onTriggered: root.removeRequested()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: queueBadge
        objectName: "timelineQueueBadge_" + root.timelineId
        anchors.top: timelineCard.top
        anchors.right: timelineCard.right
        anchors.topMargin: 1
        anchors.rightMargin: 1
        z: 2
        visible: root.queued
        width: queueBadgeText.implicitWidth + 14
        height: 20
        radius: root.appTheme.shape.sectionRadius
        color: root.appTheme.colors.highlightFill
        Accessible.role: Accessible.StaticText
        Accessible.name: qsTr("已加入播放队列")

        Rectangle {
            width: parent.radius
            height: width
            color: parent.color
        }
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: parent.radius
            height: width
            color: parent.color
        }
        Base.AppText {
            id: queueBadgeText
            anchors.centerIn: parent
            text: "☷ " + qsTr("队列")
            styleRole: UiStyle.TypographyRole.BodyS
            colorOverride: root.appTheme.colors.inverseText
        }
    }

    Rectangle {
        z: 1
        anchors.fill: timelineCard
        radius: root.appTheme.shape.sectionRadius
        color: "transparent"
        border.width: 1
        border.color: root.current
            ? root.appTheme.colors.highlightText
            : root.appTheme.colors.controlBorder
        opacity: 1
        enabled: false

        Behavior on border.color {
            ColorAnimation {
                duration: root.appTheme.motion.durationStandard
                easing.type: root.appTheme.motion.easingStandard
            }
        }
    }
}
