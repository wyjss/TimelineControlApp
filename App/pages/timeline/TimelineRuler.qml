import QtQuick 2.14
import "qrc:/UiCore/qml/components/base" as Base
import "qrc:/UiCore/qml/components/base/internal/AppThemeUtils.js" as ThemeUtils

Item {
    id: root

    // 宿主页面传入的主题对象。
    property QtObject theme
    // 时间轴总时长，单位毫秒。
    property int durationMs: 1800000
    // 当前时间，单位毫秒；用于绘制当前时刻标记。
    property int currentTimeMs: 0
    // 时间轴内容水平偏移，单位像素；值越大，内容越向左移动。
    property real scrollX: 0
    // 0ms 起点在组件内的 x 坐标，单位像素。
    property real startTimeX: 0
    // 刻度尺高度，单位像素。
    property int rulerHeight: 44
    // 基础大刻度时间间隔，单位秒。
    property int baseMajorTickSeconds: 5
    // 基础小刻度像素间隔。
    property real minorTickPixelSpacing: 16
    // 每个大刻度包含的小刻度数量。
    property int minorTicksPerMajor: 5
    // 时间缩放值；值越大，单位时间占用的像素越少。
    property real timeScale: 1.0
    // 最小时间缩放值。
    property real minTimeScale: 1.0
    // 最大时间缩放值，根据时长和可用宽度自动计算。
    readonly property real maxTimeScale: calcMaxTimeScale()
    // 滚轮缩放步进；值越大，单次滚轮缩放越明显。
    property real wheelScaleStep: 1.05
    // 是否允许拖动更新时间。
    property bool dragEnabled: true

    readonly property real targetMajorTickSeconds: Math.max(1, baseMajorTickSeconds) * safeTimeScale()
    readonly property real majorTickSeconds: calcRealMajorTickSeconds(baseMajorTickSeconds)
    readonly property int majorTickMs: majorTickSeconds * 1000
    readonly property real effectiveMinorTickPixelSpacing: resolveMinorTickPixelSpacing()
    readonly property real majorTickPixelSpacing: effectiveMinorTickPixelSpacing * safeMinorTicksPerMajor()
    // 当前缩放和吸附后的时间像素比例，单位 px/s。
    readonly property real effectivePixelsPerSecond: majorTickSeconds > 0 ? majorTickPixelSpacing / majorTickSeconds : 1
    readonly property real safePixelsPerSecond: Math.max(0.001, effectivePixelsPerSecond)
    readonly property real resolvedStartTimeX: Math.max(0, startTimeX)
    readonly property int resolvedCurrentTimeMs: Math.max(0, Math.min(durationMs, currentTimeMs))
    // 当前时间在组件内的 x 坐标，单位像素。
    readonly property real currentTimeX: timeToX(resolvedCurrentTimeMs)
    readonly property real endPaddingX: Math.max(0, width - resolvedStartTimeX)
    // 时间轴内容总宽度，单位像素。
    readonly property real contentWidth: Math.max(width, resolvedStartTimeX + durationMs / 1000 * effectivePixelsPerSecond + endPaddingX)
    readonly property int visibleStartMs: Math.max(0, Math.floor((scrollX - resolvedStartTimeX) / safePixelsPerSecond * 1000))
    readonly property int visibleEndMs: Math.min(durationMs, Math.max(0, Math.ceil((scrollX + width - resolvedStartTimeX) / safePixelsPerSecond * 1000)))
    readonly property var labelTicks: buildLabelTicks()

    // 请求宿主更新 scrollX。
    signal scrollXChangeRequested(real nextScrollX)
    // 请求宿主更新当前时间，单位毫秒。
    signal currentTimeMsChangeRequested(int nextCurrentTimeMs)
    // 请求宿主更新时间缩放值。
    signal timeScaleChangeRequested(real nextTimeScale)

    implicitHeight: rulerHeight
    clip: true


    readonly property var _bestMajorIntervals: [1.0, 2.0, 5.0, 10.0, 20.0, 30.0, 60.0]

    function colorValue(name, fallback) {
        return ThemeUtils.colorValue(theme, name, fallback)
    }

    function safeTimeScale() {
        return clampTimeScale(timeScale)
    }

    // 将缩放值限制在 minTimeScale 和 maxTimeScale 之间。
    function clampTimeScale(value) {
        return Math.max(minTimeScale, Math.min(maxTimeScale, value))
    }

    function calcMaxTimeScale() {
        var baseSeconds = Math.max(0.001, baseMajorTickSeconds)
        var durationSeconds = Math.max(baseSeconds, durationMs / 1000)
        var basePixelsPerSecond = Math.max(1, minorTickPixelSpacing) * safeMinorTicksPerMajor() / baseSeconds
        var availableWidth = Math.max(1, width - resolvedStartTimeX)
        return Math.max(minTimeScale, durationSeconds * basePixelsPerSecond / availableWidth)
    }

    function requestClampedTimeScale() {
        var nextTimeScale = clampTimeScale(timeScale)
        if (Math.abs(nextTimeScale - timeScale) > 0.0001)
            timeScaleChangeRequested(nextTimeScale)
    }

    function requestScrollXForTimeMs(ms) {
        var nextScrollX = scrollXForTimeMs(ms)
        if (Math.abs(nextScrollX - scrollX) > 0.0001)
            scrollXChangeRequested(nextScrollX)
    }

    function updateRuler(clampScale, syncScroll) {
        tickCanvas.requestPaint()
        if (clampScale)
            requestClampedTimeScale()
        if (syncScroll)
            requestScrollXForTimeMs(resolvedCurrentTimeMs)
    }

    function clampScrollX(value) {
        return Math.max(0, Math.min(Math.max(0, contentWidth - width), value))
    }

    function clampTimeMs(value) {
        return Math.max(0, Math.min(durationMs, Math.round(value)))
    }

    // 计算让指定时间对齐到 startTimeX 时需要的 scrollX，入参单位毫秒。
    function scrollXForTimeMs(ms) {
        return clampScrollX(clampTimeMs(ms) / 1000 * effectivePixelsPerSecond)
    }

    function requestCurrentTimeMs(value) {
        var nextCurrentTimeMs = clampTimeMs(value)
        if (nextCurrentTimeMs !== resolvedCurrentTimeMs)
            currentTimeMsChangeRequested(nextCurrentTimeMs)
        requestScrollXForTimeMs(nextCurrentTimeMs)
    }

    function safeMinorTicksPerMajor() {
        return Math.max(1, minorTicksPerMajor)
    }

    function calcRealMajorTickSeconds(majorTickSeconds) {
        var s = Math.max(0.001, majorTickSeconds * safeTimeScale())
        var unitFactor = 1.0
        while (s > 60.0) {
            s /= 60.0
            unitFactor *= 60.0
        }

        var bestIndex = 0
        var lastIndex = _bestMajorIntervals.length - 1

        if (s >= _bestMajorIntervals[lastIndex]) {
            bestIndex = lastIndex
        } else {
            for (var index = 0; index < lastIndex; ++index) {
                var left = _bestMajorIntervals[index]
                var right = _bestMajorIntervals[index + 1]
                if (s >= left && s <= right) {
                    var rate = (s - left) / (right - left)
                    bestIndex = rate < 0.5 ? index : index + 1
                    break
                }
            }
        }

        return _bestMajorIntervals[bestIndex] * unitFactor
    }

    function resolveMinorTickPixelSpacing() {
        var baseSpacing = Math.max(1, minorTickPixelSpacing)
        var adjustedSpacing = baseSpacing * majorTickSeconds / Math.max(0.001, targetMajorTickSeconds)
        return adjustedSpacing
    }

    function pad2(value) {
        return value < 10 ? "0" + value : String(value)
    }

    function formatTime(ms) {
        var totalSeconds = Math.floor(ms / 1000)
        var hours = Math.floor(totalSeconds / 3600)
        var minutes = Math.floor((totalSeconds % 3600) / 60)
        var seconds = totalSeconds % 60

        if (hours > 0)
            return pad2(hours) + ":" + pad2(minutes) + ":" + pad2(seconds)

        return pad2(minutes) + ":" + pad2(seconds)
    }

    // 将时间转换为组件内的 x 坐标，入参单位毫秒，返回单位像素。
    function timeToX(ms) {
        return resolvedStartTimeX + ms / 1000 * effectivePixelsPerSecond - scrollX
    }

    function clampLabelX(centerX, labelWidth) {
        var maxX = Math.max(0, width - labelWidth)
        return Math.max(0, Math.min(maxX, centerX - labelWidth / 2))
    }

    function buildLabelTicks() {
        var result = []
        var startTick = Math.max(0, Math.floor(visibleStartMs / majorTickMs) * majorTickMs)
        var endTick = Math.min(durationMs, visibleEndMs + majorTickMs)

        for (var tickMs = startTick; tickMs <= endTick; tickMs += majorTickMs)
            result.push({ "timeMs": tickMs, "label": formatTime(tickMs), "x": timeToX(tickMs) })

        return result
    }

    Canvas {
        id: tickCanvas

        anchors.fill: parent
        antialiasing: false

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var axisY = height - 1
            var majorTickHeight = 12
            var minorTickHeight = 5
            var trackLeft = 0
            var trackRight = width
            var axisColor = root.colorValue("border", "#334155")
            var tickColor = root.colorValue("neutralText", "#cbd5e1")
            var markerColor = "#ef4444"
            var minorSpacing = Math.max(1, root.effectiveMinorTickPixelSpacing)
            var minorTicksPerMajor = root.safeMinorTicksPerMajor()

            ctx.strokeStyle = axisColor
            ctx.globalAlpha = 0.28
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(trackLeft, axisY + 0.5)
            ctx.lineTo(trackRight, axisY + 0.5)
            ctx.stroke()

            ctx.strokeStyle = tickColor
            ctx.globalAlpha = 0.24
            var firstMinorIndex = Math.max(0, Math.floor((root.scrollX - root.resolvedStartTimeX) / minorSpacing))
            var maxMinorIndex = Math.ceil(root.durationMs / 1000 * root.effectivePixelsPerSecond / minorSpacing)
            var lastMinorIndex = Math.min(maxMinorIndex, Math.ceil((root.scrollX + width - root.resolvedStartTimeX) / minorSpacing))

            for (var minorIndex = firstMinorIndex; minorIndex <= lastMinorIndex; ++minorIndex) {
                var worldX = root.resolvedStartTimeX + minorIndex * minorSpacing
                var minorX = Math.round(worldX - root.scrollX) + 0.5
                if (minorX < trackLeft || minorX > trackRight)
                    continue

                if (minorIndex % minorTicksPerMajor === 0)
                    continue

                ctx.beginPath()
                ctx.moveTo(minorX, axisY - minorTickHeight)
                ctx.lineTo(minorX, axisY)
                ctx.stroke()
            }

            ctx.globalAlpha = 0.78
            var firstMajorTick = Math.max(0, Math.floor(root.visibleStartMs / root.majorTickMs) * root.majorTickMs)
            var lastMajorTick = Math.min(root.durationMs, root.visibleEndMs + root.majorTickMs)

            for (var tickMs = firstMajorTick; tickMs <= lastMajorTick; tickMs += root.majorTickMs) {
                var majorX = Math.round(root.timeToX(tickMs)) + 0.5
                if (majorX < trackLeft || majorX > trackRight)
                    continue

                ctx.beginPath()
                ctx.moveTo(majorX, axisY - majorTickHeight)
                ctx.lineTo(majorX, axisY)
                ctx.stroke()
            }

            var currentX = Math.round(root.currentTimeX) + 0.5
            if (currentX >= trackLeft && currentX <= trackRight) {
                var markerTop = axisY - 10
                ctx.fillStyle = markerColor
                ctx.globalAlpha = 0.95
                ctx.beginPath()
                ctx.moveTo(currentX, markerTop)
                ctx.lineTo(currentX - 4, markerTop - 6)
                ctx.lineTo(currentX + 4, markerTop - 6)
                ctx.closePath()
                ctx.fill()
            }

            ctx.globalAlpha = 1
        }

        Connections {
            target: root
            function onWidthChanged() { root.updateRuler(true, false) }
            function onDurationMsChanged() { root.updateRuler(true, true) }
            function onCurrentTimeMsChanged() { root.updateRuler(false, true) }
            function onScrollXChanged() { root.updateRuler(false, false) }
            function onStartTimeXChanged() { root.updateRuler(true, false) }
            function onBaseMajorTickSecondsChanged() { root.updateRuler(true, false) }
            function onMinorTickPixelSpacingChanged() { root.updateRuler(true, false) }
            function onMinorTicksPerMajorChanged() { root.updateRuler(true, false) }
            function onMinTimeScaleChanged() { root.requestClampedTimeScale() }
            function onMaxTimeScaleChanged() { root.requestClampedTimeScale() }
            function onTimeScaleChanged() { root.updateRuler(false, true) }
            function onThemeChanged() { root.updateRuler(false, false) }
        }
    }

    Repeater {
        model: root.labelTicks

        delegate: Base.AppText {
            readonly property real labelWidth: 72

            x: Math.round(root.clampLabelX(modelData.x, labelWidth))
            y: 6
            width: labelWidth
            text: modelData.label
            theme: root.theme
            styleRole: "bodyS"
            textTone: "secondary"
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: interactionArea

        property real pressX: 0
        property int pressCurrentTimeMs: 0

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        preventStealing: true
        cursorShape: root.dragEnabled ? (pressed ? Qt.SizeHorCursor : Qt.PointingHandCursor) : Qt.ArrowCursor

        onPressed: {
            if (!root.dragEnabled) {
                mouse.accepted = false
                return
            }

            pressX = mouse.x
            pressCurrentTimeMs = root.resolvedCurrentTimeMs
            mouse.accepted = true
        }

        onPositionChanged: {
            if (!root.dragEnabled || !pressed)
                return

            var deltaMs = (mouse.x - pressX) / root.safePixelsPerSecond * 1000
            root.requestCurrentTimeMs(pressCurrentTimeMs - deltaMs)
        }

        onWheel: {
            var delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y
            if (delta === 0)
                return

            var factor = delta > 0 ? 1 / root.wheelScaleStep : root.wheelScaleStep
            root.timeScaleChangeRequested(root.clampTimeScale(root.timeScale * factor))
            wheel.accepted = true
        }
    }
}
