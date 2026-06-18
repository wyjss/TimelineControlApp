import QtQuick 2.14
import "qrc:/UiCore/qml/components/base" as Base

Item {
    id: control

    property var theme
    property real rectX: 0
    property real rectY: 0
    property real rectW: 0.1
    property real rectH: 0.1
    property string title: ""
    property color strokeColor: "#7cb4ff"
    property color handleFill: "#0f172a"
    property bool selected: false
    property bool dashedBorder: false
    property bool handlesVisible: true
    property bool keepAspectRatio: false
    property bool rightDragEnabled: false
    property int acceptedButtons: Qt.LeftButton
    property real minRectW: 0.02
    property real minRectH: 0.02
    property real fillOpacity: selected ? 0.10 : 0.05
    property real borderWidth: selected ? 2 : 1.5
    property int titleLeftMargin: 8
    property int titleTopMargin: 6
    property int titleRightMargin: 8
    property int handleSize: 12
    property int handleRadius: 3

    readonly property real visualRectX: editingGeometry ? previewRectX : rectX
    readonly property real visualRectY: editingGeometry ? previewRectY : rectY
    readonly property real visualRectW: editingGeometry ? previewRectW : rectW
    readonly property real visualRectH: editingGeometry ? previewRectH : rectH
    readonly property real parentWidth: parent ? parent.width : 0
    readonly property real parentHeight: parent ? parent.height : 0
    readonly property real visualPixelX: Math.round(visualRectX * parentWidth)
    readonly property real visualPixelY: Math.round(visualRectY * parentHeight)
    readonly property real visualPixelW: Math.max(1, Math.round(visualRectW * parentWidth))
    readonly property real visualPixelH: Math.max(1, Math.round(visualRectH * parentHeight))

    property bool editingGeometry: false
    property bool rightDragging: false
    property real previewRectX: rectX
    property real previewRectY: rectY
    property real previewRectW: rectW
    property real previewRectH: rectH
    property point pressScenePos: Qt.point(0, 0)
    property var baseRect: currentRect()

    signal selectionRequested()
    signal pointerMoved(var item, real itemX, real itemY)
    signal wheelZoom(var item, var wheel)
    signal rightDragPressed(var item, real itemX, real itemY)
    signal rightDragMoved(var item, real itemX, real itemY)
    signal rightDragReleased(var item, real itemX, real itemY)
    signal rightDragCanceled()
    signal geometryCommitted(real committedX, real committedY, real committedW, real committedH)

    x: visualPixelX
    y: visualPixelY
    width: visualPixelW
    height: visualPixelH
    layer.enabled: editingGeometry

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value))
    }

    function normalizedRect(nextX, nextY, nextW, nextH) {
        var widthValue = clamp(nextW, minRectW, 1)
        var heightValue = clamp(nextH, minRectH, 1)
        var xValue = clamp(nextX, 0, 1 - widthValue)
        var yValue = clamp(nextY, 0, 1 - heightValue)
        return { "x": xValue, "y": yValue, "w": widthValue, "h": heightValue }
    }

    function currentRect() {
        return { "x": visualRectX, "y": visualRectY, "w": visualRectW, "h": visualRectH }
    }

    function applyPreview(rect) {
        if (!rect)
            return

        previewRectX = rect.x
        previewRectY = rect.y
        previewRectW = rect.w
        previewRectH = rect.h
    }

    function moveRect(base, deltaX, deltaY) {
        return normalizedRect(base.x + deltaX, base.y + deltaY, base.w, base.h)
    }

    function resizeFreeRect(handle, base, deltaX, deltaY) {
        var x = base.x
        var y = base.y
        var w = base.w
        var h = base.h

        if (handle.indexOf("e") >= 0)
            w = clamp(base.w + deltaX, minRectW, 1 - base.x)
        if (handle.indexOf("s") >= 0)
            h = clamp(base.h + deltaY, minRectH, 1 - base.y)
        if (handle.indexOf("w") >= 0) {
            x = clamp(base.x + deltaX, 0, base.x + base.w - minRectW)
            w = base.w + base.x - x
        }
        if (handle.indexOf("n") >= 0) {
            y = clamp(base.y + deltaY, 0, base.y + base.h - minRectH)
            h = base.h + base.y - y
        }

        return normalizedRect(x, y, w, h)
    }

    function resizeAspectRect(handle, base, deltaX, deltaY) {
        var east = handle.indexOf("e") >= 0
        var south = handle.indexOf("s") >= 0
        var proposedW = east ? base.w + deltaX : base.w - deltaX
        var proposedH = south ? base.h + deltaY : base.h - deltaY
        var scaleX = proposedW / Math.max(0.001, base.w)
        var scaleY = proposedH / Math.max(0.001, base.h)
        var scale = Math.abs(scaleX - 1) > Math.abs(scaleY - 1) ? scaleX : scaleY
        var maxW = east ? 1 - base.x : base.x + base.w
        var maxH = south ? 1 - base.y : base.y + base.h
        var minScale = Math.max(minRectW / Math.max(0.001, base.w), minRectH / Math.max(0.001, base.h))
        var maxScale = Math.min(maxW / Math.max(0.001, base.w), maxH / Math.max(0.001, base.h))

        scale = clamp(scale, minScale, maxScale)

        var w = base.w * scale
        var h = base.h * scale
        var x = east ? base.x : base.x + base.w - w
        var y = south ? base.y : base.y + base.h - h
        return normalizedRect(x, y, w, h)
    }

    function resizeRect(handle, base, deltaX, deltaY) {
        return keepAspectRatio
            ? resizeAspectRect(handle, base, deltaX, deltaY)
            : resizeFreeRect(handle, base, deltaX, deltaY)
    }

    function beginEdit(scenePos) {
        selectionRequested()
        applyPreview(currentRect())
        editingGeometry = true
        pressScenePos = scenePos
        baseRect = currentRect()
    }

    function commitPreview() {
        if (!editingGeometry)
            return

        var rect = currentRect()
        geometryCommitted(rect.x, rect.y, rect.w, rect.h)
        finishEditTimer.restart()
    }

    function cancelPreview() {
        editingGeometry = false
    }

    Timer {
        id: finishEditTimer

        interval: 0
        repeat: false
        onTriggered: control.editingGeometry = false
    }

    Canvas {
        id: dashedCanvas

        anchors.fill: parent
        contextType: "2d"
        visible: control.dashedBorder
        z: 1

        function drawDash(ctx, x1, y1, x2, y2) {
            var dash = 8
            var gap = 5
            var dx = x2 - x1
            var dy = y2 - y1
            var length = Math.sqrt(dx * dx + dy * dy)
            if (length <= 0)
                return

            var ux = dx / length
            var uy = dy / length
            var distance = 0
            while (distance < length) {
                var nextDistance = Math.min(distance + dash, length)
                ctx.moveTo(x1 + ux * distance, y1 + uy * distance)
                ctx.lineTo(x1 + ux * nextDistance, y1 + uy * nextDistance)
                distance += dash + gap
            }
        }

        onVisibleChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: control
            function onStrokeColorChanged() { dashedCanvas.requestPaint() }
            function onBorderWidthChanged() { dashedCanvas.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (!visible)
                return

            ctx.strokeStyle = control.strokeColor
            ctx.lineWidth = control.borderWidth
            ctx.beginPath()
            drawDash(ctx, 1, 1, width - 1, 1)
            drawDash(ctx, width - 1, 1, width - 1, height - 1)
            drawDash(ctx, width - 1, height - 1, 1, height - 1)
            drawDash(ctx, 1, height - 1, 1, 1)
            ctx.stroke()
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: !control.dashedBorder
        z: 1
        color: "transparent"
        border.color: control.strokeColor
        border.width: control.borderWidth
    }

    Rectangle {
        anchors.fill: parent
        z: 0
        color: control.strokeColor
        opacity: control.fillOpacity
    }

    Base.AppText {
        anchors.left: parent.left
        anchors.leftMargin: control.titleLeftMargin
        anchors.right: parent.right
        anchors.rightMargin: control.titleRightMargin
        anchors.top: parent.top
        anchors.topMargin: control.titleTopMargin
        text: control.title
        theme: control.theme
        styleRole: "bodyS"
        textTone: control.selected ? "accent" : "primary"
        colorOverride: control.strokeColor
        elide: Text.ElideRight
        z: 2
    }

    MouseArea {
        id: dragArea

        anchors.fill: parent
        z: 3
        acceptedButtons: control.acceptedButtons
        cursorShape: Qt.SizeAllCursor
        preventStealing: true

        onPressed: {
            if (mouse.button === Qt.RightButton && control.rightDragEnabled) {
                control.rightDragging = true
                control.rightDragPressed(dragArea, mouse.x, mouse.y)
                mouse.accepted = true
                return
            }

            if (mouse.button !== Qt.LeftButton)
                return

            control.beginEdit(control.mapToItem(control.parent, mouse.x, mouse.y))
        }

        onPositionChanged: {
            control.pointerMoved(dragArea, mouse.x, mouse.y)
            if (control.rightDragging) {
                control.rightDragMoved(dragArea, mouse.x, mouse.y)
                return
            }

            if (!pressed || !control.parent || control.parent.width <= 0 || control.parent.height <= 0)
                return

            var scenePos = control.mapToItem(control.parent, mouse.x, mouse.y)
            control.applyPreview(control.moveRect(control.baseRect,
                                                  (scenePos.x - control.pressScenePos.x) / control.parent.width,
                                                  (scenePos.y - control.pressScenePos.y) / control.parent.height))
        }

        onReleased: {
            if (control.rightDragging) {
                control.rightDragMoved(dragArea, mouse.x, mouse.y)
                control.rightDragging = false
                control.rightDragReleased(dragArea, mouse.x, mouse.y)
                return
            }

            control.commitPreview()
        }

        onCanceled: {
            if (control.rightDragging) {
                control.rightDragging = false
                control.rightDragCanceled()
                return
            }

            control.cancelPreview()
        }

        onWheel: control.wheelZoom(dragArea, wheel)
    }

    Repeater {
        model: [
            { "handle": "nw", "cursor": Qt.SizeFDiagCursor, "xRole": "left", "yRole": "top" },
            { "handle": "ne", "cursor": Qt.SizeBDiagCursor, "xRole": "right", "yRole": "top" },
            { "handle": "sw", "cursor": Qt.SizeBDiagCursor, "xRole": "left", "yRole": "bottom" },
            { "handle": "se", "cursor": Qt.SizeFDiagCursor, "xRole": "right", "yRole": "bottom" }
        ]

        delegate: Rectangle {
            id: resizeHandle

            width: control.handleSize
            height: control.handleSize
            radius: control.handleRadius
            x: modelData.xRole === "left" ? -width / 2 : control.width - width / 2
            y: modelData.yRole === "top" ? -height / 2 : control.height - height / 2
            color: control.handleFill
            border.color: control.strokeColor
            border.width: 2
            visible: control.handlesVisible
            z: 4

            property point pressScenePos: Qt.point(0, 0)
            property var baseRect: control.currentRect()

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: modelData.cursor
                preventStealing: true

                onPressed: {
                    control.beginEdit(resizeHandle.mapToItem(control.parent, mouse.x, mouse.y))
                    resizeHandle.pressScenePos = resizeHandle.mapToItem(control.parent, mouse.x, mouse.y)
                    resizeHandle.baseRect = control.currentRect()
                }

                onPositionChanged: {
                    control.pointerMoved(parent, mouse.x, mouse.y)
                    if (!pressed || !control.parent || control.parent.width <= 0 || control.parent.height <= 0)
                        return

                    var scenePos = resizeHandle.mapToItem(control.parent, mouse.x, mouse.y)
                    control.applyPreview(control.resizeRect(modelData.handle,
                                                            resizeHandle.baseRect,
                                                            (scenePos.x - resizeHandle.pressScenePos.x) / control.parent.width,
                                                            (scenePos.y - resizeHandle.pressScenePos.y) / control.parent.height))
                }

                onReleased: control.commitPreview()
                onCanceled: control.cancelPreview()
                onWheel: control.wheelZoom(parent, wheel)
            }
        }
    }
}
