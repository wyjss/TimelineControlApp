import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Dialogs 1.3
import QtQuick.Layouts 1.14
import QtQuick.Window 2.14
import "foundation"
import "components/base" as Base
import "components/shell" as Shell

Item {
    id: root

    property QtObject theme
    property var hostWindow: null
    property bool showWindowControls: false
    property QtObject taskManager: null
    property var drawers: []
    property string activeDrawerKey: ""
    property bool drawerOpen: true
    property bool leftPanelAutoHide: false
    property bool rightPanelOpen: false
    property string canvasInteractionState: "idle"
    property string leftPaneFilterText: ""
    property string canvasDelegateSource: ""
    property var inspectorObject: null
    property var inspectorData: ({})
    property var selectionData: ({})
    property int timelineState: 0
    property bool timelineStartEnabled: true
    property string planFilePath: ""
    property string planName: ""
    property real leftPanelContentOpacity: 1
    property real windowDragPressX: 0
    property real windowDragPressY: 0
    property real windowDragStartX: 0
    property real windowDragStartY: 0
    property real shellPointerX: -1
    property real shellPointerY: -1
    property bool shellPointerActive: false

    signal drawerRequested(string key)
    signal drawerOpenRequested(bool open)
    signal rightPanelOpenRequested(bool open)
    signal leftPanelAutoHideRequested(bool enabled)
    signal uiActionRequested(string actionId, var payload)

    readonly property QtObject shellTheme: theme && theme.shell ? theme.shell : null
    readonly property int topBarHeight: shellTheme ? shellTheme.topBarHeight : 44
    readonly property int railWidth: shellTheme ? shellTheme.railWidth : 52
    readonly property int topBarPadding: shellTheme ? shellTheme.topBarPadding : 10
    readonly property int topBarSearchWidth: shellTheme ? shellTheme.topBarSearchWidth : 336
    readonly property int topBarIconButtonSize: shellTheme ? shellTheme.topBarIconButtonSize : 30
    readonly property int windowControlButtonSize: shellTheme ? shellTheme.windowControlButtonSize : 30
    readonly property int topBarDragWidth: shellTheme ? shellTheme.topBarDragWidth : 132
    readonly property int railPadding: shellTheme ? shellTheme.railPadding : 6
    readonly property int railButtonSize: shellTheme ? shellTheme.railButtonSize : 38
    readonly property int overlayMargin: shellTheme ? shellTheme.shellOverlayMargin : 8
    readonly property int seamFadeSize: shellTheme ? shellTheme.shellSeamFadeSize : 14
    readonly property int leftRevealDelay: theme && theme.motion ? theme.motion.shellPanelRevealDelay : 140
    readonly property int leftHideDelay: theme && theme.motion ? theme.motion.shellPanelHideDelay : 280
    readonly property int defaultLeftPanelWidth: shellTheme ? shellTheme.sidebarWidth : 260
    readonly property int rightPanelWidth: shellTheme ? shellTheme.inspectorWidth : 304
    readonly property bool timelineStopped: timelineState === 0
    readonly property bool timelinePaused: timelineState === 2
    readonly property bool timelineCompleted: timelineState === 3
    readonly property int leftPanelSwapDuration: theme && theme.motion ? theme.motion.contentSwapDuration : 140
    readonly property bool canControlWindow: showWindowControls && !!hostWindow
    readonly property bool windowIsMaximized: canControlWindow && hostWindow.visibility === Window.Maximized

    readonly property var emptyDrawer: ({ "key": "", "label": "", "iconName": "", "detail": "", "leftPane": ({}) })
    readonly property int effectiveCurrentNavIndex: resolveCurrentNavIndex()
    readonly property var activeDrawer: drawers.length > 0 ? drawers[effectiveCurrentNavIndex] : emptyDrawer
    readonly property var activeRawPaneData: objectValue(activeDrawer, "leftPane", objectValue(activeDrawer, "leftPaneData", {}))
    readonly property string currentNavKey: activeDrawer.key !== undefined ? String(activeDrawer.key) : ""
    readonly property string activePaneDelegateSource: activeDrawer && activeDrawer.paneDelegateSource !== undefined
        ? String(activeDrawer.paneDelegateSource)
        : ""
    readonly property var activePaneController: activeDrawer && activeDrawer.paneController !== undefined
        ? activeDrawer.paneController
        : null
    readonly property bool hasCustomLeftPane: activePaneDelegateSource.length > 0
    readonly property int leftPanelWidth: resolveLeftPanelWidth()
    readonly property bool leftPanelVisible: !!drawerOpen
    readonly property bool rightPanelVisible: !!rightPanelOpen
    readonly property bool leftPanelAutoHideEnabled: !!leftPanelAutoHide
    readonly property string effectiveCanvasInteractionState: String(canvasInteractionState)
    readonly property bool leftPanelAutoHideActive: leftPanelAutoHideEnabled && effectiveCanvasInteractionState === "idle"
    readonly property bool leftPanelHoverCaptured: shellPointerActive && leftPanelHoverState(
        pointWithinItem(leftRailSurface, shellPointerX, shellPointerY),
        pointWithinItem(leftPanelBridge, shellPointerX, shellPointerY),
        pointWithinItem(leftOverlayPanel, shellPointerX, shellPointerY)
    )
    readonly property int leftOverlayInset: leftPanelVisible ? leftPanelWidth + overlayMargin * 2 : overlayMargin
    readonly property int rightOverlayInset: rightPanelVisible ? rightPanelWidth + overlayMargin * 2 : overlayMargin
    readonly property string effectiveLeftPaneFilterText: String(leftPaneFilterText)
    readonly property bool hasInteractiveCanvas: canvasDelegateSource.length > 0
    readonly property var leftPaneData: buildLeftPaneData()
    readonly property var taskItems: taskManager && taskManager.tasks !== undefined ? taskManager.tasks : []
    readonly property int taskItemCount: taskManager && taskManager.taskCount !== undefined
        ? Number(taskManager.taskCount)
        : (taskItems ? taskItems.length : 0)
    readonly property int activeTaskCount: taskManager && taskManager.activeTaskCount !== undefined
        ? Number(taskManager.activeTaskCount)
        : 0
    readonly property int finishedTaskCount: Math.max(0, taskItemCount - activeTaskCount)

    function copyObject(source) {
        var target = {}

        if (!source)
            return target

        for (var key in source)
            target[key] = source[key]

        return target
    }

    function objectValue(source, key, fallback) {
        if (source !== undefined && source !== null && source[key] !== undefined)
            return source[key]

        return fallback
    }

    function clampNavigationIndex(index) {
        if (!drawers || drawers.length === 0)
            return 0

        return Math.max(0, Math.min(Number(index), drawers.length - 1))
    }

    function indexOfNavigationKey(key, fallbackIndex) {
        var resolvedKey = key !== undefined && key !== null ? String(key) : ""

        for (var index = 0; index < drawers.length; ++index) {
            if (String(drawers[index].key) === resolvedKey)
                return index
        }

        return fallbackIndex
    }

    function resolveCurrentNavIndex() {
        var fallbackIndex = 0
        var controllerKey = activeDrawerKey

        if (String(controllerKey).length > 0)
            return indexOfNavigationKey(controllerKey, fallbackIndex)

        return fallbackIndex
    }

    function resolvedRowId(rowData) {
        if (!rowData)
            return ""

        return rowData.id !== undefined ? String(rowData.id) : String(rowData.label)
    }

    function filteredRows(rows, filterText) {
        var result = []
        var needle = filterText ? String(filterText).toLowerCase().trim() : ""

        for (var index = 0; index < rows.length; ++index) {
            var row = copyObject(rows[index])
            var haystack = (String(row.label || "") + " " + String(row.meta || "")).toLowerCase()
            row.selected = row.selected !== undefined ? !!row.selected : false

            if (!needle || haystack.indexOf(needle) >= 0)
                result.push(row)
        }

        return result
    }

    function resolveLeftPanelWidth() {
        var paneWidth = activeRawPaneData && activeRawPaneData.paneWidth !== undefined
            ? Number(activeRawPaneData.paneWidth)
            : NaN
        var controllerPaneWidth = activePaneController && activePaneController.paneWidth !== undefined
            ? Number(activePaneController.paneWidth)
            : NaN

        if (!isNaN(paneWidth) && paneWidth > 0)
            return paneWidth

        if (!isNaN(controllerPaneWidth) && controllerPaneWidth > 0)
            return controllerPaneWidth

        return defaultLeftPanelWidth
    }

    function buildLeftPaneData() {
        var drawerPane = activeRawPaneData !== undefined && activeRawPaneData !== null ? copyObject(activeRawPaneData) : {}
        var sourceItems = drawerPane.items !== undefined ? drawerPane.items : []

        drawerPane.title = drawerPane.title !== undefined ? drawerPane.title : activeDrawer.label
        drawerPane.subtitle = drawerPane.subtitle !== undefined
            ? drawerPane.subtitle
            : (leftPanelAutoHideEnabled ? "" : activeDrawer.detail)
        drawerPane.filterPlaceholder = drawerPane.filterPlaceholder !== undefined
            ? drawerPane.filterPlaceholder
            : qsTr("筛选可见项")
        drawerPane.filterText = effectiveLeftPaneFilterText
        drawerPane.items = filteredRows(sourceItems, effectiveLeftPaneFilterText)

        if (drawerPane.primaryAction === undefined) {
            drawerPane.primaryAction = {
                "actionId": "leftPane.centerSelection",
                "text": qsTr("居中到选择项"),
                "variant": "secondary"
            }
        }

        return drawerPane
    }

    function taskBadgeText(count) {
        var normalizedCount = Math.max(0, Number(count))
        return normalizedCount > 99 ? "99+" : String(normalizedCount)
    }

    function toggleTaskPopup() {
        if (taskPopup.opened)
            taskPopup.close()
        else
            taskPopup.open()
    }

    function focusCanvas() {
        if (earthCanvasLoader.item)
            earthCanvasLoader.item.forceActiveFocus(Qt.OtherFocusReason)
    }

    function requestDrawerOpen(open) {
        var nextValue = !!open
        if (drawerOpen === nextValue)
            return

        drawerOpenRequested(nextValue)
    }

    function requestRightPanelOpen(open) {
        var nextValue = !!open
        if (rightPanelOpen === nextValue)
            return

        rightPanelOpenRequested(nextValue)
    }

    function requestLeftPanelAutoHide(enabled) {
        var nextValue = !!enabled
        if (leftPanelAutoHide === nextValue)
            return

        leftPanelAutoHideRequested(nextValue)
    }

    function activateNavigation(index) {
        if (!drawers || drawers.length === 0)
            return

        var normalizedIndex = clampNavigationIndex(index)
        var navItem = drawers[normalizedIndex]
        var sameTarget = normalizedIndex === effectiveCurrentNavIndex
        var nextDrawerOpen = sameTarget ? !leftPanelVisible : true

        if (!sameTarget)
            drawerRequested(String(navItem.key))

        requestDrawerOpen(nextDrawerOpen)

        if (String(navItem.key) === "inspector" && !rightPanelVisible)
            requestRightPanelOpen(true)

        focusCanvas()
    }

    function toggleRightPanel() {
        requestRightPanelOpen(!rightPanelVisible)
    }

    function toggleWindowMaximized() {
        if (!canControlWindow)
            return

        if (windowIsMaximized)
            hostWindow.showNormal()
        else
            hostWindow.showMaximized()
    }

    function minimizeWindow() {
        if (canControlWindow)
            hostWindow.showMinimized()
    }

    function closeWindow() {
        if (canControlWindow)
            hostWindow.close()
    }

    function startWindowDrag(mouseX, mouseY) {
        if (!canControlWindow || windowIsMaximized)
            return

        windowDragPressX = mouseX
        windowDragPressY = mouseY
        windowDragStartX = hostWindow.x
        windowDragStartY = hostWindow.y
    }

    function continueWindowDrag(mouseX, mouseY, pressed) {
        if (!canControlWindow || !pressed || windowIsMaximized)
            return

        hostWindow.x = windowDragStartX + mouseX - windowDragPressX
        hostWindow.y = windowDragStartY + mouseY - windowDragPressY
    }

    function leftPanelHoverState(railHovered, bridgeHovered, panelHovered) {
        return !!railHovered || !!bridgeHovered || !!panelHovered
    }

    function pointWithinItem(item, pointX, pointY) {
        if (!item || item.visible === false)
            return false

        var localOrigin = item.mapToItem(root, 0, 0)
        return pointX >= localOrigin.x
            && pointX < localOrigin.x + item.width
            && pointY >= localOrigin.y
            && pointY < localOrigin.y + item.height
    }

    function updateShellPointerPosition(pointX, pointY) {
        shellPointerX = Number(pointX)
        shellPointerY = Number(pointY)
        shellPointerActive = true
        syncLeftPanelHoverState()
    }

    function clearShellPointerPosition() {
        shellPointerX = -1
        shellPointerY = -1
        shellPointerActive = false
        syncLeftPanelHoverState()
    }

    function cancelLeftPanelTimers() {
        leftRevealTimer.stop()
        leftHideTimer.stop()
    }

    function queueLeftPanelReveal() {
        if (!leftPanelAutoHideActive)
            return

        leftHideTimer.stop()
        if (!leftPanelVisible)
            leftRevealTimer.restart()
    }

    function queueLeftPanelHide() {
        if (!leftPanelAutoHideActive)
            return

        leftRevealTimer.stop()
        if (leftPanelVisible)
            leftHideTimer.restart()
    }

    function syncLeftPanelHoverState() {
        if (!leftPanelAutoHideActive) {
            cancelLeftPanelTimers()
            return
        }

        if (leftPanelHoverCaptured)
            queueLeftPanelReveal()
        else
            queueLeftPanelHide()
    }

    function animateLeftPanelContent() {
        leftPanelContentOpacity = 0.82
        leftPanelSwapAnimation.restart()
    }

    Timer {
        id: leftRevealTimer
        interval: root.leftRevealDelay
        repeat: false
        onTriggered: root.requestDrawerOpen(true)
    }

    Timer {
        id: leftHideTimer
        interval: root.leftHideDelay
        repeat: false
        onTriggered: root.requestDrawerOpen(false)
    }

    ParallelAnimation {
        id: leftPanelSwapAnimation

        NumberAnimation {
            target: root
            property: "leftPanelContentOpacity"
            to: 1
            duration: root.leftPanelSwapDuration
            easing.type: root.theme ? root.theme.motion.easingStandard : Easing.OutCubic
        }
    }

    onEffectiveCurrentNavIndexChanged: animateLeftPanelContent()
    onLeftPanelAutoHideEnabledChanged: {
        cancelLeftPanelTimers()

        if (!leftPanelAutoHideActive) {
            clearShellPointerPosition()
            requestDrawerOpen(true)
            return
        }

        syncLeftPanelHoverState()
    }
    onEffectiveCanvasInteractionStateChanged: {
        if (!leftPanelAutoHideEnabled)
            return

        cancelLeftPanelTimers()

        if (!leftPanelAutoHideActive) {
            clearShellPointerPosition()
            requestDrawerOpen(true)
            return
        }

        syncLeftPanelHoverState()
    }
    onLeftPanelVisibleChanged: {
        if (leftPanelAutoHideActive)
            syncLeftPanelHoverState()
    }

    function handleLeftPaneFilterTextChanged(text) {
        uiActionRequested("leftPane.filterEdited", {
            "navKey": currentNavKey,
            "text": text
        })
    }

    function handleInspectorFieldEdited(fieldKey, value) {
        var payload = {
            "fieldKey": fieldKey !== undefined && fieldKey !== null ? String(fieldKey) : ""
        }

        payload.value = value !== undefined && value !== null ? value : null

        uiActionRequested("inspector.fieldEdited", payload)
    }

    function handlePaneAction(actionId, payload) {
        var normalizedPayload = payload !== undefined && payload !== null ? payload : ({})

        if (actionId === "leftPane.rowTriggered") {
            var rowData = normalizedPayload.rowData !== undefined ? normalizedPayload.rowData : null

            normalizedPayload = {
                "navKey": currentNavKey,
                "rowId": normalizedPayload.rowId !== undefined ? normalizedPayload.rowId : resolvedRowId(rowData),
                "rowData": rowData
            }
        }

        uiActionRequested(actionId, normalizedPayload)
    }

    clip: true

    Base.AppBackdrop {
        anchors.fill: parent
        theme: root.theme
        primaryGlowOpacity: 0.28
        secondaryGlowOpacity: 0.16

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Base.AppSurface {
                Layout.fillWidth: true
                Layout.preferredHeight: root.topBarHeight
                sizeToContent: false
                theme: root.theme
                surfaceTone: "surface"
                shapeRole: AppUiEnums.ShapeRole.None
                strokeWidth: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root.topBarPadding
                    anchors.rightMargin: root.topBarPadding
                    spacing: 8

                    Item {
                        Layout.preferredWidth: root.topBarDragWidth
                        Layout.fillHeight: true

                        Base.AppText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("时间线控制")
                            theme: root.theme
                            styleRole: "bodyM"
                            overrideWeight: theme ? theme.typography.weightBold : Font.Bold
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            enabled: root.canControlWindow
                            onPressed: root.startWindowDrag(mouse.x, mouse.y)
                            onPositionChanged: root.continueWindowDrag(mouse.x, mouse.y, pressed)
                            onDoubleClicked: root.toggleWindowMaximized()
                        }
                    }

                    Base.AppTextField {
                        Layout.preferredWidth: root.topBarSearchWidth
                        theme: root.theme
                        surfaceTone: "section"
                        placeholderText: qsTr("搜索图层、工具和命令")
                        trailingContent: [
                            Base.AppText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Ctrl K")
                                theme: root.theme
                                styleRole: "bodyS"
                                textTone: "secondary"
                            }
                        ]
                    }

                    Base.AppSurface {
                        id: timelineControlBar

                        Layout.preferredWidth: timelineControlRow.implicitWidth + 16
                        Layout.preferredHeight: 34
                        Layout.alignment: Qt.AlignVCenter
                        sizeToContent: false
                        theme: root.theme
                        surfaceTone: "section"
                        shapeRole: AppUiEnums.ShapeRole.Control
                        strokeWidth: 1

                        RowLayout {
                            id: timelineControlRow

                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Base.AppText {
                                text: qsTr("时间线")
                                theme: root.theme
                                styleRole: "bodyS"
                                textTone: "secondary"
                            }

                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                radius: 4
                                color: root.timelineCompleted
                                    ? "#3b82f6"
                                    : (root.timelineStopped ? "#ef4444" : "#22c55e")
                            }

                            Base.AppText {
                                visible: root.timelineCompleted
                                text: qsTr("已完成")
                                theme: root.theme
                                styleRole: "bodyS"
                                textTone: "accent"
                            }

                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 18
                                color: root.theme.colors.border
                                opacity: 0.72
                            }

                            Base.AppButton {
                                text: root.timelineStopped ? qsTr("开始") : qsTr("停止")
                                theme: root.theme
                                size: AppUiEnums.ButtonSize.Small
                                variant: root.timelineStopped
                                    ? AppUiEnums.ButtonVariant.Tonal
                                    : AppUiEnums.ButtonVariant.Secondary
                                iconName: root.timelineStopped ? "play" : "stop"
                                enabled: !root.timelineStopped || root.timelineStartEnabled
                                onClicked: root.uiActionRequested(root.timelineStopped ? "timeline.start" : "timeline.stop", {})
                            }

                            Base.AppButton {
                                text: root.timelinePaused ? qsTr("继续") : qsTr("暂停")
                                theme: root.theme
                                size: AppUiEnums.ButtonSize.Small
                                variant: AppUiEnums.ButtonVariant.Secondary
                                iconName: root.timelinePaused ? "play" : "pause"
                                enabled: !root.timelineStopped && !root.timelineCompleted
                                onClicked: root.uiActionRequested(root.timelinePaused ? "timeline.start" : "timeline.pause", {})
                            }

                            Base.AppButton {
                                id: plansButton

                                text: root.planName.length > 0 ? root.planName : qsTr("未选择方案")
                                theme: root.theme
                                size: AppUiEnums.ButtonSize.Small
                                variant: AppUiEnums.ButtonVariant.Secondary
                                iconName: "resources"
                                enabled: root.timelineStopped
                                onClicked: planPopup.opened ? planPopup.close() : planPopup.open()
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            enabled: root.canControlWindow
                            onPressed: root.startWindowDrag(mouse.x, mouse.y)
                            onPositionChanged: root.continueWindowDrag(mouse.x, mouse.y, pressed)
                            onDoubleClicked: root.toggleWindowMaximized()
                        }
                    }

                    Item {
                        id: taskButtonHost

                        Layout.preferredWidth: root.topBarIconButtonSize
                        Layout.preferredHeight: root.topBarIconButtonSize

                        Shell.AppTopbarIconButton {
                            anchors.fill: parent
                            theme: root.theme
                            buttonSize: root.topBarIconButtonSize
                            iconName: "background-task"
                            active: taskPopup.opened
                            onClicked: root.toggleTaskPopup()
                        }

                        Base.AppSurface {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.rightMargin: -4
                            anchors.topMargin: -2
                            visible: root.activeTaskCount > 0
                            width: Math.max(16, taskBadgeTextItem.implicitWidth + 8)
                            height: 16
                            theme: root.theme
                            surfaceTone: "highlight"
                            shapeRole: AppUiEnums.ShapeRole.Pill
                            strokeWidth: 0
                            fillOverride: root.theme && root.theme.colors
                                ? root.theme.colors.highlightFill
                                : "#2563eb"
                            z: 1

                            Base.AppText {
                                id: taskBadgeTextItem

                                anchors.centerIn: parent
                                text: root.taskBadgeText(root.activeTaskCount)
                                theme: root.theme
                                styleRole: "bodyS"
                                textTone: "inverse"
                                overridePixelSize: 10
                                overrideWeight: root.theme ? root.theme.typography.weightBold : Font.Bold
                            }
                        }
                    }

                    Shell.AppTopbarIconButton {
                        theme: root.theme
                        buttonSize: root.topBarIconButtonSize
                        iconName: "inspector"
                        active: root.rightPanelVisible
                        onClicked: root.toggleRightPanel()
                    }

                    RowLayout {
                        visible: root.showWindowControls
                        spacing: 0

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 16
                            color: root.theme.colors.border
                            opacity: 0.8
                        }

                        Shell.AppTopbarIconButton {
                            theme: root.theme
                            buttonSize: root.windowControlButtonSize
                            systemGlyph: "minimize"
                            onClicked: root.minimizeWindow()
                        }

                        Shell.AppTopbarIconButton {
                            theme: root.theme
                            buttonSize: root.windowControlButtonSize
                            systemGlyph: root.windowIsMaximized ? "restore" : "maximize"
                            onClicked: root.toggleWindowMaximized()
                        }

                        Shell.AppTopbarIconButton {
                            theme: root.theme
                            buttonSize: root.windowControlButtonSize
                            systemGlyph: "close"
                            danger: true
                            onClicked: root.closeWindow()
                        }
                    }
                }

            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Base.AppSurface {
                    id: leftRailSurface

                    objectName: "leftRailSurface"
                    Layout.preferredWidth: root.railWidth
                    Layout.fillHeight: true
                    sizeToContent: false
                    theme: root.theme
                    surfaceTone: "surface"
                    shapeRole: AppUiEnums.ShapeRole.None
                    strokeWidth: 0

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: root.railPadding
                        spacing: root.railPadding

                        Repeater {
                            model: root.drawers

                            delegate: Shell.AppRailButton {
                                Layout.alignment: Qt.AlignHCenter
                                theme: root.theme
                                buttonSize: root.railButtonSize
                                active: index === root.effectiveCurrentNavIndex
                                iconName: modelData.iconName
                                onClicked: root.activateNavigation(index)
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8

                            Base.AppSurface {
                                id: autoHideButton

                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: root.railButtonSize
                                Layout.preferredHeight: root.railButtonSize
                                sizeToContent: false
                                theme: root.theme
                                surfaceTone: root.leftPanelAutoHideEnabled ? "highlight" : "section"
                                shapeRole: AppUiEnums.ShapeRole.Control
                                strokeWidth: root.leftPanelAutoHideEnabled ? 0 : 1
                                interactive: true

                                Canvas {
                                    id: autoHideGlyph
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    onVisibleChanged: requestPaint()

                                    Connections {
                                        target: root
                                        function onLeftPanelAutoHideEnabledChanged() {
                                            autoHideGlyph.requestPaint()
                                        }
                                    }

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        var stroke = root.leftPanelAutoHideEnabled ? root.theme.colors.highlightText : root.theme.colors.text

                                        ctx.clearRect(0, 0, width, height)
                                        ctx.lineWidth = 1.5
                                        ctx.lineJoin = "round"
                                        ctx.lineCap = "round"
                                        ctx.strokeStyle = stroke

                                        ctx.beginPath()
                                        ctx.moveTo(2.5, 2.5)
                                        ctx.lineTo(2.5, 13.5)
                                        ctx.stroke()

                                        ctx.fillStyle = root.leftPanelAutoHideEnabled
                                            ? Qt.rgba(root.theme.colors.highlightText.r, root.theme.colors.highlightText.g, root.theme.colors.highlightText.b, 0.06)
                                            : Qt.rgba(root.theme.colors.highlightText.r, root.theme.colors.highlightText.g, root.theme.colors.highlightText.b, 0.16)
                                        ctx.fillRect(5, 3, 8.5, 10)

                                        ctx.beginPath()
                                        ctx.rect(5, 3, 8.5, 10)
                                        ctx.stroke()

                                        if (root.leftPanelAutoHideEnabled) {
                                            ctx.beginPath()
                                            ctx.moveTo(10.5, 6)
                                            ctx.lineTo(8.5, 8)
                                            ctx.lineTo(10.5, 10)
                                            ctx.stroke()
                                        }
                                    }
                                }

                                TapHandler {
                                    acceptedButtons: Qt.LeftButton
                                    onTapped: root.requestLeftPanelAutoHide(!root.leftPanelAutoHideEnabled)
                                }
                            }

                        }
                    }

                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Item {
                        id: canvasHost

                        anchors.fill: parent
                        clip: true

                        Base.AppSurface {
                            anchors.fill: parent
                            sizeToContent: false
                            theme: root.theme
                            surfaceTone: "canvas"
                            shapeRole: AppUiEnums.ShapeRole.None
                            strokeWidth: 0
                        }

                        TapHandler {
                            enabled: !root.hasInteractiveCanvas
                            acceptedButtons: Qt.LeftButton
                            onTapped: {
                                if (root.leftPanelAutoHideActive) {
                                    root.cancelLeftPanelTimers()
                                    root.requestDrawerOpen(false)
                                }
                            }
                        }

                        Loader {
                            id: earthCanvasLoader

                            anchors.fill: parent
                            active: root.hasInteractiveCanvas
                            source: root.canvasDelegateSource
                            onLoaded: {
                                if (item)
                                    item.forceActiveFocus(Qt.OtherFocusReason)
                            }
                        }

                        Item {
                            anchors.fill: parent
                            visible: !earthCanvasLoader.active

                            Canvas {
                                id: placeholderCanvas

                                anchors.fill: parent

                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()

                                Connections {
                                    target: root
                                    function onThemeChanged() {
                                        placeholderCanvas.requestPaint()
                                    }
                                }

                                onPaint: {
                                    var ctx = getContext("2d")
                                    var w = width
                                    var h = height
                                    var colors = root.theme && root.theme.colors ? root.theme.colors : null
                                    var highlightText = colors ? colors.highlightText : Qt.rgba(0.49, 0.71, 1.0, 1)
                                    var inverseText = colors ? colors.inverseText : Qt.rgba(1, 1, 1, 1)
                                    var points = [[w * 0.23, h * 0.68], [w * 0.48, h * 0.48], [w * 0.72, h * 0.34]]

                                    ctx.clearRect(0, 0, w, h)

                                    ctx.strokeStyle = colors ? colors.border : "#334155"
                                    ctx.lineWidth = 1
                                    ctx.globalAlpha = 0.14
                                    for (var gx = 1; gx < 10; ++gx) {
                                        var gridX = gx * (w / 10)
                                        ctx.beginPath()
                                        ctx.moveTo(gridX, 0)
                                        ctx.lineTo(gridX, h)
                                        ctx.stroke()
                                    }

                                    ctx.globalAlpha = 0.12
                                    for (var gy = 1; gy < 7; ++gy) {
                                        var gridY = gy * (h / 7)
                                        ctx.beginPath()
                                        ctx.moveTo(0, gridY)
                                        ctx.lineTo(w, gridY)
                                        ctx.stroke()
                                    }
                                    ctx.globalAlpha = 1
                                    ctx.fillStyle = Qt.rgba(highlightText.r, highlightText.g, highlightText.b, 0.12)
                                    ctx.strokeStyle = Qt.rgba(highlightText.r, highlightText.g, highlightText.b, 0.48)
                                    ctx.lineWidth = 2
                                    ctx.beginPath()
                                    ctx.moveTo(w * 0.17, h * 0.22)
                                    ctx.lineTo(w * 0.46, h * 0.16)
                                    ctx.lineTo(w * 0.67, h * 0.30)
                                    ctx.lineTo(w * 0.61, h * 0.57)
                                    ctx.lineTo(w * 0.35, h * 0.63)
                                    ctx.lineTo(w * 0.15, h * 0.44)
                                    ctx.closePath()
                                    ctx.fill()
                                    ctx.stroke()

                                    ctx.strokeStyle = Qt.rgba(highlightText.r, highlightText.g, highlightText.b, 0.92)
                                    ctx.lineWidth = 3
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"
                                    ctx.beginPath()
                                    ctx.moveTo(points[0][0], points[0][1])
                                    ctx.lineTo(points[0][0] + w * 0.11, h * 0.54)
                                    ctx.lineTo(points[1][0], points[1][1])
                                    ctx.lineTo(w * 0.58, h * 0.38)
                                    ctx.lineTo(points[2][0], points[2][1])
                                    ctx.stroke()

                                    ctx.fillStyle = Qt.rgba(inverseText.r, inverseText.g, inverseText.b, 0.96)
                                    for (var i = 0; i < points.length; ++i) {
                                        ctx.beginPath()
                                        ctx.arc(points[i][0], points[i][1], 4.5, 0, Math.PI * 2)
                                        ctx.fill()
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: root.seamFadeSize
                            z: 1
                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: Qt.rgba(root.theme.colors.surface.r, root.theme.colors.surface.g, root.theme.colors.surface.b, 0.88)
                                }
                                GradientStop {
                                    position: 1
                                    color: Qt.rgba(root.theme.colors.surface.r, root.theme.colors.surface.g, root.theme.colors.surface.b, 0)
                                }
                            }
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            width: root.seamFadeSize
                            z: 1
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0
                                    color: Qt.rgba(root.theme.colors.surface.r, root.theme.colors.surface.g, root.theme.colors.surface.b, 0.82)
                                }
                                GradientStop {
                                    position: 1
                                    color: Qt.rgba(root.theme.colors.surface.r, root.theme.colors.surface.g, root.theme.colors.surface.b, 0)
                                }
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: root.seamFadeSize
                            z: 1
                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: Qt.rgba(root.theme.colors.surface.r, root.theme.colors.surface.g, root.theme.colors.surface.b, 0)
                                }
                                GradientStop {
                                    position: 1
                                    color: Qt.rgba(root.theme.colors.surface.r, root.theme.colors.surface.g, root.theme.colors.surface.b, 0.84)
                                }
                            }
                        }

                        Item {
                            id: leftPanelBridge

                            objectName: "leftPanelBridge"
                            x: 0
                            y: root.overlayMargin
                            width: root.overlayMargin
                            height: Math.max(0, parent.height - root.overlayMargin * 2)
                            visible: root.leftPanelAutoHideActive && root.leftPanelVisible
                            z: 2
                        }

                        Item {
                            id: leftOverlayPanel

                            objectName: "leftOverlayPanel"
                            x: root.leftPanelVisible ? root.overlayMargin : -width - root.overlayMargin
                            y: root.overlayMargin
                            width: root.leftPanelWidth
                            height: Math.max(0, parent.height - root.overlayMargin * 2)
                            visible: opacity > 0 || root.leftPanelVisible
                            opacity: root.leftPanelVisible ? 1 : 0
                            z: 3

                            Loader {
                                anchors.fill: parent
                                sourceComponent: root.hasCustomLeftPane ? customLeftPaneComponent : builtInLeftPaneComponent
                            }

                            Behavior on x {
                                NumberAnimation {
                                    duration: root.theme ? root.theme.motion.durationStandard : 160
                                    easing.type: root.theme ? root.theme.motion.easingStandard : Easing.OutCubic
                                }
                            }

                            Behavior on width {
                                NumberAnimation {
                                    duration: root.theme ? root.theme.motion.durationStandard : 160
                                    easing.type: root.theme ? root.theme.motion.easingStandard : Easing.OutCubic
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: root.theme ? root.theme.motion.durationFast : 100
                                    easing.type: root.theme ? root.theme.motion.easingStandard : Easing.OutCubic
                                }
                            }
                        }

                        Shell.AppInspectorPane {
                            id: rightOverlayPanel

                            x: root.rightPanelVisible ? parent.width - width - root.overlayMargin : parent.width + root.overlayMargin
                            y: root.overlayMargin
                            width: root.rightPanelWidth
                            height: Math.max(0, parent.height - root.overlayMargin * 2)
                            visible: opacity > 0 || root.rightPanelVisible
                            opacity: root.rightPanelVisible ? 1 : 0
                            z: 3
                            theme: root.theme
                            inspectorObject: root.inspectorObject
                            inspectorData: root.inspectorData
                            cornerRadius: root.theme && root.theme.shape ? root.theme.shape.overlayRadius : 14
                            onFieldEdited: function(fieldKey, value) {
                                root.handleInspectorFieldEdited(fieldKey, value)
                            }
                            onActionTriggered: function(actionId, payload) {
                                root.handlePaneAction(actionId, payload)
                            }

                            Behavior on x {
                                NumberAnimation {
                                    duration: root.theme ? root.theme.motion.durationStandard : 160
                                    easing.type: root.theme ? root.theme.motion.easingStandard : Easing.OutCubic
                                }
                            }

                            Behavior on width {
                                NumberAnimation {
                                    duration: root.theme ? root.theme.motion.durationStandard : 160
                                    easing.type: root.theme ? root.theme.motion.easingStandard : Easing.OutCubic
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: root.theme ? root.theme.motion.durationFast : 100
                                    easing.type: root.theme ? root.theme.motion.easingStandard : Easing.OutCubic
                                }
                            }
                        }

                        Component {
                            id: builtInLeftPaneComponent

                            Shell.AppLeftPane {
                                theme: root.theme
                                paneData: root.leftPaneData
                                contentOpacity: root.leftPanelContentOpacity
                                cornerRadius: root.theme && root.theme.shape ? root.theme.shape.overlayRadius : 14
                                onFilterEdited: function(text) {
                                    root.handleLeftPaneFilterTextChanged(text)
                                }
                                onActionTriggered: function(actionId, payload) {
                                    root.handlePaneAction(actionId, payload)
                                }
                            }
                        }

                        Component {
                            id: customLeftPaneComponent

                            Item {
                                id: customLeftPaneHost

                                function applyBindings() {
                                    if (!customLeftPaneLoader.item)
                                        return

                                    if (customLeftPaneLoader.item.theme !== undefined)
                                        customLeftPaneLoader.item.theme = root.theme

                                    if (customLeftPaneLoader.item.drawerData !== undefined)
                                        customLeftPaneLoader.item.drawerData = root.activeDrawer

                                    if (customLeftPaneLoader.item.paneData !== undefined)
                                        customLeftPaneLoader.item.paneData = root.leftPaneData

                                    if (customLeftPaneLoader.item.paneController !== undefined)
                                        customLeftPaneLoader.item.paneController = root.activePaneController

                                    if (customLeftPaneLoader.item.filterText !== undefined)
                                        customLeftPaneLoader.item.filterText = root.effectiveLeftPaneFilterText

                                    if (customLeftPaneLoader.item.contentOpacity !== undefined)
                                        customLeftPaneLoader.item.contentOpacity = root.leftPanelContentOpacity

                                    if (customLeftPaneLoader.item.cornerRadius !== undefined)
                                        customLeftPaneLoader.item.cornerRadius = root.theme && root.theme.shape
                                            ? root.theme.shape.overlayRadius
                                            : 14
                                }

                                Loader {
                                    id: customLeftPaneLoader

                                    anchors.fill: parent
                                    source: root.activePaneDelegateSource
                                    onLoaded: customLeftPaneHost.applyBindings()
                                }

                                Connections {
                                    target: customLeftPaneLoader.item
                                    ignoreUnknownSignals: true

                                    function onFilterEdited(text) {
                                        root.handleLeftPaneFilterTextChanged(text)
                                    }

                                    function onActionTriggered(actionId, payload) {
                                        root.handlePaneAction(actionId, payload)
                                    }
                                }

                                Connections {
                                    target: root

                                    function onThemeChanged() {
                                        customLeftPaneHost.applyBindings()
                                    }

                                    function onActiveDrawerChanged() {
                                        customLeftPaneHost.applyBindings()
                                    }

                                    function onLeftPaneDataChanged() {
                                        customLeftPaneHost.applyBindings()
                                    }

                                    function onActivePaneControllerChanged() {
                                        customLeftPaneHost.applyBindings()
                                    }

                                    function onEffectiveLeftPaneFilterTextChanged() {
                                        customLeftPaneHost.applyBindings()
                                    }

                                    function onLeftPanelContentOpacityChanged() {
                                        customLeftPaneHost.applyBindings()
                                    }
                                }
                            }
                        }

                    }
                }
            }
        }
    }

    HoverHandler {
        id: shellPointerTracker

        enabled: root.leftPanelAutoHideActive
        acceptedDevices: PointerDevice.Mouse

        onHoveredChanged: {
            if (hovered)
                root.updateShellPointerPosition(point.position.x, point.position.y)
            else
                root.clearShellPointerPosition()
        }

        onPointChanged: {
            if (hovered)
                root.updateShellPointerPosition(point.position.x, point.position.y)
        }
    }

    Shell.AppTaskPanel {
        id: taskPopup

        parent: Overlay.overlay
        theme: root.theme
        anchorItem: taskButtonHost
        taskItems: root.taskItems
        taskItemCount: root.taskItemCount
        activeTaskCount: root.activeTaskCount
        finishedTaskCount: root.finishedTaskCount
        topBarHeight: root.topBarHeight
        overlayMargin: root.overlayMargin
    }

    Base.AppPopup {
        id: planPopup

        parent: Overlay.overlay
        width: 220
        x: {
            if (!parent)
                return 0

            var origin = plansButton.mapToItem(parent, plansButton.width - width, plansButton.height + 8)
            return Math.round(Math.max(root.overlayMargin, Math.min(origin.x, parent.width - width - root.overlayMargin)))
        }
        y: {
            if (!parent)
                return root.topBarHeight + root.overlayMargin

            var origin = plansButton.mapToItem(parent, 0, plansButton.height + 8)
            return Math.round(Math.max(root.overlayMargin, origin.y))
        }
        theme: root.theme
        surfaceTone: "surface"
        modal: false
        showModalOverlay: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 12
        spacing: 8

        Base.AppButton {
            Layout.fillWidth: true
            text: qsTr("保存")
            theme: root.theme
            size: AppUiEnums.ButtonSize.Small
            enabled: root.timelineStopped
            onClicked: {
                planPopup.close()
                if (root.planFilePath.length > 0)
                    root.uiActionRequested("timeline.plan.save", { "filePath": root.planFilePath })
                else
                    savePlanDialog.open()
            }
        }

        Base.AppButton {
            Layout.fillWidth: true
            text: qsTr("另存为...")
            theme: root.theme
            size: AppUiEnums.ButtonSize.Small
            enabled: root.timelineStopped
            onClicked: {
                planPopup.close()
                savePlanDialog.open()
            }
        }

        Base.AppButton {
            Layout.fillWidth: true
            text: qsTr("加载...")
            theme: root.theme
            size: AppUiEnums.ButtonSize.Small
            enabled: root.timelineStopped
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
            if (root.timelineStopped)
                root.uiActionRequested("timeline.plan.save", { "filePath": fileUrl })
        }
    }

    FileDialog {
        id: loadPlanDialog

        title: qsTr("加载时间线方案")
        selectExisting: true
        nameFilters: [qsTr("时间线方案 (*.tlplan)"), qsTr("所有文件 (*)")]
        onAccepted: {
            if (root.timelineStopped)
                root.uiActionRequested("timeline.plan.load", { "filePath": fileUrl })
        }
    }
}

