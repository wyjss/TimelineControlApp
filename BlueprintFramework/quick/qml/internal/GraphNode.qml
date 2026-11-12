import QtQuick 2.14

Rectangle {
    id: card

    property string nodeKey
    property string kind
    property string caption
    property var parameters: ({})
    property Component contentComponent
    property var inputs: []
    property var outputs: []
    property var executionKeys: []
    property point graphPosition
    property point dragOffset: Qt.point(0, 0)
    property Item viewport
    property real viewScale: 1
    property QtObject colors
    property bool selected: false
    property string activeOutput
    property bool connecting: false
    readonly property var nodeInfo: ({id: nodeKey, typeId: kind, title: caption, parameters: parameters})
    readonly property int headerHeight: 38
    readonly property int portHeight: 28
    readonly property int portRows: Math.max(inputs.length, outputs.length)
    readonly property real portTop: headerHeight + (body.item ? body.height + 8 : 0)

    signal activated()
    signal moveRequested(point position)
    signal outputPressed(string key, point position)
    signal connectionPointerMoved(point position)
    signal outputReleased(point position)
    signal outputCanceled()
    signal inputPressed(string key, bool contextRequested, point position)
    signal anchorsChanged()

    function portAnchor(key, isOutput) {
        var keys = isOutput ? outputs : inputs
        for (var row = 0; row < keys.length; ++row) {
            if (keys[row] === key)
                return Qt.point(isOutput ? width : 0, portTop + (row + 0.5) * portHeight)
        }
        return null
    }

    x: graphPosition.x + dragOffset.x
    y: graphPosition.y + dragOffset.y
    width: 188
    height: portTop + portRows * portHeight + 10
    radius: 9
    color: colors.backgroundSurface
    border.width: selected ? 2 : 1
    border.color: selected ? colors.highlightText : colors.border
    z: selected ? 1 : 0
    onXChanged: anchorsChanged()
    onYChanged: anchorsChanged()
    onWidthChanged: anchorsChanged()
    onPortTopChanged: anchorsChanged()
    onInputsChanged: anchorsChanged()
    onOutputsChanged: anchorsChanged()

    MouseArea {
        anchors.fill: parent
        onClicked: card.activated()
    }

    Rectangle {
        x: 3
        y: 3
        width: parent.width - 6
        height: card.headerHeight - 4
        radius: 6
        color: card.colors.highlightSoft

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "◇"
            color: card.colors.highlightText
            font.pixelSize: 17
            font.bold: true
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 33
            anchors.verticalCenter: parent.verticalCenter
            text: card.caption
            color: card.colors.text
            font.pixelSize: 14
            font.bold: true
        }

        MouseArea {
            id: headerDrag
            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property point origin
            onPressed: {
                origin = card.viewport.mapFromItem(headerDrag, mouse.x, mouse.y)
                card.activated()
            }
            onPositionChanged: {
                if (pressed) {
                    var p = card.viewport.mapFromItem(headerDrag, mouse.x, mouse.y)
                    card.dragOffset = Qt.point((p.x - origin.x) / card.viewScale,
                                               (p.y - origin.y) / card.viewScale)
                }
            }
            onReleased: {
                if (card.dragOffset.x !== 0 || card.dragOffset.y !== 0)
                    card.moveRequested(Qt.point(card.x, card.y))
                card.dragOffset = Qt.point(0, 0)
            }
            onCanceled: card.dragOffset = Qt.point(0, 0)
        }
    }

    Loader {
        id: body
        x: 10
        y: card.headerHeight + 6
        width: card.width - 20
        height: item ? item.implicitHeight : 0
        sourceComponent: card.contentComponent
    }

    Binding {
        target: body.item
        property: "node"
        value: card.nodeInfo
        when: !!body.item
    }

    Repeater {
        model: card.inputs
        delegate: Item {
            readonly property bool execution: card.executionKeys.indexOf(modelData) !== -1
            readonly property color portColor: execution ? card.colors.successText : card.colors.highlightText
            x: 0
            y: card.portTop + index * card.portHeight
            width: 70
            height: card.portHeight

            Rectangle {
                width: 10
                height: width
                radius: execution ? 2 : width / 2
                x: -width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: inputHit.containsMouse && card.connecting ? portColor : card.colors.backgroundCanvas
                border.color: portColor
                border.width: 2
            }
            Text {
                x: 13
                anchors.verticalCenter: parent.verticalCenter
                text: execution ? qsTr("执行") : modelData === "value" ? qsTr("输入") : modelData
                color: card.colors.subtleText
                font.pixelSize: 12
            }
            MouseArea {
                id: inputHit
                objectName: "input-" + modelData
                x: -10
                width: parent.width + 10
                height: parent.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                // Qt 5 在悬停进入时更新坐标，但不发送 positionChanged。
                onEntered: {
                    if (card.connecting)
                        card.connectionPointerMoved(card.viewport.mapFromItem(inputHit, mouseX, mouseY))
                }
                onPositionChanged: {
                    if (card.connecting)
                        card.connectionPointerMoved(card.viewport.mapFromItem(inputHit, mouse.x, mouse.y))
                }
                onClicked: card.inputPressed(modelData, mouse.button === Qt.RightButton,
                                            card.viewport.mapFromItem(inputHit, mouse.x, mouse.y))
            }
        }
    }

    Repeater {
        model: card.outputs
        delegate: Item {
            readonly property bool execution: card.executionKeys.indexOf(modelData) !== -1
            readonly property color portColor: execution ? card.colors.successText : card.colors.highlightText
            x: card.width - 70
            y: card.portTop + index * card.portHeight
            width: 70
            height: card.portHeight

            Rectangle {
                width: 10
                height: width
                radius: execution ? 2 : width / 2
                x: parent.width - width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: outputHit.containsMouse || card.activeOutput === modelData
                       ? portColor : card.colors.backgroundCanvas
                border.color: portColor
                border.width: 2
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 13
                anchors.verticalCenter: parent.verticalCenter
                text: execution ? qsTr("继续") : modelData === "value" ? qsTr("输出") : modelData
                color: card.colors.subtleText
                font.pixelSize: 12
            }
            MouseArea {
                id: outputHit
                objectName: "output-" + modelData
                width: parent.width + 10
                height: parent.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                property point origin
                onPressed: {
                    origin = card.viewport.mapFromItem(outputHit, mouse.x, mouse.y)
                    card.outputPressed(modelData, origin)
                }
                onEntered: {
                    if (card.connecting)
                        card.connectionPointerMoved(card.viewport.mapFromItem(outputHit, mouseX, mouseY))
                }
                onPositionChanged: {
                    if (pressed || card.connecting)
                        card.connectionPointerMoved(card.viewport.mapFromItem(outputHit, mouse.x, mouse.y))
                }
                onReleased: {
                    var p = card.viewport.mapFromItem(outputHit, mouse.x, mouse.y)
                    if (Math.abs(p.x - origin.x) + Math.abs(p.y - origin.y) > 5)
                        card.outputReleased(p)
                }
                onCanceled: card.outputCanceled()
            }
        }
    }

}
