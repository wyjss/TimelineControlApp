import QtQuick 2.14
import UICore.Style 1.0
import "internal" as Internal

Internal.AppPaneBase {
    id: root

    property string title: ""
    property string subtitle: ""
    property int titleRole: compact
        ? UiStyle.TypographyRole.BodyL
        : UiStyle.TypographyRole.SectionTitle
    property int subtitleRole: UiStyle.TypographyRole.BodyS
    property bool showSubtitle: !compact

    property bool surfaced: false

    readonly property bool hasHeaderText: paneHeader.hasHeaderText
    readonly property bool hasHeaderActions: paneHeader.hasHeaderActions

    property alias headerActions: paneHeader.headerActions

    surfaceTone: surfaced ? UiStyle.SurfaceTone.Section : UiStyle.SurfaceTone.Ghost
    shapeRole: surfaced ? UiStyle.ShapeRole.Section : UiStyle.ShapeRole.None
    strokeWidth: 0
    bodyFillHeight: false
    cornerRadius: surfaced ? shapeValue("sectionRadius") : -1

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
            showSubtitle: root.showSubtitle
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
