import QtQuick 2.14
import "../../foundation"
import "internal" as Internal

Internal.AppPaneBase {
    id: root

    property string title: ""
    property string subtitle: ""
    property string titleRole: "sectionTitle"
    property string subtitleRole: "bodyS"

    property bool clearFocusOnBackgroundTap: false

    readonly property bool hasHeaderText: paneHeader.hasHeaderText
    readonly property bool hasHeaderActions: paneHeader.hasHeaderActions

    property alias headerActions: paneHeader.headerActions

    shapeRole: AppUiEnums.ShapeRole.Panel
    clearFocusOnTap: clearFocusOnBackgroundTap
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
