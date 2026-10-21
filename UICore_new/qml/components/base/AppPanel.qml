import QtQuick 2.14
import UICore.Style 1.0
import "internal" as Internal

Internal.AppPaneBase {
    id: root

    property string title: ""
    property string subtitle: ""
    property int titleRole: UiStyle.TypographyRole.SectionTitle
    property int subtitleRole: UiStyle.TypographyRole.BodyS

    property bool clearFocusOnBackgroundTap: false

    readonly property bool hasHeaderText: paneHeader.hasHeaderText
    readonly property bool hasHeaderActions: paneHeader.hasHeaderActions

    property alias headerActions: paneHeader.headerActions

    shapeRole: UiStyle.ShapeRole.Panel
    clearFocusOnTap: clearFocusOnBackgroundTap
    showHeader: paneHeader.hasHeader

    headerContent: [
        Internal.AppPaneHeader {
            id: paneHeader

            width: root.availableContentWidth
            control: root
            title: root.title
            subtitle: root.subtitle
            titleRole: root.titleRole
            subtitleRole: root.subtitleRole
            spacing: root.spacing
            headerSpacing: root.headerSpacing
            actionSpacing: root.densityValue("controlGap")
            collapsible: root.collapsible
            expanded: root.expanded
            onToggleRequested: {
                root.expanded = nextExpanded
                root.toggled(root.expanded)
            }
        }
    ]
}
