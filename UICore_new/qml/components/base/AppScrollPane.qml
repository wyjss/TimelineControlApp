import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtQuick.Window 2.14
import "internal/AppThemeUtils.js" as ThemeUtils

Control {
    id: root

    default property alias scrollContent: contentColumn.data

    property int contentSpacing: 0
    property int contentPadding: 0
    property int contentRightPadding: contentPadding
    property Item verticalScrollBarParent: root
    property bool fillContentWidth: true
    property bool clipContent: true
    property bool allowHorizontalScroll: false
    property bool showEdgeHints: false
    property int edgeHintExtent: ThemeUtils.densityValue(resolvedTheme, "scrollEdgeHintExtent")
    property real edgeHintOpacity: 1.0
    property color edgeHintColor: colorWithAlpha(colorValue("highlightText"), 0.16)

    readonly property QtObject applicationWindowTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : null
    readonly property QtObject windowTheme: Window.window && Window.window.appTheme
        ? Window.window.appTheme
        : null
    readonly property QtObject currentWindowTheme: applicationWindowTheme
        ? applicationWindowTheme
        : windowTheme
    property QtObject _retainedTheme: currentWindowTheme
    readonly property QtObject resolvedTheme: _retainedTheme
    readonly property real availableContentWidth: contentColumn.width
    readonly property real availableContentHeight: contentColumn.implicitHeight
    readonly property var flickableItem: flickable
    readonly property bool canScrollUp: !flickable.atYBeginning
    readonly property bool canScrollDown: !flickable.atYEnd
    readonly property bool edgeHintsActive: showEdgeHints
        && clipContent
        && flickable.contentHeight > flickable.height + 1

    property alias contentLayout: contentColumn
    property alias verticalScrollBar: verticalBar
    property alias horizontalScrollBar: horizontalBar

    onCurrentWindowThemeChanged: {
        if (currentWindowTheme)
            _retainedTheme = currentWindowTheme
    }

    padding: 0
    background: null

    function colorValue(name) {
        return ThemeUtils.colorValue(resolvedTheme, name)
    }

    function colorWithAlpha(colorSpec, alpha) {
        return Qt.rgba(colorSpec.r, colorSpec.g, colorSpec.b, alpha)
    }

    // Own the flickable and scrollbars directly so the shared primitive
    // does not depend on ScrollView's private child structure.
    contentItem: Item {
        id: viewport

        HoverHandler {
            id: viewportHover
        }

        Flickable {
            id: flickable

            anchors.fill: parent
            boundsBehavior: Flickable.StopAtBounds
            clip: root.clipContent
            flickableDirection: root.allowHorizontalScroll
                ? Flickable.AutoFlickDirection
                : Flickable.VerticalFlick
            contentWidth: contentHost.width
            contentHeight: contentHost.height
            interactive: contentHeight > height || (root.allowHorizontalScroll && contentWidth > width)

            ScrollBar.vertical: ScrollBar {
                id: verticalBar

                readonly property point viewportOrigin: {
                    var target = root.verticalScrollBarParent ? root.verticalScrollBarParent : root
                    // Keep coordinate mapping reactive to layout changes between the viewport and overlay.
                    var item = root
                    var positionRevision = 0
                    while (item && item !== target) {
                        positionRevision += item.x + item.y
                        item = item.parent
                    }

                    return root.mapToItem(target, positionRevision - positionRevision, 0)
                }

                parent: root.verticalScrollBarParent ? root.verticalScrollBarParent : root
                x: root.mirrored ? 0 : verticalBar.parent.width - width
                y: viewportOrigin.y
                height: root.height
                z: 2
                hoverEnabled: true
                active: (root.canScrollUp || root.canScrollDown)
                    && (flickable.movingVertically || flickable.flickingVertically
                        || viewportHover.hovered || verticalBar.hovered)
                policy: ScrollBar.AsNeeded
            }

            ScrollBar.horizontal: ScrollBar {
                id: horizontalBar

                parent: root
                x: 0
                y: root.height - height
                width: root.width
                active: root.allowHorizontalScroll
                    && flickable.contentWidth > flickable.width + 1
                    && (flickable.movingHorizontally || flickable.flickingHorizontally || viewportHover.hovered)
                policy: root.allowHorizontalScroll ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            Item {
                id: contentHost

                width: root.fillContentWidth
                    ? flickable.width
                    : Math.max(flickable.width,
                               contentColumn.implicitWidth + root.contentPadding + root.contentRightPadding)
                height: contentColumn.implicitHeight + root.contentPadding * 2

                ColumnLayout {
                    id: contentColumn

                    x: root.contentPadding
                    y: root.contentPadding
                    width: root.fillContentWidth
                        ? Math.max(0, parent.width - root.contentPadding - root.contentRightPadding)
                        : implicitWidth
                    spacing: root.contentSpacing
                }
            }
        }

        Loader {
            anchors.fill: parent
            active: root.showEdgeHints
            z: 2

            sourceComponent: AppScrollEdgeHints {
                target: flickable
                active: root.edgeHintsActive
                hovered: viewportHover.hovered
                extent: root.edgeHintExtent
                hintOpacity: root.edgeHintOpacity
                hintColor: root.edgeHintColor
            }
        }
    }
}
