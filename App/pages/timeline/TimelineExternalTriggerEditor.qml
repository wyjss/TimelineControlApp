import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/theme" as Theme

Item {
    id: root

    Theme.AppTheme {
        id: fallbackTheme
    }

    property var devices: []
    property var fences: []
    property var conditionModel: null
    property var timelineModel: null
    property var currentTimeline: null
    property Item dialogParent: root
    property bool editable: true
    property var locatorOptions: []
    property var fenceOptions: []
    property var timelineOptions: []
    property var timelineConditions: []
    readonly property QtObject pageTheme: ApplicationWindow.window
        && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : fallbackTheme

    implicitHeight: timelineConditions.length > 0
        ? Math.min(230, 50 + timelineConditions.length * 60)
        : 72

    function rebuildLocatorOptions() {
        var options = []
        for (var index = 0; index < devices.length; ++index) {
            var device = devices[index]
            if (String(device.deviceType || "") !== qsTr("定位器"))
                continue

            var id = String(device.id || "")
            var name = String(device.name || "").trim()
            options.push({
                "label": name.length > 0 ? name : id,
                "value": id
            })
        }
        locatorOptions = options
    }

    function rebuildFenceOptions() {
        var options = []
        for (var index = 0; index < fences.length; ++index) {
            var fence = fences[index]
            var handle = String(fence.handle || "")
            var name = String(fence.name || "").trim()
            options.push({
                "label": name.length > 0 ? name : handle,
                "value": handle
            })
        }
        fenceOptions = options
    }

    function rebuildTimelineOptions() {
        var options = []
        var sourceTimelineId = currentTimeline ? String(currentTimeline.id || "") : ""
        if (timelineModel) {
            for (var index = 0; index < timelineModel.count; ++index) {
                var timeline = timelineModel.timelineAt(index)
                var timelineId = String(timeline.id || "")
                if (timelineId === sourceTimelineId)
                    continue

                options.push({
                    "label": String(timeline.name || timelineId),
                    "value": timelineId
                })
            }
        }
        timelineOptions = options
    }

    function rebuildConditions() {
        var conditions = []
        if (conditionModel) {
            for (var index = 0; index < conditionModel.count; ++index)
                conditions.push(conditionModel.conditionAt(index))
        }
        timelineConditions = conditions
    }

    function optionLabel(options, value) {
        for (var index = 0; index < options.length; ++index) {
            if (String(options[index].value) === String(value))
                return String(options[index].label)
        }
        return String(value || "")
    }

    onDevicesChanged: rebuildLocatorOptions()
    onFencesChanged: rebuildFenceOptions()
    onConditionModelChanged: rebuildConditions()
    onTimelineModelChanged: rebuildTimelineOptions()
    onCurrentTimelineChanged: {
        rebuildTimelineOptions()
        rebuildConditions()
    }

    Connections {
        target: root.conditionModel
        function onConditionsChanged() { root.rebuildConditions() }
    }

    Connections {
        target: root.timelineModel
        function onTimelinesChanged() { root.rebuildTimelineOptions() }
    }

    Component.onCompleted: {
        rebuildLocatorOptions()
        rebuildFenceOptions()
        rebuildTimelineOptions()
        rebuildConditions()
    }

    Base.AppSurface {
        anchors.fill: parent
        sizeToContent: false
        surfaceTone: UiStyle.SurfaceTone.Section

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Base.AppText {
                    text: qsTr("过点触发")
                    styleRole: UiStyle.TypographyRole.BodyM
                    textTone: UiStyle.TextTone.Primary
                }

                Base.AppText {
                    text: qsTr("%1 条规则").arg(root.timelineConditions.length)
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                }

                Item {
                    Layout.fillWidth: true
                }

                Base.AppButton {
                    text: qsTr("添加规则")
                    iconSymbol: "+"
                    size: UiStyle.ButtonSize.Small
                    enabled: root.editable
                        && root.currentTimeline
                        && root.conditionModel
                        && root.locatorOptions.length > 0
                        && root.fenceOptions.length > 0
                        && root.timelineOptions.length > 0
                    onClicked: conditionDialog.openForCreate()
                }
            }

            ListView {
                id: conditionList

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.timelineConditions.length > 0
                orientation: ListView.Vertical
                spacing: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.timelineConditions

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                delegate: Base.AppCard {
                    id: conditionCard

                    readonly property var conditionData: modelData
                    readonly property string locatorText: root.optionLabel(
                        root.locatorOptions, conditionData.locator)
                    readonly property string fenceText: root.optionLabel(
                        root.fenceOptions, conditionData.fence)
                    readonly property string timelineText: root.optionLabel(
                        root.timelineOptions, conditionData.timeline)
                    readonly property string statusText: conditionData.touched
                        ? qsTr("已触发")
                        : (conditionData.active ? qsTr("待触发") : qsTr("未激活"))
                    readonly property int statusTextTone: conditionData.touched
                        ? UiStyle.TextTone.Success
                        : (conditionData.active
                            ? UiStyle.TextTone.Accent
                            : UiStyle.TextTone.Secondary)
                    readonly property color statusColor: conditionData.touched
                        ? root.pageTheme.colors.successFill
                        : (conditionData.active
                            ? root.pageTheme.colors.highlightFill
                            : root.pageTheme.colors.subtleText)

                    width: conditionList.width
                    height: 50
                    compact: true
                    animateScale: false
                    enabled: root.editable
                    onClicked: conditionDialog.openForEdit(conditionData)

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6

                        Base.AppText {
                            Layout.preferredWidth: 24
                            text: "⚡"
                            styleRole: UiStyle.TypographyRole.TitleM
                            textTone: UiStyle.TextTone.Warning
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 24
                            color: root.pageTheme
                                ? root.pageTheme.colors.border
                                : "transparent"
                        }

                        Base.AppText {
                            Layout.preferredWidth: Math.min(130,
                                                            Math.max(76,
                                                                     conditionList.width * 0.13))
                            text: conditionCard.locatorText
                            styleRole: UiStyle.TypographyRole.BodyS
                            overrideWeight: Font.Medium
                            textTone: conditionCard.conditionData.enabled
                                ? UiStyle.TextTone.Primary
                                : UiStyle.TextTone.Secondary
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 24
                            color: root.pageTheme
                                ? root.pageTheme.colors.border
                                : "transparent"
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 120
                            spacing: 3

                            Base.AppText {
                                text: qsTr("经过")
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: conditionCard.fenceText
                                styleRole: UiStyle.TypographyRole.BodyS
                                overrideWeight: Font.Medium
                                textTone: conditionCard.conditionData.enabled
                                    ? UiStyle.TextTone.Primary
                                    : UiStyle.TextTone.Secondary
                                elide: Text.ElideRight
                            }

                            Base.AppText {
                                text: "·"
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                            }

                            Base.AppText {
                                text: qsTr("朝向")
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                            }

                            Base.AppText {
                                text: qsTr("%1°").arg(Number(
                                    conditionCard.conditionData.heading).toFixed(1))
                                styleRole: UiStyle.TypographyRole.BodyS
                                overrideWeight: Font.Medium
                                textTone: conditionCard.conditionData.enabled
                                    ? UiStyle.TextTone.Primary
                                    : UiStyle.TextTone.Secondary
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 24
                            color: root.pageTheme
                                ? root.pageTheme.colors.border
                                : "transparent"
                        }

                        RowLayout {
                            Layout.preferredWidth: Math.min(190,
                                                            Math.max(140,
                                                                     conditionList.width * 0.22))
                            spacing: 7

                            Base.AppText {
                                text: "→"
                                styleRole: UiStyle.TypographyRole.TitleM
                                textTone: UiStyle.TextTone.Accent
                            }

                            Base.AppSurface {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28
                                sizeToContent: false
                                surfaceTone: UiStyle.SurfaceTone.Success
                                shapeRole: UiStyle.ShapeRole.Pill

                                Base.AppText {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    text: qsTr("触发 %1").arg(conditionCard.timelineText)
                                    styleRole: UiStyle.TypographyRole.BodyS
                                    overrideWeight: Font.Medium
                                    textTone: UiStyle.TextTone.Success
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 24
                            color: root.pageTheme
                                ? root.pageTheme.colors.border
                                : "transparent"
                        }

                        RowLayout {
                            Layout.preferredWidth: 76
                            spacing: 5

                            Rectangle {
                                width: 7
                                height: 7
                                radius: width / 2
                                color: conditionCard.statusColor
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: conditionCard.statusText
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: conditionCard.statusTextTone
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 24
                            color: root.pageTheme
                                ? root.pageTheme.colors.border
                                : "transparent"
                        }

                        Base.AppToggleControl {
                            checked: conditionCard.conditionData.enabled
                            enabled: root.editable
                            onToggled: conditionCard.conditionData.enabled = checked
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 24
                            color: root.pageTheme
                                ? root.pageTheme.colors.border
                                : "transparent"
                        }

                        Base.AppButton {
                            text: "⋮"
                            size: UiStyle.ButtonSize.Small
                            minWidth: 28
                            variant: UiStyle.ButtonVariant.Ghost
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("更多操作")
                            onClicked: conditionMenu.popup()

                            Menu {
                                id: conditionMenu

                                MenuItem {
                                    text: qsTr("编辑")
                                    onTriggered: conditionDialog.openForEdit(
                                        conditionCard.conditionData)
                                }

                                MenuItem {
                                    text: qsTr("删除")
                                    onTriggered: root.conditionModel.removeCondition(
                                        conditionCard.conditionData)
                                }
                            }
                        }
                    }
                }
            }

            Base.AppText {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.timelineConditions.length === 0
                text: root.locatorOptions.length === 0
                    ? qsTr("暂无定位器")
                    : (root.fenceOptions.length === 0
                        ? qsTr("暂无栅栏")
                        : (root.timelineOptions.length === 0
                            ? qsTr("暂无可触发的其他时间线")
                            : qsTr("暂无过点触发规则")))
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Base.AppDialog {
        id: conditionDialog

        parent: root.dialogParent

        property var editingCondition: null
        property string locatorId: ""
        property string fenceHandle: ""
        property string targetTimelineId: ""
        property real targetHeading: 0
        property bool conditionEnabled: true
        property string errorText: ""
        readonly property bool editing: editingCondition !== null
        readonly property bool formValid: root.conditionModel
            && root.currentTimeline
            && locatorId.length > 0
            && fenceHandle.length > 0
            && targetTimelineId.length > 0

        function openForCreate() {
            editingCondition = null
            locatorId = root.locatorOptions.length > 0
                ? String(root.locatorOptions[0].value)
                : ""
            fenceHandle = root.fenceOptions.length > 0
                ? String(root.fenceOptions[0].value)
                : ""
            targetTimelineId = root.timelineOptions.length > 0
                ? String(root.timelineOptions[0].value)
                : ""
            targetHeading = 0
            conditionEnabled = true
            errorText = ""
            open()
        }

        function openForEdit(condition) {
            if (!condition)
                return

            editingCondition = condition
            locatorId = String(condition.locator || "")
            fenceHandle = String(condition.fence || "")
            targetTimelineId = String(condition.timeline || "")
            targetHeading = Number(condition.heading || 0)
            conditionEnabled = condition.enabled
            errorText = ""
            open()
        }

        function commit() {
            if (!formValid)
                return

            var condition = editingCondition
            var success = editing
                ? root.conditionModel.updateCondition(condition,
                                                      locatorId,
                                                      fenceHandle,
                                                      targetHeading,
                                                      targetTimelineId)
                : (condition = root.conditionModel.addCondition(locatorId,
                                                                fenceHandle,
                                                                targetHeading,
                                                                targetTimelineId)) !== null
            if (!success) {
                errorText = qsTr("条件参数无效，请重新选择")
                return
            }

            condition.enabled = conditionEnabled
            close()
        }

        width: Math.min(560, Math.max(420, parent ? parent.width - 96 : 520))
        maximumDialogHeight: Math.min(560, Math.max(360, parent ? parent.height - 96 : 460))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        title: editing ? qsTr("编辑过点触发") : qsTr("添加过点触发")
        message: root.currentTimeline
            ? qsTr("为“%1”添加规则，满足条件后切换到目标时间线。").arg(root.currentTimeline.name)
            : ""
        rejectText: qsTr("取消")
        acceptText: editing ? qsTr("保存") : qsTr("添加")
        acceptEnabled: root.editable && formValid
        closeOnAccepted: false
        onAccepted: commit()
        onClosed: editingCondition = null

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 10
            rowSpacing: 10

            Base.AppText {
                text: qsTr("定位器")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }

            Base.AppSelect {
                Layout.fillWidth: true
                options: root.locatorOptions
                value: conditionDialog.locatorId
                onValueSelected: conditionDialog.locatorId = String(nextValue || "")
            }

            Base.AppText {
                text: qsTr("栅栏")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }

            Base.AppSelect {
                Layout.fillWidth: true
                options: root.fenceOptions
                value: conditionDialog.fenceHandle
                onValueSelected: conditionDialog.fenceHandle = String(nextValue || "")
            }

            Base.AppText {
                text: qsTr("朝向")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }

            Base.AppNumberField {
                Layout.fillWidth: true
                value: conditionDialog.targetHeading
                minimum: 0
                maximum: 359.99
                decimals: 2
                suffix: "°"
                onValueEdited: conditionDialog.targetHeading = nextValue
            }

            Base.AppText {
                text: qsTr("目标时间线")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }

            Base.AppSelect {
                Layout.fillWidth: true
                options: root.timelineOptions
                value: conditionDialog.targetTimelineId
                onValueSelected: conditionDialog.targetTimelineId = String(nextValue || "")
            }

            Base.AppText {
                text: qsTr("启用")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }

            Base.AppToggleControl {
                checked: conditionDialog.conditionEnabled
                onToggled: conditionDialog.conditionEnabled = checked
            }
        }

        Base.AppText {
            Layout.fillWidth: true
            visible: conditionDialog.errorText.length > 0
            text: conditionDialog.errorText
            styleRole: UiStyle.TypographyRole.BodyS
            textTone: UiStyle.TextTone.Danger
            elide: Text.ElideRight
        }
    }
}
