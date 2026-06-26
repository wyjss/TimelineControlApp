import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Dialogs 1.3
import QtQuick.Layouts 1.14
import TimelineControl.Media 1.0 as Media
import "qrc:/UiCore/qml/components/base" as Base
import "qrc:/UiCore/qml/theme" as Theme

Item {
    id: root

    focus: true

    Theme.AppTheme {
        id: fallbackTheme
    }

    property QtObject pageTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : fallbackTheme
    property var appRuntime: typeof app !== "undefined" ? app : null
    property var deviceManager: appRuntime && appRuntime.deviceManager ? appRuntime.deviceManager : null
    property var deviceModel: appRuntime && appRuntime.deviceModel ? appRuntime.deviceModel : null
    property var projectionManager: appRuntime && appRuntime.projectionManager ? appRuntime.projectionManager : null

    readonly property var devices: deviceModel ? deviceModel.devices : []
    readonly property var pcDevices: buildPcDevices()
    readonly property var instructionModel: projectionManager ? projectionManager.instructionModel : null
    readonly property var captureModel: projectionManager ? projectionManager.captureModel : null
    readonly property var mappingModel: projectionManager ? projectionManager.mappingModel : null
    readonly property var instructionValues: projectionManager ? projectionManager.instructions : []
    readonly property var mappingValues: projectionManager ? projectionManager.mappings : []
    readonly property int instructionCount: projectionManager ? projectionManager.instructionCount : 0
    readonly property int captureCount: projectionManager ? projectionManager.captureCount : 0
    readonly property int mappingCount: projectionManager ? projectionManager.mappingCount : 0
    property string selectedPcId: ""
    readonly property var selectedPc: selectedPcForId(selectedPcId)
    property int selectedCaptureIndex: 0

    readonly property size selectedResolution: sizeFromValue(configValue(selectedPc, "screenSize", undefined), Qt.size(1920, 1080))
    readonly property size selectedLayout: sizeFromValue(configValue(selectedPc, "screenLayout", undefined), Qt.size(1, 1))
    readonly property int screenColumns: Math.max(1, Math.round(selectedLayout.width))
    readonly property int screenRows: Math.max(1, Math.round(selectedLayout.height))
    readonly property int totalScreenWidth: Math.max(1, Math.round(selectedResolution.width)) * screenColumns
    readonly property int totalScreenHeight: Math.max(1, Math.round(selectedResolution.height)) * screenRows
    property url videoSource: ""
    property size videoNativeSize: Qt.size(1920, 1080)
    readonly property bool hasVideoSource: videoSource.toString().length > 0
    property bool videoPlaying: false
    readonly property int videoPixelWidth: Math.max(1, Math.round(videoNativeSize.width))
    readonly property int videoPixelHeight: Math.max(1, Math.round(videoNativeSize.height))
    property real minViewZoom: 0.5
    property real maxViewZoom: 6.0
    property real wheelZoomStep: 1.12
    property real videoZoom: 1.0
    property real videoPanX: 0
    property real videoPanY: 0
    property real screenZoom: 1.0
    property real screenPanX: 0
    property real screenPanY: 0
    property bool mappingDragActive: false
    property int mappingDragCaptureIndex: -1
    property string mappingDragCaptureName: ""
    property color mappingDragColor: "#7cb4ff"
    property real mappingDragX: 0
    property real mappingDragY: 0
    property bool videoPointerActive: false
    property int videoPointerPixelX: 0
    property int videoPointerPixelY: 0
    property bool screenPointerActive: false
    property int screenPointerPixelX: 0
    property int screenPointerPixelY: 0

    onPcDevicesChanged: ensureSelectedPc()
    onSelectedPcIdChanged: clampScreenPan()
    onTotalScreenWidthChanged: clampScreenPan()
    onTotalScreenHeightChanged: clampScreenPan()
    onVideoNativeSizeChanged: clampVideoPan()
    onCaptureCountChanged: selectedCaptureIndex = Math.max(0, Math.min(selectedCaptureIndex, captureCount - 1))

    Component.onCompleted: {
        ensureSelectedPc()

        var initialVideoSource = configuredInitialVideoSource()
        if (initialVideoSource.length > 0)
            loadVideo(initialVideoSource)
        else
            applyInstructionVideo(false)
    }

    Connections {
        target: root.projectionManager

        function onCurrentInstructionChanged() {
            root.selectedCaptureIndex = 0
            root.applyInstructionVideo(false)
        }

        function onVideoSourceChanged() {
            root.applyInstructionVideo(false)
        }

        function onVideoSizeChanged() {
            root.applyInstructionVideoSize()
        }
    }

    FileDialog {
        id: videoFileDialog

        title: qsTr("选择视频文件")
        selectExisting: true
        nameFilters: [
            qsTr("视频文件 (*.mp4 *.mov *.mkv *.avi *.wmv *.webm *.m4v)"),
            qsTr("所有文件 (*)")
        ]

        onAccepted: root.loadVideo(fileUrl)
    }

    function colorValue(name, fallback) {
        if (pageTheme && pageTheme.colors && pageTheme.colors[name] !== undefined)
            return pageTheme.colors[name]

        return fallback
    }

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value))
    }

    function minCaptureWidth() {
        return videoCanvas && videoCanvas.width > 0 ? Math.min(0.4, 42 / videoCanvas.width) : 0.06
    }

    function minCaptureHeight() {
        return videoCanvas && videoCanvas.height > 0 ? Math.min(0.4, 42 / videoCanvas.height) : 0.06
    }

    function captureColor(index) {
        var colors = ["#7cb4ff", "#36d399", "#fbbf24", "#f472b6", "#a78bfa"]
        return colors[index % colors.length]
    }

    function createInstruction() {
        if (!projectionManager)
            return

        projectionManager.createInstruction(qsTr("投影指令 %1").arg(root.instructionCount + 1))
        selectedCaptureIndex = 0
    }

    function duplicateInstruction() {
        if (!projectionManager)
            return

        projectionManager.duplicateCurrentInstruction()
        selectedCaptureIndex = 0
    }

    function removeInstruction() {
        if (!projectionManager || root.instructionCount <= 1)
            return

        projectionManager.removeCurrentInstruction()
        selectedCaptureIndex = 0
    }

    function addCapture() {
        if (!projectionManager)
            return

        selectedCaptureIndex = projectionManager.addCapture()
    }

    function removeSelectedCapture() {
        if (!projectionManager || captureCount <= 1 || selectedCaptureIndex < 0 || selectedCaptureIndex >= captureCount)
            return

        projectionManager.removeCapture(selectedCaptureIndex)
        selectedCaptureIndex = Math.max(0, Math.min(selectedCaptureIndex, captureCount - 1))
    }

    function captureGeometry(nextX, nextY, nextW, nextH) {
        var minW = minCaptureWidth()
        var minH = minCaptureHeight()
        var widthValue = clamp(nextW, minW, 1)
        var heightValue = clamp(nextH, minH, 1)
        var xValue = clamp(nextX, 0, 1 - widthValue)
        var yValue = clamp(nextY, 0, 1 - heightValue)

        return { "x": xValue, "y": yValue, "w": widthValue, "h": heightValue }
    }

    function setCaptureGeometry(index, nextX, nextY, nextW, nextH) {
        if (!projectionManager || index < 0 || index >= captureCount)
            return null

        var rect = captureGeometry(nextX, nextY, nextW, nextH)
        projectionManager.setCaptureGeometryNormalized(index, rect.x, rect.y, rect.w, rect.h)
        return rect
    }

    function mappingGeometry(nextX, nextY, nextW, nextH) {
        var minW = screenCanvas && screenCanvas.width > 0 ? Math.min(0.4, 32 / screenCanvas.width) : 0.02
        var minH = screenCanvas && screenCanvas.height > 0 ? Math.min(0.4, 32 / screenCanvas.height) : 0.02
        var widthValue = clamp(nextW, minW, 1)
        var heightValue = clamp(nextH, minH, 1)
        var xValue = clamp(nextX, 0, 1 - widthValue)
        var yValue = clamp(nextY, 0, 1 - heightValue)

        return { "x": xValue, "y": yValue, "w": widthValue, "h": heightValue }
    }

    function setMappingGeometry(index, nextX, nextY, nextW, nextH) {
        if (!projectionManager || index < 0 || index >= mappingCount)
            return null

        var rect = mappingGeometry(nextX, nextY, nextW, nextH)
        projectionManager.setMappingGeometryNormalized(index,
                                                       rect.x,
                                                       rect.y,
                                                       rect.w,
                                                       rect.h,
                                                       totalScreenWidth,
                                                       totalScreenHeight)
        return rect
    }

    function buildPcDevices() {
        var result = []
        for (var index = 0; index < devices.length; ++index) {
            var device = devices[index]
            var deviceType = String(device.deviceType || "")
            var templateName = String(device.templateName || "")
            var protocol = String(device.protocol || "").toLowerCase()
            if (deviceType === "电脑" || templateName === "电脑" || protocol === "pc")
                result.push(device)
        }

        return result
    }

    function selectedPcForId(deviceId) {
        var normalizedId = String(deviceId || "")
        for (var index = 0; index < pcDevices.length; ++index) {
            if (String(pcDevices[index].id || "") === normalizedId)
                return pcDevices[index]
        }

        return pcDevices.length > 0 ? pcDevices[0] : null
    }

    function ensureSelectedPc() {
        if (pcDevices.length === 0) {
            selectedPcId = ""
            return
        }

        var candidate = selectedPcForId(selectedPcId)
        selectedPcId = String(candidate.id || "")
    }

    function selectPc(deviceId) {
        selectedPcId = String(deviceId || "")
    }

    function configValue(device, key, fallback) {
        if (!device || !device.configValues)
            return fallback

        var values = device.configValues
        return values[key] !== undefined && values[key] !== null ? values[key] : fallback
    }

    function sizeFromValue(value, fallback) {
        if (value && value.width !== undefined && value.height !== undefined) {
            var widthValue = Math.round(Number(value.width))
            var heightValue = Math.round(Number(value.height))
            if (widthValue > 0 && heightValue > 0)
                return Qt.size(widthValue, heightValue)
        }

        var match = String(value || "").trim().match(/(\d+)\D+(\d+)/)
        if (match) {
            var parsedWidth = Math.round(Number(match[1]))
            var parsedHeight = Math.round(Number(match[2]))
            if (parsedWidth > 0 && parsedHeight > 0)
                return Qt.size(parsedWidth, parsedHeight)
        }

        return fallback
    }

    function sizeText(sizeValue) {
        return String(Math.round(sizeValue.width)) + "x" + String(Math.round(sizeValue.height))
    }

    function configuredInitialVideoSource() {
        if (!appRuntime || !appRuntime.settings)
            return ""

        return String(appRuntime.settings.value("projectionVideoSource", "")).trim()
    }

    function applyInstructionVideo(autoPlay) {
        if (!projectionManager)
            return

        var source = String(projectionManager.videoSource || "")
        videoSource = source
        if (source.length === 0) {
            videoFrameItem.stop()
            videoFrameItem.source = ""
            videoNativeSize = Qt.size(1920, 1080)
            return
        }

        videoFrameItem.source = source
        if (autoPlay)
            videoFrameItem.play()
        else
            videoFrameItem.pause()

        applyInstructionVideoSize()
    }

    function applyInstructionVideoSize() {
        if (!projectionManager || !projectionManager.videoSize)
            return

        var sizeValue = projectionManager.videoSize
        if (sizeValue.width > 0 && sizeValue.height > 0)
            videoNativeSize = Qt.size(Math.round(sizeValue.width), Math.round(sizeValue.height))
    }

    function videoSourceLabel() {
        if (!hasVideoSource)
            return qsTr("未加载视频")

        var value = decodeURIComponent(String(videoSource))
        var separator = Math.max(value.lastIndexOf("/"), value.lastIndexOf("\\"))
        return separator >= 0 ? value.substring(separator + 1) : value
    }

    function refreshVideoNativeSize() {
        if (videoFrameItem && videoFrameItem.videoSize && videoFrameItem.videoSize.width > 0 && videoFrameItem.videoSize.height > 0) {
            videoNativeSize = Qt.size(Math.round(videoFrameItem.videoSize.width), Math.round(videoFrameItem.videoSize.height))
            if (projectionManager)
                projectionManager.setVideoSize(videoNativeSize.width, videoNativeSize.height)
            return
        }

        if (!hasVideoSource)
            videoNativeSize = Qt.size(1920, 1080)
    }

    function loadVideo(sourceUrl) {
        if (String(sourceUrl || "").length === 0)
            return

        videoSource = sourceUrl
        if (projectionManager)
            projectionManager.videoSource = sourceUrl

        videoFrameItem.source = sourceUrl
        videoFrameItem.play()
        refreshVideoNativeSize()
    }

    function toggleVideoPlayback() {
        if (!hasVideoSource) {
            videoFileDialog.open()
            return
        }

        if (videoFrameItem.playing)
            videoFrameItem.pause()
        else
            videoFrameItem.play()
    }

    function stopVideoPlayback() {
        videoFrameItem.stop()
    }

    function formatVideoTime(milliseconds) {
        var seconds = Math.max(0, Math.floor(Number(milliseconds || 0) / 1000))
        var minutes = Math.floor(seconds / 60)
        var hours = Math.floor(minutes / 60)
        seconds = seconds % 60
        minutes = minutes % 60

        var secondText = seconds < 10 ? "0" + seconds : String(seconds)
        var minuteText = minutes < 10 ? "0" + minutes : String(minutes)
        return hours > 0
            ? String(hours) + ":" + minuteText + ":" + secondText
            : String(minutes) + ":" + secondText
    }

    function videoTimeText(position, duration) {
        return formatVideoTime(position) + " / " + formatVideoTime(duration)
    }

    function videoHasError() {
        return String(videoFrameItem.errorString || "").length > 0
    }

    function videoIsLoading() {
        return hasVideoSource && !videoFrameItem.hasFrame && !videoHasError()
    }

    function videoOverlayVisible() {
        return !hasVideoSource || videoHasError() || videoIsLoading()
    }

    function videoPlaceholderText() {
        var errorText = String(videoFrameItem.errorString || "")
        if (errorText.length > 0)
            return errorText

        return hasVideoSource ? qsTr("视频加载中") : qsTr("请选择视频文件")
    }

    function pcName(device) {
        if (!device)
            return qsTr("未选择 PC")

        var name = String(device.name || "").trim()
        return name.length > 0 ? name : String(device.id || qsTr("PC"))
    }

    function pcAddress(device) {
        if (!device)
            return qsTr("无设备")

        var address = String(device.address || "").trim()
        return address.length > 0 ? address : qsTr("未分配")
    }

    function pcDeviceById(deviceId) {
        var normalizedId = String(deviceId || "")
        for (var index = 0; index < pcDevices.length; ++index) {
            if (String(pcDevices[index].id || "") === normalizedId)
                return pcDevices[index]
        }

        return null
    }

    function mappingForCapture(captureData, captureIndex) {
        var captureId = String((captureData && (captureData.captureId || captureData.id)) || "")
        var mappings = mappingValues || []
        for (var index = 0; index < mappings.length; ++index) {
            var mapping = mappings[index] || ({})
            var mappingCaptureId = String(mapping.captureId || "")
            var mappingCaptureIndex = Number(mapping.captureIndex)
            if (captureId.length > 0 && mappingCaptureId === captureId)
                return mapping
            if (!isNaN(mappingCaptureIndex) && mappingCaptureIndex === captureIndex)
                return mapping
        }

        return null
    }

    function mappingPcName(mapping) {
        if (!mapping)
            return ""

        var pc = pcDeviceById(mapping.pcId)
        if (pc)
            return pcName(pc)

        var pcId = String(mapping.pcId || "")
        return pcId.length > 0 ? pcId : qsTr("未知 PC")
    }

    function captureMappingText(captureData, captureIndex) {
        var mapping = mappingForCapture(captureData, captureIndex)
        return mapping ? qsTr("已映射到 %1").arg(mappingPcName(mapping)) : qsTr("未映射")
    }

    function pcMappingCount(device) {
        if (!device)
            return 0

        var pcId = String(device.id || "")
        var count = 0
        var mappings = mappingValues || []
        for (var index = 0; index < mappings.length; ++index) {
            if (String((mappings[index] || ({})).pcId || "") === pcId)
                ++count
        }

        return count
    }

    function pcMappingText(device) {
        var count = pcMappingCount(device)
        return count > 0 ? qsTr("%1 个取景已映射").arg(count) : qsTr("暂无映射")
    }

    function zoomText(zoomValue) {
        return String(Math.round(zoomValue * 100)) + "%"
    }

    function capturePixelText(rectX, rectY, rectW, rectH) {
        var x = Math.round(Number(rectX) * videoPixelWidth)
        var y = Math.round(Number(rectY) * videoPixelHeight)
        var w = Math.round(Number(rectW) * videoPixelWidth)
        var h = Math.round(Number(rectH) * videoPixelHeight)
        return qsTr("x:%1 y:%2 w:%3 h:%4").arg(x).arg(y).arg(w).arg(h)
    }

    function instructionNameAt(index) {
        if (!instructionValues || index < 0 || index >= instructionValues.length)
            return ""

        var instruction = instructionValues[index]
        return String((instruction && (instruction.instructionName || instruction.name)) || "")
    }

    function clampedZoom(zoomValue) {
        return clamp(zoomValue, minViewZoom, maxViewZoom)
    }

    function wheelDelta(wheel) {
        return wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y
    }

    function clampedPan(hostExtent, contentExtent, panValue) {
        var overflow = (contentExtent - hostExtent) / 2
        if (overflow <= 0)
            return 0

        return clamp(panValue, -overflow, overflow)
    }

    function videoBaseWidth() {
        if (!videoHost || videoHost.width <= 0 || videoHost.height <= 0)
            return 0

        return Math.min(videoHost.width, videoHost.height * videoAspect())
    }

    function videoBaseHeight() {
        return videoBaseWidth() / videoAspect()
    }

    function videoAspect() {
        return Math.max(0.2, videoPixelWidth / Math.max(1, videoPixelHeight))
    }

    function screenAspect() {
        return Math.max(0.2, totalScreenWidth / Math.max(1, totalScreenHeight))
    }

    function screenBaseWidth() {
        if (!screenHost || screenHost.width <= 0 || screenHost.height <= 0)
            return 0

        return Math.min(screenHost.width, screenHost.height * screenAspect())
    }

    function screenBaseHeight() {
        return screenBaseWidth() / screenAspect()
    }

    function clampVideoPan() {
        var contentWidth = videoBaseWidth() * videoZoom
        var contentHeight = videoBaseHeight() * videoZoom
        videoPanX = clampedPan(videoHost ? videoHost.width : 0, contentWidth, videoPanX)
        videoPanY = clampedPan(videoHost ? videoHost.height : 0, contentHeight, videoPanY)
    }

    function clampScreenPan() {
        var contentWidth = screenBaseWidth() * screenZoom
        var contentHeight = screenBaseHeight() * screenZoom
        screenPanX = clampedPan(screenHost ? screenHost.width : 0, contentWidth, screenPanX)
        screenPanY = clampedPan(screenHost ? screenHost.height : 0, contentHeight, screenPanY)
    }

    function zoomVideoAt(hostX, hostY, wheelDelta) {
        var baseWidth = videoBaseWidth()
        var baseHeight = videoBaseHeight()
        if (baseWidth <= 0 || baseHeight <= 0 || wheelDelta === 0)
            return

        var oldZoom = videoZoom
        var nextZoom = clampedZoom(oldZoom * (wheelDelta > 0 ? wheelZoomStep : 1 / wheelZoomStep))
        if (nextZoom === oldZoom)
            return

        var oldWidth = baseWidth * oldZoom
        var oldHeight = baseHeight * oldZoom
        var oldX = (videoHost.width - oldWidth) / 2 + videoPanX
        var oldY = (videoHost.height - oldHeight) / 2 + videoPanY
        var ratioX = clamp((hostX - oldX) / oldWidth, 0, 1)
        var ratioY = clamp((hostY - oldY) / oldHeight, 0, 1)

        videoZoom = nextZoom

        var newWidth = baseWidth * videoZoom
        var newHeight = baseHeight * videoZoom
        videoPanX = clampedPan(videoHost.width,
                               newWidth,
                               hostX - ratioX * newWidth - (videoHost.width - newWidth) / 2)
        videoPanY = clampedPan(videoHost.height,
                               newHeight,
                               hostY - ratioY * newHeight - (videoHost.height - newHeight) / 2)
    }

    function zoomVideoFromItem(item, wheel) {
        var delta = wheelDelta(wheel)
        if (delta === 0)
            return

        var hostPoint = item.mapToItem(videoHost, wheel.x, wheel.y)
        zoomVideoAt(hostPoint.x, hostPoint.y, delta)
        wheel.accepted = true
    }

    function zoomScreenAt(hostX, hostY, wheelDelta) {
        var baseWidth = screenBaseWidth()
        var baseHeight = screenBaseHeight()
        if (baseWidth <= 0 || baseHeight <= 0 || wheelDelta === 0)
            return

        var oldZoom = screenZoom
        var nextZoom = clampedZoom(oldZoom * (wheelDelta > 0 ? wheelZoomStep : 1 / wheelZoomStep))
        if (nextZoom === oldZoom)
            return

        var oldWidth = baseWidth * oldZoom
        var oldHeight = baseHeight * oldZoom
        var oldX = (screenHost.width - oldWidth) / 2 + screenPanX
        var oldY = (screenHost.height - oldHeight) / 2 + screenPanY
        var ratioX = clamp((hostX - oldX) / oldWidth, 0, 1)
        var ratioY = clamp((hostY - oldY) / oldHeight, 0, 1)

        screenZoom = nextZoom

        var newWidth = baseWidth * screenZoom
        var newHeight = baseHeight * screenZoom
        screenPanX = clampedPan(screenHost.width,
                                newWidth,
                                hostX - ratioX * newWidth - (screenHost.width - newWidth) / 2)
        screenPanY = clampedPan(screenHost.height,
                                newHeight,
                                hostY - ratioY * newHeight - (screenHost.height - newHeight) / 2)
    }

    function zoomScreenFromItem(item, wheel) {
        var delta = wheelDelta(wheel)
        if (delta === 0)
            return

        var hostPoint = item.mapToItem(screenHost, wheel.x, wheel.y)
        zoomScreenAt(hostPoint.x, hostPoint.y, delta)
        wheel.accepted = true
    }

    function resetVideoView() {
        videoZoom = 1.0
        videoPanX = 0
        videoPanY = 0
    }

    function resetScreenView() {
        screenZoom = 1.0
        screenPanX = 0
        screenPanY = 0
    }

    function updateVideoPointerFromItem(item, itemX, itemY) {
        if (!videoCanvas || videoCanvas.width <= 0 || videoCanvas.height <= 0) {
            videoPointerActive = false
            return
        }

        var point = videoCanvas.mapFromItem(item, itemX, itemY)
        if (point.x < 0 || point.y < 0 || point.x > videoCanvas.width || point.y > videoCanvas.height) {
            videoPointerActive = false
            return
        }

        videoPointerPixelX = clamp(Math.floor(point.x / videoCanvas.width * videoPixelWidth), 0, videoPixelWidth - 1)
        videoPointerPixelY = clamp(Math.floor(point.y / videoCanvas.height * videoPixelHeight), 0, videoPixelHeight - 1)
        videoPointerActive = true
    }

    function updateScreenPointerFromItem(item, itemX, itemY) {
        if (!screenCanvas || screenCanvas.width <= 0 || screenCanvas.height <= 0) {
            screenPointerActive = false
            return
        }

        var point = screenCanvas.mapFromItem(item, itemX, itemY)
        if (point.x < 0 || point.y < 0 || point.x > screenCanvas.width || point.y > screenCanvas.height) {
            screenPointerActive = false
            return
        }

        screenPointerPixelX = clamp(Math.floor(point.x / screenCanvas.width * totalScreenWidth), 0, totalScreenWidth - 1)
        screenPointerPixelY = clamp(Math.floor(point.y / screenCanvas.height * totalScreenHeight), 0, totalScreenHeight - 1)
        screenPointerActive = true
    }

    function startMappingDrag(captureIndex, item, itemX, itemY) {
        if (!projectionManager || captureIndex < 0 || captureIndex >= captureCount)
            return

        var capture = projectionManager.captureAt(captureIndex)
        var rootPoint = item.mapToItem(root, itemX, itemY)
        mappingDragActive = true
        mappingDragCaptureIndex = captureIndex
        mappingDragCaptureName = String(capture.name || "")
        mappingDragColor = String(capture.color || captureColor(captureIndex))
        mappingDragX = rootPoint.x
        mappingDragY = rootPoint.y
        selectedCaptureIndex = captureIndex
    }

    function updateMappingDrag(item, itemX, itemY) {
        if (!mappingDragActive)
            return

        var rootPoint = item.mapToItem(root, itemX, itemY)
        mappingDragX = rootPoint.x
        mappingDragY = rootPoint.y
    }

    function finishMappingDrag() {
        if (!mappingDragActive)
            return

        var screenPoint = screenCanvas.mapFromItem(root, mappingDragX, mappingDragY)
        if (screenPoint.x >= 0
            && screenPoint.y >= 0
            && screenPoint.x <= screenCanvas.width
            && screenPoint.y <= screenCanvas.height) {
            createMappingAtScreenPoint(mappingDragCaptureIndex, screenPoint.x, screenPoint.y)
        }

        mappingDragActive = false
        mappingDragCaptureIndex = -1
        mappingDragCaptureName = ""
    }

    function cancelMappingDrag() {
        mappingDragActive = false
        mappingDragCaptureIndex = -1
        mappingDragCaptureName = ""
    }

    function createMappingAtScreenPoint(captureIndex, screenX, screenY) {
        if (!projectionManager || captureIndex < 0 || captureIndex >= captureCount || !selectedPc || screenCanvas.width <= 0 || screenCanvas.height <= 0)
            return

        var normalizedX = screenX / screenCanvas.width
        var normalizedY = screenY / screenCanvas.height
        var pcId = String(selectedPc.id || "")

        projectionManager.createMappingAtScreenPoint(captureIndex,
                                                     pcId,
                                                     normalizedX,
                                                     normalizedY,
                                                     totalScreenWidth,
                                                     totalScreenHeight,
                                                     screenColumns,
                                                     screenRows,
                                                     Math.round(selectedResolution.width),
                                                     Math.round(selectedResolution.height))
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 32
        anchors.rightMargin: 32
        anchors.topMargin: 64
        anchors.bottomMargin: 44
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Base.AppText {
                text: qsTr("视频投影指令")
                theme: root.pageTheme
                styleRole: "titleL"
            }

            ComboBox {
                id: instructionSelector

                Layout.preferredWidth: 220
                Layout.preferredHeight: 38
                model: root.instructionModel
                currentIndex: root.projectionManager ? root.projectionManager.currentInstructionIndex : -1
                enabled: root.instructionCount > 0
                onActivated: {
                    if (root.projectionManager)
                        root.projectionManager.selectInstruction(index)
                }

                delegate: ItemDelegate {
                    width: instructionSelector.width
                    height: 36
                    hoverEnabled: true

                    readonly property var instructionData: value || ({})
                    readonly property string instructionName: String(instructionData.instructionName || instructionData.name || "")

                    contentItem: Base.AppText {
                        text: instructionName
                        theme: root.pageTheme
                        styleRole: "bodyS"
                        textTone: highlighted ? "accent" : "primary"
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: highlighted
                            ? root.colorValue("highlightSoft", "#182b45")
                            : root.colorValue("surface", "#101827")
                    }
                }

                indicator: Base.AppText {
                    x: instructionSelector.width - width - 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "v"
                    theme: root.pageTheme
                    styleRole: "bodyS"
                    textTone: "secondary"
                }

                contentItem: Item {
                    Base.AppText {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 28
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.instructionNameAt(instructionSelector.currentIndex)
                        theme: root.pageTheme
                        styleRole: "bodyS"
                        textTone: "primary"
                        elide: Text.ElideRight
                    }
                }

                background: Rectangle {
                    radius: 6
                    color: root.colorValue("surface", "#101827")
                    border.color: instructionSelector.activeFocus
                        ? root.colorValue("highlightText", "#7cb4ff")
                        : root.colorValue("border", "#334155")
                    border.width: 1
                }

                popup: Popup {
                    y: instructionSelector.height + 4
                    width: instructionSelector.width
                    implicitHeight: Math.min(240, contentItem.implicitHeight + 2)
                    padding: 1

                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: instructionSelector.popup.visible ? instructionSelector.delegateModel : null
                        currentIndex: instructionSelector.highlightedIndex
                    }

                    background: Rectangle {
                        radius: 6
                        color: root.colorValue("surface", "#101827")
                        border.color: root.colorValue("border", "#334155")
                        border.width: 1
                    }
                }
            }

            Base.AppButton {
                text: qsTr("新建")
                theme: root.pageTheme
                iconName: "scene"
                onClicked: root.createInstruction()
            }

            Base.AppButton {
                text: qsTr("复制")
                theme: root.pageTheme
                iconName: "resources"
                enabled: root.instructionCount > 0
                onClicked: root.duplicateInstruction()
            }

            Base.AppButton {
                text: qsTr("删除")
                theme: root.pageTheme
                iconName: "layer-config"
                enabled: root.instructionCount > 1
                onClicked: root.removeInstruction()
            }

            Base.AppSurface {
                Layout.preferredHeight: 28
                sizeToContent: true
                theme: root.pageTheme
                surfaceTone: "section"
                padding: 10

                Base.AppText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("%1 个取景").arg(root.captureCount)
                    theme: root.pageTheme
                    styleRole: "bodyS"
                    textTone: "secondary"
                }
            }

            Base.AppSurface {
                Layout.preferredHeight: 28
                sizeToContent: true
                theme: root.pageTheme
                surfaceTone: "section"
                padding: 10

                Base.AppText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: selectedPc
                        ? qsTr("%1 屏 / %2").arg(root.screenColumns * root.screenRows).arg(root.sizeText(Qt.size(root.totalScreenWidth, root.totalScreenHeight)))
                        : qsTr("未选择 PC")
                    theme: root.pageTheme
                    styleRole: "bodyS"
                    textTone: "secondary"
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            Base.AppSurface {
                Layout.preferredWidth: 220
                Layout.minimumWidth: 196
                Layout.fillHeight: true
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Base.AppText {
                            Layout.fillWidth: true
                            text: qsTr("取景列表")
                            theme: root.pageTheme
                            styleRole: "sectionTitle"
                        }

                        Base.AppButton {
                            text: qsTr("添加")
                            theme: root.pageTheme
                            iconName: "scene"
                            onClicked: root.addCapture()
                        }
                    }

                    Base.AppScrollPane {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        theme: root.pageTheme
                        contentSpacing: 8

                        Repeater {
                            model: captureModel

                            delegate: Item {
                                id: captureRow

                                readonly property var captureData: value || ({})
                                readonly property string captureName: String(captureData.captureName || captureData.name || "")
                                readonly property real rectX: Number(captureData.rectX || 0)
                                readonly property real rectY: Number(captureData.rectY || 0)
                                readonly property real rectW: Number(captureData.rectW || 0)
                                readonly property real rectH: Number(captureData.rectH || 0)
                                readonly property string strokeColor: String(captureData.strokeColor || captureData.color || root.captureColor(index))
                                readonly property var captureMapping: root.mappingForCapture(captureData, index)
                                readonly property bool mapped: captureMapping !== null
                                readonly property bool selected: index === root.selectedCaptureIndex

                                Layout.fillWidth: true
                                Layout.preferredHeight: 86

                                Base.AppSurface {
                                    anchors.fill: parent
                                    theme: root.pageTheme
                                    surfaceTone: captureRow.selected ? "highlight" : "surface"
                                    active: captureRow.selected
                                    hoveredState: rowTap.containsMouse
                                    interactive: true
                                    strokeWidth: captureRow.selected || rowTap.containsMouse ? 1 : 0
                                    borderOverride: captureRow.selected
                                        ? root.colorValue("highlightText", "#7cb4ff")
                                        : root.colorValue("border", "#334155")
                                    hoverOverlayOpacity: 0.08
                                }

                                Rectangle {
                                    width: 4
                                    height: parent.height - 22
                                    radius: width / 2
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: strokeColor
                                }

                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 24
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3

                                    Base.AppText {
                                        width: parent.width
                                        text: captureName
                                        theme: root.pageTheme
                                        styleRole: "bodyM"
                                        textTone: captureRow.selected ? "accent" : "primary"
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        width: parent.width
                                        text: root.capturePixelText(rectX, rectY, rectW, rectH)
                                        theme: root.pageTheme
                                        styleRole: "bodyS"
                                        textTone: "secondary"
                                        elide: Text.ElideRight
                                    }

                                    Row {
                                        width: parent.width
                                        spacing: 6

                                        Rectangle {
                                            width: 7
                                            height: 7
                                            radius: width / 2
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: captureRow.mapped
                                                ? root.colorValue("highlightText", "#7cb4ff")
                                                : root.colorValue("textMuted", "#64748b")
                                        }

                                        Base.AppText {
                                            width: parent.width - 13
                                            text: root.captureMappingText(captureData, index)
                                            theme: root.pageTheme
                                            styleRole: "bodyS"
                                            textTone: captureRow.mapped ? "accent" : "secondary"
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                MouseArea {
                                    id: rowTap

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.selectedCaptureIndex = index
                                }
                            }
                        }
                    }

                    Base.AppButton {
                        Layout.fillWidth: true
                        text: qsTr("删除选中")
                        theme: root.pageTheme
                        iconName: "layer-config"
                        enabled: root.captureCount > 1
                        onClicked: root.removeSelectedCapture()
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 520
                spacing: 14

                Base.AppSurface {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 300
                    sizeToContent: false
                    theme: root.pageTheme
                    surfaceTone: "section"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Base.AppText {
                                Layout.fillWidth: true
                                text: qsTr("视频窗口")
                                theme: root.pageTheme
                                styleRole: "sectionTitle"
                            }

                            Base.AppText {
                                text: qsTr("%1x%2 / %3").arg(root.videoPixelWidth).arg(root.videoPixelHeight).arg(root.zoomText(root.videoZoom))
                                theme: root.pageTheme
                                styleRole: "bodyS"
                                textTone: "secondary"
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Base.AppButton {
                                text: qsTr("打开视频")
                                theme: root.pageTheme
                                iconName: "resources"
                                onClicked: videoFileDialog.open()
                            }

                            Base.AppButton {
                                text: root.videoPlaying ? qsTr("暂停") : qsTr("播放")
                                theme: root.pageTheme
                                iconSymbol: root.videoPlaying ? "||" : ">"
                                enabled: root.hasVideoSource
                                onClicked: root.toggleVideoPlayback()
                            }

                            Base.AppButton {
                                text: qsTr("停止")
                                theme: root.pageTheme
                                iconSymbol: "[]"
                                enabled: root.hasVideoSource
                                onClicked: root.stopVideoPlayback()
                            }

                            Slider {
                                id: videoSeek

                                Layout.fillWidth: true
                                from: 0
                                to: Math.max(1, videoFrameItem.duration)
                                value: videoFrameItem.position
                                enabled: root.hasVideoSource && videoFrameItem.duration > 0
                                live: false

                                onMoved: videoFrameItem.seek(Math.round(value))
                            }

                            Base.AppText {
                                Layout.preferredWidth: 108
                                horizontalAlignment: Text.AlignRight
                                text: root.videoTimeText(videoFrameItem.position, videoFrameItem.duration)
                                theme: root.pageTheme
                                styleRole: "bodyS"
                                textTone: "secondary"
                                elide: Text.ElideRight
                            }
                        }

                        Item {
                            id: videoHost

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 220
                            clip: true
                            onWidthChanged: root.clampVideoPan()
                            onHeightChanged: root.clampVideoPan()

                            HoverHandler {
                                id: videoCoordinateHover

                                acceptedDevices: PointerDevice.Mouse
                                onHoveredChanged: {
                                    if (!hovered)
                                        root.videoPointerActive = false
                                }
                                onPointChanged: {
                                    if (hovered)
                                        root.updateVideoPointerFromItem(videoHost, point.position.x, point.position.y)
                                }
                            }

                            MouseArea {
                                id: videoViewInteraction

                                property real pressX: 0
                                property real pressY: 0
                                property real pressPanX: 0
                                property real pressPanY: 0

                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton | Qt.MiddleButton
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: pressed ? Qt.SizeAllCursor : Qt.ArrowCursor

                                onPressed: {
                                    pressX = mouse.x
                                    pressY = mouse.y
                                    pressPanX = root.videoPanX
                                    pressPanY = root.videoPanY
                                    mouse.accepted = true
                                }

                                onPositionChanged: {
                                    root.updateVideoPointerFromItem(videoViewInteraction, mouse.x, mouse.y)
                                    if (!pressed)
                                        return

                                    var contentWidth = root.videoBaseWidth() * root.videoZoom
                                    var contentHeight = root.videoBaseHeight() * root.videoZoom
                                    root.videoPanX = root.clampedPan(videoHost.width, contentWidth, pressPanX + mouse.x - pressX)
                                    root.videoPanY = root.clampedPan(videoHost.height, contentHeight, pressPanY + mouse.y - pressY)
                                }

                                onDoubleClicked: root.resetVideoView()

                                onWheel: root.zoomVideoFromItem(videoViewInteraction, wheel)
                            }

                            Rectangle {
                                id: videoCanvas

                                x: (parent.width - width) / 2 + root.videoPanX
                                y: (parent.height - height) / 2 + root.videoPanY
                                width: Math.min(parent.width, parent.height * root.videoAspect()) * root.videoZoom
                                height: width / root.videoAspect()
                                radius: 6
                                color: root.colorValue("canvas", "#0b1020")
                                border.color: root.colorValue("border", "#334155")
                                border.width: 1
                                clip: true

                                Media.FfmpegVideoFrameItem {
                                    id: videoFrameItem

                                    anchors.fill: parent
                                    visible: root.hasVideoSource

                                    Component.onCompleted: root.videoPlaying = playing
                                    onPlayingChanged: root.videoPlaying = playing
                                    onVideoSizeChanged: root.refreshVideoNativeSize()
                                    onSourceChanged: root.refreshVideoNativeSize()
                                }

                                Canvas {
                                    id: videoGridCanvas

                                    anchors.fill: parent
                                    contextType: "2d"
                                    visible: !root.hasVideoSource || root.videoHasError()

                                    property color lineColor: root.colorValue("border", "#334155")
                                    property color softLineColor: Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.38)

                                    onLineColorChanged: requestPaint()
                                    onWidthChanged: requestPaint()
                                    onHeightChanged: requestPaint()
                                    onVisibleChanged: requestPaint()

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        ctx.fillStyle = root.colorValue("surface", "#101827")
                                        ctx.fillRect(0, 0, width, height)
                                        ctx.strokeStyle = softLineColor
                                        ctx.lineWidth = 1

                                        var step = Math.max(36, Math.min(width, height) / 8)
                                        ctx.beginPath()
                                        for (var x = step; x < width; x += step) {
                                            ctx.moveTo(x, 0)
                                            ctx.lineTo(x, height)
                                        }
                                        for (var y = step; y < height; y += step) {
                                            ctx.moveTo(0, y)
                                            ctx.lineTo(width, y)
                                        }
                                        ctx.stroke()
                                    }
                                }

                                Base.AppText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.right: parent.right
                                    anchors.rightMargin: 14
                                    anchors.top: parent.top
                                    anchors.topMargin: 12
                                    text: root.hasVideoSource ? root.videoSourceLabel() : qsTr("真实视频窗口")
                                    theme: root.pageTheme
                                    styleRole: "bodyS"
                                    textTone: "secondary"
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Math.max(0, Math.min(Math.max(0, parent.width - 32), placeholderText.implicitWidth + 28))
                                    height: 38
                                    radius: 6
                                    color: Qt.rgba(0, 0, 0, 0.44)
                                    border.color: root.colorValue("border", "#334155")
                                    border.width: 1
                                    visible: root.videoOverlayVisible()

                                    Base.AppText {
                                        id: placeholderText

                                        anchors.centerIn: parent
                                        width: Math.max(0, parent.width - 20)
                                        horizontalAlignment: Text.AlignHCenter
                                        text: root.videoPlaceholderText()
                                        theme: root.pageTheme
                                        styleRole: "bodyS"
                                        textTone: "primary"
                                        elide: Text.ElideRight
                                    }
                                }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.top: parent.top
                                anchors.topMargin: 10
                                width: videoPixelText.implicitWidth + 18
                                height: 28
                                radius: 5
                                color: Qt.rgba(0, 0, 0, 0.42)
                                border.color: root.colorValue("border", "#334155")
                                border.width: 1
                                visible: root.videoPointerActive
                                z: 30

                                Base.AppText {
                                    id: videoPixelText

                                    anchors.centerIn: parent
                                    text: qsTr("x:%1 y:%2").arg(root.videoPointerPixelX).arg(root.videoPointerPixelY)
                                    theme: root.pageTheme
                                    styleRole: "bodyS"
                                    textTone: "primary"
                                }
                            }

                            Repeater {
                                model: captureModel

                                delegate: ProjectionEditableRect {
                                    id: captureRect

                                    readonly property var captureData: value || ({})
                                    readonly property int captureIndex: index
                                    readonly property string captureName: String(captureData.captureName || captureData.name || "")
                                    readonly property string captureStrokeColor: String(captureData.strokeColor || captureData.color || root.captureColor(index))
                                    rectX: Number(captureData.rectX || 0)
                                    rectY: Number(captureData.rectY || 0)
                                    rectW: Number(captureData.rectW || 0)
                                    rectH: Number(captureData.rectH || 0)
                                    title: captureName
                                    theme: root.pageTheme
                                    strokeColor: captureStrokeColor
                                    selected: index === root.selectedCaptureIndex
                                    dashedBorder: true
                                    handlesVisible: selected
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    rightDragEnabled: true
                                    minRectW: root.minCaptureWidth()
                                    minRectH: root.minCaptureHeight()
                                    handleFill: root.colorValue("window", "#0f172a")

                                    onSelectionRequested: root.selectedCaptureIndex = captureIndex
                                    onPointerMoved: root.updateVideoPointerFromItem(item, itemX, itemY)
                                    onWheelZoom: root.zoomVideoFromItem(item, wheel)
                                    onRightDragPressed: root.startMappingDrag(captureIndex, item, itemX, itemY)
                                    onRightDragMoved: root.updateMappingDrag(item, itemX, itemY)
                                    onRightDragReleased: {
                                        root.updateMappingDrag(item, itemX, itemY)
                                        root.finishMappingDrag()
                                    }
                                    onRightDragCanceled: root.cancelMappingDrag()
                                    onGeometryCommitted: root.setCaptureGeometry(captureIndex,
                                                                                 committedX,
                                                                                 committedY,
                                                                                 committedW,
                                                                                 committedH)
                                }
                            }
                        }

                    }
                }
            }

                Base.AppSurface {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 260
                    sizeToContent: false
                    theme: root.pageTheme
                    surfaceTone: "section"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Base.AppText {
                                Layout.fillWidth: true
                                text: qsTr("屏幕画布")
                                theme: root.pageTheme
                                styleRole: "sectionTitle"
                            }

                            Base.AppText {
                                text: qsTr("%1x%2 / %3").arg(root.screenColumns).arg(root.screenRows).arg(root.zoomText(root.screenZoom))
                                theme: root.pageTheme
                                styleRole: "bodyS"
                                textTone: "secondary"
                            }
                        }

                        Item {
                            id: screenHost

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 180
                            clip: true
                            onWidthChanged: root.clampScreenPan()
                            onHeightChanged: root.clampScreenPan()

                            HoverHandler {
                                id: screenCoordinateHover

                                acceptedDevices: PointerDevice.Mouse
                                onHoveredChanged: {
                                    if (!hovered)
                                        root.screenPointerActive = false
                                }
                                onPointChanged: {
                                    if (hovered)
                                        root.updateScreenPointerFromItem(screenHost, point.position.x, point.position.y)
                                }
                            }

                            MouseArea {
                                id: screenViewInteraction

                                property real pressX: 0
                                property real pressY: 0
                                property real pressPanX: 0
                                property real pressPanY: 0

                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton | Qt.MiddleButton
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: pressed ? Qt.SizeAllCursor : Qt.ArrowCursor

                                onPressed: {
                                    pressX = mouse.x
                                    pressY = mouse.y
                                    pressPanX = root.screenPanX
                                    pressPanY = root.screenPanY
                                    mouse.accepted = true
                                }

                                onPositionChanged: {
                                    root.updateScreenPointerFromItem(screenViewInteraction, mouse.x, mouse.y)
                                    if (!pressed)
                                        return

                                    var contentWidth = root.screenBaseWidth() * root.screenZoom
                                    var contentHeight = root.screenBaseHeight() * root.screenZoom
                                    root.screenPanX = root.clampedPan(screenHost.width, contentWidth, pressPanX + mouse.x - pressX)
                                    root.screenPanY = root.clampedPan(screenHost.height, contentHeight, pressPanY + mouse.y - pressY)
                                }

                                onDoubleClicked: root.resetScreenView()

                                onWheel: root.zoomScreenFromItem(screenViewInteraction, wheel)
                            }

                            Rectangle {
                                id: screenCanvas

                                readonly property real canvasAspect: Math.max(0.2, root.totalScreenWidth / Math.max(1, root.totalScreenHeight))

                                x: (parent.width - width) / 2 + root.screenPanX
                                y: (parent.height - height) / 2 + root.screenPanY
                                width: Math.min(parent.width, parent.height * canvasAspect) * root.screenZoom
                                height: width / canvasAspect
                                radius: 6
                                color: root.colorValue("surface", "#101827")
                                border.color: root.colorValue("border", "#334155")
                                border.width: 1
                                clip: true

                            Repeater {
                                model: root.screenColumns * root.screenRows

                                delegate: Rectangle {
                                    id: screenTile

                                    readonly property int column: index % root.screenColumns
                                    readonly property int row: Math.floor(index / root.screenColumns)

                                    x: column * screenCanvas.width / root.screenColumns
                                    y: row * screenCanvas.height / root.screenRows
                                    width: screenCanvas.width / root.screenColumns
                                    height: screenCanvas.height / root.screenRows
                                    color: index % 2 === 0
                                        ? Qt.rgba(0.15, 0.24, 0.34, 0.92)
                                        : Qt.rgba(0.11, 0.19, 0.29, 0.92)
                                    border.color: root.colorValue("highlightText", "#7cb4ff")
                                    border.width: 1

                                    Column {
                                        anchors.centerIn: parent
                                        width: parent.width - 16
                                        spacing: 4

                                        Base.AppText {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            text: qsTr("屏幕 %1").arg(index + 1)
                                            theme: root.pageTheme
                                            styleRole: "bodyM"
                                            textTone: "primary"
                                            elide: Text.ElideRight
                                        }

                                        Base.AppText {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            text: root.sizeText(root.selectedResolution)
                                            theme: root.pageTheme
                                            styleRole: "bodyS"
                                            textTone: "secondary"
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }

                            Repeater {
                                model: mappingModel

                                delegate: ProjectionEditableRect {
                                    id: mappingRect

                                    readonly property var mappingData: value || ({})
                                    readonly property int mappingIndex: index
                                    readonly property int captureIndex: Number(mappingData.captureIndex === undefined ? -1 : mappingData.captureIndex)
                                    readonly property string captureName: String(mappingData.captureName || mappingData.name || "")
                                    readonly property string mappingStrokeColor: String(mappingData.strokeColor || mappingData.color || "#7cb4ff")
                                    readonly property string pcId: String(mappingData.pcId || "")

                                    visible: String(pcId || "") === root.selectedPcId
                                    rectX: Number(mappingData.rectX || 0)
                                    rectY: Number(mappingData.rectY || 0)
                                    rectW: Number(mappingData.rectW || 0)
                                    rectH: Number(mappingData.rectH || 0)
                                    title: captureName
                                    theme: root.pageTheme
                                    strokeColor: mappingStrokeColor
                                    fillOpacity: 0.20
                                    borderWidth: 2
                                    handlesVisible: true
                                    keepAspectRatio: true
                                    minRectW: screenCanvas && screenCanvas.width > 0 ? Math.min(0.4, 32 / screenCanvas.width) : 0.02
                                    minRectH: screenCanvas && screenCanvas.height > 0 ? Math.min(0.4, 32 / screenCanvas.height) : 0.02
                                    titleLeftMargin: 10
                                    titleTopMargin: 8
                                    titleRightMargin: 10
                                    handleFill: root.colorValue("window", "#0f172a")

                                    onPointerMoved: root.updateScreenPointerFromItem(item, itemX, itemY)
                                    onWheelZoom: root.zoomScreenFromItem(item, wheel)
                                    onGeometryCommitted: root.setMappingGeometry(mappingIndex,
                                                                                 committedX,
                                                                                 committedY,
                                                                                 committedW,
                                                                                 committedH)
                                }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 34
                                color: Qt.rgba(0, 0, 0, 0.28)

                                Base.AppText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.selectedPc
                                        ? root.pcName(root.selectedPc) + " / " + root.sizeText(Qt.size(root.totalScreenWidth, root.totalScreenHeight))
                                        : qsTr("未选择 PC")
                                    theme: root.pageTheme
                                    styleRole: "bodyS"
                                    textTone: "secondary"
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.top: parent.top
                                anchors.topMargin: 10
                                width: screenPixelText.implicitWidth + 18
                                height: 28
                                radius: 5
                                color: Qt.rgba(0, 0, 0, 0.42)
                                border.color: root.colorValue("border", "#334155")
                                border.width: 1
                                visible: root.screenPointerActive
                                z: 30

                                Base.AppText {
                                    id: screenPixelText

                                    anchors.centerIn: parent
                                    text: qsTr("x:%1 y:%2").arg(root.screenPointerPixelX).arg(root.screenPointerPixelY)
                                    theme: root.pageTheme
                                    styleRole: "bodyS"
                                    textTone: "primary"
                                }
                            }
                        }

                    }
                }
            }

            }

            Base.AppSurface {
                Layout.preferredWidth: 238
                Layout.minimumWidth: 210
                Layout.fillHeight: true
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Base.AppText {
                        Layout.fillWidth: true
                        text: qsTr("PC 设备")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        text: qsTr("%1 台可用").arg(root.pcDevices.length)
                        theme: root.pageTheme
                        styleRole: "bodyS"
                        textTone: "secondary"
                        elide: Text.ElideRight
                    }

                    Base.AppScrollPane {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        theme: root.pageTheme
                        contentSpacing: 8

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.pcDevices.length === 0 ? 76 : 0
                            visible: root.pcDevices.length === 0

                            Base.AppText {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("暂无 PC 设备")
                                theme: root.pageTheme
                                styleRole: "bodyM"
                                textTone: "secondary"
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }
                        }

                        Repeater {
                            model: root.pcDevices

                            delegate: Item {
                                id: pcRow

                                readonly property var pcDevice: modelData
                                readonly property bool selected: String(pcDevice.id || "") === root.selectedPcId
                                readonly property size resolution: root.sizeFromValue(root.configValue(pcDevice, "screenSize", undefined), Qt.size(1920, 1080))
                                readonly property size layoutSize: root.sizeFromValue(root.configValue(pcDevice, "screenLayout", undefined), Qt.size(1, 1))
                                readonly property int mappedCount: root.pcMappingCount(pcDevice)
                                readonly property bool mapped: mappedCount > 0

                                Layout.fillWidth: true
                                Layout.preferredHeight: 106

                                Base.AppSurface {
                                    anchors.fill: parent
                                    theme: root.pageTheme
                                    surfaceTone: pcRow.selected ? "highlight" : "surface"
                                    active: pcRow.selected
                                    hoveredState: pcTap.containsMouse
                                    interactive: true
                                    strokeWidth: pcRow.selected || pcTap.containsMouse ? 1 : 0
                                    borderOverride: pcRow.selected
                                        ? root.colorValue("highlightText", "#7cb4ff")
                                        : root.colorValue("border", "#334155")
                                    hoverOverlayOpacity: 0.08
                                }

                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Base.AppText {
                                        width: parent.width
                                        text: root.pcName(pcDevice)
                                        theme: root.pageTheme
                                        styleRole: "bodyM"
                                        textTone: pcRow.selected ? "accent" : "primary"
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        width: parent.width
                                        text: root.pcAddress(pcDevice)
                                        theme: root.pageTheme
                                        styleRole: "bodyS"
                                        textTone: "secondary"
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        width: parent.width
                                        text: root.sizeText(resolution) + " / " + Math.round(layoutSize.width) + "x" + Math.round(layoutSize.height)
                                        theme: root.pageTheme
                                        styleRole: "bodyS"
                                        textTone: "secondary"
                                        elide: Text.ElideRight
                                    }

                                    Row {
                                        width: parent.width
                                        spacing: 6

                                        Rectangle {
                                            width: 7
                                            height: 7
                                            radius: width / 2
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: pcRow.mapped
                                                ? root.colorValue("highlightText", "#7cb4ff")
                                                : root.colorValue("textMuted", "#64748b")
                                        }

                                        Base.AppText {
                                            width: parent.width - 13
                                            text: root.pcMappingText(pcDevice)
                                            theme: root.pageTheme
                                            styleRole: "bodyS"
                                            textTone: pcRow.mapped ? "accent" : "secondary"
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                MouseArea {
                                    id: pcTap

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.selectPc(pcDevice.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: mappingDragPreview

        x: Math.min(root.width - width - 12, Math.max(12, root.mappingDragX + 14))
        y: Math.min(root.height - height - 12, Math.max(12, root.mappingDragY + 14))
        width: 156
        height: 46
        radius: 6
        visible: root.mappingDragActive
        z: 1000
        color: root.colorValue("surface", "#101827")
        border.color: root.mappingDragColor
        border.width: 2
        opacity: 0.94

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 4
            height: parent.height - 18
            radius: width / 2
            color: root.mappingDragColor
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Base.AppText {
                width: parent.width
                text: qsTr("投放到屏幕")
                theme: root.pageTheme
                styleRole: "bodyS"
                textTone: "secondary"
                elide: Text.ElideRight
            }

            Base.AppText {
                width: parent.width
                text: root.mappingDragCaptureName
                theme: root.pageTheme
                styleRole: "bodyS"
                colorOverride: root.mappingDragColor
                elide: Text.ElideRight
            }
        }
    }
}
