import QtQuick 2.14

Item {
    id: root

    property bool enabled: true
    property bool takeFocusOnPress: true
    property Item focusTarget: parent
    readonly property bool hovered: tapArea.containsMouse

    signal tapped()
    signal doubleTapped()

    function takeActiveFocus() {
        if (focusTarget && focusTarget.forceActiveFocus)
            focusTarget.forceActiveFocus(Qt.MouseFocusReason)
    }

    MouseArea {
        id: tapArea

        anchors.fill: parent
        enabled: root.enabled
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        preventStealing: true
        onPressed: {
            if (root.takeFocusOnPress)
                root.takeActiveFocus()
        }
        onClicked: root.tapped()
        onDoubleClicked: root.doubleTapped()
    }
}
