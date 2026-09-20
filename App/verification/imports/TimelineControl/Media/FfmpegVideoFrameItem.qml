import QtQuick 2.14

// 页面测试替身：不打开文件、不解码视频。
Item {
    property url source: ""
    property bool playing: false
    property int position: 0
    property int duration: 150000
    property size videoSize: Qt.size(1920, 1080)
    property string errorString: ""
    property bool hasFrame: source.toString().length > 0

    onSourceChanged: { playing = false; position = 0 }
    function play() { playing = true }
    function pause() { playing = false }
    function seek(value) { position = value }

    Rectangle {
        anchors.fill: parent
        visible: parent.hasFrame
        color: "#257b9d"
        Rectangle { width: parent.width / 4; height: parent.height; color: "#66c2b7" }
    }
}
