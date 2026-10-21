import QtQuick 2.14
import QtQuick.Controls 2.14
import QtTest 1.2
import UICore.Fields 1.0
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/components/field" as Field
import "qrc:/UICore/qml/components/form" as Form
import "qrc:/UICore/qml/components/shell" as Shell
import "qrc:/UICore/qml/menus" as Menus
import "qrc:/UICore/qml/theme" as Theme

TestCase {
    id: testCase

    name: "ResourceContracts"
    when: testWindow.visible

    ApplicationWindow {
        id: testWindow

        width: 640
        height: 480
        visible: true

        property QtObject appTheme: Theme.AppTheme {}
    }

    Component {
        id: scrollPaneComponent

        Base.AppScrollPane {
            width: 240
            height: 120

            Item {
                implicitHeight: 240
            }
        }
    }

    Component {
        id: panelComponent

        Base.AppPanel {
            width: 300
            title: "Panel"
            collapsible: false
        }
    }

    Component {
        id: alertComponent

        Base.AppAlert {
            width: 360
            message: "Alert"
        }
    }

    Component {
        id: toastComponent

        Base.AppToast {
            width: 360
            message: "Toast"
            timeout: 0
        }
    }

    Component {
        id: textInputHarnessComponent

        Item {
            property alias textField: textField
            property alias textArea: textArea

            Base.AppTextField {
                id: textField

                width: 240
            }

            Base.AppTextArea {
                id: textArea

                y: textField.height + 8
                width: 240
            }
        }
    }

    Component {
        id: colorControlComponent

        Base.AppColorControl {
            width: 240
            value: "#112233"
        }
    }

    Component {
        id: formContentComponent

        Form.AppFormContent {
            width: 360
            height: implicitHeight
            formData: ({
                "sections": [{
                    "key": "section",
                    "title": "Section",
                    "collapsible": true,
                    "expanded": false,
                    "fields": [{
                        "key": "field",
                        "kind": AppField.Kind.Summary,
                        "label": "Field",
                        "value": "Value"
                    }]
                }]
            })
        }
    }

    Component {
        id: menuPaneComponent

        Menus.AppMenuPane {
            width: 400
            height: 360
            paneData: ({
                "title": "Menu",
                "blocks": [{
                    "key": "block",
                    "title": "Block",
                    "collapsible": true,
                    "expanded": true,
                    "sections": [{
                        "key": "menuSection",
                        "fields": [{
                            "key": "menuField",
                            "kind": AppField.Kind.Summary,
                            "label": "Menu field",
                            "value": "Value"
                        }]
                    }]
                }]
            })
        }
    }

    Component {
        id: rendererHarnessComponent

        Item {
            property alias control: fieldControl
            property var fieldData: null

            Field.AppFieldControl {
                id: fieldControl

                width: 320
                height: implicitHeight
                fieldData: parent.fieldData
            }
        }
    }

    Component {
        id: sidebarComponent

        Shell.AppSidebar {
            width: implicitWidth
            height: 320
            menuItems: [{
                "key": "menu",
                "label": "Menu",
                "iconName": "scene"
            }]
        }
    }

    function directLoaders(item) {
        var result = []
        var childItems = item ? item.children : null
        for (var index = 0; childItems && index < childItems.length; ++index) {
            var child = childItems[index]
            try {
                if (child.sourceComponent !== undefined
                        && child.item !== undefined
                        && child.active !== undefined)
                    result.push(child)
            } catch (error) {
            }
        }
        return result
    }

    function loadedCount(loaders) {
        var count = 0
        for (var index = 0; index < loaders.length; ++index) {
            if (loaders[index].item)
                ++count
        }
        return count
    }

    function resourceLoaders(item) {
        var result = []
        var resources = item ? item.resources : null
        for (var index = 0; resources && index < resources.length; ++index) {
            var resource = resources[index]
            try {
                if (resource.sourceComponent !== undefined
                        && resource.item !== undefined
                        && resource.active !== undefined)
                    result.push(resource)
            } catch (error) {
            }
        }
        return result
    }

    function findRailButton(item) {
        if (!item)
            return null

        if (item.buttonSize !== undefined
                && item.iconName !== undefined
                && item.showText !== undefined)
            return item

        var childItems = item.children
        for (var index = 0; childItems && index < childItems.length; ++index) {
            var result = findRailButton(childItems[index])
            if (result)
                return result
        }
        return null
    }

    function test_optionalBaseContentLifecycle() {
        var scrollPane = createTemporaryObject(scrollPaneComponent, testWindow.contentItem)
        verify(scrollPane)
        var scrollLoaders = directLoaders(scrollPane.contentItem)
        compare(scrollLoaders.length, 1)
        compare(loadedCount(scrollLoaders), 0)

        scrollPane.showEdgeHints = true
        wait(0)
        compare(loadedCount(scrollLoaders), 1)
        scrollPane.showEdgeHints = false
        wait(0)
        compare(loadedCount(scrollLoaders), 0)

        var panel = createTemporaryObject(panelComponent, testWindow.contentItem)
        verify(panel)
        compare(findChild(panel, "paneDisclosure"), null)
        panel.collapsible = true
        wait(0)
        verify(findChild(panel, "paneDisclosure"))
        panel.collapsible = false
        wait(0)
        compare(findChild(panel, "paneDisclosure"), null)

        var alert = createTemporaryObject(alertComponent, testWindow.contentItem)
        verify(alert)
        var alertLoaders = directLoaders(alert.contentItem)
        compare(alertLoaders.length, 2)
        compare(loadedCount(alertLoaders), 0)
        alert.actionText = "Retry"
        wait(0)
        compare(loadedCount(alertLoaders), 1)
        alert.closable = true
        wait(0)
        compare(loadedCount(alertLoaders), 2)
        alert.actionText = ""
        alert.closable = false
        wait(0)
        compare(loadedCount(alertLoaders), 0)

        var toast = createTemporaryObject(toastComponent, testWindow.contentItem)
        verify(toast)
        var toastLoaders = directLoaders(toast.contentItem.children[0])
        compare(toastLoaders.length, 1)
        compare(loadedCount(toastLoaders), 0)
        toast.actionText = "Undo"
        wait(0)
        compare(loadedCount(toastLoaders), 1)
        toast.actionText = ""
        wait(0)
        compare(loadedCount(toastLoaders), 0)
    }

    function test_menuPaneContentAndScrollBarUseSeparateEdges() {
        var menu = createTemporaryObject(menuPaneComponent, testWindow.contentItem)
        verify(menu)
        menu.height = 120
        wait(0)

        var menuScroll = findChild(menu, "menuScroll")
        verify(menuScroll)
        compare(menu.leftPadding, menu.paneRightPadding)
        compare(menu.rightPadding, menu.paneRightPadding)
        compare(Math.round(menuScroll.width), Math.round(menu.availableWidth))
        compare(menuScroll.contentRightPadding, 0)
        compare(menuScroll.verticalScrollBarParent, menu)

        var scrollBar = menuScroll.verticalScrollBar
        verify(scrollBar)
        var scrollOrigin = menuScroll.mapToItem(menu, 0, 0)
        var scrollBarRight = scrollBar.mapToItem(menu, scrollBar.width, 0).x
        compare(Math.round(scrollBarRight), menu.width)
        compare(Math.round(scrollBar.y), Math.round(scrollOrigin.y))

        verify(menuScroll.canScrollDown)
        var scrollBarCenter = scrollBar.mapToItem(
            testWindow.contentItem,
            scrollBar.width / 2,
            scrollBar.height / 2
        )
        mouseMove(testWindow.contentItem, scrollBarCenter.x, scrollBarCenter.y)
        tryCompare(scrollBar, "hovered", true)

        var scrollBarTrackEnd = scrollBar.mapToItem(
            testWindow.contentItem,
            scrollBar.width / 2,
            scrollBar.height - 2
        )
        mouseClick(testWindow.contentItem, scrollBarTrackEnd.x, scrollBarTrackEnd.y)
        tryVerify(function() { return menuScroll.flickableItem.contentY > 0 })
    }

    function test_scrollBarOverlayParentFollowsLayoutDirection() {
        var scrollPane = createTemporaryObject(scrollPaneComponent, testWindow.contentItem)
        verify(scrollPane)
        scrollPane.x = 24
        scrollPane.y = 16
        scrollPane.verticalScrollBarParent = testWindow.contentItem
        wait(0)

        var scrollBar = scrollPane.verticalScrollBar
        verify(scrollBar)
        compare(scrollBar.parent, testWindow.contentItem)

        var viewportTopLeft = scrollPane.mapToItem(testWindow.contentItem, 0, 0)
        compare(Math.round(scrollBar.x + scrollBar.width), testWindow.contentItem.width)
        compare(Math.round(scrollBar.y), viewportTopLeft.y)

        scrollPane.locale = Qt.locale("ar_SA")
        tryCompare(scrollPane, "mirrored", true)
        compare(Math.round(scrollBar.x), 0)

        scrollPane.x = 40
        scrollPane.y = 30
        wait(0)
        viewportTopLeft = scrollPane.mapToItem(testWindow.contentItem, 0, 0)
        compare(Math.round(scrollBar.x), 0)
        compare(Math.round(scrollBar.y), viewportTopLeft.y)
    }

    function test_nativeHoverStateContracts() {
        var harness = createTemporaryObject(textInputHarnessComponent, testWindow.contentItem)
        verify(harness)

        compare(harness.textField.hoverEnabled, true)
        compare(harness.textArea.hoverEnabled, true)
        harness.textField.readOnly = true
        harness.textArea.readOnly = true
        compare(harness.textField.hoverEnabled, false)
        compare(harness.textArea.hoverEnabled, false)
        harness.textField.readOnly = false
        harness.textArea.readOnly = false
        harness.textField.enabled = false
        harness.textArea.enabled = false
        compare(harness.textField.hoverEnabled, false)
        compare(harness.textArea.hoverEnabled, false)
    }

    function test_colorDialogUnloadsAfterClose() {
        var control = createTemporaryObject(colorControlComponent, testWindow.contentItem)
        verify(control)
        var loaders = directLoaders(control.contentItem)
        compare(loaders.length, 1)
        var dialogLoader = loaders[0]
        compare(dialogLoader.item, null)

        dialogLoader.active = true
        wait(0)
        verify(dialogLoader.item)
        dialogLoader.item.open()
        wait(0)
        verify(dialogLoader.item.visible)
        dialogLoader.item.close()
        wait(0)
        compare(dialogLoader.item, null)
    }

    function test_toolTipsLoadOnlyWhenApplicable() {
        var sidebar = createTemporaryObject(sidebarComponent, testWindow.contentItem)
        verify(sidebar)
        wait(0)
        var railButton = findRailButton(sidebar)
        verify(railButton)
        var sidebarLoaders = resourceLoaders(railButton)
        compare(sidebarLoaders.length, 1)
        compare(loadedCount(sidebarLoaders), 0)
        sidebar.showItemLabels = false
        wait(0)
        compare(loadedCount(sidebarLoaders), 1)
        sidebar.showItemLabels = true
        wait(0)
        compare(loadedCount(sidebarLoaders), 0)

        var harness = createTemporaryObject(rendererHarnessComponent, testWindow.contentItem)
        verify(harness)
        harness.control.width = 100
        harness.fieldData = {
            "key": "summary",
            "kind": AppField.Kind.Summary,
            "value": "This summary is intentionally too long for its field"
        }
        wait(0)
        var renderer = findChild(harness.control, "field:summary")
        verify(renderer)
        var summaryText = findChild(renderer, "summaryText:summary")
        verify(summaryText)
        verify(summaryText.truncated)
        var summaryLoaders = resourceLoaders(renderer.fieldControl)
        compare(summaryLoaders.length, 1)
        compare(loadedCount(summaryLoaders), 1)

        harness.fieldData = {
            "key": "summary",
            "kind": AppField.Kind.Summary,
            "value": "Short"
        }
        wait(0)
        compare(summaryText.truncated, false)
        compare(loadedCount(summaryLoaders), 0)
    }

    function test_formCollapsedFieldsUnloadAfterAnimation() {
        var form = createTemporaryObject(formContentComponent, testWindow.contentItem)
        verify(form)
        wait(0)

        var section = findChild(form, "section:section")
        verify(section)
        var disclosure = findChild(section, "paneDisclosure")
        verify(disclosure)
        compare(findChild(form, "field:field"), null)

        disclosure.Accessible.pressAction()
        wait(0)
        verify(findChild(form, "field:field"))

        disclosure.Accessible.pressAction()
        verify(section.bodyVisible)
        verify(findChild(form, "field:field"))
        wait(testWindow.appTheme.motion.paneRevealDuration + 40)
        compare(section.bodyVisible, false)
        compare(findChild(form, "field:field"), null)
    }

    function test_menuFormContentSurvivesClosingAnimation() {
        var menu = createTemporaryObject(menuPaneComponent, testWindow.contentItem)
        verify(menu)
        wait(0)

        var block = findChild(menu, "block:block")
        verify(block)
        var disclosure = findChild(block, "paneDisclosure")
        verify(disclosure)
        verify(findChild(block, "field:menuField"))

        disclosure.Accessible.pressAction()
        verify(block.bodyVisible)
        verify(findChild(block, "field:menuField"))
        wait(testWindow.appTheme.motion.paneRevealDuration + 40)
        compare(block.bodyVisible, false)
        compare(findChild(block, "field:menuField"), null)
    }

    function test_controlledRendererBindingsFollowExternalValue() {
        var harness = createTemporaryObject(rendererHarnessComponent, testWindow.contentItem)
        verify(harness)

        harness.fieldData = {
            "key": "choice",
            "kind": AppField.Kind.Choice,
            "options": [{ "label": "First", "value": "first" }],
            "value": "first"
        }
        wait(0)
        var renderer = findChild(harness.control, "field:choice")
        verify(renderer)
        compare(renderer.fieldControl.value, "first")
        harness.fieldData = {
            "key": "choice",
            "kind": AppField.Kind.Choice,
            "options": [{ "label": "Second", "value": "second" }],
            "value": "second"
        }
        wait(0)
        compare(renderer.fieldControl.value, "second")

        harness.fieldData = {
            "key": "segmented",
            "kind": AppField.Kind.Segmented,
            "options": [{ "label": "First", "value": "first" }],
            "value": "first"
        }
        wait(0)
        renderer = findChild(harness.control, "field:segmented")
        verify(renderer)
        compare(renderer.fieldControl.value, "first")

        harness.fieldData = {
            "key": "select",
            "kind": AppField.Kind.Select,
            "options": [{ "label": "Second", "value": "second" }],
            "value": "second"
        }
        wait(0)
        renderer = findChild(harness.control, "field:select")
        verify(renderer)
        compare(renderer.fieldControl.value, "second")

        harness.fieldData = {
            "key": "color",
            "kind": AppField.Kind.Color,
            "value": "#112233"
        }
        wait(0)
        renderer = findChild(harness.control, "field:color")
        verify(renderer)
        compare(renderer.fieldControl.value, "#112233")

        harness.fieldData = {
            "key": "slider",
            "kind": AppField.Kind.Slider,
            "min": 0,
            "max": 100,
            "value": 42
        }
        wait(0)
        renderer = findChild(harness.control, "field:slider")
        verify(renderer)
        compare(renderer.fieldControl.value, 42)
        harness.fieldData = {
            "key": "slider",
            "kind": AppField.Kind.Slider,
            "min": 0,
            "max": 100,
            "value": 64
        }
        wait(0)
        compare(renderer.fieldControl.value, 64)
    }
}
