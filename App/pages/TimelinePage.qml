import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UiCore/qml/components/base" as Base
import "qrc:/UiCore/qml/theme" as Theme

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
        if (!timelinePlanController || !timelineStopped || !plan)
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
                anchors.margins: 24
                spacing: 18

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Base.AppText {
                            text: qsTr("时间轴")
                            theme: root.pageTheme
                            styleRole: "titleL"
                        }

                        Base.AppText {
                            text: qsTr("选择时间轴进入编辑，或创建新的时间轴")
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }
                    }

                    Base.AppText {
                        visible: root.checkedPlanCount > 0
                        text: qsTr("已选 %1 项").arg(root.checkedPlanCount)
                        theme: root.pageTheme
                        styleRole: "bodyM"
                        textTone: "accent"
                    }
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

                        Base.AppSurface {
                            anchors.fill: parent
                            anchors.margins: 8
                            sizeToContent: false
                            theme: root.pageTheme
                            surfaceTone: planCell.checked ? "highlight" : "section"
                            active: planCell.checked || planCell.current
                            hoveredState: planMouse.containsMouse
                            interactive: true
                            strokeWidth: planCell.checked || planCell.current || planMouse.containsMouse ? 1 : 0
                            borderOverride: planCell.checked
                                ? "#60a5fa"
                                : (planCell.current ? "#3b82f6" : "#334155")
                            hoverOverlayOpacity: 0.08
                        }

                        MouseArea {
                            id: planMouse

                            anchors.fill: parent
                            anchors.margins: 8
                            hoverEnabled: true
                            enabled: root.timelineStopped
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (planCell.addItem)
                                    createPlanPopup.openForCreate()
                                else
                                    root.editPlan(planCell.planData)
                            }
                        }

                        Base.AppText {
                            anchors.centerIn: parent
                            width: parent.width - 42
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: planCell.addItem ? "+" : String(planCell.planData.name || qsTr("未命名时间轴"))
                            theme: root.pageTheme
                            styleRole: planCell.addItem ? "titleL" : "titleM"
                            textTone: planCell.addItem ? "accent" : "primary"
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
                                color: root.pageTheme.colors.windowAccent
                            }

                            Rectangle {
                                width: parent.width * planCell.playProgress
                                height: parent.height
                                radius: height / 2
                                color: root.pageTheme.colors.highlightFill
                            }
                        }

                        Item {
                            z: 2
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 14
                            anchors.rightMargin: 14
                            width: 26
                            height: 26
                            visible: !planCell.addItem && planMouse.containsMouse
                            opacity: root.timelinePlans.length > 1 ? 1 : 0.35

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "#991b1b"
                            }

                            Base.AppText {
                                anchors.centerIn: parent
                                text: "×"
                                theme: root.pageTheme
                                styleRole: "bodyM"
                                colorOverride: "#ffffff"
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.timelinePlans.length > 1
                                cursorShape: Qt.PointingHandCursor
                                onClicked: removePlanPopup.openForPlan(planCell.planData)
                            }
                        }

                        Item {
                            z: 2
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: 16
                            anchors.bottomMargin: 16
                            width: 22
                            height: 22
                            visible: !planCell.addItem && (planMouse.containsMouse || planCell.checked)

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: planCell.checked ? "#2563eb" : "#111827"
                                border.width: 1
                                border.color: planCell.checked ? "#60a5fa" : "#64748b"
                            }

                            Base.AppText {
                                anchors.centerIn: parent
                                visible: planCell.checked
                                text: String(planCell.checkedNumber)
                                theme: root.pageTheme
                                styleRole: "bodyS"
                                colorOverride: "#ffffff"
                            }

                            MouseArea {
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
                            iconSymbol: "←"
                            theme: root.pageTheme
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
                            theme: root.pageTheme
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

    Base.AppPopup {
        id: createPlanPopup

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

        modal: true
        focus: true
        width: Math.min(420, Math.max(320, parent ? parent.width - 96 : 380))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        padding: 18
        spacing: 14
        theme: root.pageTheme
        surfaceTone: "section"
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("新建时间轴")
            theme: root.pageTheme
            styleRole: "titleM"
        }

        Base.AppTextField {
            id: createPlanNameField

            Layout.fillWidth: true
            text: createPlanPopup.planName
            placeholderText: qsTr("时间轴名称")
            theme: root.pageTheme
            onTextChanged: createPlanPopup.planName = text
            onAccepted: createPlanPopup.commit()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.fillWidth: true
            }

            Base.AppButton {
                text: qsTr("取消")
                theme: root.pageTheme
                onClicked: createPlanPopup.close()
            }

            Base.AppButton {
                text: qsTr("创建")
                theme: root.pageTheme
                enabled: createPlanPopup.planName.trim().length > 0
                onClicked: createPlanPopup.commit()
            }
        }
    }

    Base.AppPopup {
        id: removePlanPopup

        property var planData: null

        function openForPlan(plan) {
            planData = plan
            open()
        }

        function commit() {
            root.removePlan(planData)
            close()
        }

        modal: true
        focus: true
        width: Math.min(420, Math.max(320, parent ? parent.width - 96 : 380))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        padding: 18
        spacing: 14
        theme: root.pageTheme
        surfaceTone: "section"
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("删除时间轴")
            theme: root.pageTheme
            styleRole: "titleM"
        }

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("确定删除“%1”？其中的时间轴指令也会被删除。")
                .arg(removePlanPopup.planData ? removePlanPopup.planData.name : "")
            theme: root.pageTheme
            styleRole: "bodyM"
            textTone: "secondary"
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.fillWidth: true
            }

            Base.AppButton {
                text: qsTr("取消")
                theme: root.pageTheme
                onClicked: removePlanPopup.close()
            }

            Base.AppButton {
                text: qsTr("删除")
                theme: root.pageTheme
                onClicked: removePlanPopup.commit()
            }
        }
    }
}
