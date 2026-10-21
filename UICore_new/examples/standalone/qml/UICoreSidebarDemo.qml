import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/components/shell" as Shell

ColumnLayout {
    id: root

    readonly property QtObject density: ApplicationWindow.window.appTheme.density
    readonly property QtObject motion: ApplicationWindow.window.appTheme.motion
    readonly property QtObject colors: ApplicationWindow.window.appTheme.colors
    readonly property var shell: ApplicationWindow.window ? ApplicationWindow.window.shell : null
    readonly property var sidebar: shell ? shell.sidebar : null
    readonly property var sidebarPane: shell ? shell.sidebarPane : null

    property bool initialized: false
    property Component defaultFooterContent: null
    property string contentMode: "menu"
    property bool showHeader: false
    property bool showFooter: true
    property bool showSidebarText: true
    property bool sidebarOpened: true
    property bool sidebarAutoHideEnabled: false
    property bool animated: true
    property int revealDelay: motion.shellPanelRevealDelay
    property int hideDelay: motion.shellPanelHideDelay
    property var toggleOptions: [
        { "label": qsTr("Header 插槽"), "propertyName": "showHeader" },
        { "label": qsTr("Footer 插槽"), "propertyName": "showFooter" },
        { "label": qsTr("菜单文字"), "propertyName": "showSidebarText" },
        { "label": qsTr("侧栏显示"), "propertyName": "sidebarOpened" },
        { "label": qsTr("侧栏自动隐藏"), "propertyName": "sidebarAutoHideEnabled" },
        { "label": qsTr("动画"), "propertyName": "animated" }
    ]

    signal eventTriggered(string message)

    spacing: density.paneContentSpacing

    Component.onCompleted: {
        defaultFooterContent = sidebar.footerContent
        showSidebarText = sidebar.showItemLabels
        sidebarOpened = shell.sidebarOpen
        sidebarAutoHideEnabled = sidebar.autoHideEnabled
        animated = sidebarPane.animated
        revealDelay = sidebarPane.revealDelay
        hideDelay = sidebarPane.hideDelay
        initialized = true
    }

    Binding {
        target: root.sidebar
        property: "headerContent"
        value: root.showHeader ? sidebarHeaderComponent : null
        when: root.initialized
    }

    Binding {
        target: root.sidebar
        property: "content"
        value: root.contentMode === "custom" ? sidebarCustomContentComponent : null
        when: root.initialized
    }

    Binding {
        target: root.sidebar
        property: "footerContent"
        value: root.showFooter ? root.defaultFooterContent : null
        when: root.initialized
    }

    Binding {
        target: root.sidebar
        property: "showItemLabels"
        value: root.showSidebarText
        when: root.initialized
    }

    Binding {
        target: root.sidebar
        property: "menuItems"
        value: root.contentMode === "blank" ? [] : root.shell.navigationItems
        when: root.initialized
    }

    Binding {
        target: root.sidebar
        property: "animated"
        value: root.animated
        when: root.initialized
    }

    Binding {
        target: root.sidebarPane
        property: "animated"
        value: root.animated
        when: root.initialized
    }

    Binding {
        target: root.sidebarPane
        property: "revealDelay"
        value: root.revealDelay
        when: root.initialized
    }

    Binding {
        target: root.sidebarPane
        property: "hideDelay"
        value: root.hideDelay
        when: root.initialized
    }

    Connections {
        target: root.sidebar

        function onItemTriggered(key) {
            root.eventTriggered(qsTr("AppSidebar 触发：%1").arg(key))
        }

        function onAutoHideEnabledChanged() {
            root.sidebarAutoHideEnabled = root.sidebar.autoHideEnabled
        }
    }

    Connections {
        target: root.shell

        function onSidebarOpenChanged() {
            root.sidebarOpened = root.shell.sidebarOpen
        }

    }

    Base.AppSurface {
        Layout.fillWidth: true
        Layout.preferredHeight: 72
        sizeToContent: false
        surfaceTone: UiStyle.SurfaceTone.Info
        shapeRole: UiStyle.ShapeRole.Section
        strokeWidth: 0
        padding: root.density.panePaddingCompact

        RowLayout {
            anchors.fill: parent
            spacing: root.density.controlGap

            Base.AppIcon {
                name: "layers"
                size: 18
            }

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("AppSidebar 独立控制自身显隐和自动隐藏；AppSidebarPane 独立控制展开面板。leftContentInset 只读取 Sidebar 实际占用的宽度。")
                styleRole: UiStyle.TypographyRole.BodyM
                textTone: UiStyle.TextTone.Info
                wrapMode: Text.WordWrap
            }
        }
    }

    Base.AppText {
        text: qsTr("主体内容")
        styleRole: UiStyle.TypographyRole.Label
    }

    Base.AppSegmentedControl {
        Layout.fillWidth: true
        value: root.contentMode
        options: [
            { "label": qsTr("默认菜单"), "value": "menu" },
            { "label": qsTr("自定义"), "value": "custom" },
            { "label": qsTr("空白"), "value": "blank" }
        ]
        onValueSelected: {
            root.contentMode = nextValue
            root.eventTriggered(qsTr("AppSidebar 内容：%1").arg(nextValue))
        }
    }

    Base.AppText {
        text: qsTr("默认菜单选中项")
        styleRole: UiStyle.TypographyRole.Label
    }

    Base.AppSegmentedControl {
        Layout.fillWidth: true
        value: root.shell.activeNavigationKey
        options: [
            { "label": qsTr("无"), "value": "" },
            { "label": qsTr("组件"), "value": "components" }
        ]
        onValueSelected: root.shell.activeNavigationKey = nextValue
    }

    Base.AppText {
        text: qsTr("面板显示模式（当前%1）").arg(
            root.shell.leftPaneOpen ? qsTr("打开") : qsTr("关闭"))
        styleRole: UiStyle.TypographyRole.Label
    }

    Base.AppSegmentedControl {
        Layout.fillWidth: true
        value: root.shell.leftPaneDisplayMode
        options: [
            { "label": qsTr("固定隐藏"), "value": Shell.AppSidebarPane.Hidden },
            { "label": qsTr("固定显示"), "value": Shell.AppSidebarPane.Pinned },
            { "label": qsTr("自动显隐"), "value": Shell.AppSidebarPane.AutoHide }
        ]
        onValueSelected: {
            root.shell.leftPaneDisplayMode = nextValue
            root.eventTriggered(qsTr("AppSidebarPane 显示模式：%1").arg(nextValue))
        }
    }

    GridLayout {
        id: toggleGrid

        Layout.fillWidth: true
        columns: 1
        columnSpacing: root.density.panePadding
        rowSpacing: root.density.controlGap

        Binding {
            target: toggleGrid
            property: "columns"
            value: root.width >= 700 ? 2 : 1
            delayed: true
        }

        Repeater {
            model: root.toggleOptions

            delegate: RowLayout {
                Layout.fillWidth: true
                spacing: root.density.controlGap

                Base.AppText {
                    Layout.fillWidth: true
                    text: modelData.label
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                }

                Base.AppToggleControl {
                    checked: !!root[modelData.propertyName]
                    onToggled: {
                        root[modelData.propertyName] = checked

                        if (modelData.propertyName === "sidebarOpened")
                            root.shell.sidebarOpen = checked
                        else if (modelData.propertyName === "sidebarAutoHideEnabled")
                            root.sidebar.autoHideEnabled = checked

                        root.eventTriggered(qsTr("%1：%2").arg(modelData.label).arg(
                            checked ? qsTr("开启") : qsTr("关闭")))
                    }
                }
            }
        }
    }

    Base.AppText {
        text: qsTr("面板展开延迟：%1 ms").arg(root.revealDelay)
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Secondary
    }

    Base.AppSliderControl {
        Layout.fillWidth: true
        value: root.revealDelay
        from: 0
        to: 1000
        stepSize: 20
        suffix: " ms"
        onValueEdited: root.revealDelay = Math.round(nextValue)
    }

    Base.AppText {
        text: qsTr("面板收起延迟：%1 ms").arg(root.hideDelay)
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Secondary
    }

    Base.AppSliderControl {
        Layout.fillWidth: true
        value: root.hideDelay
        from: 0
        to: 1000
        stepSize: 20
        suffix: " ms"
        onValueEdited: root.hideDelay = Math.round(nextValue)
    }

    Component {
        id: sidebarHeaderComponent

        Item {
            implicitHeight: root.density.controlHeightLg + root.density.dividerThickness

            Base.AppSurface {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.density.controlHeightLg
                sizeToContent: false
                surfaceTone: UiStyle.SurfaceTone.Highlight
                shapeRole: UiStyle.ShapeRole.Control
                strokeWidth: 0

                Base.AppIcon {
                    anchors.centerIn: parent
                    name: "workflow"
                    size: 16
                    color: root.colors.inverseText
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: root.density.dividerThickness
                color: root.colors.border
            }
        }
    }

    Component {
        id: sidebarCustomContentComponent

        ColumnLayout {
            spacing: root.density.controlGap

            Shell.AppRailButton {
                id: weatherButton

                Layout.alignment: Qt.AlignHCenter
                iconName: "weather"
                text: qsTr("自定义天气动作")
                animated: root.animated
                onClicked: root.eventTriggered(qsTr("点击自定义内容"))

                Base.AppToolTip {
                    parent: weatherButton
                    visible: weatherButton.hovered
                    text: weatherButton.text
                }
            }

            Shell.AppRailButton {
                id: resourcesButton

                Layout.alignment: Qt.AlignHCenter
                iconName: "resources"
                text: qsTr("自定义资源动作")
                animated: root.animated
                onClicked: root.eventTriggered(qsTr("点击自定义资源内容"))

                Base.AppToolTip {
                    parent: resourcesButton
                    visible: resourcesButton.hovered
                    text: resourcesButton.text
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
