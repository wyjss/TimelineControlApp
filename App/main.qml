import QtQuick 2.14
import QtQuick.Controls 2.14
import "qrc:/UiCore/qml" as Ui
import "qrc:/UiCore/qml/theme" as Theme

ApplicationWindow {
    id: window

    property var appRuntime: typeof app !== "undefined" ? app : null
    property var shellController: appRuntime && appRuntime.shell
        ? appRuntime.shell
        : (typeof timelineShellController !== "undefined" ? timelineShellController : null)
    readonly property bool showDrawerPane: false
    readonly property string defaultCanvasDelegateSource: appRuntime && appRuntime.settings
        ? String(appRuntime.settings.value("canvasDelegateSource", ""))
        : ""

    Theme.AppTheme {
        id: appTheme
    }

    function canvasSourceForDrawer(key) {
        switch (String(key)) {
        case "timeline":
            return "qrc:/TimelineControlApp/App/pages/TimelinePage.qml"
        case "devices":
            return "qrc:/TimelineControlApp/App/pages/DevicesPage.qml"
        case "runs":
            return "qrc:/TimelineControlApp/App/pages/RunsPage.qml"
        default:
            return defaultCanvasDelegateSource
        }
    }

    width: appTheme.metrics.windowWidth
    height: appTheme.metrics.windowHeight
    minimumWidth: appTheme.metrics.windowMinWidth
    minimumHeight: appTheme.metrics.windowMinHeight
    visible: true
    title: appRuntime && appRuntime.settings && appRuntime.settings.applicationName
        ? String(appRuntime.settings.applicationName)
        : qsTr("Timeline Control App")
    color: appTheme.colors.window

    Ui.AppShell {
        anchors.fill: parent
        theme: appTheme
        hostWindow: window
        showWindowControls: true
        taskManager: appRuntime && appRuntime.taskManager ? appRuntime.taskManager : null
        canvasDelegateSource: shellController
            ? window.canvasSourceForDrawer(shellController.activeDrawerKey)
            : window.defaultCanvasDelegateSource
        drawers: shellController ? shellController.drawers : []
        activeDrawerKey: shellController ? shellController.activeDrawerKey : ""
        drawerOpen: window.showDrawerPane && shellController ? shellController.drawerOpen : false
        leftPanelAutoHide: shellController ? shellController.leftPanelAutoHide : false
        rightPanelOpen: shellController ? shellController.rightPanelOpen : false
        canvasInteractionState: shellController ? shellController.canvasInteractionState : "idle"
        leftPaneFilterText: shellController ? shellController.leftPaneFilterText : ""
        inspectorObject: shellController ? shellController.inspectorObject : null
        inspectorData: shellController ? shellController.inspectorData : ({})
        selectionData: shellController ? shellController.selectionData : ({})

        onDrawerRequested: {
            if (shellController)
                shellController.selectDrawer(key)
        }

        onDrawerOpenRequested: {
            if (shellController && window.showDrawerPane)
                shellController.drawerOpen = open
        }

        onRightPanelOpenRequested: {
            if (shellController)
                shellController.rightPanelOpen = open
        }

        onLeftPanelAutoHideRequested: {
            if (shellController)
                shellController.leftPanelAutoHide = enabled
        }

        onUiActionRequested: {
            if (shellController)
                shellController.handleUiAction(actionId, payload)
        }
    }
}
