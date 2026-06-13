import QtQuick 2.14
import QtQuick.Layouts 1.14
import ".." as Base

Base.AppSurface {
    id: root

    default property alias bodyContent: bodyLayout.data

    property bool compact: false
    property int contentSpacing: densityValue("paneContentSpacing", 10)
    property int headerSpacing: densityValue("paneHeaderSpacing", 4)
    property int dividerThickness: densityValue("dividerThickness", 1)

    property bool bodyFillHeight: true
    property bool collapsible: false
    property bool expanded: true

    property bool showHeader: headerHost.children.length > 0
    property bool showFooter: footerLayout.children.length > 0
    property bool showHeaderDivider: false
    property bool showFooterDivider: false

    readonly property real targetBodyReveal: root.expanded ? 1 : 0
    property real animatedBodyReveal: targetBodyReveal
    readonly property bool bodyFillActive: root.bodyFillHeight
        && (root.expanded || bodyRevealAnimation.running)
    readonly property bool bodyVisible: root.animatedBodyReveal > 0.001
        || bodyRevealAnimation.running
    readonly property real naturalBodyHeight: bodyLayout.implicitHeight
    readonly property real collapsedBodyHeight: naturalBodyHeight * root.animatedBodyReveal

    property alias headerContent: headerHost.data
    property alias footerContent: footerLayout.data
    property alias bodyItem: bodyLayout

    signal toggled(bool expanded)

    padding: compact
        ? densityValue("panePaddingCompact", 14)
        : densityValue("panePadding", 18)
    spacing: densityValue("paneSpacing", 12)

    onTargetBodyRevealChanged: animatedBodyReveal = targetBodyReveal

    Behavior on animatedBodyReveal {
        NumberAnimation {
            id: bodyRevealAnimation
            duration: root.animated ? root.transitionDuration : 0
            easing.type: root.transitionEasing
        }
    }

    contentItem: ColumnLayout {
        id: paneColumn

        spacing: root.spacing

        Item {
            Layout.fillWidth: true
            visible: root.showHeader
            implicitHeight: root.showHeader ? headerHost.implicitHeight : 0

            Item {
                id: headerHost
                width: parent ? parent.width : 0
                implicitHeight: childrenRect.height
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.dividerThickness
            visible: root.showHeader && root.showHeaderDivider
            color: root.colorValue("border", "#334155")
            opacity: 0.88
        }

        Item {
            id: bodyHost

            Layout.fillWidth: true
            Layout.fillHeight: root.bodyFillActive
            Layout.minimumHeight: 0
            Layout.preferredHeight: root.bodyFillActive ? -1 : root.collapsedBodyHeight
            visible: root.bodyVisible
            implicitHeight: root.collapsedBodyHeight

            Item {
                id: bodyClip

                width: parent ? parent.width : 0
                height: root.bodyFillActive && parent
                    ? parent.height * root.animatedBodyReveal
                    : root.collapsedBodyHeight
                clip: root.clipContent || root.animatedBodyReveal < 0.999

                ColumnLayout {
                    id: bodyLayout

                    anchors.left: parent ? parent.left : undefined
                    anchors.right: parent ? parent.right : undefined
                    anchors.top: parent ? parent.top : undefined
                    anchors.bottom: root.bodyFillActive && parent ? parent.bottom : undefined
                    opacity: 0.72 + 0.28 * root.animatedBodyReveal
                    y: (1 - root.animatedBodyReveal) * -6
                    spacing: root.contentSpacing
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.dividerThickness
            visible: root.showFooter && root.showFooterDivider
            color: root.colorValue("border", "#334155")
            opacity: 0.88
        }

        ColumnLayout {
            id: footerLayout

            Layout.fillWidth: true
            visible: root.showFooter
            spacing: root.contentSpacing
        }
    }
}
