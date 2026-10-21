import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Controls 1.4 as Controls1
import QtQml.Models 2.14
import QtTest 1.2
import UICore.Tests 1.0
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/theme" as Theme

TestCase {
    id: testCase

    name: "TreeSelectionContracts"
    when: windowShown && testWindow.visible

    ApplicationWindow {
        id: testWindow

        width: 640
        height: 480
        visible: true
        property QtObject appTheme: Theme.AppTheme {}
    }

    TreeTestModel { id: testModel }

    SignalSpy { id: scrollSpy; signalName: "contentYChanged" }
    SignalSpy { id: rowCountSpy; signalName: "visibleRowCountChanged" }

    Component {
        id: treeComponent

        Base.AppTreeList {
            id: tree

            width: 480
            height: 300
            rowHeight: 32
            model: testModel
            selection: ItemSelectionModel { model: testModel }
            property var observedRows: ({})
            property int activationCount: 0
            property var activatedIndex: null
            property int doubleClickCount: 0
            property var doubleClickedIndex: null
            property int expansionCount: 0
            property int collapseCount: 0
            onActivated: {
                ++activationCount
                activatedIndex = index
            }
            onDoubleClicked: {
                ++doubleClickCount
                doubleClickedIndex = index
            }
            onExpanded: ++expansionCount
            onCollapsed: ++collapseCount

            contentDelegate: Component {
                Item {
                    id: rowContent

                    property QtObject treeItem
                    readonly property int visualRow: treeItem ? treeItem.row : -1
                    readonly property bool selected: treeItem ? treeItem.selected : false
                    onVisualRowChanged: {
                        if (visualRow >= 0)
                            tree.observedRows[visualRow] = rowContent
                    }
                }
            }
        }
    }

    function init() {
        testModel.resetItems()
    }

    function createTree(mode) {
        var tree = createTemporaryObject(treeComponent, testWindow.contentItem, {
            selectionMode: mode
        })
        verify(tree)
        testWindow.requestActivate()
        tryCompare(testWindow, "active", true)
        tryVerify(function() { return tree.observedRows[4] !== undefined })
        return tree
    }

    function test_singleSelection() {
        var tree = createTree(Controls1.SelectionMode.SingleSelection)
        mouseClick(tree, 180, 16)
        compare(tree.selection.selectedIndexes.length, 1)
        compare(tree.selection.selectedIndexes[0].row, 0)
        mouseClick(tree, 180, 112)
        compare(tree.selection.selectedIndexes.length, 1)
        compare(tree.selection.selectedIndexes[0].row, 3)
        compare(tree.observedRows[0].selected, false)
        compare(tree.observedRows[3].selected, true)
    }

    function test_visibleRowCount() {
        var tree = createTree(Controls1.SelectionMode.SingleSelection)
        rowCountSpy.target = tree
        rowCountSpy.clear()
        compare(tree.visibleRowCount, 5)
        var parentIndex = testModel.index(4, 0)
        tree.expand(parentIndex)
        tryCompare(tree, "visibleRowCount", 6)
        verify(rowCountSpy.count > 0)
        tree.height = 64
        compare(tree.visibleRowCount, 6)
        tree.collapse(parentIndex)
        tryCompare(tree, "visibleRowCount", 5)
        testModel.insertItem(0)
        tryCompare(tree, "visibleRowCount", 6)
        testModel.removeItem(0)
        tryCompare(tree, "visibleRowCount", 5)
        tree.rootIndex = testModel.index(4, 0)
        tryCompare(tree, "visibleRowCount", 1)
        tree.rootIndex = testModel.index(0, 0)
        tryCompare(tree, "visibleRowCount", 0)
        tree.rootIndex = testModel.parent(testModel.index(0, 0))
        tryCompare(tree, "visibleRowCount", 5)
        testModel.removeItem(4)
        tryCompare(tree, "visibleRowCount", 4)
        testModel.resetItems()
        tryCompare(tree, "visibleRowCount", 5)
        tree.model = null
        tryCompare(tree, "visibleRowCount", 0)
        tree.model = testModel
        tryCompare(tree, "visibleRowCount", 5)
    }

    function test_scrollPosition() {
        var tree = createTree(Controls1.SelectionMode.SingleSelection)
        tree.height = 64
        verify(waitForRendering(tree))
        scrollSpy.target = tree
        scrollSpy.clear()
        tree.scrollToContentY(40)
        compare(tree.contentY, 40)
        verify(scrollSpy.count > 0)
        var savedY = tree.contentY
        scrollSpy.clear()
        mouseWheel(tree, 180, 32, 0, -120)
        tryVerify(function() { return tree.contentY > savedY })
        verify(scrollSpy.count > 0)
        compare(tree.visibleRowCount, 5)
        tree.scrollToContentY(savedY)
        compare(tree.contentY, savedY)
        verify(waitForRendering(tree))
        compare(tree.contentY, savedY)
    }

    function test_scrollBounds() {
        var tree = createTree(Controls1.SelectionMode.SingleSelection)
        tree.height = 64
        tree.scrollToContentY(10000)
        compare(tree.contentY, 96)
        tree.scrollToContentY(-10000)
        compare(tree.contentY, 0)
        tree.scrollToContentY(32)
        tree.scrollToContentY(NaN)
        tree.scrollToContentY(Infinity)
        tree.scrollToContentY(-Infinity)
        compare(tree.contentY, 32)
        var parentIndex = testModel.index(4, 0)
        tree.expand(parentIndex)
        tree.scrollToContentY(10000)
        compare(tree.contentY, 128)
        tree.collapse(parentIndex)
        tree.scrollToContentY(10000)
        compare(tree.contentY, 96)
        tree.height = 300
        tree.scrollToContentY(10000)
        compare(tree.contentY, 0)
        tree.model = null
        tree.scrollToContentY(10000)
        compare(tree.contentY, 0)
    }

    function test_scrollAfterRowsChanged() {
        var tree = createTree(Controls1.SelectionMode.SingleSelection)
        tree.height = 64
        for (var i = 0; i < 15; ++i)
            testModel.insertItem(0)
        tree.scrollToContentY(500)
        verify(waitForRendering(tree))
        testModel.removeItem(0)
        verify(waitForRendering(tree))
        tree.scrollToContentY(-10000)
        compare(tree.contentY, 0)
        tree.scrollToContentY(10000)
        compare(tree.contentY, 544)
        tree.scrollToContentY(120)
        verify(waitForRendering(tree))
        var savedY = tree.contentY
        var rowY = tree.observedRows[4].mapToItem(tree, 0, 0).y
        compare(rowY, 8)
        tree.visible = false
        var restoredTree = createTree(Controls1.SelectionMode.SingleSelection)
        restoredTree.height = 64
        restoredTree.scrollToContentY(savedY)
        compare(restoredTree.contentY, savedY)
        verify(waitForRendering(restoredTree))
        compare(restoredTree.observedRows[4].mapToItem(restoredTree, 0, 0).y, rowY)
    }

    function test_multiToggle() {
        var tree = createTree(Controls1.SelectionMode.MultiSelection)
        mouseClick(tree, 180, 16)
        mouseClick(tree, 180, 112)
        compare(tree.selection.selectedIndexes.length, 2)
        mouseClick(tree, 180, 16)
        compare(tree.selection.selectedIndexes.length, 1)
        compare(tree.selection.selectedIndexes[0].row, 3)
    }

    function test_doubleClickActivation() {
        var tree = createTree(Controls1.SelectionMode.SingleSelection)
        tree.activateItemOnSingleClick = false
        mouseClick(tree, 180, 16)
        compare(tree.activationCount, 0)
        compare(tree.doubleClickCount, 0)
        compare(tree.selection.selectedIndexes[0], testModel.index(0, 0))
        mouseDoubleClickSequence(tree, 180, 112, Qt.LeftButton)
        compare(tree.activationCount, 1)
        compare(tree.activatedIndex, testModel.index(3, 0))
        compare(tree.doubleClickCount, 1)
        compare(tree.doubleClickedIndex, testModel.index(3, 0))
        compare(tree.expansionCount, 0)
        keyClick(Qt.Key_Return)
        compare(tree.activationCount, 2)
        compare(tree.doubleClickCount, 1)
    }

    function test_doubleClickExpansion() {
        var tree = createTree(Controls1.SelectionMode.ExtendedSelection)
        tree.activateItemOnSingleClick = false
        var parentIndex = testModel.index(4, 0)
        mouseDoubleClickSequence(tree, 180, 144, Qt.LeftButton)
        compare(tree.isExpanded(parentIndex), false)
        compare(tree.doubleClickCount, 1)
        tree.expandsOnDoubleClick = true
        mouseDoubleClickSequence(tree, 180, 144, Qt.LeftButton)
        compare(tree.isExpanded(parentIndex), true)
        compare(tree.expansionCount, 1)
        compare(tree.doubleClickCount, 2)
        compare(tree.doubleClickedIndex, parentIndex)
        tryVerify(function() { return tree.observedRows[5] !== undefined })
        mouseDoubleClickSequence(tree, 180, 176, Qt.LeftButton)
        compare(tree.doubleClickedIndex, testModel.index(0, 0, parentIndex))
        compare(tree.expansionCount, 1)
        mouseDoubleClickSequence(tree, 180, 144, Qt.LeftButton)
        compare(tree.isExpanded(parentIndex), false)
        compare(tree.collapseCount, 1)
        compare(tree.doubleClickCount, 4)
    }

    function test_doubleClickArrow() {
        var tree = createTree(Controls1.SelectionMode.SingleSelection)
        tree.expandsOnDoubleClick = true
        mouseDoubleClickSequence(tree, tree.indentWidth / 2, 144, Qt.LeftButton)
        compare(tree.doubleClickCount, 1)
        compare(tree.expansionCount, 1)
        compare(tree.collapseCount, 0)
        compare(tree.isExpanded(testModel.index(4, 0)), true)
    }

    function test_extendedSelection() {
        var tree = createTree(Controls1.SelectionMode.ExtendedSelection)
        mouseClick(tree, 180, 16)
        mouseClick(tree, 180, 112, Qt.LeftButton, Qt.ControlModifier)
        compare(tree.selection.selectedIndexes.length, 2)
        mouseClick(tree, 180, 144)
        compare(tree.selection.selectedIndexes.length, 1)
        mouseClick(tree, 180, 16, Qt.LeftButton, Qt.ShiftModifier)
        compare(tree.selection.selectedIndexes.length, 3)
    }

    function test_unselectableAndDisabled_data() {
        return [
            { tag: "single", mode: Controls1.SelectionMode.SingleSelection },
            { tag: "multi", mode: Controls1.SelectionMode.MultiSelection },
            { tag: "extended", mode: Controls1.SelectionMode.ExtendedSelection }
        ]
    }

    function test_unselectableAndDisabled(data) {
        var tree = createTree(data.mode)
        mouseClick(tree, 180, 48)
        compare(tree.selection.selectedIndexes.length, 0)
        compare(tree.observedRows[1].selected, false)
        mouseClick(tree, 180, 80)
        compare(tree.selection.selectedIndexes.length, 0)
        compare(tree.observedRows[2].selected, false)
    }

    function test_flagsChange() {
        var tree = createTree(Controls1.SelectionMode.SingleSelection)
        mouseClick(tree, 180, 16)
        compare(tree.observedRows[0].selected, true)
        testModel.setItemFlags(0, Qt.ItemIsEnabled)
        compare(tree.selection.selectedIndexes.length, 0)
        compare(tree.observedRows[0].selected, false)
        testModel.setItemFlags(0, Qt.ItemIsSelectable | Qt.ItemIsEnabled)
        compare(tree.selection.selectedIndexes.length, 1)
        compare(tree.observedRows[0].selected, true)
        testModel.setItemFlags(0, Qt.ItemIsSelectable)
        compare(tree.observedRows[0].selected, false)
    }

    function test_externalCurrentControlsKeyboard() {
        var tree = createTree(Controls1.SelectionMode.SingleSelection)
        mouseClick(tree, 180, 16)
        tree.selection.setCurrentIndex(testModel.index(3, 0), ItemSelectionModel.ClearAndSelect)
        compare(tree.currentIndex, tree.selection.currentIndex)
        compare(tree.observedRows[3].selected, true)
        keyClick(Qt.Key_Return)
        compare(tree.activationCount, 2)
        compare(tree.activatedIndex, testModel.index(3, 0))
        keyClick(Qt.Key_Down)
        compare(tree.currentIndex, testModel.index(4, 0))
    }

    function test_externalCurrentSetsRangeAnchor() {
        var tree = createTree(Controls1.SelectionMode.ExtendedSelection)
        mouseClick(tree, 180, 16)
        tree.selection.setCurrentIndex(testModel.index(3, 0), ItemSelectionModel.ClearAndSelect)
        mouseClick(tree, 180, 144, Qt.LeftButton, Qt.ShiftModifier)
        compare(tree.selection.selectedIndexes.length, 2)
        compare(tree.selection.isSelected(testModel.index(0, 0)), false)
    }

    function test_hiddenCurrentAndRemoval() {
        var tree = createTree(Controls1.SelectionMode.SingleSelection)
        var parentIndex = testModel.index(4, 0)
        var childIndex = testModel.index(0, 0, parentIndex)
        tree.selection.setCurrentIndex(childIndex, ItemSelectionModel.ClearAndSelect)
        compare(tree.currentIndex.valid, false)
        tree.expand(parentIndex)
        tryCompare(tree, "currentIndex", childIndex)
        tree.collapse(parentIndex)
        tryVerify(function() { return !tree.currentIndex.valid })
        tree.expand(parentIndex)
        tryCompare(tree, "currentIndex", childIndex)
        testModel.removeItem(4)
        compare(tree.selection.selectedIndexes.length, 0)
        testModel.resetItems()
        tryVerify(function() { return !tree.currentIndex.valid })
    }

    function test_clearAndModeSwitch() {
        var tree = createTree(Controls1.SelectionMode.MultiSelection)
        mouseClick(tree, 180, 16)
        mouseClick(tree, 180, 112)
        compare(tree.selection.selectedIndexes.length, 2)
        tree.selectionMode = Controls1.SelectionMode.SingleSelection
        compare(tree.selection.selectedIndexes.length, 0)
        compare(tree.observedRows[3].selected, false)
        mouseClick(tree, 180, 112)
        tree.selection.clearSelection()
        compare(tree.observedRows[3].selected, false)
        tree.selection.clearCurrentIndex()
        compare(tree.currentIndex.valid, false)
    }

    function test_singleWithoutSelectionModel() {
        var tree = createTree(Controls1.SelectionMode.SingleSelection)
        tree.selection = null
        mouseClick(tree, 180, 16)
        compare(tree.currentIndex, testModel.index(0, 0))
        compare(tree.observedRows[0].selected, true)
        mouseClick(tree, 180, 48)
        compare(tree.observedRows[1].selected, false)
        tree.selectionMode = Controls1.SelectionMode.NoSelection
        mouseClick(tree, 180, 16)
        compare(tree.observedRows[0].selected, false)
    }
}
