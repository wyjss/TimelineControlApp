import QtQuick 2.14

Item {
    id: root

    property string name: ""
    property int size: 32

    readonly property url iconSource: "image://deviceicon/"
        + encodeURIComponent(name.length > 0 ? name : "missing")

    implicitWidth: size
    implicitHeight: size

    Image {
        anchors.fill: parent
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }
}
