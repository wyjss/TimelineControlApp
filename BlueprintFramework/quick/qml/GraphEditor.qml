import QtQuick 2.14
import QtQuick.Layouts 1.14
import "internal" as Internal

Item {
    id: editor

    property var session: null
    property QtObject colors
    // 内容组件根项声明 node 属性并通过 implicitHeight 提供高度。
    property var nodeContents: ({})
    property Component palettePanel
    property Component inspectorPanel
    property alias selectedNodeId: canvas.selectedNodeId
    readonly property string selectedConnectionId: canvas.selectedConnectionId
    readonly property var selectedNode: canvas.selectedNode
    readonly property int nodeCount: canvas.nodeCount
    readonly property int connectionCount: canvas.links.length
    readonly property real zoom: canvas.zoom
    readonly property bool connecting: canvas.pendingNode !== ""

    // 参数和画布坐标可选，支持直接放置已绑定对象。
    function addNode(typeId, parameters, position) { canvas.addNode(typeId, parameters, position) }
    function fit() { canvas.fit() }
    // 扩展内容可将释放位置转换成画布坐标，只接受空白区域。
    function emptyDropPosition(source, x, y) { return canvas.emptyDropPosition(source, x, y) }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Loader {
            sourceComponent: editor.palettePanel
            visible: !!sourceComponent
            Layout.fillHeight: true
            Layout.preferredWidth: item ? item.implicitWidth : 0
        }

        Internal.GraphCanvas {
            id: canvas
            objectName: "graphCanvas"
            Layout.fillWidth: true
            Layout.fillHeight: true
            session: editor.session
            colors: editor.colors
            nodeContents: editor.nodeContents
        }

        Loader {
            sourceComponent: editor.inspectorPanel
            visible: !!sourceComponent
            Layout.fillHeight: true
            Layout.preferredWidth: item ? item.implicitWidth : 0
        }
    }
}
