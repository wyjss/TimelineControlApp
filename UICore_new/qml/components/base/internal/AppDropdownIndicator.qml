import QtQuick 2.14

Item {
    id: root

    property color strokeColor: "#97a3b6"
    property bool expanded: false
    property int transitionDuration: 180
    property int transitionEasing: Easing.OutCubic

    width: 10
    height: 10
    rotation: expanded ? 180 : 0

    Rectangle {
        width: root.width * 0.52
        height: Math.max(1.6, root.width * 0.16)
        radius: height / 2
        x: root.width * 0.36 - width / 2
        y: root.height * 0.56 - height / 2
        rotation: 57.5
        color: root.strokeColor

        Behavior on color {
            ColorAnimation {
                duration: root.transitionDuration
                easing.type: root.transitionEasing
            }
        }
    }

    Rectangle {
        width: root.width * 0.52
        height: Math.max(1.6, root.width * 0.16)
        radius: height / 2
        x: root.width * 0.64 - width / 2
        y: root.height * 0.56 - height / 2
        rotation: -57.5
        color: root.strokeColor

        Behavior on color {
            ColorAnimation {
                duration: root.transitionDuration
                easing.type: root.transitionEasing
            }
        }
    }

    Behavior on rotation {
        NumberAnimation {
            duration: root.transitionDuration
            easing.type: root.transitionEasing
        }
    }
}
