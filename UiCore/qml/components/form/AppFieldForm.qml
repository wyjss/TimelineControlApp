import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtQuick.Window 2.14
import "../../foundation"

Item {
    id: root

    default property alias formContent: formColumn.data

    property QtObject theme
    readonly property QtObject applicationWindowTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : null
    readonly property QtObject windowTheme: Window.window && Window.window.appTheme
        ? Window.window.appTheme
        : null
    readonly property QtObject resolvedTheme: theme
        ? theme
        : (applicationWindowTheme ? applicationWindowTheme : windowTheme)
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
    property bool clipContent: false

    readonly property int resolvedLayoutModeValue: AppUiEnums.normalizeLayoutMode(layoutMode)
    readonly property string resolvedLayoutMode: {
        switch (resolvedLayoutModeValue) {
        case AppUiEnums.LayoutMode.Horizontal:
            return "horizontal"
        case AppUiEnums.LayoutMode.Vertical:
            return "vertical"
        default:
            return resolvedContentWidth >= horizontalBreakpoint ? "horizontal" : "vertical"
        }
    }
    readonly property string resolvedLayoutModeName: resolvedLayoutMode
    readonly property real availableContentWidth: Math.max(0, width)
    readonly property real resolvedContentWidth: {
        var innerWidth = Math.max(0, availableContentWidth - contentPadding * 2)

        if (maxContentWidth > 0)
            return Math.min(maxContentWidth, innerWidth)

        return innerWidth
    }

    property alias contentLayout: formColumn

    function densityValue(name, fallback) {
        if (resolvedTheme && resolvedTheme.density && resolvedTheme.density[name] !== undefined)
            return Number(resolvedTheme.density[name])

        return resolvedTheme && resolvedTheme.metrics && resolvedTheme.metrics[name] !== undefined
            ? Number(resolvedTheme.metrics[name])
            : fallback
    }

    implicitWidth: formContextRoot.implicitWidth
    implicitHeight: formContextRoot.implicitHeight
    clip: root.clipContent

    Item {
        id: formContextRoot

        width: root.resolvedContentWidth + root.contentPadding * 2
        implicitWidth: width
        implicitHeight: formColumn.implicitHeight + root.contentPadding * 2
        anchors.top: parent ? parent.top : undefined
        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined

        ColumnLayout {
            id: formColumn

            property bool fieldFormContext: true
            property string fieldLayoutMode: root.resolvedLayoutMode
            property int fieldLabelWidth: root.labelWidth
            property int fieldFieldSpacing: root.fieldSpacing
            property bool fieldShowDivider: root.showDivider
            property bool fieldShowUnderline: root.showUnderline
            property string fieldUnderlineScope: root.underlineScope

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: root.contentPadding
            anchors.rightMargin: root.contentPadding
            anchors.topMargin: root.contentPadding
            spacing: root.sectionSpacing
        }
    }
}
