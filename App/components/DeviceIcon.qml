import QtQuick 2.14

Item {
    id: root

    property string name: ""
    property int size: 32

    readonly property url iconSource: name.length > 0
        ? "qrc:/TimelineControlApp/App/assets/icons/" + encodeURIComponent(name) + ".png"
        : ""
    readonly property url missingSource: "qrc:/TimelineControlApp/App/assets/icons/missing.png"

    implicitWidth: size
    implicitHeight: size

    Image {
        anchors.fill: parent
        source: root.missingSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: iconImage.status !== Image.Ready
    }

    Image {
        id: iconImage

        anchors.fill: parent
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: status === Image.Ready
    }
}
