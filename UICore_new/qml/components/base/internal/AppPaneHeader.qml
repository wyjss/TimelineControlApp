import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtQuick.Window 2.14
import UICore.Style 1.0
import ".." as Base

Item {
    id: root

    property var control: null

    property string title: ""
    property string subtitle: ""
    property int titleRole: UiStyle.TypographyRole.SectionTitle
    property int subtitleRole: UiStyle.TypographyRole.BodyS
    property bool showSubtitle: true

    property int spacing: 0
    property int headerSpacing: 0
    property int actionSpacing: 8

    readonly property bool hasHeaderText: title.length > 0
        || (showSubtitle && subtitle.length > 0)
    readonly property bool hasHeaderActions: headerActionHost.children.length > 0
    readonly property bool hasCustomHeader: customHeaderHost.children.length > 0
    readonly property bool hasHeader: hasCustomHeader || hasHeaderText || hasHeaderActions || collapsible

    property bool collapsible: false
    property bool expanded: true

    property alias headerActions: headerActionHost.data
    property alias customHeaderContent: customHeaderHost.data
    readonly property QtObject applicationWindowTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : null
    readonly property QtObject windowTheme: Window.window && Window.window.appTheme
        ? Window.window.appTheme
        : null
    readonly property QtObject resolvedTheme: applicationWindowTheme
        ? applicationWindowTheme
        : (windowTheme ? windowTheme : (root.control && root.control.resolvedTheme ? root.control.resolvedTheme : null))

    signal toggleRequested(bool nextExpanded)

    implicitHeight: hasHeader ? headerRow.implicitHeight : 0
    visible: hasHeader

    RowLayout {
        id: headerRow

        width: root.width
        spacing: root.spacing
        visible: root.hasHeader

        Item {
            Layout.fillWidth: true
            implicitHeight: Math.max(defaultHeaderColumn.implicitHeight, customHeaderHost.implicitHeight)
            visible: root.hasCustomHeader || root.hasHeaderText

            ColumnLayout {
                id: defaultHeaderColumn

                width: parent ? parent.width : implicitWidth
                spacing: root.headerSpacing
                visible: !root.hasCustomHeader && root.hasHeaderText

                Base.AppText {
                    Layout.fillWidth: true
                    visible: root.title.length > 0
                    text: root.title
                    styleRole: root.titleRole
                    wrapMode: Text.WordWrap
                }

                Base.AppText {
                    Layout.fillWidth: true
                    visible: root.showSubtitle && root.subtitle.length > 0
                    text: root.subtitle
                    styleRole: root.subtitleRole
                    textTone: UiStyle.TextTone.Secondary
                    wrapMode: Text.WordWrap
                }
            }

            Item {
                id: customHeaderHost

                width: parent ? parent.width : 0
                visible: root.hasCustomHeader
                implicitHeight: childrenRect.height
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignTop
            spacing: root.actionSpacing
            visible: root.hasHeaderActions || root.collapsible

            RowLayout {
                id: headerActionHost
                visible: root.hasHeaderActions
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
                spacing: root.actionSpacing
            }

            Loader {
                active: root.collapsible
                visible: active

                sourceComponent: AppPaneDisclosure {
                    control: root.control
                    expanded: root.expanded
                    accessibleName: root.title.length > 0 ? root.title : qsTr("面板")
                    onToggleRequested: root.toggleRequested(nextExpanded)
                }
            }
        }
    }
}
