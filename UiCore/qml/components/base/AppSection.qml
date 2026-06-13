import QtQuick 2.14
import "internal" as Internal

Internal.AppPaneBase {
    id: root

    property string title: ""
    property string subtitle: ""
    property string titleRole: compact ? "bodyL" : "sectionTitle"
    property string subtitleRole: "bodyS"
    property bool showSubtitle: !compact

    property bool surfaced: false

    readonly property bool hasHeaderText: paneHeader.hasHeaderText
    readonly property bool hasHeaderActions: paneHeader.hasHeaderActions

    property alias headerActions: paneHeader.headerActions

    surfaceTone: surfaced ? "section" : "ghost"
    shapeRole: surfaced ? "section" : "none"
    strokeWidth: surfaced ? 1 : 0
    bodyFillHeight: false
    cornerRadius: surfaced
        ? shapeValue("sectionRadius", 10)
        : -1

    showHeader: paneHeader.hasHeader

    headerContent: [
        Internal.AppPaneHeader {
            id: paneHeader

            width: root.availableContentWidth
            theme: root.resolvedTheme
            control: root
            title: root.title
            subtitle: root.subtitle
            titleRole: root.titleRole
            subtitleRole: root.subtitleRole
            showSubtitle: root.showSubtitle
            spacing: root.spacing
            headerSpacing: root.headerSpacing
            actionSpacing: root.densityValue("controlGap", 8)
            collapsible: root.collapsible
            expanded: root.expanded
            onToggleRequested: {
                root.expanded = nextExpanded
                root.toggled(root.expanded)
            }
        }
    ]
}
