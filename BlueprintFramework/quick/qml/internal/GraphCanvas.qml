import QtQuick 2.14
import QtQuick.Window 2.14
import QtQuick.Controls 2.14

// 焦点作用域保留内部焦点。点击画布或节点时，将焦点显式移到 backgroundArea。
FocusScope {
    id: canvas

    property Item interactionHost
    property var session
    property QtObject colors
    property var nodeContents
    property var nodeStates: ({})
    property var nodeHeaders
    property var nodeColors: ({})
    property string selectedNodeId: ""
    property string selectedConnectionId: ""
    property real zoom: 1
    property bool initialFitPending: true
    property point pan: Qt.point(0, 0)
    property string pendingNode: ""
    property string pendingPort: ""
    property bool pendingOutput: true
    property string reconnectId: ""
    property point pointer: Qt.point(0, 0)
    property var connectionTarget: null
    property var nodeItems: ({})
    property Item selectedItem: null
    readonly property int nodeCount: cards.count
    readonly property var links: session ? session.connections : []
    readonly property string graphId: session ? session.graphId : ""
    readonly property bool previewExecution: {
        if (pendingOutput && connectionTarget)
            return connectionTarget.execution
        var item = nodeItems[pendingNode]
        var ports = item ? (pendingOutput ? item.outputs : item.inputs) : []
        var port = ports.find(function(port) { return port.key === pendingPort })
        return !!port && port.execution
    }
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
        if (interactionHost)
            interactionHost.interactionCanceled()
        initialFitPending = true
        Qt.callLater(fitInitially)
    }
    onGraphIdChanged: {
        selectedNodeId = ""
        selectedConnectionId = ""
        if (interactionHost)
            interactionHost.interactionCanceled()
        initialFitPending = true
        Qt.callLater(fitInitially)
    }
    onWidthChanged: if (initialFitPending) Qt.callLater(fitInitially)
    onHeightChanged: if (initialFitPending) Qt.callLater(fitInitially)
    onColorsChanged: if (initialFitPending) Qt.callLater(fitInitially)
    onVisibleChanged: if (visible && initialFitPending) Qt.callLater(fitInitially)
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
        if (reconnectId && !links.some(function(link) { return link.id === reconnectId }))
            interactionHost.interactionCanceled()
        Qt.callLater(resolveWires)
    }
    onPendingNodeChanged: {
        if (!pendingNode) {
            reconnectId = ""
            connectionTarget = null
        }
        Qt.callLater(resolveWires)
    }
    onReconnectIdChanged: Qt.callLater(resolveWires)
    onPointerChanged: if (pendingNode) Qt.callLater(resolveWires)
    Keys.priority: Keys.AfterItem
    Keys.onPressed: {
        if (!backgroundArea.activeFocus) {
            event.accepted = false
            return
        }
        event.accepted = true
        if (event.key === Qt.Key_Escape) {
            interactionHost.interactionCanceled()
            selectedConnectionId = ""
        } else if (event.key === Qt.Key_Delete) {
            if (pendingNode)
                interactionHost.interactionCanceled()
            else if (session && selectedConnectionId)
                session.removeConnection(selectedConnectionId)
            else if (session && selectedNodeId)
                session.removeNode(selectedNodeId)
        } else if (session && event.matches(StandardKey.Undo)) {
            interactionHost.interactionCanceled()
            session.undo()
        } else if (session && event.matches(StandardKey.Redo)) {
            interactionHost.interactionCanceled()
            session.redo()
        } else {
            event.accepted = false
        }
    }

    Connections {
        target: canvas.interactionHost
        function onInteractionCanceled() {
            canvas.pendingNode = ""
            canvas.connectionTarget = null
            if (backgroundArea.panning)
                canvas.pan = backgroundArea.originalPan
            backgroundArea.panning = false
            backgroundArea.canceled = true
            if (canvas.Window.window && canvas.Window.window.active)
                backgroundArea.forceActiveFocus()
        }
    }

    Connections {
        target: canvas.session
        function onModelReset() { canvas.interactionHost.interactionCanceled() }
        function onGraphChanged() {
            if (canvas.selectedNodeId && !canvas.session.containsNode(canvas.selectedNodeId))
                canvas.selectedNodeId = ""
            if (canvas.pendingNode && !canvas.viewportAnchor(canvas.pendingNode, canvas.pendingPort, canvas.pendingOutput))
                canvas.interactionHost.interactionCanceled()
            Qt.callLater(canvas.resolveWires)
        }
    }

    function addNode(typeId, parameters, position) {
        if (!session)
            return
        interactionHost.interactionCanceled()
        if (!position) {
            var start = world.mapFromItem(canvas, width / 2, height / 2)
            var offset = (cards.count % 7) * 18
            position = Qt.point(start.x - 94 + offset, start.y - 60 + offset)
        }
        var id = session.placeNode(typeId, position, parameters || {})
        if (id) {
            initialFitPending = false
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

    // 嵌入布局和节点委托可能分批就绪，只在用户操作视口前自动适配。
    function fitInitially() {
        if (initialFitPending && colors && visible && width > 68 && height > 68
            && Object.keys(nodeItems).length === cards.count)
            fit()
    }

    function fit() {
        if (width <= 0 || height <= 0)
            return
        initialFitPending = false
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

    // 吸附预检与提交共用端点和替换连线，避免预览允许而提交失败。
    function connectionProposal(nodeId, key) {
        var source = pendingOutput ? pendingNode : nodeId
        var sourcePort = pendingOutput ? pendingPort : key
        var target = pendingOutput ? nodeId : pendingNode
        var targetPort = pendingOutput ? key : pendingPort
        var replaced = reconnectId ? null : links.find(function(link) {
            return !link.execution && link.target === target && link.targetPort === targetPort
        })
        return {source: source, sourcePort: sourcePort, target: target, targetPort: targetPort,
                id: reconnectId || (replaced ? replaced.id : "")}
    }

    function resolveWires() {
        var segments = []
        for (var i = 0; i < links.length; ++i) {
            var link = links[i]
            if (link.id === reconnectId)
                continue
            var from = viewportAnchor(link.source, link.sourcePort, true)
            var to = viewportAnchor(link.target, link.targetPort, false)
            if (from && to)
                segments.push({id: link.id, from: from, to: to,
                               execution: link.execution})
        }
        var target = null, invalidTarget = null
        var distance = Infinity, invalidDistance = Infinity
        if (pendingNode && session && contains(pointer)) {
            for (var id in nodeItems) {
                var item = nodeItems[id]
                if (!item.visible || !item.enabled)
                    continue
                var ports = pendingOutput ? item.inputs : item.outputs
                var hitHalfSize = item.portHitHalfSize * zoom
                for (var p = 0; p < ports.length; ++p) {
                    var key = ports[p].key
                    var anchor = viewportAnchor(id, key, !pendingOutput)
                    if (!anchor || !contains(anchor))
                        continue
                    var dx = pointer.x - anchor.x, dy = pointer.y - anchor.y
                    if (Math.abs(dx) > hitHalfSize || Math.abs(dy) > hitHalfSize)
                        continue
                    var candidate = dx * dx + dy * dy
                    // 取端口朝卡片内侧的一点，避免浮点误差把它判到卡片外。
                    var hitX = anchor.x + (pendingOutput ? 1 : -1) * zoom
                    var hit = world.mapFromItem(canvas, hitX, anchor.y)
                    if (world.childAt(hit.x, hit.y) !== item)
                        continue
                    var proposal = connectionProposal(id, key)
                    var error = session.canConnect(proposal.source, proposal.sourcePort,
                                                   proposal.target, proposal.targetPort, proposal.id)
                    if (!error && candidate <= distance) {
                        target = {nodeId: id, portKey: key, position: anchor, error: "", execution: ports[p].execution}
                        distance = candidate
                    } else if (error && candidate <= invalidDistance) {
                        invalidTarget = {nodeId: id, portKey: key, position: anchor, error: error, execution: ports[p].execution}
                        invalidDistance = candidate
                    }
                }
            }
        }
        connectionTarget = target || invalidTarget
        wireLayer.segments = segments
        wireLayer.draftStart = pendingNode ? viewportAnchor(pendingNode, pendingPort, pendingOutput) : null
    }

    function completeConnection(nodeId, key) {
        var proposal = connectionProposal(nodeId, key)
        var connected = proposal.id
            ? session.reconnectConnection(proposal.id, proposal.source, proposal.sourcePort,
                                          proposal.target, proposal.targetPort)
            : session.connectPorts(proposal.source, proposal.sourcePort, proposal.target, proposal.targetPort)
        if (connected)
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
        property point draftEnd: canvas.connectionTarget && !canvas.connectionTarget.error
                                 ? canvas.connectionTarget.position : canvas.pointer
        preview: canvas.pendingNode && draftStart
                 ? (canvas.pendingOutput ? {from: draftStart, to: draftEnd}
                                         : {from: draftEnd, to: draftStart}) : null
        zoom: canvas.zoom
        lineColor: canvas.colors ? canvas.colors.highlightText : "transparent"
        executionColor: canvas.colors ? canvas.colors.successText : "transparent"
        previewColor: canvas.colors ? (canvas.connectionTarget && canvas.connectionTarget.error
                                      ? canvas.colors.dangerText : canvas.previewExecution
                                        ? canvas.colors.successText : canvas.colors.infoText) : "transparent"
        selectedColor: canvas.colors ? canvas.colors.text : "transparent"
        selectedId: canvas.selectedConnectionId
        hoveredId: canvas.hoveredConnectionId
    }

    ToolTip {
        parent: canvas
        visible: !!canvas.pendingNode && !!canvas.connectionTarget && !!canvas.connectionTarget.error
        text: canvas.connectionTarget ? canvas.connectionTarget.error : ""
        x: Math.min(canvas.pointer.x + 12, canvas.width - width)
        y: Math.min(canvas.pointer.y + 12, canvas.height - height)
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
        property bool canceled: true
        onPressed: {
            canvas.interactionHost.interactionCanceled()
            backgroundArea.forceActiveFocus()
            canceled = false
            origin = Qt.point(mouse.x, mouse.y)
            originalPan = canvas.pan
            panning = false
        }
        onEntered: canvas.pointer = Qt.point(mouseX, mouseY)
        onPositionChanged: {
            canvas.pointer = Qt.point(mouse.x, mouse.y)
            if (pressed && !canceled && (mouse.buttons & (Qt.LeftButton | Qt.MiddleButton))) {
                var dx = mouse.x - origin.x, dy = mouse.y - origin.y
                if (panning || Math.abs(dx) + Math.abs(dy) >= Qt.styleHints.startDragDistance) {
                    panning = true
                    canvas.initialFitPending = false
                    canvas.pan = Qt.point(originalPan.x + dx, originalPan.y + dy)
                }
            }
        }
        onReleased: {
            // 平移后不再按单击处理，包括拖回按下位置的情况。
            canceled = canceled || panning
            panning = false
        }
        onCanceled: canvas.interactionHost.interactionCanceled()
        onClicked: {
            if (canceled || Math.abs(mouse.x - origin.x) + Math.abs(mouse.y - origin.y) >= Qt.styleHints.startDragDistance)
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
            if (scale !== canvas.zoom)
                canvas.initialFitPending = false
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
                if (canvas.initialFitPending)
                    Qt.callLater(canvas.fitInitially)
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
                headerComponent: canvas.nodeHeaders ? canvas.nodeHeaders[nodeType] || null : null
                inputs: inputPorts
                outputs: outputPorts
                graphPosition: nodePosition
                executionState: canvas.nodeStates[card.nodeKey] || ""
                colors: canvas.colors
                headerColors: canvas.nodeColors ? canvas.nodeColors[nodeType] || null : null
                viewport: canvas
                viewScale: canvas.zoom
                selected: canvas.selectedNodeId === card.nodeKey
                activeOutput: canvas.pendingOutput && canvas.pendingNode === card.nodeKey ? canvas.pendingPort : ""
                connecting: canvas.pendingNode !== ""
                targetInput: canvas.pendingOutput && canvas.connectionTarget
                             && canvas.connectionTarget.nodeId === card.nodeKey ? canvas.connectionTarget.portKey : ""
                targetOutput: !canvas.pendingOutput && canvas.connectionTarget
                              && canvas.connectionTarget.nodeId === card.nodeKey ? canvas.connectionTarget.portKey : ""
                connectionError: canvas.connectionTarget ? canvas.connectionTarget.error : ""
                connectionExecution: canvas.previewExecution
                onAnchorsChanged: Qt.callLater(canvas.resolveWires)
                onActivated: {
                    canvas.interactionHost.interactionCanceled()
                    backgroundArea.forceActiveFocus()
                    canvas.selectedNodeId = card.nodeKey
                }
                onMoveRequested: canvas.session.moveNode(card.nodeKey, position)
                onPortPressed: {
                    backgroundArea.forceActiveFocus()
                    var incoming = isOutput ? [] : canvas.links.filter(function(link) {
                        return link.target === card.nodeKey && link.targetPort === key
                    })
                    // 多条线共用输入时，只重接或删除明确选中的线。
                    var existing = incoming.length === 1 ? incoming[0] : incoming.find(function(link) {
                        return link.id === canvas.selectedConnectionId
                    })
                    if (contextRequested) {
                        canvas.interactionHost.interactionCanceled()
                        if (existing) {
                            canvas.selectedConnectionId = existing.id
                            connectionMenu.popup(position.x, position.y)
                        } else {
                            canvas.selectedNodeId = card.nodeKey
                        }
                        return
                    }
                    canvas.selectedNodeId = card.nodeKey
                    // 再次按下正在重接的端口时继续拖线，不提前完成原连接。
                    if (canvas.pendingNode && canvas.pendingOutput !== isOutput
                        && (!existing || existing.id !== canvas.reconnectId)) {
                        canvas.completeConnection(card.nodeKey, key)
                        return
                    }
                    canvas.interactionHost.interactionCanceled()
                    canvas.reconnectId = existing ? existing.id : ""
                    canvas.pendingOutput = isOutput || !!existing
                    canvas.pendingPort = !isOutput && existing ? existing.sourcePort : key
                    canvas.pendingNode = !isOutput && existing ? existing.source : card.nodeKey
                    canvas.pointer = position
                    Qt.callLater(canvas.resolveWires)
                }
                onConnectionPointerMoved: canvas.pointer = position
                onConnectionCanceled: canvas.interactionHost.interactionCanceled()
                onPortReleased: {
                    if (!canvas.pendingNode)
                        return
                    if (canvas.contains(position)) {
                        canvas.pointer = position
                        canvas.resolveWires()
                        if (canvas.connectionTarget)
                            canvas.completeConnection(canvas.connectionTarget.nodeId, canvas.connectionTarget.portKey)
                    }
                    canvas.pendingNode = ""
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

    // Qt 5 按移动前的几何选择光标，拖动期间用视口区域保持光标稳定。
    MouseArea {
        anchors.fill: parent
        z: 1
        visible: !!canvas.selectedItem && canvas.selectedItem.dragging
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.ClosedHandCursor
    }
}
