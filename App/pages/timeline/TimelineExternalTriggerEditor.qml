import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base

Item {
    id: root

    property var devices: []
    property var timelineModel: null
    property Item dialogParent: root
    property bool editable: true
    property var deviceOptions: []
    property var timelineOptions: []
    property alias ruleModel: triggerRuleModel

    implicitHeight: triggerRuleModel.count > 0 ? 116 : 72

    function rebuildDeviceOptions() {
        var options = []
        for (var index = 0; index < devices.length; ++index) {
            var device = devices[index]
            var id = String(device.id || "")
            var name = String(device.name || "").trim()
            options.push({
                "label": name.length > 0 ? name : id,
                "value": id
            })
        }
        deviceOptions = options
    }

    function rebuildTimelineOptions() {
        var options = []
        if (timelineModel) {
            for (var index = 0; index < timelineModel.count; ++index) {
                var timeline = timelineModel.timelineAt(index)
                options.push({
                    "label": String(timeline.name || timeline.id),
                    "value": String(timeline.id || "")
                })
            }
        }
        timelineOptions = options
    }

    function optionLabel(options, value) {
        for (var index = 0; index < options.length; ++index) {
            if (String(options[index].value) === String(value))
                return String(options[index].label)
        }
        return String(value || "")
    }

    onDevicesChanged: rebuildDeviceOptions()
    onTimelineModelChanged: rebuildTimelineOptions()
    Component.onCompleted: {
        rebuildDeviceOptions()
        rebuildTimelineOptions()
    }

    Connections {
        target: root.timelineModel
        function onTimelinesChanged() {
            root.rebuildTimelineOptions()
        }
    }

    ListModel {
        id: triggerRuleModel
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
                    text: qsTr("外部触发")
                    styleRole: UiStyle.TypographyRole.BodyM
                    textTone: UiStyle.TextTone.Primary
                }

                Base.AppText {
                    text: qsTr("%1 条规则").arg(triggerRuleModel.count)
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
                        && root.deviceOptions.length > 0
                        && root.timelineOptions.length > 0
                    onClicked: triggerRuleDialog.openForCreate()
                }
            }

            ListView {
                id: ruleList

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: triggerRuleModel.count > 0
                orientation: ListView.Horizontal
                spacing: 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: triggerRuleModel

                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                delegate: Base.AppCard {
                    id: ruleCard

                    width: Math.min(360, Math.max(280, ruleList.width * 0.45))
                    height: ruleList.height
                    compact: true
                    animateScale: false
                    enabled: root.editable
                    onClicked: triggerRuleDialog.openForEdit(index)

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Base.AppText {
                                Layout.fillWidth: true
                                text: model.sourceDeviceName
                                    + " · " + model.eventKey
                                    + " " + model.comparison
                                    + " " + model.expectedValue
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: model.enabled
                                    ? UiStyle.TextTone.Primary
                                    : UiStyle.TextTone.Secondary
                                elide: Text.ElideRight
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: "→ " + model.targetTimelineName + " · " + model.playModeLabel
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Accent
                                elide: Text.ElideRight
                            }
                        }

                        Base.AppToggleControl {
                            checked: model.enabled
                            enabled: root.editable
                            onToggled: triggerRuleModel.setProperty(index, "enabled", checked)
                        }

                        Base.AppButton {
                            visible: ruleCard.hovered || hovered
                            text: qsTr("编辑")
                            size: UiStyle.ButtonSize.Small
                            onClicked: triggerRuleDialog.openForEdit(index)
                        }

                        Base.AppButton {
                            visible: ruleCard.hovered || hovered
                            text: qsTr("删除")
                            size: UiStyle.ButtonSize.Small
                            variant: UiStyle.ButtonVariant.Danger
                            onClicked: triggerRuleModel.remove(index)
                        }
                    }
                }
            }

            Base.AppText {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: triggerRuleModel.count === 0
                text: root.deviceOptions.length === 0
                    ? qsTr("暂无可用的外部触发设备")
                    : (root.timelineOptions.length === 0
                        ? qsTr("暂无可触发的时间线")
                        : qsTr("暂无规则，外部数据不会随播放头执行"))
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Base.AppDialog {
        id: triggerRuleDialog

        parent: root.dialogParent

        property int editingIndex: -1
        property string sourceDeviceId: ""
        property string eventKey: ""
        property string comparison: "=="
        property string expectedValue: ""
        property string targetTimelineId: ""
        property string playMode: "switch"
        property bool ruleEnabled: true
        readonly property bool editing: editingIndex >= 0
        readonly property bool formValid: sourceDeviceId.length > 0
            && eventKey.trim().length > 0
            && expectedValue.trim().length > 0
            && targetTimelineId.length > 0

        function openForCreate() {
            editingIndex = -1
            sourceDeviceId = root.deviceOptions.length > 0
                ? String(root.deviceOptions[0].value)
                : ""
            eventKey = ""
            comparison = "=="
            expectedValue = ""
            targetTimelineId = root.timelineOptions.length > 0
                ? String(root.timelineOptions[0].value)
                : ""
            playMode = "switch"
            ruleEnabled = true
            open()
            Qt.callLater(function() { eventKeyField.forceActiveFocus() })
        }

        function openForEdit(index) {
            var rule = triggerRuleModel.get(index)
            editingIndex = index
            sourceDeviceId = String(rule.sourceDeviceId || "")
            eventKey = String(rule.eventKey || "")
            comparison = String(rule.comparison || "==")
            expectedValue = String(rule.expectedValue || "")
            targetTimelineId = String(rule.targetTimelineId || "")
            playMode = String(rule.playMode || "switch")
            ruleEnabled = rule.enabled
            open()
        }

        function commit() {
            if (!formValid)
                return

            var rule = {
                "sourceDeviceId": sourceDeviceId,
                "sourceDeviceName": root.optionLabel(root.deviceOptions, sourceDeviceId),
                "eventKey": eventKey.trim(),
                "comparison": comparison,
                "expectedValue": expectedValue.trim(),
                "targetTimelineId": targetTimelineId,
                "targetTimelineName": root.optionLabel(root.timelineOptions, targetTimelineId),
                "playMode": playMode,
                "playModeLabel": root.optionLabel(playModeSelect.options, playMode),
                "enabled": ruleEnabled
            }
            if (editing)
                triggerRuleModel.set(editingIndex, rule)
            else
                triggerRuleModel.append(rule)
            close()
        }

        width: Math.min(620, Math.max(440, parent ? parent.width - 96 : 560))
        maximumDialogHeight: Math.min(620, Math.max(400, parent ? parent.height - 96 : 520))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        title: editing ? qsTr("编辑外部触发规则") : qsTr("添加外部触发规则")
        message: qsTr("设备数据满足条件后触发目标时间线，与播放头时间无关。")
        rejectText: qsTr("取消")
        acceptText: editing ? qsTr("保存") : qsTr("添加")
        acceptEnabled: root.editable && formValid
        closeOnAccepted: false
        onAccepted: commit()

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 10
            rowSpacing: 10

            Base.AppText {
                text: qsTr("触发设备")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }

            Base.AppSelect {
                Layout.fillWidth: true
                options: root.deviceOptions
                value: triggerRuleDialog.sourceDeviceId
                onValueSelected: triggerRuleDialog.sourceDeviceId = String(nextValue || "")
            }

            Base.AppText {
                text: qsTr("数据字段")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }

            Base.AppTextField {
                id: eventKeyField

                Layout.fillWidth: true
                text: triggerRuleDialog.eventKey
                placeholderText: qsTr("例如：regionState")
                onTextChanged: triggerRuleDialog.eventKey = text
            }

            Base.AppText {
                text: qsTr("判断条件")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Base.AppSelect {
                    Layout.preferredWidth: 100
                    options: [
                        { "label": "=", "value": "==" },
                        { "label": "≠", "value": "!=" },
                        { "label": ">", "value": ">" },
                        { "label": "≥", "value": ">=" },
                        { "label": "<", "value": "<" },
                        { "label": "≤", "value": "<=" }
                    ]
                    value: triggerRuleDialog.comparison
                    onValueSelected: triggerRuleDialog.comparison = String(nextValue || "==")
                }

                Base.AppTextField {
                    Layout.fillWidth: true
                    text: triggerRuleDialog.expectedValue
                    placeholderText: qsTr("期望值")
                    onTextChanged: triggerRuleDialog.expectedValue = text
                }
            }

            Base.AppText {
                text: qsTr("目标时间线")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }

            Base.AppSelect {
                Layout.fillWidth: true
                options: root.timelineOptions
                value: triggerRuleDialog.targetTimelineId
                onValueSelected: triggerRuleDialog.targetTimelineId = String(nextValue || "")
            }

            Base.AppText {
                text: qsTr("播放方式")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }

            Base.AppSelect {
                id: playModeSelect

                Layout.fillWidth: true
                options: [
                    { "label": qsTr("切换播放"), "value": "switch" },
                    { "label": qsTr("并行播放"), "value": "parallel" },
                    { "label": qsTr("当前结束后播放"), "value": "queue" }
                ]
                value: triggerRuleDialog.playMode
                onValueSelected: triggerRuleDialog.playMode = String(nextValue || "switch")
            }
        }
    }
}
