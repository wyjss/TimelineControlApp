import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "../base" as Base

Base.AppPopup {
    id: root

    property Item anchorItem: null
    property var taskItems: []
    property int taskItemCount: taskItems ? taskItems.length : 0
    property int activeTaskCount: 0
    property int finishedTaskCount: Math.max(0, taskItemCount - activeTaskCount)
    property int topBarHeight: 44
    property int overlayMargin: 8
    property var taskExpansionState: ({})
    readonly property QtObject controlStyles: resolvedTheme.controlStyles

    width: parent ? Math.min(440, Math.max(300, parent.width - overlayMargin * 2)) : 440
    height: parent ? Math.min(520, Math.max(220, parent.height - topBarHeight - overlayMargin * 2)) : 520
    surfaceTone: UiStyle.SurfaceTone.SurfaceOverlay
    modal: false
    showModalOverlay: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 16
    spacing: 12

    onAboutToShow: updatePopupPosition()
    onWidthChanged: {
        if (visible)
            updatePopupPosition()
    }

    function updatePopupPosition() {
        if (!parent || !anchorItem)
            return

        var origin = anchorItem.mapToItem(parent, anchorItem.width - width, anchorItem.height + 8)
        x = Math.round(Math.max(overlayMargin, Math.min(origin.x, parent.width - width - overlayMargin)))
        y = Math.round(Math.max(overlayMargin, origin.y))
    }

    function colorValue(name) {
        return resolvedTheme.colors[name]
    }

    function taskTitle(taskItem) {
        var resolvedName = taskItem && taskItem.taskName !== undefined
            ? String(taskItem.taskName).trim()
            : ""
        if (resolvedName.length > 0)
            return resolvedName

        return qsTr("未命名任务")
    }

    function taskPhaseName(taskItem) {
        var phase = taskItem && taskItem.phase !== undefined ? Number(taskItem.phase) : 0
        switch (phase) {
        case 1:
            return "running"
        case 2:
            return "succeeded"
        case 3:
            return "failed"
        case 4:
            return "cancelled"
        case 0:
        default:
            return "ready"
        }
    }

    function taskPhaseLabel(phaseName) {
        switch (String(phaseName)) {
        case "running":
            return qsTr("运行中")
        case "succeeded":
            return qsTr("已成功")
        case "failed":
            return qsTr("已失败")
        case "cancelled":
            return qsTr("已取消")
        case "ready":
        default:
            return qsTr("就绪")
        }
    }

    function taskPhaseSpec(phaseName) {
        return controlStyles.taskPhaseSpec(phaseName)
    }

    function taskPhaseTint(phaseName) {
        var spec = taskPhaseSpec(phaseName)
        return colorValue(spec.text)
    }

    function taskPhaseFill(phaseName) {
        var spec = taskPhaseSpec(phaseName)
        return colorValue(spec.fill)
    }

    function taskExecutionModeLabel(mode) {
        return Number(mode) === 1 ? qsTr("并行") : qsTr("串行")
    }

    function taskDispatchHintLabel(dispatchHint) {
        return Number(dispatchHint) === 1 ? qsTr("工作线程") : qsTr("直接执行")
    }

    function taskProgressValue(taskItem) {
        var progress = taskItem && taskItem.progress !== undefined ? Number(taskItem.progress) : 0
        if (isNaN(progress))
            return 0

        return Math.max(0, Math.min(progress, 1))
    }

    function taskProgressText(taskItem) {
        return Math.round(taskProgressValue(taskItem) * 100) + "%"
    }

    function taskStatusText(taskItem) {
        var phaseName = taskPhaseName(taskItem)
        var label = taskPhaseLabel(phaseName)

        if (phaseName === "running")
            return label + " " + taskProgressText(taskItem)

        return label
    }

    function taskSummaryText(taskItem) {
        var errorText = taskItem && taskItem.error !== undefined ? String(taskItem.error).trim() : ""
        if (errorText.length > 0)
            return errorText

        var messageText = taskItem && taskItem.message !== undefined ? String(taskItem.message).trim() : ""
        if (messageText.length > 0)
            return messageText

        var detailText = taskItem && taskItem.detail !== undefined ? String(taskItem.detail).trim() : ""
        if (detailText.length > 0)
            return detailText

        return qsTr("暂无详情")
    }

    function taskProgressVisible(taskItem) {
        return taskPhaseName(taskItem) === "running"
            || !!(taskItem && taskItem.finished !== undefined ? taskItem.finished : false)
            || taskProgressValue(taskItem) > 0
    }

    function copyObject(source) {
        var target = {}

        if (!source)
            return target

        for (var key in source)
            target[key] = source[key]

        return target
    }

    function isTaskExpanded(taskId) {
        return !!taskExpansionState[String(taskId)]
    }

    function setTaskExpanded(taskId, expanded) {
        var normalizedTaskId = String(taskId)
        var nextState = copyObject(taskExpansionState)

        if (expanded)
            nextState[normalizedTaskId] = true
        else
            delete nextState[normalizedTaskId]

        taskExpansionState = nextState
    }

    Base.AppText {
        Layout.fillWidth: true
        text: qsTr("后台任务")
        styleRole: UiStyle.TypographyRole.SectionTitle
    }

    Base.AppText {
        Layout.fillWidth: true
        text: root.taskItemCount > 0
            ? qsTr("共 %1 个 · %2 个活跃 · %3 个已完成").arg(root.taskItemCount).arg(root.activeTaskCount).arg(root.finishedTaskCount)
            : qsTr("排队、运行中、已完成、失败和已取消的任务会显示在这里。")
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Secondary
        wrapMode: Text.WordWrap
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: root.taskItemCount > 0

        Base.AppBadge {
            surfaceTone: UiStyle.SurfaceTone.Section
            text: qsTr("全部 %1").arg(root.taskItemCount)
            textTone: UiStyle.TextTone.Primary
        }

        Base.AppBadge {
            surfaceTone: root.activeTaskCount > 0
                ? UiStyle.SurfaceTone.Highlight
                : UiStyle.SurfaceTone.Section
            text: qsTr("活跃 %1").arg(root.activeTaskCount)
            textTone: root.activeTaskCount > 0
                ? UiStyle.TextTone.Accent
                : UiStyle.TextTone.Secondary
        }

        Item {
            Layout.fillWidth: true
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: root.colorValue("border")
        opacity: 0.82
    }

    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: root.visible
        sourceComponent: root.taskItemCount > 0 ? taskListComponent : emptyStateComponent
    }

    Component {
        id: taskListComponent

        ListView {
            id: taskList

            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 0
            model: root.taskItems
            spacing: 10

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: Base.AppSection {
                id: taskSection

                readonly property var taskItem: modelData
                readonly property string entryId: taskItem && taskItem.taskId !== undefined ? String(taskItem.taskId) : String(index)
                readonly property string phaseName: root.taskPhaseName(taskItem)
                readonly property real progressValue: root.taskProgressValue(taskItem)
                readonly property string concurrencyKey: taskItem && taskItem.concurrencyKey !== undefined ? String(taskItem.concurrencyKey) : ""
                readonly property string messageText: taskItem && taskItem.message !== undefined ? String(taskItem.message) : ""
                readonly property string errorText: taskItem && taskItem.error !== undefined ? String(taskItem.error) : ""
                readonly property string detailText: taskItem && taskItem.detail !== undefined ? String(taskItem.detail) : ""

                width: ListView.view.width
                height: implicitHeight
                surfaced: true
                surfaceTone: UiStyle.SurfaceTone.Section
                compact: false
                collapsible: true
                expanded: root.isTaskExpanded(entryId)
                title: root.taskTitle(taskItem)
                subtitle: root.taskSummaryText(taskItem)
                showSubtitle: true
                showHeaderDivider: expanded
                onToggled: root.setTaskExpanded(entryId, expanded)
                headerActions: [
                    Base.AppBadge {
                        surfaceTone: UiStyle.SurfaceTone.Ghost
                        fillOverride: root.taskPhaseFill(taskSection.phaseName)
                        text: root.taskStatusText(taskSection.taskItem)
                        textColorOverride: root.taskPhaseTint(taskSection.phaseName)
                    }
                ]

                Loader {
                    id: taskDetailsLoader

                    Layout.fillWidth: true
                    Layout.preferredHeight: item ? item.implicitHeight : 0
                    active: taskSection.expanded || taskSection.bodyVisible
                    sourceComponent: taskDetailsComponent
                }

                Component {
                    id: taskDetailsComponent

                    ColumnLayout {
                        width: taskDetailsLoader.width
                        spacing: taskSection.contentSpacing

                        Base.AppProgressBar {
                            Layout.fillWidth: true
                            visible: root.taskProgressVisible(taskSection.taskItem)
                            from: 0
                            to: 1
                            value: taskSection.progressValue
                            fillOverride: root.taskPhaseTint(taskSection.phaseName)
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Base.AppText {
                                Layout.preferredWidth: 88
                                text: qsTr("详情")
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: taskSection.detailText.length > 0 ? taskSection.detailText : qsTr("无")
                                styleRole: UiStyle.TypographyRole.BodyS
                                wrapMode: Text.WordWrap
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Base.AppText {
                                Layout.preferredWidth: 88
                                text: qsTr("模式")
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.taskExecutionModeLabel(
                                    taskSection.taskItem && taskSection.taskItem.executionMode !== undefined
                                        ? taskSection.taskItem.executionMode
                                        : 0
                                )
                                styleRole: UiStyle.TypographyRole.BodyS
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Base.AppText {
                                Layout.preferredWidth: 88
                                text: qsTr("调度")
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.taskDispatchHintLabel(
                                    taskSection.taskItem && taskSection.taskItem.dispatchHint !== undefined
                                        ? taskSection.taskItem.dispatchHint
                                        : 0
                                )
                                styleRole: UiStyle.TypographyRole.BodyS
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Base.AppText {
                                Layout.preferredWidth: 88
                                text: qsTr("进度")
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.taskProgressText(taskSection.taskItem)
                                styleRole: UiStyle.TypographyRole.BodyS
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: taskSection.concurrencyKey.length > 0

                            Base.AppText {
                                Layout.preferredWidth: 88
                                text: qsTr("键")
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: taskSection.concurrencyKey
                                styleRole: UiStyle.TypographyRole.BodyS
                                wrapMode: Text.WordWrap
                            }
                        }

                        Base.AppSurface {
                            Layout.fillWidth: true
                            visible: taskSection.messageText.length > 0
                            surfaceTone: UiStyle.SurfaceTone.Ghost
                            shapeRole: UiStyle.ShapeRole.Control
                            strokeWidth: 0
                            padding: 10

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 4

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: qsTr("消息")
                                    styleRole: UiStyle.TypographyRole.BodyS
                                    textTone: UiStyle.TextTone.Secondary
                                }

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: taskSection.messageText
                                    styleRole: UiStyle.TypographyRole.BodyS
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        Base.AppSurface {
                            Layout.fillWidth: true
                            visible: taskSection.errorText.length > 0
                            surfaceTone: UiStyle.SurfaceTone.Ghost
                            shapeRole: UiStyle.ShapeRole.Control
                            strokeWidth: 0
                            padding: 10
                            fillOverride: root.colorValue("dangerSoft")

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 4

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: qsTr("错误")
                                    styleRole: UiStyle.TypographyRole.BodyS
                                    colorOverride: root.colorValue("dangerText")
                                }

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: taskSection.errorText
                                    styleRole: UiStyle.TypographyRole.BodyS
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: emptyStateComponent

        Item {
            Base.AppSection {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                surfaced: true
                surfaceTone: UiStyle.SurfaceTone.Section
                compact: false
                title: qsTr("暂无任务")
                subtitle: qsTr("后台工作项注册后会显示在这里。")
                showSubtitle: true

                Base.AppText {
                    Layout.fillWidth: true
                    text: qsTr("此面板会同时显示活跃任务、已完成任务和失败结果。")
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
