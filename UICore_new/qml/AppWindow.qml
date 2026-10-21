import QtQuick 2.14
import QtQuick.Controls 2.14
import "theme" as Theme

ApplicationWindow {
    id: root

    property QtObject appTheme: Theme.AppTheme {}
    property alias shell: appShell

    width: appTheme.metrics.windowWidth
    height: appTheme.metrics.windowHeight
    minimumWidth: appTheme.metrics.windowMinWidth
    minimumHeight: appTheme.metrics.windowMinHeight
    title: appShell.applicationTitle
    color: appTheme.colors.backgroundWindow

    AppShell {
        id: appShell

        anchors.fill: parent
    }
}
