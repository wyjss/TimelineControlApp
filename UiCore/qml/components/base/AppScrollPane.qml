import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "internal/AppThemeUtils.js" as ThemeUtils

Control {
    id: root

    default property alias scrollContent: contentColumn.data

    property QtObject theme
    property int contentSpacing: 0
    property bool fillContentWidth: true
    property bool clipContent: true
    property bool allowHorizontalScroll: false
    property bool showEdgeHints: true
    property int edgeHintExtent: 22
    property real edgeHintOpacity: 1.0
    property color edgeHintColor: colorWithAlpha(colorValue("highlightText", Qt.rgba(0.49, 0.71, 1, 1)), 0.16)

    readonly property real availableContentWidth: contentColumn.width
    readonly property real availableContentHeight: contentColumn.implicitHeight
    readonly property var flickableItem: flickable
    readonly property bool canScrollUp: flickable.contentY > 0.5
    readonly property bool canScrollDown: flickable.contentY + flickable.height < flickable.contentHeight - 0.5
    readonly property bool edgeHintsActive: showEdgeHints
        && clipContent
        && flickable.contentHeight > flickable.height + 1

    property alias contentLayout: contentColumn
    property alias verticalScrollBar: verticalBar
    property alias horizontalScrollBar: horizontalBar

    padding: 0
    background: null

    function colorValue(name, fallback) {
        return ThemeUtils.colorValue(theme, name, fallback)
    }

    function colorWithAlpha(colorSpec, alpha) {
        return Qt.rgba(colorSpec.r, colorSpec.g, colorSpec.b, alpha)
    }

    // Own the flickable and scrollbars directly so the shared primitive
    // does not depend on ScrollView's private child structure.
    contentItem: Item {
        id: viewport

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

                parent: root
                x: root.mirrored ? 0 : root.width - width
                y: 0
                height: root.height
                active: flickable.movingVertically || flickable.flickingVertically || horizontalBar.active
                policy: ScrollBar.AsNeeded
            }

            ScrollBar.horizontal: ScrollBar {
                id: horizontalBar

                parent: root
                x: 0
                y: root.height - height
                width: root.width
                active: root.allowHorizontalScroll
                    && (flickable.movingHorizontally || flickable.flickingHorizontally || verticalBar.active)
                policy: root.allowHorizontalScroll ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            Item {
                id: contentHost

                width: root.fillContentWidth
                    ? flickable.width
                    : Math.max(flickable.width, contentColumn.implicitWidth)
                height: contentColumn.implicitHeight

                ColumnLayout {
                    id: contentColumn

                    width: root.fillContentWidth ? parent.width : implicitWidth
                    spacing: root.contentSpacing
                }
            }
        }

        Rectangle {
            id: topEdgeHint

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.min(root.edgeHintExtent, parent.height * 0.5)
            enabled: false
            visible: opacity > 0.001
            opacity: root.edgeHintsActive && root.canScrollUp ? root.edgeHintOpacity : 0
            z: 2

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: root.edgeHintColor
                }

                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            id: bottomEdgeHint

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.min(root.edgeHintExtent, parent.height * 0.5)
            enabled: false
            visible: opacity > 0.001
            opacity: root.edgeHintsActive && root.canScrollDown ? root.edgeHintOpacity : 0
            z: 2

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: "transparent"
                }

                GradientStop {
                    position: 1.0
                    color: root.edgeHintColor
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
