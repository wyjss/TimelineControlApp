import QtQuick 2.14
import QtQuick.Controls 2.14

Rectangle {
    id: card

    property string nodeKey
    property string kind
    property string caption
    property var parameters: ({})
    property Component contentComponent
    property Component headerComponent
    property var inputs: []
    property var outputs: []
    property string executionState
    property point graphPosition
    property point dragOffset: Qt.point(0, 0)
    property Item viewport
    property real viewScale: 1
    property QtObject colors
    property var headerColors: null
    property bool selected: false
    property string activeOutput
    property bool connecting: false
    property string targetInput
    property string targetOutput
    property bool connectionExecution: false
    property string connectionError
    readonly property var nodeInfo: ({id: nodeKey, typeId: kind, title: caption, parameters: parameters})
    readonly property bool dragging: headerDrag.pressed && !headerDrag.canceled
    readonly property real headerHeight: header.item ? header.item.implicitHeight + 6 : 38
    readonly property int portHeight: 28
    readonly property int portHitHalfSize: 9
    readonly property string statusText: executionState === "running" ? qsTr("执行中")
                                         : executionState === "waiting" ? qsTr("等待中")
                                         : executionState === "failed" ? qsTr("执行失败") : ""
    readonly property int statusHeight: statusText ? 17 : 0
    readonly property int portRows: Math.max(inputs.length, outputs.length)
    readonly property real portTop: headerHeight + (body.item ? body.height + 8 : 0)

    signal activated()
    signal moveRequested(point position)
    signal portPressed(string key, bool isOutput, bool contextRequested, point position)
    signal connectionPointerMoved(point position)
    signal portReleased(point position)
    signal connectionCanceled()
    signal anchorsChanged()

    function portAnchor(key, isOutput) {
        var keys = isOutput ? outputs : inputs
        for (var row = 0; row < keys.length; ++row) {
            if (keys[row].key === key)
                return Qt.point(isOutput ? width : 0, portTop + (row + 0.5) * portHeight)
        }
        return null
    }

    x: graphPosition.x + dragOffset.x
    y: graphPosition.y + dragOffset.y
    width: 188
    height: portTop + portRows * portHeight + statusHeight + 10
    radius: 9
    color: colors.backgroundSurface
    border.width: selected ? 2 : 1
    border.color: selected ? (headerColors ? colors.text : colors.highlightText) : colors.border
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
        color: header.item ? "transparent" : card.headerColors ? card.headerColors.background : card.colors.highlightSoft

        Loader {
            id: header
            anchors.fill: parent
            sourceComponent: card.headerComponent
        }

        Binding {
            target: header.item
            property: "node"
            value: card.nodeInfo
            when: !!header.item
        }

        Text {
            visible: !header.item
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "◇"
            color: card.headerColors ? card.headerColors.accent : card.colors.highlightText
            font.pixelSize: 17
            font.bold: true
        }

        Text {
            id: titleLabel
            visible: !header.item
            anchors.left: parent.left
            anchors.leftMargin: 33
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: card.caption
            elide: Text.ElideRight
            color: card.colors.text
            font.pixelSize: 14
            font.bold: true
        }

        MouseArea {
            id: headerDrag
            anchors.fill: parent
            hoverEnabled: !card.connecting
            ToolTip.visible: !header.item && titleLabel.truncated && containsMouse && !pressed && !card.connecting
            ToolTip.text: card.caption
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property point origin
            property bool canceled: false
            property bool dragStarted: false

            Connections {
                target: card.viewport.interactionHost
                function onInteractionCanceled() {
                    headerDrag.canceled = true
                    headerDrag.dragStarted = false
                    card.dragOffset = Qt.point(0, 0)
                }
            }

            onPressed: {
                card.activated()
                origin = card.viewport.mapFromItem(headerDrag, mouse.x, mouse.y)
                canceled = false
                dragStarted = false
            }
            onPositionChanged: {
                if (pressed && !canceled) {
                    var p = card.viewport.mapFromItem(headerDrag, mouse.x, mouse.y)
                    var dx = p.x - origin.x, dy = p.y - origin.y
                    if (!dragStarted) {
                        if (Math.abs(dx) + Math.abs(dy) <= Qt.styleHints.startDragDistance)
                            return
                        dragStarted = true
                        // 从越过阈值的位置起算，避免起步跳过整段累计位移。
                        origin = p
                        return
                    }
                    card.dragOffset = Qt.point(dx / card.viewScale, dy / card.viewScale)
                }
            }
            onReleased: {
                if (!canceled && dragStarted && (card.dragOffset.x !== 0 || card.dragOffset.y !== 0))
                    card.moveRequested(Qt.point(card.x, card.y))
                card.dragOffset = Qt.point(0, 0)
                dragStarted = false
            }
            onCanceled: {
                canceled = true
                dragStarted = false
                card.dragOffset = Qt.point(0, 0)
            }
        }
    }

    Text {
        objectName: "nodeExecutionState"
        x: 10
        y: card.portTop + card.portRows * card.portHeight
        width: card.width - 20
        visible: card.statusText !== ""
        text: card.statusText
        font.pixelSize: 11
        color: card.executionState === "failed" ? card.colors.dangerText
             : card.executionState === "waiting" ? card.colors.infoText : card.colors.successText
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
            readonly property bool execution: modelData.execution
            readonly property color portColor: execution ? card.colors.successText : card.colors.highlightText
            readonly property bool candidate: card.targetInput === modelData.key
            readonly property color feedbackColor: candidate && card.connectionError !== "" ? card.colors.dangerText : portColor
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
                color: candidate ? feedbackColor : card.colors.backgroundCanvas
                border.color: feedbackColor
                border.width: 2
            }
            Text {
                id: inputLabel
                readonly property string overrideText: {
                    var host = card.viewport ? card.viewport.interactionHost : null
                    return host && host.inputPortLabel ? host.inputPortLabel(card.nodeInfo, modelData) : ""
                }
                x: 13
                width: card.outputs.length > index ? card.width / 2 - 17 : card.width - 26
                anchors.verticalCenter: parent.verticalCenter
                text: overrideText || modelData.title
                elide: Text.ElideRight
                color: overrideText ? card.colors.text : card.colors.subtleText
                font.pixelSize: overrideText ? 14 : 12
                font.bold: overrideText !== ""
            }
            MouseArea {
                id: inputHit
                ToolTip.visible: inputLabel.truncated && containsMouse && !pressed && !card.connecting
                ToolTip.text: inputLabel.text
                objectName: "input-" + modelData.key
                x: -card.portHitHalfSize
                width: card.portHitHalfSize * 2
                height: width
                anchors.verticalCenter: parent.verticalCenter
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                property point origin
                property bool dragged: false
                property bool canceled: true

                Connections {
                    target: card.viewport.interactionHost
                    function onInteractionCanceled() {
                        inputHit.canceled = true
                        inputHit.dragged = false
                    }
                }
                onPressed: {
                    dragged = false
                    origin = card.viewport.mapFromItem(inputHit, mouse.x, mouse.y)
                    card.portPressed(modelData.key, false, mouse.button === Qt.RightButton, origin)
                    canceled = false
                }
                // Qt 5 在悬停进入时更新坐标，但不发送 positionChanged。
                onEntered: {
                    if (card.connecting)
                        card.connectionPointerMoved(card.viewport.mapFromItem(inputHit, mouseX, mouseY))
                }
                onPositionChanged: {
                    var p = card.viewport.mapFromItem(inputHit, mouse.x, mouse.y)
                    if (pressed && !canceled
                        && Math.abs(p.x - origin.x) + Math.abs(p.y - origin.y) > Qt.styleHints.startDragDistance)
                        dragged = true
                    if ((pressed && !canceled) || card.connecting)
                        card.connectionPointerMoved(p)
                }
                onReleased: {
                    var p = card.viewport.mapFromItem(inputHit, mouse.x, mouse.y)
                    if (!canceled && mouse.button === Qt.LeftButton
                        && (dragged || Math.abs(p.x - origin.x) + Math.abs(p.y - origin.y) > Qt.styleHints.startDragDistance))
                        card.portReleased(p)
                }
                onCanceled: {
                    canceled = true
                    card.connectionCanceled()
                }
            }
        }
    }

    Repeater {
        model: card.outputs
        delegate: Item {
            readonly property bool execution: modelData.execution
            readonly property bool compound: modelData.data && modelData.executionCapable
            readonly property color portColor: execution ? card.colors.successText : card.colors.highlightText
            readonly property bool candidate: card.targetOutput === modelData.key
            readonly property color feedbackColor: candidate && card.connectionError !== "" ? card.colors.dangerText
                : (candidate || card.activeOutput === modelData.key) && card.connectionExecution ? card.colors.successText : portColor
            x: card.width - 70
            y: card.portTop + index * card.portHeight
            width: 70
            height: card.portHeight

            Rectangle {
                objectName: "outputGraphic-" + modelData.key
                width: 10
                height: width
                radius: execution || compound ? 2 : width / 2
                rotation: compound ? 45 : 0
                x: parent.width - width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: candidate || outputHit.containsMouse || card.activeOutput === modelData.key
                       ? feedbackColor : card.colors.backgroundCanvas
                border.color: feedbackColor
                border.width: 2

                Rectangle {
                    anchors.centerIn: parent
                    width: 4
                    height: width
                    radius: width / 2
                    visible: compound
                    color: card.colors.successText
                }
            }
            Text {
                id: outputLabel
                anchors.right: parent.right
                anchors.rightMargin: 13
                anchors.verticalCenter: parent.verticalCenter
                width: card.inputs.length > index ? card.width / 2 - 17 : card.width - 26
                text: modelData.title
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                color: card.colors.subtleText
                font.pixelSize: 12
            }
            MouseArea {
                id: outputHit
                ToolTip.visible: (outputLabel.truncated || compound) && containsMouse && !pressed && !card.connecting
                ToolTip.text: outputLabel.truncated ? modelData.title + (compound ? "\n" + qsTr("数据 + 执行") : "")
                                                   : qsTr("数据 + 执行")
                objectName: "output-" + modelData.key
                x: parent.width - card.portHitHalfSize
                width: card.portHitHalfSize * 2
                height: width
                anchors.verticalCenter: parent.verticalCenter
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                property point origin
                property bool dragged: false
                property bool canceled: true

                Connections {
                    target: card.viewport.interactionHost
                    function onInteractionCanceled() {
                        outputHit.canceled = true
                        outputHit.dragged = false
                    }
                }
                onPressed: {
                    dragged = false
                    origin = card.viewport.mapFromItem(outputHit, mouse.x, mouse.y)
                    card.portPressed(modelData.key, true, false, origin)
                    canceled = false
                }
                onEntered: {
                    if (card.connecting)
                        card.connectionPointerMoved(card.viewport.mapFromItem(outputHit, mouseX, mouseY))
                }
                onPositionChanged: {
                    var p = card.viewport.mapFromItem(outputHit, mouse.x, mouse.y)
                    if (pressed && !canceled
                        && Math.abs(p.x - origin.x) + Math.abs(p.y - origin.y) > Qt.styleHints.startDragDistance)
                        dragged = true
                    if ((pressed && !canceled) || card.connecting)
                        card.connectionPointerMoved(p)
                }
                onReleased: {
                    var p = card.viewport.mapFromItem(outputHit, mouse.x, mouse.y)
                    if (!canceled && (dragged || Math.abs(p.x - origin.x) + Math.abs(p.y - origin.y) > Qt.styleHints.startDragDistance))
                        card.portReleased(p)
                }
                onCanceled: {
                    canceled = true
                    card.connectionCanceled()
                }
            }
        }
    }

}
