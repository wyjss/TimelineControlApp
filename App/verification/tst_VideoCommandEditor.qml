import QtQuick 2.14
import QtQuick.Controls 2.14
import QtTest 1.2
import "qrc:/UICore/qml/theme" as Theme
import "../pages" as Pages

TestCase {
    id: testCase
    name: "VideoCommandEditor"
    when: windowShown && testWindow.visible

    ApplicationWindow {
        id: testWindow
        width: 1800
        height: 1000
        visible: true
        property QtObject appTheme: Theme.AppTheme {}
    }

    Component { id: pageComponent; Pages.ProjectionPage {} }

    function createPage(width, height) {
        var page = createTemporaryObject(pageComponent, testWindow.contentItem,
                                         { width: width || 1700, height: height || 900, appRuntime: null })
        verify(page)
        wait(50)
        return page
    }

    function test_addAndSwitchTimeline() {
        var page = createPage()
        compare(page.timelineCommands.length, 4)
        verify(!page.selectedCommand.dirty)
        mouseClick(findChild(page, "addVideoCommand_pc-02"))
        compare(page.timelineCommands.length, 5)
        compare(page.selectedCommand.pcId, "pc-02")
        compare(page.selectedCommand.startTimeMs, 0)
        var addedId = page.selectedCommandId
        page.setRectangle(false, { x: 100, y: 200, w: 600, h: 300 })
        findChild(page, "videoTimelineSelect").valueSelected("welcome")
        compare(page.timelineCommands.length, 1)
        compare(page.selectedCommand.name, "迎宾视频")
        findChild(page, "videoTimelineSelect").valueSelected("main")
        page.selectedCommandId = addedId
        compare(page.outputRect.x, 100)
        compare(page.outputRect.h, 300)
    }

    function test_deleteLastAndAddAgain() {
        var page = createPage()
        while (page.timelineCommands.length)
            mouseClick(findChild(page, "deleteVideoCommand"))
        compare(page.selectedCommand, null)
        verify(!findChild(page, "saveVideoCommand").enabled)
        verify(!findChild(page, "deleteVideoCommand").enabled)
        compare(page.commandItems.length, 1, "Other timeline must remain intact")
        mouseClick(findChild(page, "addVideoCommand_pc-01"))
        compare(page.timelineCommands.length, 1)
        compare(page.selectedCommand.pcId, "pc-01")
    }

    function test_searchAndIndependentEdits() {
        var page = createPage()
        var search = findChild(page, "videoCommandSearch")
        mouseClick(search)
        search.text = "no-matching-command"
        search.textEdited()
        compare(page.commandsForPc(page.pcDevices[0]).length, 0)
        compare(page.timelineCommands.length, 4)
        mouseClick(findChild(page, "addVideoCommand_pc-01"))
        compare(page.searchText, "")
        page.selectedCommandId = "command-1"
        page.setRectangle(true, { x: 100, y: 120, w: 800, h: 400 })
        page.selectedCommandId = "command-2"
        compare(page.sourceRect.x, 0)
        page.selectedCommandId = "command-1"
        compare(page.sourceRect.x, 100)
        verify(page.selectedCommand.dirty)
        mouseClick(findChild(page, "saveVideoCommand"))
        verify(!page.selectedCommand.dirty)
        page.selectedCommandId = "command-2"
        page.selectedCommandId = "command-1"
        compare(page.sourceRect.w, 800)
    }

    function test_numericBoundsAndCanvasActions() {
        var page = createPage()
        page.setRectangle(false, { x: 5000, y: -100, w: 900, h: 400 })
        compare(page.outputRect.x, 2940)
        compare(page.outputRect.y, 0)
        var widthField = findChild(page, "output_w")
        widthField.forceActiveFocus()
        widthField.text = "1200"
        widthField.commitText()
        page.forceActiveFocus()
        compare(page.outputRect.w, 1200)
        compare(page.outputRect.x, 2640)
        mouseClick(findChild(page, "centerVideoOutput"))
        compare(page.outputRect.x, 1320)
        compare(page.outputRect.y, 880)
        mouseClick(findChild(page, "fillVideoCanvas"))
        compare(page.outputRect.w, 3840)
        compare(page.outputRect.h, 2160)
        compare(page.outputRect.x, 0)
        page.setRectangle(true, { x: 100, y: 120, w: 800, h: 400 })
        mouseClick(findChild(page, "useFullVideo"))
        compare(page.sourceRect.w, 1920)
        compare(page.sourceRect.x, 0)
    }

    function test_dragAndResize() {
        var page = createPage()
        var rect = findChild(page, "videoOutputRect")
        var originalX = page.outputRect.x
        mouseDrag(rect, rect.width / 2, rect.height / 2, 30, 15)
        wait(30)
        verify(page.outputRect.x > originalX)
        var originalWidth = page.outputRect.w
        mouseDrag(rect, rect.width - 1, rect.height - 1, -25, -15)
        wait(30)
        verify(page.outputRect.w < originalWidth)
        compare(page.sourceRect.x, 0, "Target edits must not change the source rectangle")
    }

    function test_timeAndPlaybackOption() {
        var page = createPage()
        var time = findChild(page, "videoCommandTime")
        time.forceActiveFocus()
        time.text = "01:02:03.456"
        time.editingFinished()
        page.forceActiveFocus()
        compare(page.selectedCommand.startTimeMs, 3723456)
        compare(page.formatTime(3723456), "01:02:03.456")
        var play = findChild(page, "videoCommandPlay")
        mouseClick(play)
        compare(page.selectedCommand.play, false)
    }

    function test_previewSourceAndCrop() {
        var page = createPage()
        page.updateCommand({ videoFile: "file:///test-video.mp4" })
        compare(page.videoItem.source.toString(), "file:///test-video.mp4")
        page.setRectangle(true, { x: 480, y: 270, w: 960, h: 540 })
        var texture = findChild(page, "videoOutputTexture")
        verify(texture.visible)
        compare(texture.sourceItem, page.videoItem)
        fuzzyCompare(texture.sourceRect.x, page.videoItem.width / 4, 0.01)
        fuzzyCompare(texture.sourceRect.width, page.videoItem.width / 2, 0.01)
        page.videoItem.play()
        mouseClick(findChild(page, "videoCommand_command-2"))
        compare(page.videoItem.playing, false)
        compare(page.videoItem.source.toString(), "")
    }

    function test_layout_data() {
        return [ { tag: "wide", pageWidth: 1700, pageHeight: 900 },
                 { tag: "compact", pageWidth: 1180, pageHeight: 660 },
                 { tag: "stacked", pageWidth: 1000, pageHeight: 700 } ]
    }

    function test_layout(data) {
        var page = createPage(data.pageWidth, data.pageHeight)
        var source = findChild(page, "videoSourcePanel")
        var target = findChild(page, "videoOutputPanel")
        var content = findChild(page, "videoEditorScroll")
        verify(source.width > 300)
        verify(target.width > 300)
        if (data.pageWidth >= 1180)
            compare(Math.round(source.y), Math.round(target.y))
        else
            verify(target.y > source.y)
        var position = target.mapToItem(content, 0, 0)
        verify(position.x >= 0 && position.x + target.width <= content.width + 1)
        for (var name of ["source_x", "source_y", "source_w", "source_h", "output_x", "output_y", "output_w", "output_h"]) {
            var field = findChild(page, name)
            var panel = name.indexOf("source") === 0 ? source : target
            var point = field.mapToItem(panel, 0, 0)
            verify(point.x >= 0 && point.x + field.width <= panel.width)
            verify(point.y >= 0 && point.y + field.height <= panel.height)
        }
    }
}
