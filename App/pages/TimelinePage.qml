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
    property var timelinePlanController: appRuntime && appRuntime.timelinePlanController
        ? appRuntime.timelinePlanController
        : null
    property var timelineController: appRuntime && appRuntime.timelineController
        ? appRuntime.timelineController
        : null
    readonly property var timelinePlans: timelinePlanController && timelinePlanController.plans
        ? timelinePlanController.plans
        : []
    readonly property bool timelineStopped: !timelineController || timelineController.state === 0
    readonly property var selectedPlanIds: timelinePlanController
        ? timelinePlanController.selectedPlanIds
        : []
    readonly property int checkedPlanCount: selectedPlanIds.length
    readonly property bool editing: ApplicationWindow.window
        ? ApplicationWindow.window.timelineEditing
        : false


    Connections {
        target: root.timelinePlanController
        function onCurrentPlanChanged() {
            editorTimelinePlanSelector.value = root.timelinePlanController
                ? root.timelinePlanController.currentPlanIndex
                : -1
        }
    }

    function isPlanChecked(planId) {
        return checkedPlanNumber(planId) > 0
    }

    function checkedPlanNumber(planId) {
        return selectedPlanIds.indexOf(String(planId || "")) + 1
    }

    function togglePlanChecked(planId) {
        if (timelinePlanController)
            timelinePlanController.togglePlanSelected(String(planId || ""))
    }

    function createPlan(name) {
        if (!timelinePlanController || !timelineStopped || String(name || "").trim().length === 0)
            return -1
        return timelinePlanController.createPlan(String(name).trim())
    }

    function removePlan(plan) {
        if (!timelinePlanController || !timelineStopped || timelinePlans.length <= 1 || !plan)
            return

        var planIndex = Number(plan.index)
        timelinePlanController.currentPlanIndex = planIndex
        if (timelinePlanController.currentPlanIndex !== planIndex)
            return

        timelinePlanController.removeCurrentPlan()
    }

    function editPlan(plan) {
        if (!timelinePlanController || !plan)
            return

        var planIndex = Number(plan.index)
        timelinePlanController.currentPlanIndex = planIndex
        if (timelinePlanController.currentPlanIndex !== planIndex)
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
                    visible: root.checkedPlanCount > 0
                    Layout.alignment: Qt.AlignRight
                    text: qsTr("已选 %1 项").arg(root.checkedPlanCount)
                    styleRole: UiStyle.TypographyRole.BodyM
                    textTone: UiStyle.TextTone.Accent
                }

                GridView {
                    id: planGrid

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    cellWidth: 190
                    cellHeight: 190
                    model: root.timelinePlans.length + 1
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Item {
                        id: planCell

                        readonly property bool addItem: index === root.timelinePlans.length
                        readonly property var planData: addItem ? null : root.timelinePlans[index]
                        readonly property string planId: planData ? String(planData.id || "") : ""
                        readonly property bool checked: !addItem && root.isPlanChecked(planId)
                        readonly property int checkedNumber: root.checkedPlanNumber(planId)
                        readonly property bool current: !addItem
                            && root.timelinePlanController
                            && Number(planData.index) === root.timelinePlanController.currentPlanIndex
                        readonly property bool playing: !addItem && Boolean(planData.playbackActive)
                        readonly property bool completed: !addItem && Boolean(planData.playbackCompleted)
                        readonly property real playProgress: completed
                            ? 1
                            : (playing && root.timelineController.durationMs > 0
                               ? Math.max(0, Math.min(1, root.timelineController.currentTimeMs
                                                     / root.timelineController.durationMs))
                               : 0)

                        width: planGrid.cellWidth
                        height: planGrid.cellHeight

                        Base.AppCard {
                            id: planCard

                            anchors.fill: parent
                            anchors.margins: 8
                            text: planCell.addItem
                                ? qsTr("新建时间轴")
                                : String(planCell.planData.name || qsTr("未命名时间轴"))
                            checkable: false
                            checked: planCell.checked
                            emphasizedSelection: true
                            enabled: !planCell.addItem || root.timelineStopped
                            onCheckedChanged: {
                                if (checked !== planCell.checked)
                                    checked = Qt.binding(function() { return planCell.checked })
                            }
                            onClicked: {
                                if (planCell.addItem)
                                    createPlanPopupLoader.openForCreate()
                                else
                                    root.editPlan(planCell.planData)
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.Wrap
                                text: planCell.addItem ? "+" : String(planCell.planData.name || qsTr("未命名时间轴"))
                                styleRole: planCell.addItem ? UiStyle.TypographyRole.TitleL : UiStyle.TypographyRole.TitleM
                                textTone: planCell.addItem ? UiStyle.TextTone.Accent : UiStyle.TextTone.Primary
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
                            visible: planCell.playing || planCell.completed

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: root.pageTheme.colors.backgroundWindowVariant
                            }

                            Rectangle {
                                width: parent.width * planCell.playProgress
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
                            visible: !planCell.addItem && (planCard.hovered || hovered)
                            text: "×"
                            size: UiStyle.ButtonSize.Small
                            minWidth: 28
                            enabled: root.timelineStopped && root.timelinePlans.length > 1
                            opacity: enabled ? 1 : 0.35
                            onClicked: removePlanPopupLoader.openForPlan(planCell.planData)
                        }

                        Item {
                            z: 2
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: 16
                            anchors.bottomMargin: 16
                            width: 22
                            height: 22
                            visible: !planCell.addItem
                                && (planCard.hovered || checkPlanMouse.containsMouse || planCell.checked)

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: planCell.checked
                                    ? root.pageTheme.colors.highlightFill
                                    : root.pageTheme.colors.disabledFill
                                border.width: 1
                                border.color: planCell.checked
                                    ? root.pageTheme.colors.highlightText
                                    : root.pageTheme.colors.controlBorder
                            }

                            Base.AppText {
                                anchors.centerIn: parent
                                visible: planCell.checked
                                text: String(planCell.checkedNumber)
                                styleRole: UiStyle.TypographyRole.BodyS
                                colorOverride: root.pageTheme.colors.inverseText
                            }

                            MouseArea {
                                id: checkPlanMouse

                                anchors.fill: parent
                                enabled: root.timelineStopped
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.togglePlanChecked(planCell.planId)
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
                            id: editorTimelinePlanSelector

                            Layout.preferredWidth: 210
                            options: root.timelinePlans
                            textRole: "name"
                            valueRole: "index"
                            value: root.timelinePlanController
                                ? root.timelinePlanController.currentPlanIndex
                                : -1
                            enabled: root.timelinePlanController !== null && root.timelineStopped
                            onValueSelected: {
                                if (root.timelinePlanController)
                                    root.timelinePlanController.currentPlanIndex = Number(nextValue)
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
        id: createPlanPopupLoader

        active: false

        function openForCreate() {
            active = true
            item.openForCreate()
        }

        sourceComponent: Component {
            Base.AppDialog {
                id: createPlanPopup
                parent: root
                onClosed: createPlanPopupLoader.active = false

        property string planName: ""

        function openForCreate() {
            planName = qsTr("时间轴 %1").arg(root.timelinePlans.length + 1)
            open()
            Qt.callLater(function() {
                createPlanNameField.forceActiveFocus()
                createPlanNameField.selectAll()
            })
        }

        function commit() {
            if (root.createPlan(planName) >= 0)
                close()
        }

        width: Math.min(420, Math.max(320, parent ? parent.width - 96 : 380))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        title: qsTr("新建时间轴")
        rejectText: qsTr("取消")
        acceptText: qsTr("创建")
        acceptEnabled: planName.trim().length > 0
        initialFocusItem: createPlanNameField
        closeOnAccepted: false
        onAccepted: commit()

        Base.AppTextField {
            id: createPlanNameField

            Layout.fillWidth: true
            text: createPlanPopup.planName
            placeholderText: qsTr("时间轴名称")
            onTextChanged: createPlanPopup.planName = text
        }
            }
        }
    }

    Loader {
        id: removePlanPopupLoader

        active: false

        function openForPlan(plan) {
            active = true
            item.openForPlan(plan)
        }

        sourceComponent: Component {
            Base.AppDialog {
                id: removePlanPopup
                parent: root
                onClosed: removePlanPopupLoader.active = false

        property var planData: null

        function openForPlan(plan) {
            planData = plan
            open()
        }

        function commit() {
            root.removePlan(planData)
        }

        width: Math.min(420, Math.max(320, parent ? parent.width - 96 : 380))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        title: qsTr("删除时间轴")
        message: qsTr("确定删除“%1”？其中的时间轴指令也会被删除。")
            .arg(removePlanPopup.planData ? removePlanPopup.planData.name : "")
        rejectText: qsTr("取消")
        acceptText: qsTr("删除")
        acceptButtonVariant: UiStyle.ButtonVariant.Danger
        onAccepted: commit()
            }
        }
    }
}
