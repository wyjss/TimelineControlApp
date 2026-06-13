import QtQuick 2.14
import QtQuick.Controls 2.14
import "../theme" as Theme
import ".." as Ui

ApplicationWindow {
    id: window

    Theme.AppTheme {
        id: appThemeObject
    }

    width: appThemeObject.metrics.windowWidth
    height: appThemeObject.metrics.windowHeight
    minimumWidth: appThemeObject.metrics.windowMinWidth
    minimumHeight: appThemeObject.metrics.windowMinHeight
    visible: true
    title: qsTr("UiCore")
    color: appThemeObject.colors.window

    Ui.AppShell {
        anchors.fill: parent
        theme: appThemeObject
        hostWindow: window
        showWindowControls: false
        drawers: []
        activeDrawerKey: ""
        drawerOpen: false
        rightPanelOpen: false
        selectionData: ({})
    }
}
