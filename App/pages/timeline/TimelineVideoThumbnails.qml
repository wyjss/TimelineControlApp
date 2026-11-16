import QtQuick 2.14
import QtQuick.Window 2.14

Item {
    id: root
    objectName: "timelineVideoThumbnails"

    property var mediaCache: null
    property string source: ""
    property real sourceStartMs: 0
    property real segmentDurationMs: 0
    property real visibleOffsetPx: 0
    property real pixelsPerSecond: 1
    property bool loop: false
    readonly property real durationMs: sourceDurationMs

    readonly property int tileWidth: 96
    readonly property real stepMs: tileWidth * 1000 / Math.max(0.001, pixelsPerSecond)
    readonly property int firstSlot: Math.max(0, Math.floor(visibleOffsetPx / tileWidth))
    readonly property int afterLastSlot: Math.max(firstSlot, Math.ceil(Math.min(
        visibleOffsetPx + width, segmentDurationMs * pixelsPerSecond / 1000) / tileWidth))
    readonly property size pixelSize: Qt.size(Math.ceil(tileWidth * Screen.devicePixelRatio),
                                              Math.ceil(height * Screen.devicePixelRatio))
    readonly property string sampleMapping: sourceStartMs + ":" + loop
    readonly property string grid: sampleMapping + ":" + stepMs + ":" + segmentDurationMs
                                   + ":" + pixelSize.width + ":" + pixelSize.height
    readonly property string visibleGrid: grid + ":" + firstSlot + ":" + afterLastSlot

    property bool initialized: false
    property var requestCache: null
    property var sourceRequestId: 0
    property real sourceDurationMs: 0
    property string version: ""
    property var pending: null
    property string completedGrid: ""

    clip: true

    function cancelRequests() {
        if (requestCache && sourceRequestId)
            requestCache.cancel(sourceRequestId)
        if (requestCache && pending)
            requestCache.cancel(pending.id)
    }

    function resetSource() {
        refresh.stop()
        cancelRequests()
        sourceRequestId = 0
        sourceDurationMs = 0
        version = ""
        pending = null
        completedGrid = ""
        tiles.clear()
        requestCache = mediaCache
        if (requestCache && source.length > 0)
            sourceRequestId = requestCache.requestVideoSource(source)
    }

    function finishGrid(grid) {
        pending = null
        completedGrid = grid
        for (var i = tiles.count - 1; i >= 0; --i) {
            if (tiles.get(i).grid !== grid)
                tiles.remove(i)
        }
    }

    onMediaCacheChanged: if (initialized) resetSource()
    onSourceChanged: if (initialized) resetSource()
    onVisibleGridChanged: if (initialized && version) refresh.restart()

    Component.onCompleted: {
        initialized = true
        resetSource()
    }
    Component.onDestruction: cancelRequests()

    Timer {
        id: refresh

        interval: 32
        onTriggered: {
            if (!root.requestCache || !root.version)
                return
            var grid = root.grid
            var firstMs = root.firstSlot * root.stepMs
            var endMs = Math.min(root.segmentDurationMs, root.afterLastSlot * root.stepMs)
            var signature = root.visibleGrid
            if (root.pending && root.pending.signature === signature)
                return
            var previousRequestId = root.pending ? root.pending.id : 0

            // 缩放时旧网格仍按时间定位，直到新网格补齐。滚动只移除出屏的格子。
            var displayed = {}
            for (var i = tiles.count - 1; i >= 0; --i) {
                var tile = tiles.get(i)
                if (tile.endMs <= firstMs || tile.startMs >= endMs || tile.mapping !== root.sampleMapping
                    || (tile.grid !== grid && tile.grid !== root.completedGrid)) {
                    tiles.remove(i)
                } else if (tile.grid === grid) {
                    displayed[tile.slotId] = true
                }
            }

            var samples = []
            var slots = {}
            for (var index = root.firstSlot; index < root.afterLastSlot; ++index) {
                var slotId = String(index)
                if (displayed[slotId])
                    continue
                var start = index * root.stepMs
                var end = Math.min(root.segmentDurationMs, start + root.stepMs)
                if (end <= start)
                    continue
                slots[slotId] = { slotId: slotId, startMs: start, endMs: end,
                    grid: grid, mapping: root.sampleMapping, thumbnailUrl: "" }
                samples.push({ slotId: slotId, sourceTimeMs: Math.floor(root.sourceStartMs + (start + end) / 2),
                    loop: root.loop })
            }
            if (samples.length === 0) {
                root.finishGrid(grid)
            } else {
                root.pending = {
                    id: root.requestCache.requestVideoThumbnails(root.version, samples, root.pixelSize),
                    signature: signature, grid: grid, slots: slots, remaining: samples.length
                }
            }
            // 先登记新网格的订阅，避免重叠的取帧任务一度失去订阅者。
            if (previousRequestId)
                root.requestCache.cancel(previousRequestId)
        }
    }

    Connections {
        target: root.requestCache

        function onVideoSourceReady(requestId, version, durationMs) {
            if (requestId !== root.sourceRequestId)
                return
            root.sourceRequestId = 0
            root.sourceDurationMs = durationMs
            root.version = version
            refresh.restart()
        }

        function onThumbnailReady(requestId, slotId, imageUrl) {
            var batch = root.pending
            if (!batch || requestId !== batch.id || !batch.slots[slotId])
                return
            var tile = batch.slots[slotId]
            delete batch.slots[slotId]
            tile.thumbnailUrl = String(imageUrl || "")
            tiles.append(tile)
            if (--batch.remaining === 0)
                root.finishGrid(batch.grid)
        }

        function onVideoSourceInvalidated(version) {
            if (version === root.version)
                root.resetSource()
        }

        function onFailed(requestId, errorString) {
            if (requestId === root.sourceRequestId)
                root.sourceRequestId = 0
            else if (root.pending && requestId === root.pending.id)
                root.finishGrid(root.pending.grid)
        }
    }

    ListModel { id: tiles }

    Repeater {
        model: tiles

        delegate: Item {
            x: Math.round(startMs * root.pixelsPerSecond / 1000 - root.visibleOffsetPx)
            width: Math.max(0, Math.round(endMs * root.pixelsPerSecond / 1000 - root.visibleOffsetPx) - x)
            height: root.height
            clip: true
            visible: mapping === root.sampleMapping

            Image {
                anchors.centerIn: parent
                width: Math.max(parent.width, root.tileWidth)
                height: parent.height
                source: thumbnailUrl
                fillMode: Image.PreserveAspectCrop
            }
        }
    }
}
