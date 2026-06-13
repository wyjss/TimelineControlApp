import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "../../foundation"
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
    readonly property QtObject controlStyles: theme && theme.controlStyles ? theme.controlStyles : null

    width: parent ? Math.min(440, Math.max(300, parent.width - overlayMargin * 2)) : 440
    height: parent ? Math.min(520, Math.max(220, parent.height - topBarHeight - overlayMargin * 2)) : 520
    x: {
        if (!parent || !anchorItem)
            return 0

        var origin = anchorItem.mapToItem(parent, anchorItem.width - width, anchorItem.height + 8)
        return Math.round(Math.max(overlayMargin, Math.min(origin.x, parent.width - width - overlayMargin)))
    }
    y: {
        if (!parent)
            return topBarHeight + overlayMargin

        if (!anchorItem)
            return overlayMargin

        var origin = anchorItem.mapToItem(parent, 0, anchorItem.height + 8)
        return Math.round(Math.max(overlayMargin, origin.y))
    }
    surfaceTone: "surface"
    modal: false
    showModalOverlay: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 16
    spacing: 12

    function colorValue(name, fallback) {
        return theme && theme.colors && theme.colors[name] !== undefined
            ? theme.colors[name]
            : fallback
    }

    function taskTitle(taskItem) {
        var resolvedName = taskItem && taskItem.taskName !== undefined
            ? String(taskItem.taskName).trim()
            : ""
        if (resolvedName.length > 0)
            return resolvedName

        return qsTr("Unnamed Task")
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
            return qsTr("Running")
        case "succeeded":
            return qsTr("Succeeded")
        case "failed":
            return qsTr("Failed")
        case "cancelled":
            return qsTr("Cancelled")
        case "ready":
        default:
            return qsTr("Ready")
        }
    }

    function taskPhaseSpec(phaseName) {
        if (controlStyles && controlStyles.taskPhaseSpec !== undefined)
            return controlStyles.taskPhaseSpec(phaseName)

        return {
            "text": "neutralText",
            "textFallback": "#cbd5e1",
            "fill": "neutralSoft",
            "fillFallback": "#202a36"
        }
    }

    function taskPhaseTint(phaseName) {
        var spec = taskPhaseSpec(phaseName)
        return colorValue(spec.text, spec.textFallback)
    }

    function taskPhaseFill(phaseName) {
        var spec = taskPhaseSpec(phaseName)
        return colorValue(spec.fill, spec.fillFallback)
    }

    function taskExecutionModeLabel(mode) {
        return Number(mode) === 1 ? qsTr("Parallel") : qsTr("Serial")
    }

    function taskDispatchHintLabel(dispatchHint) {
        return Number(dispatchHint) === 1 ? qsTr("Worker Thread") : qsTr("Direct")
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

        return qsTr("No detail available")
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
        text: qsTr("Background Tasks")
        theme: root.theme
        styleRole: "sectionTitle"
    }

    Base.AppText {
        Layout.fillWidth: true
        text: root.taskItemCount > 0
            ? qsTr("%1 total · %2 active · %3 finished").arg(root.taskItemCount).arg(root.activeTaskCount).arg(root.finishedTaskCount)
            : qsTr("Queued, running, finished, failed, and cancelled tasks will appear here.")
        theme: root.theme
        styleRole: "bodyS"
        textTone: "secondary"
        wrapMode: Text.WordWrap
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: root.taskItemCount > 0

        Base.AppSurface {
            Layout.preferredHeight: root.theme && root.theme.density ? root.theme.density.chipHeight : 30
            theme: root.theme
            surfaceTone: "section"
            shapeRole: AppUiEnums.ShapeRole.Pill
            strokeWidth: 0
            padding: 10
            constrainContentHeight: true

            Base.AppText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("All %1").arg(root.taskItemCount)
                theme: root.theme
                styleRole: "bodyS"
            }
        }

        Base.AppSurface {
            Layout.preferredHeight: root.theme && root.theme.density ? root.theme.density.chipHeight : 30
            theme: root.theme
            surfaceTone: root.activeTaskCount > 0 ? "highlight" : "section"
            shapeRole: AppUiEnums.ShapeRole.Pill
            strokeWidth: 0
            padding: 10
            constrainContentHeight: true

            Base.AppText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Active %1").arg(root.activeTaskCount)
                theme: root.theme
                styleRole: "bodyS"
                textTone: root.activeTaskCount > 0 ? "accent" : "secondary"
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: root.colorValue("border", "#334155")
        opacity: 0.82
    }

    Base.AppScrollPane {
        id: taskScroll

        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.taskItemCount > 0
        theme: root.theme
        contentSpacing: 0

        ColumnLayout {
            width: taskScroll.availableContentWidth
            spacing: 10

            Repeater {
                model: root.taskItems

                delegate: Base.AppSection {
                    readonly property var taskItem: modelData
                    readonly property string entryId: taskItem && taskItem.taskId !== undefined ? String(taskItem.taskId) : String(index)
                    readonly property string phaseName: root.taskPhaseName(taskItem)
                    readonly property real progressValue: root.taskProgressValue(taskItem)
                    readonly property string concurrencyKey: taskItem && taskItem.concurrencyKey !== undefined ? String(taskItem.concurrencyKey) : ""
                    readonly property string messageText: taskItem && taskItem.message !== undefined ? String(taskItem.message) : ""
                    readonly property string errorText: taskItem && taskItem.error !== undefined ? String(taskItem.error) : ""
                    readonly property string detailText: taskItem && taskItem.detail !== undefined ? String(taskItem.detail) : ""

                    Layout.fillWidth: true
                    theme: root.theme
                    surfaced: true
                    surfaceTone: "section"
                    compact: false
                    collapsible: true
                    expanded: root.isTaskExpanded(entryId)
                    title: root.taskTitle(taskItem)
                    subtitle: root.taskSummaryText(taskItem)
                    showSubtitle: true
                    showHeaderDivider: expanded
                    onToggled: root.setTaskExpanded(entryId, expanded)
                    headerActions: [
                        Base.AppSurface {
                            Layout.preferredHeight: root.theme && root.theme.density ? root.theme.density.chipHeight : 28
                            theme: root.theme
                            surfaceTone: "ghost"
                            shapeRole: AppUiEnums.ShapeRole.Pill
                            strokeWidth: 0
                            padding: 10
                            constrainContentHeight: true
                            fillOverride: root.taskPhaseFill(phaseName)

                            Base.AppText {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.taskStatusText(taskItem)
                                theme: root.theme
                                styleRole: "bodyS"
                                colorOverride: root.taskPhaseTint(phaseName)
                            }
                        }
                    ]

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.taskProgressVisible(taskItem) ? 6 : 0
                        visible: root.taskProgressVisible(taskItem)

                        Rectangle {
                            anchors.fill: parent
                            radius: height * 0.5
                            color: root.colorValue("windowAccent", "#222b36")
                        }

                        Rectangle {
                            width: parent.width * progressValue
                            height: parent.height
                            radius: height * 0.5
                            color: root.taskPhaseTint(phaseName)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Base.AppText {
                            Layout.preferredWidth: 88
                            text: qsTr("Detail")
                            theme: root.theme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }

                        Base.AppText {
                            Layout.fillWidth: true
                            text: detailText.length > 0 ? detailText : qsTr("None")
                            theme: root.theme
                            styleRole: "bodyS"
                            wrapMode: Text.WordWrap
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Base.AppText {
                            Layout.preferredWidth: 88
                            text: qsTr("Mode")
                            theme: root.theme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }

                        Base.AppText {
                            Layout.fillWidth: true
                            text: root.taskExecutionModeLabel(taskItem && taskItem.executionMode !== undefined ? taskItem.executionMode : 0)
                            theme: root.theme
                            styleRole: "bodyS"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Base.AppText {
                            Layout.preferredWidth: 88
                            text: qsTr("Dispatch")
                            theme: root.theme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }

                        Base.AppText {
                            Layout.fillWidth: true
                            text: root.taskDispatchHintLabel(taskItem && taskItem.dispatchHint !== undefined ? taskItem.dispatchHint : 0)
                            theme: root.theme
                            styleRole: "bodyS"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Base.AppText {
                            Layout.preferredWidth: 88
                            text: qsTr("Progress")
                            theme: root.theme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }

                        Base.AppText {
                            Layout.fillWidth: true
                            text: root.taskProgressText(taskItem)
                            theme: root.theme
                            styleRole: "bodyS"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: concurrencyKey.length > 0

                        Base.AppText {
                            Layout.preferredWidth: 88
                            text: qsTr("Key")
                            theme: root.theme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }

                        Base.AppText {
                            Layout.fillWidth: true
                            text: concurrencyKey
                            theme: root.theme
                            styleRole: "bodyS"
                            wrapMode: Text.WordWrap
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        visible: messageText.length > 0
                        theme: root.theme
                        surfaceTone: "ghost"
                        shapeRole: AppUiEnums.ShapeRole.Control
                        strokeWidth: 0
                        padding: 10

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 4

                            Base.AppText {
                                Layout.fillWidth: true
                                text: qsTr("Message")
                                theme: root.theme
                                styleRole: "bodyS"
                                textTone: "secondary"
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: messageText
                                theme: root.theme
                                styleRole: "bodyS"
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        visible: errorText.length > 0
                        theme: root.theme
                        surfaceTone: "ghost"
                        shapeRole: AppUiEnums.ShapeRole.Control
                        strokeWidth: 0
                        padding: 10
                        fillOverride: root.colorValue("dangerSoft", "#2b1a21")

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 4

                            Base.AppText {
                                Layout.fillWidth: true
                                text: qsTr("Error")
                                theme: root.theme
                                styleRole: "bodyS"
                                colorOverride: root.colorValue("dangerText", "#ff9eb2")
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: errorText
                                theme: root.theme
                                styleRole: "bodyS"
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.taskItemCount === 0

        Base.AppSection {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            theme: root.theme
            surfaced: true
            surfaceTone: "section"
            compact: false
            title: qsTr("No Tasks Yet")
            subtitle: qsTr("Background work items will appear here after they are registered.")
            showSubtitle: true

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("This panel keeps active tasks together with completed and failed results.")
                theme: root.theme
                styleRole: "bodyS"
                textTone: "secondary"
                wrapMode: Text.WordWrap
            }
        }
    }
}
