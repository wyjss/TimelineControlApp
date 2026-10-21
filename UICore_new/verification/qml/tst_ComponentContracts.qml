import QtQuick 2.14
import QtQuick.Controls 2.14
import QtTest 1.2
import UICore.Fields 1.0
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/components/field" as Field
import "qrc:/UICore/qml/components/task" as TaskView
import "qrc:/UICore/qml/theme" as Theme

TestCase {
    id: testCase

    name: "ComponentContracts"
    when: testWindow.visible

    ApplicationWindow {
        id: testWindow

        width: 640
        height: 480
        visible: true

        property QtObject appTheme: Theme.AppTheme {}
    }

    Component {
        id: buttonComponent

        Base.AppButton {
            x: 40
            y: 40
            text: "Button"
            animated: false
            property int clickCount: 0
            onClicked: ++clickCount
        }
    }

    function test_buttonRaisedLifecycle_data() {
        return [
            { tag: "Primary", variant: UiStyle.ButtonVariant.Primary },
            { tag: "Secondary", variant: UiStyle.ButtonVariant.Secondary },
            { tag: "Tonal", variant: UiStyle.ButtonVariant.Tonal },
            { tag: "Subtle", variant: UiStyle.ButtonVariant.Subtle },
            { tag: "Ghost", variant: UiStyle.ButtonVariant.Ghost },
            { tag: "Nav", variant: UiStyle.ButtonVariant.Nav },
            { tag: "Danger", variant: UiStyle.ButtonVariant.Danger }
        ]
    }

    function test_buttonRaisedLifecycle(data) {
        var button = createTemporaryObject(buttonComponent, testWindow.contentItem, {
            variant: data.variant
        })
        verify(button)
        mouseMove(testWindow.contentItem, 600, 400)
        compare(button.raised, false)
        compare(findChild(button, "buttonRaisedSurface"), null)
        var originalWidth = button.implicitWidth
        var originalHeight = button.implicitHeight

        button.raised = true
        wait(0)
        compare(button.background.strokeWidth, 0)
        var transparentVariant = data.variant === UiStyle.ButtonVariant.Ghost
            || data.variant === UiStyle.ButtonVariant.Nav
        compare(!!findChild(button, "buttonRaisedSurface"), !transparentVariant)

        mouseMove(button, button.width / 2, button.height / 2)
        tryCompare(button, "hovered", true)
        var effect = findChild(button, "buttonRaisedSurface")
        verify(effect)
        var hoverOpacity = effect.opacity
        mousePress(button, button.width / 2, button.height / 2)
        verify(button.down)
        verify(effect.opacity < hoverOpacity)
        mouseRelease(button, button.width / 2, button.height / 2)
        compare(button.clickCount, 1)

        testWindow.requestActivate()
        wait(50)
        if (testWindow.active) {
            testWindow.contentItem.forceActiveFocus()
            button.forceActiveFocus(Qt.TabFocusReason)
            tryCompare(button, "visualFocus", true)
            compare(button.background.strokeWidth, 2)
            keyClick(Qt.Key_Space)
            compare(button.clickCount, 2)
        }
        var clickCount = button.clickCount
        compare(button.implicitWidth, originalWidth)
        compare(button.implicitHeight, originalHeight)

        button.enabled = false
        wait(0)
        compare(findChild(button, "buttonRaisedSurface"), null)
        mouseClick(button, button.width / 2, button.height / 2)
        compare(button.clickCount, clickCount)
        button.enabled = true
        button.checked = true
        wait(0)
        verify(findChild(button, "buttonRaisedSurface"))

        for (var index = 0; index < 3; ++index) {
            button.raised = false
            wait(0)
            compare(findChild(button, "buttonRaisedSurface"), null)
            button.raised = true
            wait(0)
            verify(findChild(button, "buttonRaisedSurface"))
        }
        button.raised = false
        wait(0)
        compare(findChild(button, "buttonRaisedSurface"), null)
        compare(button.variant, data.variant)
    }

    Component {
        id: textAreaHarnessComponent

        Item {
            property alias control: textArea
            property string externalText: "Initial text"

            Base.AppTextArea {
                id: textArea

                width: 120
                text: parent.externalText
            }
        }
    }

    Component {
        id: checkBoxComponent

        Base.AppCheckBox {
            width: 160
            text: "Enabled"
        }
    }

    Component {
        id: editorHintHarnessComponent

        Item {
            property alias sourceField: sourceField
            property alias proxyField: proxyField

            AppField {
                id: sourceField
            }

            AppField {
                id: proxyField
            }
        }
    }

    Component {
        id: checkBoxRendererHarnessComponent

        Item {
            property alias field: checkBoxField
            property alias control: fieldControl
            property int editCount: 0

            AppField {
                id: checkBoxField

                key: "checkbox"
                kind: AppField.Kind.CheckBox
                label: "Check"
                value: false
            }

            Field.AppFieldControl {
                id: fieldControl

                width: 280
                fieldData: checkBoxField
                onValueEdited: function(value) {
                    parent.editCount += 1
                    checkBoxField.value = value
                }
            }
        }
    }

    Component {
        id: textAreaRendererHarnessComponent

        Item {
            property alias field: textAreaField
            property alias control: fieldControl
            property int editCount: 0

            AppField {
                id: textAreaField

                key: "textarea"
                kind: AppField.Kind.TextArea
                label: "Notes"
                value: "Initial"
            }

            Field.AppFieldControl {
                id: fieldControl

                width: 280
                fieldData: textAreaField
                onValueEdited: function(value) {
                    parent.editCount += 1
                    textAreaField.value = value
                }
            }
        }
    }

    Component {
        id: progressComponent

        Base.AppProgressBar {
            width: 200
            from: 0
            to: 100
            value: 0
        }
    }

    Component {
        id: iconComponent

        Base.AppIcon {
            name: "workflow"
            size: 20
            animateColor: false
        }
    }

    Component {
        id: tooltipHarnessComponent

        Item {
            id: tooltipHost

            property alias tooltip: tooltip

            Base.AppToolTip {
                id: tooltip

                parent: tooltipHost
                text: "Tooltip"
            }
        }
    }

    Component {
        id: badgeLoaderComponent

        Loader {
            asynchronous: true
            sourceComponent: Base.AppBadge {
                text: "Badge"
            }
        }
    }

    Component {
        id: toastComponent

        Base.AppToast {
            width: 360
            message: "A long message that must wrap when the toast width becomes narrow enough."
            iconSymbol: ""
            timeout: 0
            closable: false
        }
    }

    Component {
        id: fieldBlockComponent

        Base.AppFieldBlock {
            width: 320
            label: "Name"
            required: true

            Item {
                implicitWidth: 120
                implicitHeight: 24
            }
        }
    }

    Component {
        id: rendererInputHarnessComponent

        Item {
            property alias objectField: objectField
            property alias objectControl: objectControl
            property alias mapControl: mapControl
            property var mapField: ({
                "kind": AppField.Kind.CheckBox,
                "key": "map",
                "label": "Map",
                "value": false,
                "required": true,
                "errorText": "Map error"
            })

            AppField {
                id: objectField

                key: "object"
                kind: AppField.Kind.CheckBox
                label: "Object"
                value: false
                required: true
                errorText: "Object error"
            }

            Field.AppFieldControl {
                id: objectControl

                width: 300
                fieldData: objectField
            }

            Field.AppFieldControl {
                id: mapControl

                y: objectControl.implicitHeight + 8
                width: 300
                fieldData: parent.mapField
            }
        }
    }

    Component {
        id: taskPanelComponent

        TaskView.AppTaskPanel {
            width: 420
            height: 360
            taskExpansionState: ({ "task-1": true })
            taskItems: [
                {
                    "taskId": "task-1",
                    "taskName": "Task",
                    "phase": 1,
                    "progress": 0.5,
                    "finished": false,
                    "message": "Running"
                }
            ]
            activeTaskCount: 1
        }
    }

    function findProgressBar(item) {
        if (!item)
            return null

        if (item.trackHeight !== undefined
                && item.indeterminate !== undefined
                && item.position !== undefined) {
            return item
        }

        var childItems = item.children
        for (var index = 0; childItems && index < childItems.length; ++index) {
            var result = findProgressBar(childItems[index])
            if (result)
                return result
        }

        return null
    }

    function test_textAreaContracts() {
        var harness = createTemporaryObject(textAreaHarnessComponent, testWindow.contentItem)
        verify(harness)
        var textArea = harness.control

        compare(textArea.wrapMode, TextEdit.Wrap)
        var minimumHeight = textArea.implicitHeight
        harness.externalText = "This long text must wrap across several visual lines in the narrow text area."
        wait(0)
        verify(textArea.lineCount > 1)
        verify(textArea.implicitHeight > minimumHeight)

        textArea.readOnly = true
        compare(textArea.readOnly, true)

        harness.externalText = "External update"
        tryCompare(textArea, "text", "External update")
    }

    function test_editorHintMappings() {
        compare(BaseField.MultilineTextEditor, 10)
        compare(BaseField.CheckBoxEditor, 11)
        compare(AppField.Kind.TextArea, 11)
        compare(AppField.Kind.CheckBox, 12)

        var harness = createTemporaryObject(editorHintHarnessComponent, testWindow.contentItem)
        verify(harness)

        harness.sourceField.sourceField.editorHint = BaseField.MultilineTextEditor
        harness.proxyField.sourceField = harness.sourceField.sourceField
        compare(harness.proxyField.kind, AppField.Kind.TextArea)

        harness.proxyField.sourceField = null
        harness.sourceField.sourceField.editorHint = BaseField.CheckBoxEditor
        harness.proxyField.sourceField = harness.sourceField.sourceField
        compare(harness.proxyField.kind, AppField.Kind.CheckBox)

        harness.sourceField.required = true
        harness.sourceField.errorText = "Required"
        compare(harness.proxyField.required, true)
        compare(harness.proxyField.errorText, "Required")
        compare(harness.proxyField.valid, false)
    }

    function test_checkBoxContracts() {
        var checkBox = createTemporaryObject(checkBoxComponent, testWindow.contentItem)
        verify(checkBox)

        mouseClick(checkBox, checkBox.width / 2, checkBox.height / 2, Qt.LeftButton)
        compare(checkBox.checked, true)

        checkBox.enabled = false
        mouseClick(checkBox, checkBox.width / 2, checkBox.height / 2, Qt.LeftButton)
        compare(checkBox.checked, true)
        checkBox.enabled = true

        checkBox.tristate = true
        checkBox.checkState = Qt.PartiallyChecked
        compare(checkBox.checkState, Qt.PartiallyChecked)
        mouseClick(checkBox, checkBox.width / 2, checkBox.height / 2, Qt.LeftButton)
        verify(checkBox.checkState !== Qt.PartiallyChecked)

        testWindow.requestActivate()
        wait(50)
        compare(checkBox.focusPolicy, Qt.StrongFocus)
        if (testWindow.active) {
            checkBox.forceActiveFocus(Qt.TabFocusReason)
            tryCompare(checkBox, "activeFocus", true)
            var checkedBeforeSpace = checkBox.checked
            keyClick(Qt.Key_Space)
            compare(checkBox.checked, !checkedBeforeSpace)
        }
    }

    function test_checkBoxRendererSingleEdit() {
        var harness = createTemporaryObject(checkBoxRendererHarnessComponent, testWindow.contentItem)
        verify(harness)
        var renderer = findChild(harness.control, "field:checkbox")
        verify(renderer)
        var checkBox = renderer.fieldControl
        verify(checkBox)

        mouseClick(checkBox, checkBox.width / 2, checkBox.height / 2, Qt.LeftButton)
        compare(harness.editCount, 1)
        compare(harness.field.value, true)
    }

    function test_multilineRendererContracts() {
        var harness = createTemporaryObject(textAreaRendererHarnessComponent, testWindow.contentItem)
        verify(harness)
        var renderer = findChild(harness.control, "field:textarea")
        verify(renderer)
        var textArea = renderer.fieldControl
        verify(textArea)

        compare(textArea.text, "Initial")
        textArea.text = "Edited"
        compare(harness.editCount, 1)
        compare(harness.field.value, "Edited")

        harness.field.readOnly = true
        compare(textArea.readOnly, true)
        harness.field.value = "External"
        wait(0)
        compare(textArea.text, "External")

        harness.field.value = null
        wait(0)
        compare(textArea.text, "")
    }

    function test_progressContracts() {
        var progress = createTemporaryObject(progressComponent, testWindow.contentItem)
        verify(progress)
        var fill = progress.contentItem.children[0]
        verify(fill)

        compare(progress.position, 0)
        compare(fill.width, 0)

        progress.value = 50
        wait(testWindow.appTheme.motion.durationStandard + 20)
        compare(progress.position, 0.5)
        compare(Math.round(fill.width), 100)

        progress.value = 100
        wait(testWindow.appTheme.motion.durationStandard + 20)
        compare(progress.position, 1)
        compare(Math.round(fill.width), 200)

        progress.from = 10
        progress.to = 30
        progress.value = 15
        wait(testWindow.appTheme.motion.durationStandard + 20)
        compare(progress.position, 0.25)
        compare(Math.round(fill.width), 50)

        progress.LayoutMirroring.enabled = true
        compare(progress.mirrored, true)
        compare(progress.visualPosition, 0.75)
        compare(Math.round(fill.width), 50)
        compare(Math.round(fill.x), 150)

        progress.indeterminate = true
        progress.visible = true
        var initialIndeterminateProgress = fill.indeterminateProgress
        wait(80)
        verify(fill.indeterminateProgress !== initialIndeterminateProgress)

        progress.visible = false
        var stoppedIndeterminateProgress = fill.indeterminateProgress
        wait(80)
        compare(fill.indeterminateProgress, stoppedIndeterminateProgress)
    }

    function test_iconTintRenderingContracts() {
        var icon = createTemporaryObject(iconComponent, testWindow.contentItem)
        verify(icon)
        var paintedIcon = icon.contentItem.children[0]
        var fallback = icon.contentItem.children[1]
        verify(paintedIcon)
        verify(fallback)

        tryCompare(paintedIcon, "ready", true)
        compare(paintedIcon.visible, true)
        compare(paintedIcon.tintSource, true)
        compare(fallback.visible, false)

        icon.color = "#80ff0000"
        wait(0)
        compare(String(paintedIcon.color), "#80ff0000")

        icon.tintSource = false
        wait(0)
        compare(paintedIcon.tintSource, false)
        compare(paintedIcon.visible, true)

        icon.name = ""
        icon.symbol = "Z"
        tryCompare(paintedIcon, "ready", false)
        compare(fallback.visible, true)
        compare(fallback.text, "Z")
    }

    function test_taskPanelUsesProgressBar() {
        var panel = createTemporaryObject(taskPanelComponent, testWindow.contentItem)
        verify(panel)
        panel.open()
        wait(100)

        var progress = findProgressBar(panel.contentItem)
        verify(progress)
        compare(progress.value, 0.5)
        panel.close()
    }

    function test_toolTipContracts() {
        var harness = createTemporaryObject(tooltipHarnessComponent, testWindow.contentItem)
        verify(harness)
        var tooltip = harness.tooltip

        compare(tooltip.delay, testWindow.appTheme.motion.tooltipDelay)
        compare(tooltip.timeout, testWindow.appTheme.motion.tooltipTimeout)

        tooltip.delay = 25
        tooltip.timeout = 75
        compare(tooltip.delay, 25)
        compare(tooltip.timeout, 75)
    }

    function test_badgeContracts() {
        var loader = createTemporaryObject(badgeLoaderComponent, testWindow.contentItem)
        verify(loader)
        tryCompare(loader, "status", Loader.Ready)
        var badge = loader.item
        var label = badge.contentItem.children[0]
        compare(label.text, badge.text)
        compare(label.horizontalAlignment, Text.AlignHCenter)
        compare(label.verticalAlignment, Text.AlignVCenter)
        compare(label.width, badge.availableWidth)
        compare(label.height, badge.availableHeight)

        badge.animated = false
        badge.surfaceTone = UiStyle.SurfaceTone.Highlight
        badge.textTone = UiStyle.TextTone.Accent
        badge.fillOverride = "#123456"
        badge.textColorOverride = "#FEDCBA"
        wait(testWindow.appTheme.motion.durationStandard + 20)

        compare(badge.surfaceTone, UiStyle.SurfaceTone.Highlight)
        compare(badge.textTone, UiStyle.TextTone.Accent)
        compare(badge.fillColor, badge.fillOverride)
        compare(String(label.color), "#fedcba")
    }

    function test_toastContentSizing() {
        var toast = createTemporaryObject(toastComponent, testWindow.contentItem)
        verify(toast)
        toast.open()
        tryCompare(toast, "opened", true)

        var wideHeight = toast.height
        verify(wideHeight > toast.topPadding + toast.bottomPadding)

        toast.width = 180
        wait(50)
        verify(toast.height > wideHeight)

        toast.title = "Saved"
        toast.actionText = "Undo"
        toast.iconSymbol = "i"
        toast.closable = true
        wait(0)
        verify(toast.height > toast.topPadding + toast.bottomPadding)

        toast.title = ""
        toast.message = ""
        toast.actionText = ""
        toast.iconSymbol = ""
        toast.closable = false
        wait(0)
        compare(toast.height, toast.topPadding + toast.bottomPadding)

        toast.message = "Saved"
        wait(0)
        verify(toast.height > toast.topPadding + toast.bottomPadding)
        toast.close()
    }

    function test_fieldRequiredAndErrorHeight() {
        var fieldBlock = createTemporaryObject(fieldBlockComponent, testWindow.contentItem)
        verify(fieldBlock)
        compare(fieldBlock.required, true)
        compare(fieldBlock.valid, true)

        var heightWithoutError = fieldBlock.implicitHeight
        fieldBlock.errorText = "This field is required"
        wait(0)
        compare(fieldBlock.valid, false)
        verify(fieldBlock.implicitHeight > heightWithoutError)
        compare(fieldBlock.Accessible.description, "This field is required")
    }

    function test_objectAndMapRendererInputs() {
        var harness = createTemporaryObject(rendererInputHarnessComponent, testWindow.contentItem)
        verify(harness)
        var objectRenderer = findChild(harness.objectControl, "field:object")
        var mapRenderer = findChild(harness.mapControl, "field:map")
        verify(objectRenderer)
        verify(mapRenderer)

        compare(objectRenderer.required, true)
        compare(objectRenderer.errorText, "Object error")
        compare(objectRenderer.valid, false)
        compare(mapRenderer.required, true)
        compare(mapRenderer.errorText, "Map error")
        compare(mapRenderer.valid, false)

        var objectHeightWithError = objectRenderer.implicitHeight
        harness.objectField.errorText = ""
        wait(0)
        compare(objectRenderer.valid, true)
        verify(objectRenderer.implicitHeight < objectHeightWithError)

        harness.mapField = {
            "kind": AppField.Kind.CheckBox,
            "key": "map",
            "label": null,
            "value": false,
            "required": true,
            "errorText": null
        }
        wait(0)
        compare(mapRenderer.label, "")
        compare(mapRenderer.errorText, "")
        compare(mapRenderer.valid, true)
    }
}
