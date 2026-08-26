import QtQuick 2.14
import QtQuick.Controls 2.14
import "qrc:/UICore/qml/components/base" as Base

Item {
    id: root

    property alias buttonGroup: cardGroup
    property color selectionColor: "#78afff"
    property bool animated: true

    enabled: false
    z: 1

    readonly property var checkedButton: cardGroup.checkedButton
    property rect targetGeometry: Qt.rect(0, 0, 0, 0)
    property rect selectionGeometry: Qt.rect(0, 0, 0, 0)
    property bool animateGeometry: false

    function updateSelection(useAnimation) {
        var button = checkedButton
        if (!button || !button.visible || !button.enabled) {
            geometryAnimation.stop()
            selectionFrame.visible = false
            return
        }

        var topLeft = button.mapToItem(root, 0, 0)
        targetGeometry = Qt.rect(topLeft.x, topLeft.y, button.width, button.height)
        animateGeometry = selectionFrame.visible && useAnimation && animated
        if (!animateGeometry)
            geometryAnimation.stop()
        selectionGeometry = targetGeometry
        selectionFrame.visible = true
    }

    onWidthChanged: updateTimer.restart()
    onHeightChanged: updateTimer.restart()
    Component.onCompleted: updateTimer.restart()

    ButtonGroup {
        id: cardGroup

        onCheckedButtonChanged: updateTimer.restart()
    }

    Timer {
        id: updateTimer

        interval: 0
        property bool previousSelectionVisible: false
        onTriggered: {
            var useAnimation = previousSelectionVisible
            root.updateSelection(useAnimation)
            previousSelectionVisible = selectionFrame.visible
        }
    }

    Connections {
        target: root.checkedButton
        ignoreUnknownSignals: true

        function onXChanged() { updateTimer.restart() }
        function onYChanged() { updateTimer.restart() }
        function onWidthChanged() { updateTimer.restart() }
        function onHeightChanged() { updateTimer.restart() }
    }

    Connections {
        target: root.checkedButton && root.checkedButton.parent
            ? root.checkedButton.parent
            : null
        ignoreUnknownSignals: true

        function onXChanged() { updateTimer.restart() }
        function onYChanged() { updateTimer.restart() }
        function onWidthChanged() { updateTimer.restart() }
        function onHeightChanged() { updateTimer.restart() }
    }

    Item {
        id: selectionFrame

        x: root.selectionGeometry.x
        y: root.selectionGeometry.y
        width: root.selectionGeometry.width
        height: root.selectionGeometry.height
        visible: false

        Base.AppSurface {
            anchors.fill: parent
            enabled: false
            sizeToContent: false
            shapeRole: root.checkedButton ? root.checkedButton.shapeRole : 0
            strokeWidth: 1
            fillOverride: Qt.rgba(root.selectionColor.r,
                                  root.selectionColor.g,
                                  root.selectionColor.b,
                                  0.05)
            borderOverride: Qt.rgba(root.selectionColor.r,
                                    root.selectionColor.g,
                                    root.selectionColor.b,
                                    0.32)
            animated: false

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: Math.max(24, parent.height - 24)
                radius: width / 2
                color: root.selectionColor
                opacity: 0.9
            }
        }
    }

    Behavior on selectionGeometry {
        enabled: root.animateGeometry

        PropertyAnimation {
            id: geometryAnimation

            duration: 160
            easing.type: Easing.InOutCubic
        }
    }
}
