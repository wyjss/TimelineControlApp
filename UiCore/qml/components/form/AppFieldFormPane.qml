import QtQuick 2.14
import QtQuick.Layouts 1.14
import "../../foundation"
import "../base/internal" as Internal

Internal.AppPaneBase {
    id: root

    default property alias formContent: fieldForm.formContent

    property string title: ""
    property string subtitle: ""
    property string titleRole: compact ? "bodyL" : "sectionTitle"
    property string subtitleRole: "bodyS"
    property bool showSubtitle: !compact
    property bool surfaced: true
    property string paneSurfaceTone: "section"

    property var layoutMode: AppUiEnums.LayoutMode.Horizontal
    property int horizontalBreakpoint: 840
    property int labelWidth: 156
    property int fieldSpacing: densityValue("controlGap", 12)
    property int sectionSpacing: densityValue("paneSpacing", 16)
    property int contentPadding: 0
    property real maxContentWidth: -1
    property bool showDivider: false
    property bool showUnderline: false
    property string underlineScope: "field"
    property bool clipFormContent: false

    readonly property bool hasHeaderText: paneHeader.hasHeaderText
    readonly property bool hasHeaderActions: paneHeader.hasHeaderActions
    readonly property bool hasCustomHeader: paneHeader.hasCustomHeader
    readonly property string resolvedLayoutMode: fieldForm.resolvedLayoutMode
    readonly property real resolvedContentWidth: fieldForm.resolvedContentWidth

    property alias headerActions: paneHeader.headerActions
    property alias customHeaderContent: paneHeader.customHeaderContent
    property alias contentLayout: fieldForm.contentLayout
    property alias fieldFormItem: fieldForm

    surfaceTone: surfaced ? root.paneSurfaceTone : "ghost"
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

    AppFieldForm {
        id: fieldForm

        Layout.fillWidth: true
        theme: root.resolvedTheme
        layoutMode: root.layoutMode
        horizontalBreakpoint: root.horizontalBreakpoint
        labelWidth: root.labelWidth
        fieldSpacing: root.fieldSpacing
        sectionSpacing: root.sectionSpacing
        contentPadding: root.contentPadding
        maxContentWidth: root.maxContentWidth
        showDivider: root.showDivider
        showUnderline: root.showUnderline
        underlineScope: root.underlineScope
        clipContent: root.clipFormContent
    }
}
