import QtQuick 2.14

Item {
    id: root

    property bool enabled: true
    readonly property bool hovered: tapArea.containsMouse

    signal tapped()
    signal doubleTapped()

    MouseArea {
        id: tapArea

        anchors.fill: parent
        enabled: root.enabled
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        preventStealing: true
        onClicked: root.tapped()
        onDoubleClicked: root.doubleTapped()
    }
}
