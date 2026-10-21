import QtQuick 2.14
import QtQuick.Controls 2.14
import QtTest 1.2
import UICore.Style 1.0
import "qrc:/UICore/qml" as Ui
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/components/base/internal" as BaseInternal
import "qrc:/UICore/qml/components/base/internal/AppPopupGeometry.js" as PopupGeometry
import "qrc:/UICore/qml/components/shell" as Shell
import "qrc:/UICore/qml/theme" as Theme

TestCase {
    id: testCase

    name: "ControlContracts"
    when: testWindow.visible
    width: 480
    height: 360

    ApplicationWindow {
        id: testWindow

        width: 480
        height: 360
        visible: true

        property QtObject appTheme: Theme.AppTheme {}
    }

    Component {
        id: choiceHarnessComponent

        Item {
            property alias control: choiceControl
            property string externalValue: "first"
            property bool acceptsChange: false

            Base.AppChoiceControl {
                id: choiceControl

                options: [
                    { "label": "First", "value": "first" },
                    { "label": "Second", "value": "second" }
                ]
                value: parent.externalValue
                onValueSelected: function(nextValue) {
                    if (parent.acceptsChange)
                        parent.externalValue = nextValue
                }
            }
        }
    }

    Component {
        id: segmentedHarnessComponent

        Item {
            property alias control: segmentedControl
            property string externalValue: "first"
            property bool acceptsChange: false

            Base.AppSegmentedControl {
                id: segmentedControl

                width: 240
                options: [
                    { "label": "First", "value": "first" },
                    { "label": "Second", "value": "second" }
                ]
                value: parent.externalValue
                onValueSelected: function(nextValue) {
                    if (parent.acceptsChange)
                        parent.externalValue = nextValue
                }
            }
        }
    }

    Component {
        id: colorHarnessComponent

        Item {
            property alias control: colorControl
            property string externalValue: "#112233"
            property bool acceptsChange: false

            Base.AppColorControl {
                id: colorControl

                value: parent.externalValue
                onValueEdited: function(nextValue) {
                    if (parent.acceptsChange)
                        parent.externalValue = nextValue
                }
            }
        }
    }

    Component {
        id: sliderComponent

        Base.AppSliderControl {
            width: 240
        }
    }

    Component {
        id: fieldBlockHarnessComponent

        Item {
            property alias fieldBlock: fieldBlock
            property alias underlineState: underlineState

            width: 320
            height: fieldBlock.implicitHeight

            QtObject {
                id: underlineState

                property bool interactionHovered: false
                property bool interactionActive: false
                property bool enabled: true
            }

            Base.AppFieldBlock {
                id: fieldBlock

                width: 320
                showUnderline: true
                fieldControl: underlineState

                Item {
                    implicitWidth: 120
                    implicitHeight: 32
                }
            }
        }
    }

    Component {
        id: panelComponent

        Base.AppPanel {
            width: 300
            title: "Panel"
            collapsible: true
            expanded: true
            animated: false
        }
    }

    Component {
        id: surfaceChromeContractComponent

        Item {
            property alias surface: surface
            property alias chrome: chrome

            Base.AppSurface {
                id: surface

                width: 120
                height: 32
                sizeToContent: false
                animated: false
            }

            BaseInternal.AppSurfaceChrome {
                id: chrome

                width: surface.width
                height: surface.height
                themeContext: testWindow.appTheme
                surfaceTone: surface.surfaceTone
                active: surface.active
                hoveredState: surface.hoveredState
                pressedState: surface.pressedState
                animated: false
                shapeRole: surface.shapeRole
                cornerRadius: surface.cornerRadius
                strokeWidth: surface.strokeWidth
                fillOverride: surface.fillOverride
                borderOverride: surface.borderOverride
                hoverOverlayOpacity: surface.hoverOverlayOpacity
                activeOverlayOpacity: surface.activeOverlayOpacity
            }
        }
    }

    Component {
        id: sidebarDoubleClickHarnessComponent

        Item {
            property alias shell: shell
            property int navigationCount: 0
            property string activeNavigationKey: ""

            Ui.AppShell {
                id: shell

                width: 480
                height: 360
                leftPaneDisplayMode: Shell.AppSidebarPane.Hidden
                activeNavigationKey: parent.activeNavigationKey
                navigationItems: [
                    {
                        "key": "menu",
                        "label": "Menu"
                    }
                ]
                onNavigationRequested: parent.navigationCount += 1
            }
        }
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

    function test_choiceControlledValue() {
        var harness = createTemporaryObject(choiceHarnessComponent, testWindow.contentItem)
        verify(harness)

        harness.control.commitOption(harness.control.options[1])
        compare(harness.externalValue, "first")
        compare(harness.control.value, "first")

        harness.acceptsChange = true
        harness.control.commitOption(harness.control.options[1])
        compare(harness.externalValue, "second")
        compare(harness.control.value, "second")

        harness.externalValue = "first"
        compare(harness.control.value, "first")
    }

    function test_segmentedControlledValue() {
        var harness = createTemporaryObject(segmentedHarnessComponent, testWindow.contentItem)
        verify(harness)

        harness.control.commitOption(harness.control.options[1])
        compare(harness.externalValue, "first")
        compare(harness.control.value, "first")

        harness.acceptsChange = true
        harness.control.commitOption(harness.control.options[1])
        compare(harness.externalValue, "second")
        compare(harness.control.value, "second")

        harness.externalValue = "first"
        compare(harness.control.value, "first")
    }

    function test_colorControlledValue() {
        var harness = createTemporaryObject(colorHarnessComponent, testWindow.contentItem)
        verify(harness)
        var input = harness.control.contentItem.children[0]
        verify(input)

        verify(harness.control.commitText("#445566"))
        compare(harness.externalValue, "#112233")
        compare(harness.control.value, "#112233")
        compare(input.text, "#112233")

        input.forceActiveFocus()
        harness.externalValue = "#778899"
        compare(harness.control.value, "#778899")
        compare(input.text, "#778899")

        harness.acceptsChange = true
        verify(harness.control.commitText("#445566"))
        compare(harness.externalValue, "#445566")
        compare(harness.control.value, "#445566")
        compare(input.text, "#445566")

        harness.externalValue = "#AABBCC"
        compare(harness.control.value, "#AABBCC")
        compare(input.text, "#AABBCC")
    }

    function test_animatedFalseStopsManagedTransitions() {
        var choiceHarness = createTemporaryObject(choiceHarnessComponent, testWindow.contentItem)
        var segmentedHarness = createTemporaryObject(segmentedHarnessComponent, testWindow.contentItem)
        var slider = createTemporaryObject(sliderComponent, testWindow.contentItem)
        var fieldHarness = createTemporaryObject(fieldBlockHarnessComponent, testWindow.contentItem)
        verify(choiceHarness)
        verify(segmentedHarness)
        verify(slider)
        verify(fieldHarness)

        choiceHarness.control.animated = false
        segmentedHarness.control.animated = false
        slider.animated = false
        fieldHarness.fieldBlock.animated = false
        wait(testWindow.appTheme.motion.durationStandard + 20)

        var choiceFirstIndicator = findChild(choiceHarness.control, "choiceSelectionIndicator_0")
        var choiceSecondIndicator = findChild(choiceHarness.control, "choiceSelectionIndicator_1")
        var segmentedIndicator = findChild(segmentedHarness.control, "segmentedSelectionIndicator")
        var sliderHandle = findChild(slider, "sliderHandle")
        var sliderValueLabel = findChild(slider, "sliderValueLabel")
        var fieldUnderline = findChild(fieldHarness.fieldBlock, "fieldUnderline")
        verify(choiceFirstIndicator)
        verify(choiceSecondIndicator)
        verify(segmentedIndicator)
        verify(sliderHandle)
        verify(sliderValueLabel)
        verify(fieldUnderline)

        choiceHarness.externalValue = "second"
        compare(choiceFirstIndicator.opacity, 0)
        compare(choiceSecondIndicator.opacity, 1)

        segmentedHarness.externalValue = "second"
        compare(
            Math.round(segmentedIndicator.x),
            Math.round(segmentedHarness.control.segmentWidth + segmentedHarness.control.segmentGap)
        )

        segmentedHarness.control.enabled = false
        compare(segmentedIndicator.fillColor, segmentedHarness.control.colorValue("disabledBorder"))

        slider.enabled = false
        compare(sliderHandle.color, slider.colorValue("disabledText"))
        compare(sliderValueLabel.color, slider.colorValue("disabledText"))

        fieldHarness.underlineState.interactionActive = true
        compare(fieldUnderline.color, fieldHarness.fieldBlock.colorValue("highlightText"))
    }

    function test_surfaceChromeMatchesSurfaceVisualState() {
        var harness = createTemporaryObject(surfaceChromeContractComponent, testWindow.contentItem)
        verify(harness)

        function compareVisualState() {
            compare(harness.chrome.resolvedRadius, harness.surface.resolvedRadius)
            compare(harness.chrome.fillColor, harness.surface.fillColor)
            compare(harness.chrome.borderColor, harness.surface.borderColor)
            compare(harness.chrome.hoverOverlayColor, harness.surface.hoverOverlayColor)
            compare(harness.chrome.activeOverlayColor, harness.surface.activeOverlayColor)
            compare(harness.chrome.resolvedHoverOpacity, harness.surface.resolvedHoverOpacity)
            compare(harness.chrome.resolvedActiveOpacity, harness.surface.resolvedActiveOpacity)
        }

        compareVisualState()

        harness.surface.surfaceTone = UiStyle.SurfaceTone.Ghost
        harness.surface.shapeRole = UiStyle.ShapeRole.Pill
        harness.surface.active = true
        harness.surface.hoveredState = true
        harness.surface.pressedState = true
        harness.surface.strokeWidth = 2
        compareVisualState()

        harness.surface.cornerRadius = 7
        harness.surface.fillOverride = "#123456"
        harness.surface.borderOverride = "#654321"
        compareVisualState()
    }

    function test_panelDisclosureInputContracts() {
        var panel = createTemporaryObject(panelComponent, testWindow.contentItem)
        verify(panel)
        var disclosure = findChild(panel, "paneDisclosure")
        verify(disclosure)

        testWindow.requestActivate()
        wait(50)

        mouseClick(disclosure, disclosure.width / 2, disclosure.height / 2, Qt.LeftButton)
        compare(panel.expanded, false)

        compare(disclosure.focusPolicy, Qt.StrongFocus)
        compare(disclosure.Accessible.focusable, true)
        if (testWindow.active) {
            disclosure.forceActiveFocus(Qt.TabFocusReason)
            tryCompare(disclosure, "activeFocus", true)
            verify(disclosure.visualFocus)

            keyClick(Qt.Key_Space)
            compare(panel.expanded, true)
            keyClick(Qt.Key_Return)
            compare(panel.expanded, false)
            keyClick(Qt.Key_Enter)
            compare(panel.expanded, true)
        }

        compare(disclosure.Accessible.checked, panel.expanded)
        verify(disclosure.Accessible.name.length > 0)
        verify(disclosure.Accessible.description.length > 0)
        var expandedBeforeAccessiblePress = panel.expanded
        disclosure.Accessible.pressAction()
        compare(panel.expanded, !expandedBeforeAccessiblePress)
    }

    function test_sidebarDoubleClickPreservesControlledState() {
        var harness = createTemporaryObject(sidebarDoubleClickHarnessComponent, testWindow.contentItem)
        verify(harness)
        var shell = harness.shell
        wait(0)
        var railButton = findRailButton(shell.sidebar)
        verify(railButton)

        mouseDoubleClickSequence(
            railButton,
            railButton.width / 2,
            railButton.height / 2,
            Qt.LeftButton
        )
        compare(harness.navigationCount, 2)
        compare(shell.leftPaneDisplayMode, Shell.AppSidebarPane.Hidden)
        compare(shell.activeNavigationKey, "")

        harness.activeNavigationKey = "menu"
        compare(shell.activeNavigationKey, "menu")
    }

    function test_popupGeometryBelowAndAbove() {
        var boundary = createTemporaryQmlObject(
            "import QtQuick 2.14; Item { width: 200; height: 140 }",
            testWindow.contentItem
        )
        var anchor = createTemporaryQmlObject(
            "import QtQuick 2.14; Item { width: 40; height: 20 }",
            boundary
        )
        verify(boundary)
        verify(anchor)

        anchor.x = 40
        anchor.y = 10
        var below = PopupGeometry.resolve(anchor, boundary, 100, 40, 6, 6)
        compare(below.openAbove, false)
        compare(below.y, 26)
        compare(below.contentHeight, 40)

        anchor.y = 115
        var above = PopupGeometry.resolve(anchor, boundary, 100, 60, 6, 6)
        compare(above.openAbove, true)
        compare(above.y, -78)
        compare(above.contentHeight, 60)
    }

    function test_popupGeometryHorizontalClamping() {
        var boundary = createTemporaryQmlObject(
            "import QtQuick 2.14; Item { width: 200; height: 140 }",
            testWindow.contentItem
        )
        var anchor = createTemporaryQmlObject(
            "import QtQuick 2.14; Item { width: 40; height: 20; y: 20 }",
            boundary
        )
        verify(boundary)
        verify(anchor)

        anchor.x = -20
        var left = PopupGeometry.resolve(anchor, boundary, 80, 40, 6, 6)
        compare(left.x, 20)

        anchor.x = 180
        var right = PopupGeometry.resolve(anchor, boundary, 80, 40, 6, 6)
        compare(right.x, -60)

        anchor.x = 50
        var oversized = PopupGeometry.resolve(anchor, boundary, 300, 40, 6, 6)
        compare(oversized.width, 200)
        compare(oversized.x, -50)
    }

    function test_popupGeometryTinyBoundary() {
        var boundary = createTemporaryQmlObject(
            "import QtQuick 2.14; Item { width: 1; height: 1 }",
            testWindow.contentItem
        )
        var anchor = createTemporaryQmlObject(
            "import QtQuick 2.14; Item { width: 1; height: 1 }",
            boundary
        )
        verify(boundary)
        verify(anchor)

        var result = PopupGeometry.resolve(anchor, boundary, 300, 300, 6, 6)
        compare(result.width, 1)
        compare(result.contentHeight, 0)
        verify(isFinite(result.x))
        verify(isFinite(result.y))
    }
}
