import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import QtQuick.Dialogs 1.3
import QtQuick.Layouts 1.14
import "qrc:/UICore/qml" as Ui
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/components/shell" as Shell
import "qrc:/UICore/qml/components/task" as Task
import "qrc:/UICore/qml/theme" as Theme

ApplicationWindow {
    id: window

    property QtObject appTheme: Theme.AppTheme {}
    property var appRuntime: typeof app !== "undefined" ? app : null
    property var timelineManager: appRuntime && appRuntime.timelineManager
        ? appRuntime.timelineManager
        : null
    property var shellController: appRuntime && appRuntime.shell
        ? appRuntime.shell
        : (typeof timelineShellController !== "undefined" ? timelineShellController : null)
    property bool timelineEditing: false
    readonly property var settingsNavigationItem: ({
        "key": "system-settings",
        "label": qsTr("系统设置"),
        "iconName": "layer-config",
        "source": "qrc:/TimelineControlApp/App/pages/SystemSettingsPane.qml"
    })
    readonly property string defaultCanvasDelegateSource: appRuntime && appRuntime.settings
        ? String(appRuntime.settings.value("canvasDelegateSource", ""))
        : ""
    readonly property bool timelineStopped: !timelineManager || timelineManager.playbackState === 0
    readonly property bool timelinePaused: timelineManager && timelineManager.playbackState === 2
    readonly property bool timelineCompleted: timelineManager && timelineManager.playbackState === 3

    function activateNavigation(key) {
        var items = shell.navigationItems || []
        for (var index = 0; index < items.length; ++index) {
            var item = items[index]
            if (String(item.key) === String(key)) {
                shell.hideLeftPane()
                shell.activeNavigationKey = String(key)
                shell.canvasDelegateSource = String(item.source || "")
                shell.focusCanvas()
                return
            }
        }

        shell.activeNavigationKey = String(key)
        shell.canvasDelegateSource = defaultCanvasDelegateSource
    }

    width: appTheme.metrics.windowWidth
    height: appTheme.metrics.windowHeight
    minimumWidth: appTheme.metrics.windowMinWidth
    minimumHeight: appTheme.metrics.windowMinHeight
    visible: true
    title: appRuntime && appRuntime.settings && appRuntime.settings.applicationName
        ? String(appRuntime.settings.applicationName)
        : qsTr("时间线控制应用")
    color: appTheme.colors.backgroundWindow
    Component.onCompleted: activateNavigation(shellController
        ? shellController.activeNavigationKey
        : "")

    Ui.AppShell {
        id: shell

        anchors.fill: parent
        applicationTitle: window.title
        navigationItems: window.shellController ? window.shellController.navigationItems : []
        leftPaneDisplayMode: Shell.AppSidebarPane.Hidden
        leftPanelWidth: 320
        canvasInteractionState: window.shellController
            ? window.shellController.canvasInteractionState
            : "idle"
        canvasDelegateSource: window.defaultCanvasDelegateSource

        sidebar.footerContent: Component {
            Shell.AppRailButton {
                text: window.settingsNavigationItem.label
                iconName: window.settingsNavigationItem.iconName
                showText: shell.sidebar.showItemLabels
                active: shell.activeNavigationKey === window.settingsNavigationItem.key
                onClicked: {
                    if (active && shell.leftPaneOpen) {
                        shell.hideLeftPane()
                        shell.activeNavigationKey = window.shellController
                            ? window.shellController.activeNavigationKey
                            : ""
                        return
                    }

                    shell.leftPaneSource = window.settingsNavigationItem.source
                    shell.activeNavigationKey = window.settingsNavigationItem.key
                    shell.showLeftPane()
                }

                ToolTip.visible: hovered && !showText
                ToolTip.text: text
            }
        }

        topNavigationBar.content: Component {
            RowLayout {
                spacing: window.appTheme.density.controlGap

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: window.timelineCompleted
                        ? window.appTheme.colors.warningFill
                        : (window.timelineStopped
                            ? window.appTheme.colors.dangerFill
                            : window.appTheme.colors.successFill)
                }

                Base.AppButton {
                    size: UiStyle.ButtonSize.Small
                    variant: window.timelineStopped
                        ? UiStyle.ButtonVariant.Primary
                        : UiStyle.ButtonVariant.Secondary
                    text: window.timelineStopped ? qsTr("开始") : qsTr("停止")
                    iconName: window.timelineStopped ? "play" : "stop"
                    enabled: !window.timelineStopped
                        || (window.timelineManager
                            && window.timelineManager.playQueue.length > 0)
                    onClicked: {
                        if (window.shellController)
                            window.shellController.handleUiAction(
                                window.timelineStopped ? "timeline.start" : "timeline.stop",
                                {}
                            )
                    }
                }

                Base.AppButton {
                    size: UiStyle.ButtonSize.Small
                    variant: UiStyle.ButtonVariant.Secondary
                    text: window.timelinePaused ? qsTr("继续") : qsTr("暂停")
                    iconName: window.timelinePaused ? "play" : "pause"
                    enabled: !window.timelineStopped && !window.timelineCompleted
                    onClicked: {
                        if (window.shellController)
                            window.shellController.handleUiAction(
                                window.timelinePaused ? "timeline.start" : "timeline.pause",
                                {}
                            )
                    }
                }

                Base.AppButton {
                    id: plansButton

                    size: UiStyle.ButtonSize.Small
                    variant: UiStyle.ButtonVariant.Ghost
                    text: window.appRuntime && window.appRuntime.currentPlanName.length > 0
                        ? window.appRuntime.currentPlanName
                        : qsTr("未选择方案")
                    enabled: window.timelineStopped
                    onClicked: planPopup.opened ? planPopup.close() : planPopup.open()
                }

                Item {
                    Layout.fillWidth: true
                }

                Base.AppButton {
                    id: taskButton

                    size: UiStyle.ButtonSize.Small
                    variant: UiStyle.ButtonVariant.Ghost
                    iconName: "background-task"
                    text: window.appRuntime && window.appRuntime.taskManager
                        && window.appRuntime.taskManager.activeTaskCount > 0
                        ? String(window.appRuntime.taskManager.activeTaskCount)
                        : ""
                    onClicked: taskPopup.opened ? taskPopup.close() : taskPopup.open()
                }

                Base.AppPopup {
                    id: planPopup

                    parent: window.contentItem
                    width: 240
                    modal: false
                    showModalOverlay: false
                    surfaceTone: UiStyle.SurfaceTone.SurfaceOverlay
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    onAboutToShow: {
                        var origin = plansButton.mapToItem(
                            parent,
                            0,
                            plansButton.height + 8
                        )
                        x = origin.x
                        y = origin.y
                    }

                    Base.AppButton {
                        Layout.fillWidth: true
                        text: qsTr("保存")
                        enabled: window.timelineStopped
                            && window.appRuntime
                            && window.appRuntime.currentPlanFilePath.length > 0
                        onClicked: {
                            planPopup.close()
                            if (window.shellController)
                                window.shellController.handleUiAction("timeline.plan.save", {
                                    "filePath": window.appRuntime.currentPlanFilePath
                                })
                        }
                    }

                    Base.AppButton {
                        Layout.fillWidth: true
                        text: qsTr("另存为")
                        enabled: window.timelineStopped
                        onClicked: {
                            planPopup.close()
                            savePlanDialog.open()
                        }
                    }

                    Base.AppButton {
                        Layout.fillWidth: true
                        text: qsTr("加载")
                        enabled: window.timelineStopped
                        onClicked: {
                            planPopup.close()
                            loadPlanDialog.open()
                        }
                    }
                }

                Task.AppTaskPanel {
                    id: taskPopup

                    parent: window.contentItem
                    anchorItem: taskButton
                    taskItems: window.appRuntime && window.appRuntime.taskManager
                        ? window.appRuntime.taskManager.tasks
                        : []
                    taskItemCount: window.appRuntime && window.appRuntime.taskManager
                        ? window.appRuntime.taskManager.taskCount
                        : 0
                    activeTaskCount: window.appRuntime && window.appRuntime.taskManager
                        ? window.appRuntime.taskManager.activeTaskCount
                        : 0
                    topBarHeight: shell.topBarHeight
                    overlayMargin: shell.overlayMargin
                }

                FileDialog {
                    id: savePlanDialog

                    title: qsTr("保存时间线方案")
                    selectExisting: false
                    nameFilters: [qsTr("时间线方案 (*.tlplan)"), qsTr("所有文件 (*)")]
                    onAccepted: {
                        if (window.timelineStopped && window.shellController)
                            window.shellController.handleUiAction("timeline.plan.save", {
                                "filePath": fileUrl
                            })
                    }
                }

                FileDialog {
                    id: loadPlanDialog

                    title: qsTr("加载时间线方案")
                    selectExisting: true
                    nameFilters: [qsTr("时间线方案 (*.tlplan)"), qsTr("所有文件 (*)")]
                    onAccepted: {
                        if (window.timelineStopped && window.shellController)
                            window.shellController.handleUiAction("timeline.plan.load", {
                                "filePath": fileUrl
                            })
                    }
                }
            }
        }

        onNavigationRequested: function(key) {
            shell.hideLeftPane()
            if (window.shellController)
                window.shellController.activeNavigationKey = key
            window.activateNavigation(key)
        }
    }

    Connections {
        target: window.shellController

        function onActiveNavigationKeyChanged() {
            if (shell.activeNavigationKey !== window.shellController.activeNavigationKey)
                window.activateNavigation(window.shellController.activeNavigationKey)
        }
    }

    Connections {
        target: shell.sidebarPane

        function onOpenedChanged() {
            if (!shell.leftPaneOpen
                    && shell.activeNavigationKey === window.settingsNavigationItem.key
                    && window.shellController)
                shell.activeNavigationKey = window.shellController.activeNavigationKey
        }
    }
}
