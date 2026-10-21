import QtQuick 2.14
import QtQuick.Controls 1.4 as Controls1
import QtQuick.Controls.Styles 1.4 as Styles1
import QtQuick.Layouts 1.14
import QtQuick.Window 2.14
import UICore.Style 1.0
import "internal" as Internal
import "internal/AppThemeUtils.js" as ThemeUtils

Item {
    id: root

    property alias model: treeView.model
    property alias rootIndex: treeView.rootIndex
    property alias selection: treeView.selection
    property alias selectionMode: treeView.selectionMode
    property bool activateItemOnSingleClick: true
    property bool expandsOnDoubleClick: false
    property string textRole: "display"
    property string iconRole: "iconName"
    property Component contentDelegate: null
    property bool animated: true
    property int maximumVisibleRows: 8
    property int rowHeight: resolvedTheme ? densityValue("controlHeightSm") : 0
    property int indentWidth: resolvedTheme ? densityValue("controlPaddingXSm") * 2 : 0
    property int scrollBarExtent: resolvedTheme ? densityValue("controlGap") : 0
    readonly property var currentIndex: treeView.currentIndex
    readonly property real contentY: treeView.__listView.contentY - treeView.__listView.originY
    readonly property int visibleRowCount: treeView.__listView.count
    property int _modelRevision: 0

    readonly property QtObject owningWindow: Window.window
    readonly property QtObject currentWindowTheme: owningWindow && owningWindow.appTheme
        ? owningWindow.appTheme
        : null
    property QtObject _retainedTheme: currentWindowTheme
    readonly property QtObject resolvedTheme: _retainedTheme

    signal activated(var index)
    signal clicked(var index)
    signal doubleClicked(var index)
    signal expanded(var index)
    signal collapsed(var index)

    implicitHeight: rowHeight * Math.max(1, maximumVisibleRows)

    onCurrentWindowThemeChanged: {
        if (currentWindowTheme)
            _retainedTheme = currentWindowTheme
    }
    onOwningWindowChanged: Qt.callLater(function() {
        if (root.owningWindow && !root.currentWindowTheme)
            console.error("UICore AppTreeList requires appTheme on its window")
    })

    function densityValue(name) {
        return ThemeUtils.densityValue(resolvedTheme, name)
    }

    function metricValue(name) {
        return ThemeUtils.metricValue(resolvedTheme, name)
    }

    function colorValue(name) {
        return ThemeUtils.colorValue(resolvedTheme, name)
    }

    function expand(index) {
        treeView.expand(index)
    }

    function collapse(index) {
        treeView.collapse(index)
    }

    function isExpanded(index) {
        return treeView.isExpanded(index)
    }

    function scrollToContentY(y) {
        if (!isFinite(y))
            return

        var view = treeView.__listView
        view.cancelFlick()
        view.forceLayout()
        view.contentY = view.originY + Math.max(0, Math.min(y, view.contentHeight - view.height))
    }

    function _isRowSelected(row) {
        // flags() 没有属性通知，读取版本以响应模型数据变化。
        var revision = _modelRevision
        if (row < 0 || !model || selectionMode === Controls1.SelectionMode.NoSelection)
            return false

        var index = treeView.__model.mapRowToModelIndex(row)
        var flags = model.flags(index)
        if (!(flags & Qt.ItemIsSelectable) || !(flags & Qt.ItemIsEnabled))
            return false

        return selection
            ? selection.hasSelection && selection.isSelected(index)
            : currentIndex === index
    }

    function _syncCurrentIndex() {
        if (!selection || selection.model !== model || !treeView.__model)
            return

        var index = selection.currentIndex
        if (treeView.__model.mapRowToModelIndex(treeView.__currentRow) === index)
            return

        var row = -1
        if (index.valid) {
            for (var i = 0; i < treeView.__model.rowCount(); ++i) {
                if (treeView.__model.mapRowToModelIndex(i) === index) {
                    row = i
                    break
                }
            }
        }
        treeView.__currentRow = row
        // 使用索引值副本，避免选择起点跟随 selection.currentIndex 改变。
        treeView.__mouseArea.clickedIndex = row >= 0
            ? treeView.__model.mapRowToModelIndex(row) : undefined
    }

    onSelectionChanged: Qt.callLater(_syncCurrentIndex)
    onModelChanged: Qt.callLater(_syncCurrentIndex)
    Component.onCompleted: Qt.callLater(_syncCurrentIndex)

    Connections {
        target: root.selection

        function onCurrentChanged() { root._syncCurrentIndex() }
    }

    Connections {
        target: treeView.__model

        function onDataChanged() { ++root._modelRevision }
        function onRowsInserted() { ++root._modelRevision; Qt.callLater(root._syncCurrentIndex) }
        function onRowsRemoved() { ++root._modelRevision; Qt.callLater(root._syncCurrentIndex) }
        function onModelReset() { ++root._modelRevision; Qt.callLater(root._syncCurrentIndex) }
        function onLayoutChanged() { ++root._modelRevision; Qt.callLater(root._syncCurrentIndex) }
    }

    Component {
        id: defaultContentDelegate

        RowLayout {
            property QtObject treeItem

            spacing: root.densityValue("controlGap")

            AppIcon {
                Layout.preferredWidth: root.metricValue("iconSizeMd")
                Layout.preferredHeight: root.metricValue("iconSizeMd")
                name: treeItem ? treeItem.iconName : ""
                size: root.metricValue("iconSizeMd")
                color: treeItem && treeItem.selected
                    ? root.colorValue("highlightText")
                    : root.colorValue("subtleText")
                animateColor: root.animated
            }

            AppText {
                Layout.fillWidth: true
                text: treeItem ? String(treeItem.value) : ""
                styleRole: UiStyle.TypographyRole.BodyM
                textTone: treeItem && treeItem.selected
                    ? UiStyle.TextTone.Accent
                    : UiStyle.TextTone.Primary
                elide: Text.ElideRight
            }
        }
    }

    Controls1.TreeView {
        id: treeView

        anchors.fill: parent
        anchors.leftMargin: root.densityValue("controlGap") / 2
        anchors.rightMargin: root.densityValue("controlGap") / 2

        onActivated: root.activated(index)
        onClicked: root.clicked(index)
        onDoubleClicked: {
            var mouseArea = treeView.__mouseArea
            if (root.expandsOnDoubleClick && root.model && root.model.hasChildren(index)
                    && !mouseArea.branchDecorationContains(mouseArea.mouseX, mouseArea.mouseY)) {
                if (treeView.isExpanded(index))
                    treeView.collapse(index)
                else
                    treeView.expand(index)
            }
            root.doubleClicked(index)
        }
        onExpanded: root.expanded(index)
        onCollapsed: root.collapsed(index)

        headerVisible: false
        backgroundVisible: false
        frameVisible: false
        alternatingRowColors: false
        horizontalScrollBarPolicy: Qt.ScrollBarAlwaysOff
        verticalScrollBarPolicy: Qt.ScrollBarAsNeeded

        Controls1.TableViewColumn {
            role: root.textRole
            width: treeView.viewport ? treeView.viewport.width : treeView.width
            resizable: false
        }

        style: Styles1.TreeViewStyle {
        indentation: root.indentWidth
        activateItemOnSingleClick: root.activateItemOnSingleClick
        textColor: root.colorValue("text")
        highlightedTextColor: root.colorValue("highlightText")
        backgroundColor: root.colorValue("backgroundSurface")
        alternateBackgroundColor: root.colorValue("backgroundSurface")
        minimumHandleLength: root.densityValue("controlHeightLg")
        handleOverlap: 0
        transientScrollBars: false
        padding.left: 0
        padding.top: 0
        padding.right: 0
        padding.bottom: 0

        frame: Item {}
        corner: Item {}

        rowDelegate: Item {
            id: rowBackground

            readonly property bool selected: root._isRowSelected(styleData.row)
            height: root.rowHeight

            HoverHandler {
                id: rowHover
            }

            Internal.AppSurfaceChrome {
                width: treeView.viewport.width
                height: parent.height
                themeContext: root.resolvedTheme
                animated: root.animated
                surfaceTone: UiStyle.SurfaceTone.Ghost
                shapeRole: UiStyle.ShapeRole.Control
                active: rowBackground.selected
                hoveredState: root.enabled && rowHover.hovered
                pressedState: root.enabled && styleData.pressed
                strokeWidth: styleData.hasActiveFocus
                    ? root.densityValue("dividerThickness") * 2
                    : 0
                fillOverride: rowBackground.selected
                    ? root.colorValue("highlightSoft")
                    : undefined
                borderOverride: styleData.hasActiveFocus
                    ? root.colorValue("highlightText")
                    : undefined
            }
        }

        itemDelegate: Item {
            height: root.rowHeight

            QtObject {
                id: itemContext

                readonly property var index: styleData.row >= 0 && treeView.__model
                    ? treeView.__model.mapRowToModelIndex(styleData.row)
                    : null
                readonly property var roles: model
                readonly property var value: styleData.value !== undefined
                    ? styleData.value
                    : ""
                readonly property string iconName: model && root.iconRole.length > 0
                    && model[root.iconRole] !== undefined
                    ? String(model[root.iconRole])
                    : ""
                readonly property int row: styleData.row
                readonly property int depth: styleData.depth
                readonly property bool selected: root._isRowSelected(styleData.row)
                readonly property bool pressed: styleData.pressed
                readonly property bool hasActiveFocus: styleData.hasActiveFocus
                readonly property bool hasChildren: styleData.hasChildren
                readonly property bool expanded: styleData.isExpanded
            }

            Canvas {
                readonly property int connectorRow: styleData.row
                readonly property int connectorDepth: styleData.depth
                readonly property bool connectorHasSibling: styleData.hasSibling
                readonly property bool connectorHasChildren: styleData.hasChildren
                readonly property bool connectorExpanded: styleData.isExpanded
                readonly property var connectorModel: root.model
                readonly property var connectorViewModel: treeView.__model
                readonly property int connectorRevision: root._modelRevision
                readonly property real lineWidth: root.densityValue("dividerThickness")
                property color lineColor: root.colorValue("border")

                x: -root.indentWidth * (styleData.depth + 1)
                width: root.indentWidth * (styleData.depth + 1)
                    + root.densityValue("controlGap")
                height: parent.height
                contextType: "2d"

                onConnectorRowChanged: requestPaint()
                onConnectorDepthChanged: requestPaint()
                onConnectorHasSiblingChanged: requestPaint()
                onConnectorHasChildrenChanged: requestPaint()
                onConnectorExpandedChanged: requestPaint()
                onConnectorModelChanged: requestPaint()
                onConnectorViewModelChanged: requestPaint()
                onConnectorRevisionChanged: requestPaint()
                onLineWidthChanged: requestPaint()
                onLineColorChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    var centerY = Math.round(height / 2) + lineWidth / 2
                    var indent = root.indentWidth
                    var currentX = Math.round(connectorDepth * indent + indent / 2)
                        + lineWidth / 2
                    var gap = root.densityValue("controlGap") / 2

                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = lineColor
                    ctx.lineWidth = lineWidth
                    ctx.beginPath()

                    // 子节点接到父级箭头列，根节点之间不画连线。
                    if (connectorDepth > 0) {
                        var parentX = currentX - indent
                        ctx.moveTo(parentX, 0)
                        ctx.lineTo(parentX, connectorHasSibling ? height : centerY)
                        ctx.moveTo(parentX, centerY)
                        ctx.lineTo(connectorHasChildren
                            ? currentX - root.metricValue("iconSizeSm") / 2 - gap
                            : width - gap, centerY)
                    }
                    if (connectorHasChildren && connectorExpanded) {
                        ctx.moveTo(currentX, Math.min(height,
                            centerY + root.metricValue("iconSizeSm") / 2 + gap))
                        ctx.lineTo(currentX, height)
                    }

                    if (connectorDepth > 0 && connectorRow >= 0
                            && connectorModel && connectorViewModel) {
                        var ancestor = connectorViewModel.mapRowToModelIndex(connectorRow)
                        for (var level = connectorDepth - 1;
                                ancestor.valid && level > 0; --level) {
                            ancestor = connectorModel.parent(ancestor)
                            if (!ancestor.valid)
                                break

                            var parentIndex = connectorModel.parent(ancestor)
                            if (ancestor.row + 1 < connectorModel.rowCount(parentIndex)) {
                                var ancestorX = currentX - (connectorDepth - level + 1) * indent
                                ctx.moveTo(ancestorX, 0)
                                ctx.lineTo(ancestorX, height)
                            }
                        }
                    }

                    ctx.stroke()
                }
            }

            Loader {
                id: contentLoader

                anchors.fill: parent
                anchors.leftMargin: root.densityValue("controlGap")
                anchors.rightMargin: root.densityValue("controlPaddingXSm")
                sourceComponent: root.contentDelegate
                    ? root.contentDelegate
                    : defaultContentDelegate
                onLoaded: item.treeItem = itemContext
            }
        }

        branchDelegate: Item {
            id: branchDelegate

            width: root.indentWidth
            height: root.rowHeight

            Canvas {
                id: branchChevron

                anchors.centerIn: parent
                width: root.metricValue("iconSizeSm")
                height: width
                rotation: styleData.isExpanded ? 90 : 0
                contextType: "2d"
                property color lineColor: root._isRowSelected(styleData.row)
                    ? root.colorValue("highlightText")
                    : root.colorValue("subtleText")

                onLineColorChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")

                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = lineColor
                    ctx.lineWidth = root.densityValue("dividerThickness") * 1.5
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(width * 0.25, height * 0.2)
                    ctx.lineTo(width * 0.65, height * 0.5)
                    ctx.lineTo(width * 0.25, height * 0.8)
                    ctx.stroke()
                }

                Behavior on rotation {
                    enabled: root.animated

                    NumberAnimation {
                        duration: root.resolvedTheme.motion.durationFast
                        easing.type: root.resolvedTheme.motion.easingStandard
                    }
                }
            }
        }

        scrollBarBackground: Item {
            implicitWidth: styleData.horizontal ? 0 : root.scrollBarExtent
            implicitHeight: styleData.horizontal ? 0 : root.scrollBarExtent
        }

        handle: Item {
            implicitWidth: styleData.horizontal ? 0 : root.scrollBarExtent
            implicitHeight: styleData.horizontal ? 0 : root.scrollBarExtent

            Rectangle {
                anchors.fill: parent
                anchors.margins: root.densityValue("dividerThickness")
                radius: width / 2
                color: styleData.pressed || styleData.hovered
                    ? root.colorValue("highlightText")
                    : root.colorValue("controlBorder")

                Behavior on color {
                    enabled: root.animated

                    ColorAnimation {
                        duration: root.resolvedTheme.motion.durationFast
                        easing.type: root.resolvedTheme.motion.easingStandard
                    }
                }
            }
        }

        incrementControl: Item {
            implicitWidth: 0
            implicitHeight: 0
        }

        decrementControl: Item {
            implicitWidth: 0
            implicitHeight: 0
        }
    }
}
}
