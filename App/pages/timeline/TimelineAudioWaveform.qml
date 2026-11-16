import QtQuick 2.14
import QtQuick.Controls 2.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base

Canvas {
    id: root
    objectName: "timelineAudioWaveform"

    property var mediaCache: null
    property string source: ""
    property real sourceStartMs: 0
    property real sourceEndMs: 0
    property bool loop: false
    property bool playbackRunning: false
    property color waveformColor: "transparent"
    property real durationMs: 0

    readonly property real queryStartMs: Math.floor(sourceStartMs)
    readonly property real queryEndMs: Math.ceil(sourceEndMs)
    readonly property int columns: Math.ceil(width / 3)
    readonly property var peaks: displayedColumns ? displayedColumns.peaks : []
    readonly property bool hasPeaks: peaks.length > 0
    property bool initialized: false
    property var requestCache: null
    property var waveformRequestId: 0
    property string version: ""
    property var pendingColumns: null
    property var displayedColumns: null
    property string errorMessage: ""

    function resetSource() {
        columnRefresh.stop()
        if (requestCache) {
            if (waveformRequestId)
                requestCache.cancel(waveformRequestId)
            if (pendingColumns)
                requestCache.cancel(pendingColumns.id)
        }
        waveformRequestId = 0
        pendingColumns = null
        displayedColumns = null
        version = ""
        durationMs = 0
        errorMessage = ""
        requestCache = mediaCache
        if (requestCache && source.length > 0)
            waveformRequestId = requestCache.requestWaveform(source)
    }

    function scheduleColumns() {
        if (!initialized)
            return
        requestPaint()
        if (!requestCache || !visible || !version || columns <= 0 || sourceEndMs <= sourceStartMs) {
            columnRefresh.stop()
            if (requestCache && pendingColumns) {
                requestCache.cancel(pendingColumns.id)
                pendingColumns = null
            }
            return
        }
        if (pendingColumns)
            return
        if (displayedColumns && displayedColumns.startMs === queryStartMs && displayedColumns.endMs === queryEndMs
            && displayedColumns.count === columns && displayedColumns.loop === loop) {
            columnRefresh.stop()
            return
        }
        columnRefresh.start()
    }

    onMediaCacheChanged: if (initialized) resetSource()
    onSourceChanged: if (initialized) resetSource()
    onSourceStartMsChanged: scheduleColumns()
    onSourceEndMsChanged: scheduleColumns()
    onWidthChanged: scheduleColumns()
    onHeightChanged: requestPaint()
    onLoopChanged: scheduleColumns()
    onVisibleChanged: scheduleColumns()
    onDisplayedColumnsChanged: requestPaint()
    onWaveformColorChanged: requestPaint()

    Component.onCompleted: {
        initialized = true
        resetSource()
    }
    Component.onDestruction: {
        if (requestCache) {
            if (waveformRequestId)
                requestCache.cancel(waveformRequestId)
            if (pendingColumns)
                requestCache.cancel(pendingColumns.id)
        }
    }

    Timer {
        id: columnRefresh

        interval: 32
        onTriggered: {
            if (root.requestCache && root.visible && root.version && !root.pendingColumns
                && root.columns > 0 && root.sourceEndMs > root.sourceStartMs) {
                var start = root.queryStartMs
                var end = root.queryEndMs
                var count = root.columns
                var loop = root.loop
                root.errorMessage = ""
                root.pendingColumns = {
                    id: root.requestCache.requestWaveformColumns(root.version, start, end, count, loop, true, true),
                    startMs: start, endMs: end, count: count, loop: loop
                }
            }
        }
    }

    Connections {
        target: root.requestCache

        function onWaveformReady(requestId, version, durationMs) {
            if (requestId !== root.waveformRequestId)
                return
            root.waveformRequestId = 0
            root.durationMs = durationMs
            root.version = version
            root.scheduleColumns()
        }

        function onWaveformColumnsReady(requestId, version, peaks) {
            var request = root.pendingColumns
            if (!request || requestId !== request.id || version !== root.version)
                return
            root.pendingColumns = null
            if (request.loop === root.loop) {
                request.peaks = peaks
                root.displayedColumns = request
            }
            root.scheduleColumns()
        }

        function onWaveformInvalidated(version) {
            if (version === root.version)
                root.resetSource()
        }

        function onFailed(requestId, errorString) {
            if (requestId === root.waveformRequestId) {
                root.waveformRequestId = 0
                root.errorMessage = errorString
            } else if (root.pendingColumns && requestId === root.pendingColumns.id) {
                root.pendingColumns = null
                root.errorMessage = errorString
            }
        }
    }

    Base.AppText {
        objectName: "timelineAudioWaveformStatus"

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        visible: !root.hasPeaks && text.length > 0 && width >= 32
        text: root.errorMessage || (root.waveformRequestId
            ? (root.playbackRunning ? qsTr("暂停或停止后生成波形") : qsTr("正在生成波形…")) : "")
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: root.errorMessage ? UiStyle.TextTone.Warning : UiStyle.TextTone.Secondary
        elide: Text.ElideRight
        ToolTip.visible: visible && truncated && statusHover.hovered
        ToolTip.text: text

        HoverHandler { id: statusHover }
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        var displayed = displayedColumns
        if (!displayed || displayed.loop !== loop
            || peaks.length !== displayed.count * 3 || sourceEndMs <= sourceStartMs)
            return

        // 视口改变时，把上次查询的峰值按素材时间投影到当前视口，保留两次取样之间可用的波形。
        var visibleStart = Math.max(sourceStartMs, displayed.startMs)
        var visibleEnd = Math.min(sourceEndMs, displayed.endMs)
        if (visibleEnd <= visibleStart)
            return
        var columnDuration = (displayed.endMs - displayed.startMs) / displayed.count
        var first = Math.floor((visibleStart - displayed.startMs) / columnDuration)
        var afterLast = Math.min(displayed.count, Math.ceil((visibleEnd - displayed.startMs) / columnDuration))
        var pixelsPerMs = width / (sourceEndMs - sourceStartMs)
        var center = height / 2
        var amplitude = Math.max(0, center - 1)
        ctx.save()
        ctx.strokeStyle = waveformColor
        ctx.fillStyle = waveformColor
        ctx.lineWidth = 1
        for (var layer = 0; layer < 2; ++layer) {
            var rmsLayer = layer === 1
            ctx.globalAlpha = rmsLayer ? 0.85 : 0.32
            ctx.beginPath()
            for (var column = first; column < afterLast; ++column) {
                var left = Math.max(visibleStart, displayed.startMs + column * columnDuration)
                var right = Math.min(visibleEnd, displayed.startMs + (column + 1) * columnDuration)
                if (right <= left)
                    continue
                var x = (left - sourceStartMs) * pixelsPerMs
                var columnWidth = (right - left) * pixelsPerMs
                var offset = column * 3
                if (rmsLayer) {
                    var rmsHeight = Math.max(0, Math.min(1, peaks[offset + 2])) * amplitude
                    ctx.rect(x, center - rmsHeight, columnWidth, 2 * rmsHeight)
                } else {
                    var top = center - Math.max(-1, Math.min(1, peaks[offset + 1])) * amplitude
                    var bottom = center - Math.max(-1, Math.min(1, peaks[offset])) * amplitude
                    var columnCenter = x + columnWidth / 2
                    ctx.moveTo(columnCenter, top)
                    ctx.lineTo(columnCenter, Math.max(top + 0.75, bottom))
                }
            }
            if (rmsLayer)
                ctx.fill()
            else
                ctx.stroke()
        }
        ctx.restore()
    }
}
