import QtQuick 2.14
import QtQuick.Controls 2.14

Item {
    id: root

    property var fences: []
    property string currentHandle: ""

    signal selected(string handle)
    signal removeRequested(string handle)

    ListView {
        anchors.fill: parent
        clip: true
        spacing: 4
        model: root.fences

        delegate: Rectangle {
            width: ListView.view.width
            height: 40
            radius: 4
            color: root.currentHandle === String(modelData.handle)
                ? "#405f8f"
                : "#26313f"

            Label {
                anchors.left: parent.left
                anchors.right: removeButton.left
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: String(modelData.name)
                color: "white"
                elide: Text.ElideRight
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.selected(String(modelData.handle))
            }

            ToolButton {
                id: removeButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("删除")
                onClicked: root.removeRequested(String(modelData.handle))
            }
        }

        Label {
            anchors.centerIn: parent
            visible: parent.count === 0
            text: qsTr("暂无栅栏")
            color: "#aab4c0"
        }
    }
}
