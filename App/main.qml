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
    readonly property bool timelineRunning: timelineManager && timelineManager.playbackState === 1
    readonly property bool timelinePaused: timelineManager && timelineManager.playbackState === 2
    readonly property bool timelineCompleted: timelineManager && timelineManager.playbackState === 3
    readonly property bool hasQueuedTimelines: timelineManager
        && timelineManager.playQueue.length > 0
    readonly property var availablePlaybackDevices: appRuntime && appRuntime.deviceModel
        ? appRuntime.deviceModel.devices
        : []
    readonly property var playbackDeviceIds: timelineManager
        ? timelineManager.playbackDevices
        : []
    readonly property int playbackDeviceCount: playbackDeviceIds.length
    readonly property string playbackStateText: timelineRunning
        ? qsTr("播放中")
        : (timelinePaused
            ? qsTr("已暂停")
            : (timelineCompleted ? qsTr("已完成") : qsTr("待播放")))
    readonly property string playbackActionText: timelineRunning
        ? qsTr("暂停")
        : (timelinePaused
            ? qsTr("继续播放")
            : (hasQueuedTimelines ? qsTr("播放队列") : qsTr("播放当前节目")))

    function playbackDeviceSelected(deviceId) {
        return playbackDeviceIds.indexOf(String(deviceId || "")) >= 0
    }

    function setPlaybackDevices(deviceIds) {
        if (timelineManager && timelineStopped)
            timelineManager.playbackDevices = deviceIds
    }

    function togglePlaybackDevice(deviceId) {
        if (!timelineManager || !timelineStopped)
            return

        var id = String(deviceId || "")
        var deviceIds = playbackDeviceIds.slice()
        var index = deviceIds.indexOf(id)
        if (index >= 0)
            deviceIds.splice(index, 1)
        else
            deviceIds.push(id)
        setPlaybackDevices(deviceIds)
    }

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
                    implicitWidth: playbackControls.implicitWidth + 12
                    implicitHeight: 40
                    radius: 8
                    color: window.appTheme.colors.backgroundSection
                    border.width: 1
                    border.color: window.appTheme.colors.border

                    RowLayout {
                        id: playbackControls

                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 6

                        Rectangle {
                            Layout.leftMargin: 4
                            width: 8
                            height: 8
                            radius: 4
                            color: window.timelineRunning
                                ? window.appTheme.colors.successFill
                                : (window.timelinePaused
                                    ? window.appTheme.colors.warningFill
                                    : window.appTheme.colors.neutralBorder)
                        }

                        Base.AppText {
                            text: window.playbackStateText
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: window.timelineRunning
                                ? UiStyle.TextTone.Success
                                : (window.timelinePaused
                                    ? UiStyle.TextTone.Warning
                                    : UiStyle.TextTone.Secondary)
                        }

                        Base.AppButton {
                            id: playbackDeviceButton

                            size: UiStyle.ButtonSize.Small
                            variant: window.playbackDeviceCount > 0
                                ? UiStyle.ButtonVariant.Danger
                                : UiStyle.ButtonVariant.Tonal
                            minWidth: window.playbackDeviceCount > 0 ? 112 : 96
                            text: window.playbackDeviceCount > 0
                                ? qsTr("过滤中 · %1 台").arg(window.playbackDeviceCount)
                                : qsTr("设备过滤")
                            iconName: "resources"
                            onClicked: playbackDevicePopup.opened
                                ? playbackDevicePopup.close()
                                : playbackDevicePopup.open()

                            ToolTip.visible: hovered
                            ToolTip.text: window.timelineStopped
                                ? qsTr("设置参与播放的设备")
                                : qsTr("播放期间不能修改设备过滤")
                        }

                        Rectangle {
                            Layout.leftMargin: 2
                            Layout.rightMargin: 2
                            width: 1
                            height: 20
                            color: window.appTheme.colors.border
                        }

                        Base.AppButton {
                            size: UiStyle.ButtonSize.Small
                            variant: UiStyle.ButtonVariant.Primary
                            minWidth: window.timelineRunning || window.timelinePaused ? 88 : 116
                            text: window.playbackActionText
                            iconName: window.timelineRunning ? "pause" : "play"
                            enabled: window.timelineRunning
                                || window.timelinePaused
                                || (window.timelineManager
                                    && (window.hasQueuedTimelines
                                        || window.timelineManager.currentTimeline))
                            onClicked: {
                                if (window.shellController)
                                    window.shellController.handleUiAction(
                                        window.timelineRunning ? "timeline.pause" : "timeline.start",
                                        {}
                                    )
                            }
                        }

                        Base.AppButton {
                            size: UiStyle.ButtonSize.Small
                            variant: UiStyle.ButtonVariant.Danger
                            minWidth: 92
                            text: qsTr("停止播放")
                            iconName: "stop"
                            enabled: !window.timelineStopped
                            onClicked: {
                                if (window.shellController)
                                    window.shellController.handleUiAction("timeline.stop", {})
                            }
                        }
                    }
                }

                Base.AppPopup {
                    id: playbackDevicePopup

                    parent: window.contentItem
                    width: 280
                    modal: false
                    showModalOverlay: false
                    surfaceTone: UiStyle.SurfaceTone.SurfaceOverlay
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    onAboutToShow: {
                        var origin = playbackDeviceButton.mapToItem(
                            parent,
                            0,
                            playbackDeviceButton.height + 8
                        )
                        x = origin.x
                        y = origin.y
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        text: qsTr("播放设备")
                        styleRole: UiStyle.TypographyRole.BodyM
                        overrideWeight: window.appTheme.typography.weightBold
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        text: window.timelineStopped
                            ? qsTr("不勾选设备时播放全部设备")
                            : qsTr("播放期间已锁定过滤范围")
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Secondary
                    }

                    Base.AppButton {
                        Layout.fillWidth: true
                        text: qsTr("全部设备")
                        iconSymbol: window.playbackDeviceCount === 0 ? "✓" : ""
                        contentAlignment: "start"
                        variant: window.playbackDeviceCount === 0
                            ? UiStyle.ButtonVariant.Tonal
                            : UiStyle.ButtonVariant.Ghost
                        enabled: window.timelineStopped
                        onClicked: window.setPlaybackDevices([])
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: window.appTheme.colors.border
                    }

                    ListView {
                        id: playbackDeviceList

                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(240,
                            Math.max(36, window.availablePlaybackDevices.length * 36))
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: window.availablePlaybackDevices
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        delegate: Base.AppCheckBox {
                            readonly property string deviceId: String(modelData.id || "")

                            width: playbackDeviceList.width
                            text: String(modelData.name || deviceId || qsTr("未命名设备"))
                            checked: window.playbackDeviceSelected(deviceId)
                            enabled: window.timelineStopped
                            onClicked: window.togglePlaybackDevice(deviceId)
                        }

                        Base.AppText {
                            anchors.centerIn: parent
                            visible: window.availablePlaybackDevices.length === 0
                            text: qsTr("暂无设备")
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                        }
                    }
                }

                Rectangle {
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    width: 1
                    height: 24
                    color: window.appTheme.colors.borderHeaderDivider
                }

                Base.AppButton {
                    id: plansButton

                    size: UiStyle.ButtonSize.Small
                    variant: UiStyle.ButtonVariant.Secondary
                    minWidth: 112
                    iconName: "workflow"
                    text: window.appRuntime && window.appRuntime.currentPlanName.length > 0
                        ? qsTr("管理工程 · %1").arg(window.appRuntime.currentPlanName)
                        : qsTr("管理工程")
                    enabled: window.timelineStopped
                    onClicked: planPopup.opened ? planPopup.close() : planPopup.open()

                    ToolTip.visible: hovered
                    ToolTip.text: window.appRuntime && window.appRuntime.currentPlanName.length > 0
                        ? qsTr("当前工程：%1").arg(window.appRuntime.currentPlanName)
                        : qsTr("保存、另存或加载工程")
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
