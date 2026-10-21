import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtQuick.Window 2.14
import UICore.Style 1.0
import "../base/internal/AppThemeUtils.js" as ThemeUtils

Item {
    id: root

    default property alias formContent: formColumn.data

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
    property int layoutMode: UiStyle.LayoutMode.Horizontal
    property int horizontalBreakpoint: resolvedTheme.metrics.layoutBreakpointMd
    property int labelWidth: 156
    property int fieldSpacing: densityValue("controlGap")
    property int sectionSpacing: densityValue("paneSpacing")
    property int contentPadding: 0
    property real maxContentWidth: -1
    property bool showDivider: false
    property bool showUnderline: false
    property string underlineScope: "field"
    property int fieldAppearance: UiStyle.ControlAppearance.Filled
    property bool clipContent: false

    onCurrentWindowThemeChanged: {
        if (currentWindowTheme)
            _retainedTheme = currentWindowTheme
    }

    readonly property string resolvedLayoutMode: {
        switch (layoutMode) {
        case UiStyle.LayoutMode.Horizontal:
            return "horizontal"
        case UiStyle.LayoutMode.Vertical:
            return "vertical"
        default:
            return resolvedContentWidth >= horizontalBreakpoint ? "horizontal" : "vertical"
        }
    }
    readonly property real availableContentWidth: Math.max(0, width)
    readonly property real resolvedContentWidth: {
        var innerWidth = Math.max(0, availableContentWidth - contentPadding * 2)

        if (maxContentWidth > 0)
            return Math.min(maxContentWidth, innerWidth)

        return innerWidth
    }

    property alias contentLayout: formColumn

    function densityValue(name) {
        return ThemeUtils.densityValue(resolvedTheme, name)
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
            property int fieldLayoutMode: root.resolvedLayoutMode === "horizontal"
                ? UiStyle.LayoutMode.Horizontal
                : UiStyle.LayoutMode.Vertical
            property int fieldLabelWidth: root.labelWidth
            property int fieldFieldSpacing: root.fieldSpacing
            property bool fieldShowDivider: root.showDivider
            property bool fieldShowUnderline: root.showUnderline
            property string fieldUnderlineScope: root.underlineScope
            property int fieldAppearance: root.fieldAppearance

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
