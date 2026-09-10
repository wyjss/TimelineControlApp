import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import QtQuick.Dialogs 1.3
import QtQuick.Layouts 1.14
import "qrc:/UICore/qml" as Ui
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/components/shell" as Shell
import "qrc:/UICore/qml/theme" as Theme
import "qrc:/TimelineControlApp/App/pages" as Pages

ApplicationWindow {
    id: window

    property QtObject appTheme: Theme.AppTheme {}
    property var appRuntime: typeof app !== "undefined" ? app : null
    property var timelineManager: appRuntime && appRuntime.timelineManager
        ? appRuntime.timelineManager
        : null
    property var shellController: appRuntime && appRuntime.shell
        ? appRuntime.shell
        : null
    property int timelineStartTimeMs: 0
    property bool timelineEditing: false
    property bool locatorMonitorOpen: false
    readonly property bool locatorManagementActive: shell.activeNavigationKey === "locator"
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
            : (hasQueuedTimelines ? qsTr("播放顺序") : qsTr("播放当前节目")))

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
    minimumWidth: Math.min(appTheme.metrics.windowMinWidth, screen.width - 32)
    minimumHeight: Math.min(appTheme.metrics.windowMinHeight, screen.height - 64)
    visible: false
    title: appRuntime && appRuntime.settings && appRuntime.settings.applicationName
        ? String(appRuntime.settings.applicationName)
        : qsTr("时间线控制应用")
    color: appTheme.colors.backgroundWindow
    Component.onCompleted: {
        var screens = Qt.application.screens
        for (var index = 0; index < screens.length; ++index) {
            if (screens[index].virtualX < screen.virtualX)
                screen = screens[index]
        }
        width = Math.min(width, screen.width - 32)
        height = Math.min(height, screen.height - 64)
        x = screen.virtualX + Math.round((screen.width - width) / 2)
        y = screen.virtualY + Math.round((screen.height - height) / 2)
        activateNavigation(shellController ? shellController.activeNavigationKey : "")
        visible = true
    }

    Ui.AppShell {
        id: shell

        anchors.fill: parent
        applicationTitle: window.title
        navigationItems: window.shellController ? window.shellController.navigationItems : []
        sidebar.itemDelegate: Component {
            Shell.AppRailButton {
                id: navigationButton

                readonly property string itemKey: String(modelData && modelData.key || "")
                readonly property string itemLabel: String(modelData && modelData.label || "")
                readonly property url itemIconSource: modelData && modelData.iconSource !== undefined
                    ? modelData.iconSource
                    : ""

                Layout.fillWidth: true
                buttonSize: shell.sidebar.resolvedTheme.shell.railButtonSize
                implicitHeight: showText
                    ? navigationIcon.height + navigationText.implicitHeight
                        + resolvedTheme.shell.railPadding
                        + resolvedTheme.density.controlGap
                    : buttonSize
                animated: shell.sidebar.animated
                text: itemLabel
                showText: shell.sidebar.showItemLabels
                iconName: String(modelData && modelData.iconName || "")
                active: itemKey === shell.sidebar.activeItemKey
                enabled: !modelData || modelData.enabled === undefined || !!modelData.enabled
                visible: !modelData || modelData.visible === undefined || !!modelData.visible
                onClicked: {
                    shell.sidebar.itemActivated(itemKey, modelData)
                    shell.sidebar.itemTriggered(itemKey)
                }
                onDoubleClicked: navigationButton.clicked()

                contentItem: Item {
                    implicitWidth: navigationButton.buttonSize
                    implicitHeight: navigationButton.buttonSize

                    Base.AppIcon {
                        id: navigationIcon

                        anchors.horizontalCenter: parent.horizontalCenter
                        y: navigationButton.showText
                            ? navigationButton.resolvedTheme.shell.railPadding / 2
                            : Math.round((parent.height - height) / 2)
                        name: navigationButton.itemIconSource.toString().length > 0
                            ? ""
                            : navigationButton.iconName
                        source: navigationButton.itemIconSource
                        size: Math.round(navigationButton.buttonSize * 0.6)
                        color: navigationButton.iconTint
                        animateColor: navigationButton.animated
                    }

                    Base.AppText {
                        id: navigationText

                        anchors.top: navigationIcon.bottom
                        anchors.topMargin: navigationButton.resolvedTheme.density.controlGap
                        anchors.left: parent.left
                        anchors.leftMargin: navigationButton.resolvedTheme.shell.railPadding / 2
                        anchors.right: parent.right
                        anchors.rightMargin: navigationButton.resolvedTheme.shell.railPadding / 2
                        visible: navigationButton.showText
                        text: navigationButton.text
                        styleRole: UiStyle.TypographyRole.BodyS
                        colorOverride: navigationButton.iconTint
                        animateColor: navigationButton.animated
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                ToolTip.visible: hovered && (!showText || navigationText.truncated)
                ToolTip.text: text
            }
        }
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
                spacing: window.appTheme.density.paneSpacing

                RowLayout {
                    id: playbackControls

                    Layout.alignment: Qt.AlignVCenter
                    spacing: window.appTheme.density.controlGap

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
                        Layout.rightMargin: window.appTheme.density.controlGap
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

                        raised: variant === UiStyle.ButtonVariant.Secondary
                        size: UiStyle.ButtonSize.Medium
                        variant: window.playbackDeviceCount > 0
                            ? UiStyle.ButtonVariant.Tonal
                            : UiStyle.ButtonVariant.Secondary
                        minWidth: 116
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
                        size: UiStyle.ButtonSize.Medium
                        variant: UiStyle.ButtonVariant.Primary
                        minWidth: 144
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
                                    { startTimeMs: window.timelineStartTimeMs }
                                )
                        }
                    }

                    Base.AppButton {
                        size: UiStyle.ButtonSize.Medium
                        variant: UiStyle.ButtonVariant.Danger
                        minWidth: 112
                        text: qsTr("停止播放")
                        iconName: "stop"
                        enabled: !window.timelineStopped
                        onClicked: {
                            if (window.shellController)
                                window.shellController.handleUiAction("timeline.stop", {})
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
                    color: window.appTheme.colors.controlBorder
                }

                Base.AppButton {
                    id: plansButton

                    raised: true
                    Layout.maximumWidth: 240
                    size: UiStyle.ButtonSize.Medium
                    variant: UiStyle.ButtonVariant.Secondary
                    minWidth: 128
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
                        raised: true
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
                        raised: true
                        Layout.fillWidth: true
                        text: qsTr("另存为")
                        enabled: window.timelineStopped
                        onClicked: {
                            planPopup.close()
                            savePlanDialog.open()
                        }
                    }

                    Base.AppButton {
                        raised: true
                        Layout.fillWidth: true
                        text: qsTr("加载")
                        enabled: window.timelineStopped
                        onClicked: {
                            planPopup.close()
                            loadPlanDialog.open()
                        }
                    }
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

        topNavigationBar.trailingContent: Component {
            RowLayout {
                Base.AppButton {
                    raised: variant === UiStyle.ButtonVariant.Secondary
                    size: UiStyle.ButtonSize.Medium
                    variant: window.locatorMonitorOpen
                        ? UiStyle.ButtonVariant.Tonal
                        : UiStyle.ButtonVariant.Secondary
                    minWidth: 116
                    iconName: "scene"
                    text: qsTr("定位监视")
                    onClicked: window.locatorMonitorOpen = true
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

    Base.AppSurface {
        id: locatorViewerHost

        readonly property bool managementMode: window.locatorManagementActive
        readonly property real hostWidth: Math.max(0, shell.width - shell.leftContentInset)
        readonly property real hostHeight: Math.max(0, shell.height - shell.topBarHeight
            - (shell.showBottomBar ? shell.bottomBarHeight : 0))
        readonly property real monitorMinX: shell.leftContentInset + shell.overlayMargin
        readonly property real monitorMaxX: Math.max(monitorMinX,
            shell.width - width - shell.overlayMargin)
        readonly property real monitorMinY: shell.topBarHeight + shell.overlayMargin
        readonly property real monitorMaxY: Math.max(monitorMinY,
            shell.height - (shell.showBottomBar ? shell.bottomBarHeight : 0)
            - height - shell.overlayMargin)
        property real monitorX: NaN
        property real monitorY: NaN

        x: managementMode
            ? shell.leftContentInset
            : Math.max(monitorMinX, Math.min(isNaN(monitorX) ? monitorMaxX : monitorX,
                                             monitorMaxX))
        y: managementMode
            ? shell.topBarHeight
            : Math.max(monitorMinY, Math.min(isNaN(monitorY) ? monitorMinY : monitorY,
                                             monitorMaxY))
        width: managementMode
            ? hostWidth
            : Math.min(520, Math.max(320, hostWidth * 0.42))
        height: managementMode
            ? hostHeight
            : Math.min(360, Math.max(240, hostHeight * 0.45))
        visible: managementMode || window.locatorMonitorOpen
        z: 10
        sizeToContent: false
        clipContent: true
        surfaceTone: managementMode
            ? UiStyle.SurfaceTone.Canvas
            : UiStyle.SurfaceTone.SurfaceOverlay
        shapeRole: managementMode ? UiStyle.ShapeRole.None : UiStyle.ShapeRole.Overlay

        Rectangle {
            id: locatorMonitorHeader

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: visible ? 40 : 0
            visible: !locatorViewerHost.managementMode
            color: window.appTheme.colors.backgroundSection
            border.width: 1
            border.color: window.appTheme.colors.border

            MouseArea {
                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                property real pressWindowX: 0
                property real pressWindowY: 0
                property real pressHostX: 0
                property real pressHostY: 0

                onPressed: {
                    var point = mapToItem(window.contentItem, mouse.x, mouse.y)
                    pressWindowX = point.x
                    pressWindowY = point.y
                    pressHostX = locatorViewerHost.x
                    pressHostY = locatorViewerHost.y
                }
                onPositionChanged: {
                    if (!pressed)
                        return
                    var point = mapToItem(window.contentItem, mouse.x, mouse.y)
                    locatorViewerHost.monitorX = Math.max(locatorViewerHost.monitorMinX,
                        Math.min(pressHostX + point.x - pressWindowX,
                                 locatorViewerHost.monitorMaxX))
                    locatorViewerHost.monitorY = Math.max(locatorViewerHost.monitorMinY,
                        Math.min(pressHostY + point.y - pressWindowY,
                                 locatorViewerHost.monitorMaxY))
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 6
                spacing: 6

                Base.AppText {
                    Layout.fillWidth: true
                    text: qsTr("定位监视")
                    styleRole: UiStyle.TypographyRole.BodyM
                }

                Base.AppButton {
                    size: UiStyle.ButtonSize.Small
                    variant: UiStyle.ButtonVariant.Ghost
                    text: qsTr("展开")
                    onClicked: {
                        if (window.shellController)
                            window.shellController.activeNavigationKey = "locator"
                        window.activateNavigation("locator")
                    }
                }

                Base.AppButton {
                    size: UiStyle.ButtonSize.Small
                    variant: UiStyle.ButtonVariant.Ghost
                    text: "×"
                    onClicked: window.locatorMonitorOpen = false
                }
            }
        }

        Pages.LocatorManagementPage {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: locatorMonitorHeader.bottom
            anchors.bottom: parent.bottom
            managementMode: locatorViewerHost.managementMode && window.timelineStopped
            deviceModel: window.appRuntime ? window.appRuntime.deviceModel : null
            fenceManager: window.appRuntime ? window.appRuntime.fenceManager : null
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
