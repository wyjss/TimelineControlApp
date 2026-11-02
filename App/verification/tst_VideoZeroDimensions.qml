import QtQuick 2.14
import QtQuick.Controls 2.14
import QtTest 1.2
import "qrc:/UICore/qml/theme" as Theme
import "../pages" as Pages

TestCase {
    id: testCase
    name: "VideoZeroDimensions"
    when: windowShown && testWindow.visible
    property var page: null

    ApplicationWindow {
        id: testWindow
        width: 1800
        height: 1000
        visible: true
        property QtObject appTheme: Theme.AppTheme {}
    }

    QtObject {
        id: loadCommand
        property string commandType: "openVideo"
        property var executionInputFields: [
            { key: "videoFile", value: "$first.mp4", options: ["$first.mp4", "$second.mp4"] },
            { key: "videoSrcW", value: 0 }, { key: "videoSrcH", value: 0 },
            { key: "videoWindowW", value: 1920 }, { key: "videoWindowH", value: 1080 }
        ]
        function resolvedParams(values) { return values }
    }
    QtObject {
        id: command
        property string id: "selected"
        property string targetDeviceId: "pc"
        property var targetCommand: loadCommand
        property string commandName: "测试视频"
        property double startTimeMs: 1000
        property var executionInputValues: ({})
    }
    QtObject {
        id: referenceCommand
        property string id: "reference"
        property string targetDeviceId: "pc"
        property var targetCommand: loadCommand
        property string commandName: "参考视频"
        property double startTimeMs: 0
        property var executionInputValues: ({ videoWindowW: "0", videoWindowH: "0" })
    }
    QtObject {
        id: testCommandModel
        property var commands: [referenceCommand, command]
        property string selectedCommandId: "selected"
        property int writes: 0
        function updateCommand(item, timeMs, values) {
            item.startTimeMs = timeMs
            item.executionInputValues = values
            ++writes
            return true
        }
    }
    QtObject {
        id: timeline
        property string id: "main"
        property string name: "测试节目"
        property int state: 0
        property var commandModel: testCommandModel
    }
    QtObject {
        id: manager
        property int playbackState: 0
        property var currentTimeline: timeline
        property var timelineModel: null
    }
    QtObject {
        id: device
        property string id: "pc"
        property string name: "测试电脑"
        property string deviceType: "电脑"
        property string templateName: "电脑"
        property var supportedProtocols: ["pc"]
        property var configValues: ({})
        property var commands: [loadCommand]
    }
    QtObject {
        id: devices
        property var devices: [device]
    }
    Component {
        id: pageComponent
        Pages.ProjectionPage {
            width: 1700
            height: 900
            // 满足页面时间格式接口；本用例只编辑矩形，不提交时间。
            property var app: ({ formatTimeMs: function(value) { return "00:00:01.000" },
                parseTimeMs: function(value) { return 1000 } })
            appRuntime: ({ timelineManager: manager, deviceModel: devices })
        }
    }

    function init() {
        command.executionInputValues = { videoFile: "$first.mp4", videoSrcW: 0, videoSrcH: 0,
            videoWindowW: 0, videoWindowH: 0, customParameter: "保留" }
        device.configValues = { virtualScreenWidth: 3840, virtualScreenHeight: 2160 }
        testCommandModel.writes = 0
        page = createTemporaryObject(pageComponent, testWindow.contentItem)
        verify(page)
        tryVerify(function() { return !!page.videoItem && !!findChild(page, "output_w") })
    }

    function test_previewFollowsResolution_data() {
        return [{ tag: "number", zero: 0 }, { tag: "string", zero: "0" }]
    }

    function test_previewFollowsResolution(data) {
        command.executionInputValues = { videoFile: "$first.mp4", videoSrcW: data.zero, videoSrcH: data.zero,
            videoWindowW: data.zero, videoWindowH: data.zero }
        page.videoItem.videoSize = Qt.size(4096, 2304)
        compare(page.sourceRect.w, 4096)
        compare(page.sourceRect.h, 2304)
        compare(page.outputRect.w, 3840)
        compare(page.outputRect.h, 2160)
        for (var name of ["source_w", "source_h", "output_w", "output_h"])
            compare(findChild(page, name).value, 0)
        page.videoItem.videoSize = Qt.size(7680, 4320)
        device.configValues = { virtualScreenWidth: 5120, virtualScreenHeight: 2880 }
        compare(page.sourceRect.w, 7680)
        compare(page.sourceRect.h, 4320)
        compare(page.outputRect.w, 5120)
        compare(page.outputRect.h, 2880)
        compare(command.executionInputValues.videoSrcW, data.zero)
        compare(command.executionInputValues.videoWindowH, data.zero)
        compare(testCommandModel.writes, 0)
        var reference = findChild(page, "videoOutputReference_reference")
        var canvas = findChild(page, "videoOutputCanvas")
        tryVerify(function() { return canvas.width > 0 })
        fuzzyCompare(reference.width, canvas.width, 1)
        fuzzyCompare(reference.height, canvas.height, 1)
    }

    function test_numericCommitAndUnrelatedEdits() {
        page.setRectangle(true, { w: 800, h: 450 })
        page.setRectangle(false, { w: 1000, h: 500 })
        for (var name of ["source_w", "source_h", "output_w", "output_h"]) {
            var field = findChild(page, name)
            field.forceActiveFocus()
            field.text = "0"
            verify(field.acceptableInput)
            verify(field.commitText())
            page.forceActiveFocus()
            compare(field.value, 0)
            compare(field.text, "0")
        }
        page.setRectangle(true, { x: 0 })
        page.setRectangle(false, { y: 0 })
        page.updateCommand({ play: false })
        findChild(page, "videoFileSelect").valueSelected("$second.mp4")
        for (var key of ["videoSrcW", "videoSrcH", "videoWindowW", "videoWindowH"])
            compare(command.executionInputValues[key], 0)
        compare(command.executionInputValues.customParameter, "保留")
        compare(command.executionInputValues.videoFile, "$second.mp4")
    }

    function test_geometryCommitPreservesUnchangedZero() {
        var rect = findChild(page, "videoOutputRect")
        page.setRectangle(false, { h: 500 })
        rect.geometryCommitted(0, 100 / page.canvasHeight, 1, 500 / page.canvasHeight)
        compare(command.executionInputValues.videoWindowW, 0)
        compare(command.executionInputValues.videoWindowY, 100)
        rect.geometryCommitted(0, 100 / page.canvasHeight, 1, 600 / page.canvasHeight)
        compare(command.executionInputValues.videoWindowW, 0)
        compare(command.executionInputValues.videoWindowH, 600)
        rect.geometryCommitted(0, 100 / page.canvasHeight, 1000 / page.canvasWidth, 600 / page.canvasHeight)
        compare(command.executionInputValues.videoWindowW, 1000)
        page.setRectangle(false, { h: 0 })
        rect.geometryCommitted(0, 0, 1200 / page.canvasWidth, 1)
        compare(command.executionInputValues.videoWindowW, 1200)
        compare(command.executionInputValues.videoWindowH, 0)
        compare(command.executionInputValues.videoSrcW, 0)
    }

    function test_cloneUsesTargetCanvasWithoutChangingParameters() {
        var dialog = findChild(page, "cloneVideoCommandDialog")
        dialog.openForCommand(command.id)
        verify(!dialog.rectangleOutside)
        compare(dialog.sourceParameters.videoWindowW, 0)
        device.configValues = { virtualScreenWidth: 1280, virtualScreenHeight: 720 }
        verify(!dialog.rectangleOutside)
        compare(dialog.sourceParameters.videoWindowH, 0)
        compare(testCommandModel.writes, 0)
        dialog.close()
    }
}
