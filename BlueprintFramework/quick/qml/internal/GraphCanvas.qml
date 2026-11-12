import QtQuick 2.14
import QtQuick.Controls 2.14

// 焦点作用域保留内部焦点。点击画布或节点时，将焦点显式移到 backgroundArea。
FocusScope {
    id: canvas

    property var session
    property QtObject colors
    property var nodeContents
    property string selectedNodeId: ""
    property string selectedConnectionId: ""
    property real zoom: 1
    property point pan: Qt.point(0, 0)
    property string pendingNode: ""
    property string pendingPort: ""
    property point pointer: Qt.point(0, 0)
    property var nodeItems: ({})
    property Item selectedItem: null
    readonly property int nodeCount: cards.count
    readonly property var links: session ? session.connections : []
    readonly property string graphId: session ? session.graphId : ""
    readonly property var selectedNode: selectedItem ? selectedItem.nodeInfo : null
    readonly property string hoveredConnectionId: backgroundArea.containsMouse && !backgroundArea.pressed
                                                  && !pendingNode && !connectionMenu.visible
                                                  ? wireLayer.connectionAt(pointer) : ""

    clip: true
    onSelectedNodeIdChanged: {
        selectedItem = nodeItems[selectedNodeId] || null
        if (selectedNodeId)
            selectedConnectionId = ""
    }
    onSelectedConnectionIdChanged: if (selectedConnectionId) selectedNodeId = ""
    onSessionChanged: {
        selectedNodeId = ""
        selectedConnectionId = ""
        pendingNode = ""
    }
    onGraphIdChanged: {
        selectedNodeId = ""
        selectedConnectionId = ""
        pendingNode = ""
    }
    onPanChanged: {
        grid.requestPaint()
        Qt.callLater(resolveWires)
    }
    onZoomChanged: {
        grid.requestPaint()
        Qt.callLater(resolveWires)
    }
    onLinksChanged: {
        if (selectedConnectionId && !links.some(function(link) { return link.id === selectedConnectionId }))
            selectedConnectionId = ""
        Qt.callLater(resolveWires)
    }
    onPendingNodeChanged: Qt.callLater(resolveWires)
    Keys.onEscapePressed: {
        if (pendingNode)
            pendingNode = ""
        else
            selectedConnectionId = ""
    }
    Keys.onDeletePressed: {
        if (pendingNode)
            pendingNode = ""
        else if (session && selectedConnectionId)
            session.removeConnection(selectedConnectionId)
        else if (session && selectedNodeId)
            session.removeNode(selectedNodeId)
    }

    Connections {
        target: canvas.session
        function onGraphChanged() {
            if (canvas.selectedNodeId && !canvas.session.containsNode(canvas.selectedNodeId))
                canvas.selectedNodeId = ""
            if (canvas.pendingNode && !canvas.session.containsNode(canvas.pendingNode))
                canvas.pendingNode = ""
        }
    }

    function addNode(typeId, parameters, position) {
        if (!session)
            return
        if (!position) {
            var start = world.mapFromItem(canvas, width / 2, height / 2)
            var offset = (cards.count % 7) * 18
            position = Qt.point(start.x - 94 + offset, start.y - 60 + offset)
        }
        var id = session.placeNode(typeId, position, parameters || {})
        if (id) {
            backgroundArea.forceActiveFocus()
            selectedNodeId = id
            var card = nodeItems[id]
            if (card) {
                var center = card.mapToItem(canvas, card.width / 2, card.height / 2)
                if (!contains(center))
                    pan = Qt.point(pan.x + width / 2 - center.x, pan.y + height / 2 - center.y)
            }
        }
    }

    function fit() {
        var left = Infinity, top = Infinity, right = -Infinity, bottom = -Infinity
        for (var id in nodeItems) {
            var item = nodeItems[id]
            left = Math.min(left, item.x)
            top = Math.min(top, item.y)
            right = Math.max(right, item.x + item.width)
            bottom = Math.max(bottom, item.y + item.height)
        }
        if (left === Infinity) {
            zoom = 1
            pan = Qt.point(0, 0)
            return
        }
        zoom = Math.min(1, Math.max(0.12, Math.min((width - 68) / (right - left),
                                                 (height - 68) / (bottom - top))))
        pan = Qt.point(width / 2 - (left + right) * zoom / 2,
                       height / 2 - (top + bottom) * zoom / 2)
    }

    function emptyDropPosition(source, x, y) {
        var point = mapFromItem(source, x, y)
        if (!contains(point))
            return null
        for (var id in nodeItems) {
            var card = nodeItems[id]
            if (card.contains(card.mapFromItem(canvas, point.x, point.y)))
                return null
        }
        return world.mapFromItem(canvas, point.x, point.y)
    }

    function viewportAnchor(nodeId, key, isOutput) {
        var item = nodeItems[nodeId]
        var anchor = item ? item.portAnchor(key, isOutput) : null
        return anchor ? item.mapToItem(canvas, anchor.x, anchor.y) : null
    }

    function resolveWires() {
        var segments = []
        for (var i = 0; i < links.length; ++i) {
            var link = links[i]
            var from = viewportAnchor(link.source, link.sourcePort, true)
            var to = viewportAnchor(link.target, link.targetPort, false)
            if (from && to)
                segments.push({id: link.id, from: from, to: to,
                               execution: nodeItems[link.source].executionKeys.indexOf(link.sourcePort) !== -1})
        }
        wireLayer.segments = segments
        wireLayer.draftStart = pendingNode ? viewportAnchor(pendingNode, pendingPort, true) : null
    }

    function connectInput(nodeId, key) {
        if (pendingNode && session.connectPorts(pendingNode, pendingPort, nodeId, key))
            pendingNode = ""
    }

    Rectangle {
        anchors.fill: parent
        color: canvas.colors ? canvas.colors.backgroundCanvas : "transparent"
    }

    Canvas {
        id: grid
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (!canvas.colors)
                return
            var step = 26 * canvas.zoom
            if (step < 12)
                step *= 4
            var startX = (canvas.pan.x % step + step) % step
            var startY = (canvas.pan.y % step + step) % step
            ctx.strokeStyle = canvas.colors.borderPane
            ctx.lineWidth = 1
            ctx.beginPath()
            for (var x = startX; x < width; x += step) {
                ctx.moveTo(x, 0)
                ctx.lineTo(x, height)
            }
            for (var y = startY; y < height; y += step) {
                ctx.moveTo(0, y)
                ctx.lineTo(width, y)
            }
            ctx.stroke()
        }
    }

    ConnectionLayer {
        id: wireLayer
        objectName: "connectionLayer"
        anchors.fill: parent
        property var draftStart: null
        preview: canvas.pendingNode && draftStart ? ({from: draftStart, to: canvas.pointer}) : null
        zoom: canvas.zoom
        lineColor: canvas.colors ? canvas.colors.highlightText : "transparent"
        executionColor: canvas.colors ? canvas.colors.successText : "transparent"
        previewColor: canvas.colors ? canvas.colors.infoText : "transparent"
        selectedColor: canvas.colors ? canvas.colors.text : "transparent"
        selectedId: canvas.selectedConnectionId
        hoveredId: canvas.hoveredConnectionId
    }

    Menu {
        id: connectionMenu
        objectName: "connectionMenu"
        parent: canvas

        MenuItem {
            objectName: "removeConnectionMenuItem"
            text: qsTr("删除连线")
            enabled: !!canvas.selectedConnectionId
            onTriggered: if (canvas.session && canvas.selectedConnectionId)
                             canvas.session.removeConnection(canvas.selectedConnectionId)
        }
    }

    MouseArea {
        id: backgroundArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: pressed && panning ? Qt.ClosedHandCursor
                   : canvas.hoveredConnectionId ? Qt.PointingHandCursor : Qt.ArrowCursor
        property point origin
        property point originalPan
        property bool panning: false
        onPressed: {
            backgroundArea.forceActiveFocus()
            origin = Qt.point(mouse.x, mouse.y)
            originalPan = canvas.pan
            panning = false
        }
        onEntered: canvas.pointer = Qt.point(mouseX, mouseY)
        onPositionChanged: {
            canvas.pointer = Qt.point(mouse.x, mouse.y)
            if (pressed && (mouse.buttons & (Qt.LeftButton | Qt.MiddleButton))) {
                var dx = mouse.x - origin.x, dy = mouse.y - origin.y
                if (panning || Math.abs(dx) + Math.abs(dy) >= 5) {
                    panning = true
                    canvas.pan = Qt.point(originalPan.x + dx, originalPan.y + dy)
                }
            }
        }
        onClicked: {
            if (panning || Math.abs(mouse.x - origin.x) + Math.abs(mouse.y - origin.y) >= 5)
                return
            var id = canvas.pendingNode ? "" : wireLayer.connectionAt(Qt.point(mouse.x, mouse.y))
            if (mouse.button === Qt.RightButton) {
                if (id) {
                    canvas.selectedConnectionId = id
                    connectionMenu.popup(mouse.x, mouse.y)
                }
            } else if (mouse.button === Qt.LeftButton) {
                canvas.selectedConnectionId = id
                canvas.selectedNodeId = ""
                canvas.pendingNode = ""
            }
        }
        onWheel: {
            if (!wheel.angleDelta.y)
                return
            var scale = Math.max(0.12, Math.min(2.4, canvas.zoom * Math.pow(1.15, wheel.angleDelta.y / 120)))
            var ratio = scale / canvas.zoom
            canvas.pan = Qt.point(wheel.x - (wheel.x - canvas.pan.x) * ratio,
                                  wheel.y - (wheel.y - canvas.pan.y) * ratio)
            canvas.zoom = scale
            wheel.accepted = true
        }
    }

    Item {
        id: world
        x: canvas.pan.x
        y: canvas.pan.y
        scale: canvas.zoom
        transformOrigin: Item.TopLeft

        Repeater {
            id: cards
            model: canvas.colors ? canvas.session : null
            onItemAdded: {
                canvas.nodeItems[item.nodeKey] = item
                if (canvas.selectedNodeId === item.nodeKey)
                    canvas.selectedItem = item
                Qt.callLater(canvas.resolveWires)
            }
            onItemRemoved: {
                delete canvas.nodeItems[item.nodeKey]
                if (canvas.selectedItem === item)
                    canvas.selectedItem = null
                Qt.callLater(canvas.resolveWires)
            }

            delegate: GraphNode {
                id: card
                objectName: "node-" + nodeType
                nodeKey: nodeId
                kind: nodeType
                caption: nodeTitle
                parameters: nodeParameters
                contentComponent: canvas.nodeContents ? canvas.nodeContents[nodeType] || null : null
                inputs: inputPorts
                outputs: outputPorts
                executionKeys: executionPorts
                graphPosition: nodePosition
                colors: canvas.colors
                viewport: canvas
                viewScale: canvas.zoom
                selected: canvas.selectedNodeId === card.nodeKey
                activeOutput: canvas.pendingNode === card.nodeKey ? canvas.pendingPort : ""
                connecting: canvas.pendingNode !== ""
                onAnchorsChanged: Qt.callLater(canvas.resolveWires)
                onActivated: {
                    backgroundArea.forceActiveFocus()
                    canvas.selectedNodeId = card.nodeKey
                }
                onMoveRequested: canvas.session.moveNode(card.nodeKey, position)
                onOutputPressed: {
                    backgroundArea.forceActiveFocus()
                    canvas.selectedNodeId = card.nodeKey
                    canvas.pendingPort = key
                    canvas.pendingNode = card.nodeKey
                    canvas.pointer = position
                    Qt.callLater(canvas.resolveWires)
                }
                onConnectionPointerMoved: canvas.pointer = position
                onOutputCanceled: canvas.pendingNode = ""
                onOutputReleased: {
                    var closestNode = "", closestPort = "", distance = 16 * 16
                    for (var id in canvas.nodeItems) {
                        var other = canvas.nodeItems[id]
                        for (var p = 0; p < other.inputs.length; ++p) {
                            var key = other.inputs[p]
                            var anchor = canvas.viewportAnchor(id, key, false)
                            if (!anchor)
                                continue
                            var dx = position.x - anchor.x, dy = position.y - anchor.y
                            var candidate = dx * dx + dy * dy
                            if (candidate <= distance) {
                                closestNode = id
                                closestPort = key
                                distance = candidate
                            }
                        }
                    }
                    if (closestNode)
                        canvas.connectInput(closestNode, closestPort)
                    else
                        canvas.pendingNode = ""
                }
                onInputPressed: {
                    backgroundArea.forceActiveFocus()
                    if (contextRequested) {
                        canvas.pendingNode = ""
                        for (var i = 0; i < canvas.links.length; ++i) {
                            var link = canvas.links[i]
                            if (link.target === card.nodeKey && link.targetPort === key) {
                                canvas.selectedConnectionId = link.id
                                connectionMenu.popup(position.x, position.y)
                                return
                            }
                        }
                    }
                    canvas.selectedNodeId = card.nodeKey
                    if (!contextRequested)
                        canvas.connectInput(card.nodeKey, key)
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: cards.count === 0 && !!canvas.colors
        color: canvas.colors ? canvas.colors.subtleText : "transparent"
        font.pixelSize: 15
        text: qsTr("从节点库添加节点")
    }

    Component.onCompleted: Qt.callLater(fit)
}
