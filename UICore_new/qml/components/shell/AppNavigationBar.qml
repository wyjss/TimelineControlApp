import QtQuick 2.14
import QtQuick.Layouts 1.14
import "../base" as Base

Base.AppSurface {
    id: root

    property int orientation: Qt.Horizontal
    property Component leadingContent: null
    property Component content: null
    property Component trailingContent: null
    property Component itemDelegate: null
    property var menuItems: []
    property string activeItemKey: ""
    property real contentSpacing: resolvedTheme.density.controlGap

    readonly property bool vertical: orientation === Qt.Vertical

    signal itemTriggered(string key)

    sizeToContent: false

    GridLayout {
        anchors.fill: parent
        columns: root.vertical ? 1 : 3
        rows: root.vertical ? 3 : 1
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        columnSpacing: root.contentSpacing
        rowSpacing: root.contentSpacing

        Loader {
            Layout.fillWidth: root.vertical
            Layout.fillHeight: !root.vertical
            Layout.preferredWidth: item ? item.implicitWidth : 0
            Layout.preferredHeight: item ? item.implicitHeight : 0
            visible: sourceComponent !== null
            sourceComponent: root.leadingContent
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: root.content !== null
                ? root.content
                : (root.itemDelegate !== null ? navigationItemsContent : null)
        }

        Loader {
            Layout.fillWidth: root.vertical
            Layout.fillHeight: !root.vertical
            Layout.preferredWidth: item ? item.implicitWidth : 0
            Layout.preferredHeight: item ? item.implicitHeight : 0
            visible: sourceComponent !== null
            sourceComponent: root.trailingContent
        }
    }

    Component {
        id: navigationItemsContent

        GridLayout {
            columns: root.vertical ? 1 : navigationItems.count + 1
            rows: root.vertical ? navigationItems.count + 1 : 1
            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            columnSpacing: root.contentSpacing
            rowSpacing: root.contentSpacing

            Repeater {
                id: navigationItems

                model: root.menuItems
                delegate: root.itemDelegate
            }

            Item {
                Layout.fillWidth: !root.vertical
                Layout.fillHeight: root.vertical
            }
        }
    }
}
