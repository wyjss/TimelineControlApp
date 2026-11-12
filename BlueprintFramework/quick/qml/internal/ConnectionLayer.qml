import QtQuick 2.14

Canvas {
    id: layer

    // 直接在渲染线程绘制，避免拖动时反复上传整张连线画布。
    renderTarget: Canvas.FramebufferObject
    renderStrategy: Canvas.Cooperative

    property var segments: []
    property var preview: null
    property real zoom: 1
    property color lineColor
    property color executionColor
    property color previewColor
    property color selectedColor
    property string selectedId
    property string hoveredId

    onSegmentsChanged: requestPaint()
    onPreviewChanged: requestPaint()
    onZoomChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onExecutionColorChanged: requestPaint()
    onPreviewColorChanged: requestPaint()
    onSelectedColorChanged: requestPaint()
    onSelectedIdChanged: requestPaint()
    onHoveredIdChanged: requestPaint()

    function controlOffset(a, b) {
        return Math.max(34, Math.abs(b.x - a.x) * 0.5)
    }

    function connectionAt(point) {
        // 命中范围使用视口像素，与画布缩放无关。
        var tolerance = 7
        var bestDistance = tolerance * tolerance
        var bestId = ""
        for (var i = 0; i < segments.length; ++i) {
            var segment = segments[i]
            var a = segment.from, b = segment.to
            var reach = controlOffset(a, b)
            var control1 = a.x + reach, control2 = b.x - reach
            if (point.x < Math.min(a.x, b.x, control1, control2) - tolerance
                || point.x > Math.max(a.x, b.x, control1, control2) + tolerance
                || point.y < Math.min(a.y, b.y) - tolerance
                || point.y > Math.max(a.y, b.y) + tolerance)
                continue

            var previousX = a.x, previousY = a.y
            var steps = Math.max(16, Math.min(96, Math.ceil((Math.abs(b.x - a.x) + Math.abs(b.y - a.y)) / 16)))
            for (var step = 1; step <= steps; ++step) {
                var t = step / steps, u = 1 - t
                var w0 = u * u * u, w1 = 3 * u * u * t, w2 = 3 * u * t * t, w3 = t * t * t
                var x = w0 * a.x + w1 * control1 + w2 * control2 + w3 * b.x
                var y = (w0 + w1) * a.y + (w2 + w3) * b.y
                var dx = x - previousX, dy = y - previousY
                var lengthSquared = dx * dx + dy * dy
                var fraction = lengthSquared > 0 ? Math.max(0, Math.min(1,
                        ((point.x - previousX) * dx + (point.y - previousY) * dy) / lengthSquared)) : 0
                var offX = point.x - previousX - fraction * dx
                var offY = point.y - previousY - fraction * dy
                var distance = offX * offX + offY * offY
                if (distance <= bestDistance) {
                    bestDistance = distance
                    bestId = segment.id
                }
                previousX = x
                previousY = y
            }
        }
        return bestId
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        var baseWidth = Math.max(1.5, 2.3 * layer.zoom)

        function drawWire(a, b) {
            var reach = layer.controlOffset(a, b)
            ctx.beginPath()
            ctx.moveTo(a.x, a.y)
            ctx.bezierCurveTo(a.x + reach, a.y, b.x - reach, b.y, b.x, b.y)
            ctx.stroke()
        }

        for (var i = 0; i < layer.segments.length; ++i) {
            var segment = layer.segments[i]
            var selected = segment.id === layer.selectedId
            var hovered = segment.id === layer.hoveredId
            ctx.strokeStyle = selected ? layer.selectedColor : hovered ? layer.previewColor
                            : segment.execution ? layer.executionColor : layer.lineColor
            ctx.lineWidth = baseWidth + (selected ? 2 : hovered ? 1 : 0)
            drawWire(segment.from, segment.to)
        }
        if (layer.preview) {
            ctx.strokeStyle = layer.previewColor
            ctx.lineWidth = baseWidth
            drawWire(layer.preview.from, layer.preview.to)
        }
    }
}
