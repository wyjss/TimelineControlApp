import QtQuick 2.14
import QtQuick.Controls 2.14

MouseArea {
    id: source

    property Item graphEditor
    property string title
    property string dropText: qsTr("释放创建节点")
    property bool canceled: true
    readonly property bool dragging: drag.active && !canceled
    readonly property var dropPosition: dragging
                                        ? graphEditor.emptyDropPosition(source, mouseX, mouseY) : null

    signal dropped(point position)

    hoverEnabled: true
    preventStealing: true
    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    drag.target: preview
    drag.smoothed: false
    Keys.priority: Keys.AfterItem
    Keys.onEscapePressed: {
        graphEditor.interactionCanceled()
        event.accepted = true
    }
    onPressed: {
        graphEditor.interactionCanceled()
        canceled = false
        forceActiveFocus()
        var position = mapToItem(Overlay.overlay, mouse.x, mouse.y)
        preview.x = position.x
        preview.y = position.y
    }
    onReleased: {
        if (canceled)
            return
        var position = graphEditor.emptyDropPosition(source, mouse.x, mouse.y)
        graphEditor.interactionCanceled()
        if (position !== null)
            dropped(position)
    }
    onCanceled: canceled = true

    Connections {
        target: source.graphEditor
        function onInteractionCanceled() { source.canceled = true }
    }

    Rectangle {
        id: preview

        parent: Overlay.overlay
        visible: source.dragging
        width: 188 * source.graphEditor.zoom
        height: 38 * source.graphEditor.zoom
        radius: 7 * source.graphEditor.zoom
        opacity: 0.9
        color: source.graphEditor.colors.backgroundSurface
        border.width: 2
        border.color: source.dropPosition !== null ? source.graphEditor.colors.highlightText
                                                   : source.graphEditor.colors.dangerText

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10 * source.graphEditor.zoom
            anchors.rightMargin: 10 * source.graphEditor.zoom
            anchors.verticalCenter: parent.verticalCenter
            text: source.title
            elide: Text.ElideRight
            font.pixelSize: 14 * source.graphEditor.zoom
            font.bold: true
            color: source.graphEditor.colors.text
        }

        Text {
            anchors.top: parent.bottom
            anchors.topMargin: 6
            text: source.dropPosition === null ? qsTr("拖到画布空白处") : source.dropText
            font.pixelSize: 11
            color: preview.border.color
        }
    }
}
