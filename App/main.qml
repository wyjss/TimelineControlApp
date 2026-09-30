import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import QtQuick.Dialogs 1.3
import QtQuick.Layouts 1.14
import QtQuick.Window 2.14
import "qrc:/UICore/qml" as Ui
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/components/shell" as Shell
import "qrc:/UICore/qml/theme" as Theme
import "qrc:/TimelineControlApp/App/pages" as Pages
import "qrc:/TimelineControlApp/App/pages/timeline" as Timeline

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
    property bool closeConfirmed: false
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
    readonly property bool queuePlayback: timelineManager && timelineManager.queuePlayback
    readonly property string playbackStateText: timelineRunning
        ? qsTr("播放中")
        : (timelinePaused
            ? qsTr("已暂停")
            : (timelineCompleted ? qsTr("已完成") : qsTr("待播放")))
    readonly property string playbackActionText: !queuePlayback && timelineRunning
        ? qsTr("暂停")
        : (!queuePlayback && timelinePaused
            ? qsTr("继续播放")
            : qsTr("播放当前节目"))

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
    onClosing: {
        close.accepted = timelineStopped && closeConfirmed
        closeConfirmed = false

        if (window.visibility === Window.Minimized)
             window.showNormal()
        window.raise()
        window.requestActivate()

        if (!close.accepted && !exitConfirmDialog.visible)
            exitConfirmDialog.open()
    }
    onTimelineStoppedChanged: exitConfirmDialog.close()
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

    Base.AppDialog {
        id: exitConfirmDialog
        objectName: "exitConfirmDialog"

        parent: window.contentItem
        width: Math.min(420, parent.width - window.appTheme.density.pageMargin * 2)
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        title: window.timelineStopped ? qsTr("退出确认") : qsTr("无法退出")
        message: window.timelineStopped
            ? qsTr("确定退出时间线控制应用？尚未保存的工程修改将丢失。")
            : qsTr("请先停止播放，再退出应用。")
        initialFocusItem: cancelExitButton

        RowLayout {
            Layout.fillWidth: true
            spacing: exitConfirmDialog.spacing

            Item {
                Layout.fillWidth: true
            }

            Base.AppButton {
                id: cancelExitButton

                text: window.timelineStopped ? qsTr("取消") : qsTr("确认")
                variant: UiStyle.ButtonVariant.Secondary
                onClicked: exitConfirmDialog.close()
            }

            Base.AppButton {
                text: qsTr("退出")
                visible: window.timelineStopped
                enabled: window.timelineStopped
                onClicked: {
                    if (!window.timelineStopped)
                        return
                    window.closeConfirmed = true
                    window.close()
                }
            }
        }
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
                        id: deviceScopeButton
                        objectName: "deviceScopeButton"

                        raised: variant === UiStyle.ButtonVariant.Secondary
                        size: UiStyle.ButtonSize.Medium
                        variant: deviceScopePopup.filterActive
                            ? UiStyle.ButtonVariant.Tonal
                            : UiStyle.ButtonVariant.Secondary
                        minWidth: 116
                        text: deviceScopePopup.filterActive
                            ? qsTr("设备范围 · %1/%2").arg(deviceScopePopup.matchedDeviceCount)
                                .arg(deviceScopePopup.devices.length)
                            : qsTr("设备范围")
                        iconName: "resources"
                        enabled: !!window.timelineManager
                        onClicked: deviceScopePopup.visible
                            ? deviceScopePopup.close()
                            : deviceScopePopup.open()

                        ToolTip.visible: hovered
                        ToolTip.text: window.timelineManager && window.timelineManager.executionFilterEnabled
                            ? qsTr("已限制播放设备；点击设置设备范围与时间轴显示")
                            : qsTr("设置时间轴显示范围；当前全部设备参与播放")
                    }

                    Rectangle {
                        Layout.leftMargin: 2
                        Layout.rightMargin: 2
                        width: 1
                        height: 20
                        color: window.appTheme.colors.border
                    }

                    Base.AppButton {
                        objectName: "currentTimelinePlayButton"
                        size: UiStyle.ButtonSize.Medium
                        variant: UiStyle.ButtonVariant.Primary
                        minWidth: 144
                        text: window.playbackActionText
                        iconName: !window.queuePlayback && window.timelineRunning ? "pause" : "play"
                        enabled: window.timelineManager
                            && window.timelineManager.currentTimeline
                            && !window.timelineCompleted
                            && (!window.queuePlayback || window.timelineStopped)
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

                Timeline.TimelineFilterPopup {
                    id: deviceScopePopup
                    parent: window.contentItem
                    timelineManager: window.timelineManager
                    deviceModel: window.appRuntime ? window.appRuntime.deviceModel : null
                    anchorItem: deviceScopeButton
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

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: window.appTheme.colors.border
                    }

                    Base.AppButton {
                        raised: true
                        Layout.fillWidth: true
                        text: qsTr("导入设备")
                        enabled: window.timelineStopped
                        onClicked: {
                            planPopup.close()
                            importDevicesDialog.open()
                        }

                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("将设备配置导入到当前工程")
                    }

                    Base.AppButton {
                        raised: true
                        Layout.fillWidth: true
                        text: qsTr("导入时间线")
                        enabled: window.timelineStopped
                        onClicked: {
                            planPopup.close()
                            importTimelinesDialog.open()
                        }

                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("导入到当前工程；同名时间线将重新创建")
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

                FileDialog {
                    id: importDevicesDialog

                    title: qsTr("导入设备到当前工程")
                    selectExisting: true
                    nameFilters: [qsTr("设备配置 (*.ini)")]
                    onAccepted: {
                        if (window.timelineStopped && window.shellController)
                            window.shellController.handleUiAction("timeline.plan.importDevices", {
                                "filePath": fileUrl
                            })
                    }
                }

                FileDialog {
                    id: importTimelinesDialog

                    title: qsTr("导入时间线到当前工程")
                    selectExisting: true
                    nameFilters: [qsTr("时间线配置 (*.json)")]
                    onAccepted: {
                        if (window.timelineStopped && window.shellController)
                            window.shellController.handleUiAction("timeline.plan.importTimelines", {
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
        property real monitorWidth: NaN
        property real monitorHeight: NaN

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
            : Math.min(Math.max(0, hostWidth - shell.overlayMargin * 2),
                       Math.max(320, isNaN(monitorWidth)
                           ? Math.min(520, hostWidth * 0.42) : monitorWidth))
        height: managementMode
            ? hostHeight
            : Math.min(Math.max(0, hostHeight - shell.overlayMargin * 2),
                       Math.max(240, isNaN(monitorHeight)
                           ? Math.min(360, hostHeight * 0.45) : monitorHeight))
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

        Repeater {
            model: 2

            MouseArea {
                id: resizeHandle

                readonly property bool leftEdge: index === 0
                anchors.left: leftEdge ? parent.left : undefined
                anchors.right: leftEdge ? undefined : parent.right
                anchors.bottom: parent.bottom
                width: 24
                height: 24
                visible: !locatorViewerHost.managementMode
                z: 1
                hoverEnabled: true
                cursorShape: leftEdge ? Qt.SizeBDiagCursor : Qt.SizeFDiagCursor
                acceptedButtons: Qt.LeftButton
                preventStealing: true

                property real pressWindowX: 0
                property real pressWindowY: 0
                property real pressHostX: 0
                property real pressWidth: 0
                property real pressHeight: 0

                onPressed: {
                    var point = mapToItem(window.contentItem, mouse.x, mouse.y)
                    pressWindowX = point.x
                    pressWindowY = point.y
                    pressHostX = locatorViewerHost.x
                    pressWidth = locatorViewerHost.width
                    pressHeight = locatorViewerHost.height
                    locatorViewerHost.monitorX = pressHostX
                    locatorViewerHost.monitorY = locatorViewerHost.y
                }
                onPositionChanged: {
                    if (!pressed)
                        return
                    var point = mapToItem(window.contentItem, mouse.x, mouse.y)
                    locatorViewerHost.monitorWidth = Math.min(
                        Math.max(0, leftEdge
                            ? pressHostX + pressWidth - locatorViewerHost.monitorMinX
                            : shell.width - pressHostX - shell.overlayMargin),
                        Math.max(320, pressWidth + (leftEdge ? -1 : 1) * (point.x - pressWindowX)))
                    if (leftEdge)
                        locatorViewerHost.monitorX = pressHostX + pressWidth - locatorViewerHost.width
                    locatorViewerHost.monitorHeight = Math.min(
                        Math.max(0, shell.height - (shell.showBottomBar ? shell.bottomBarHeight : 0)
                            - locatorViewerHost.y - shell.overlayMargin),
                        Math.max(240, pressHeight + point.y - pressWindowY))
                }

                Text {
                    anchors.left: resizeHandle.leftEdge ? parent.left : undefined
                    anchors.right: resizeHandle.leftEdge ? undefined : parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 4
                    text: resizeHandle.leftEdge ? "◣" : "◢"
                    font.pixelSize: 12
                    color: window.appTheme.colors.border
                }
            }
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
