import QtQuick 2.14
import UICore.Style 1.0
import ".." as Ui
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/components/shell" as Shell
import "qrc:/UICore/qml/menus" as Menus

Ui.AppWindow {
    id: window

    property string menuColorCanvasTone: "black"
    readonly property bool smokeTest:
        Qt.application.arguments.indexOf("--smoke-test") >= 0
    readonly property QtObject activeMenuModel:
        shell.activeNavigationKey === "scene"
            ? sceneMenuModel
            : (shell.activeNavigationKey === "scroll-test"
                ? scrollMenuModel
                : layerMenuModel)

    //x: -2000
    y: 0
    visible: true
    Component.onCompleted: {
        showMaximized()
        if (window.smokeTest)
            shell.showLeftPane()
    }

    Timer {
        property int step: 0

        interval: 800
        repeat: true
        running: window.smokeTest
        onTriggered: {
            if (step === 0) {
                window.shell.navigationRequested("layers")
                ++step
                return
            }

            if (step === 1) {
                window.shell.navigationRequested("scene")
                ++step
                return
            }

            if (step === 2) {
                window.shell.navigationRequested("scroll-test")
                ++step
                return
            }

            if (step === 3) {
                window.shell.leftPaneSource =
                    "qrc:/UICore/qml/standalone/UICoreMenuColorCanvas.qml"
                window.shell.activeNavigationKey = "smoke-pane"
                window.shell.showLeftPane()
                ++step
                return
            }

            window.shell.canvasDelegateSource =
                "qrc:/UICore/qml/standalone/UICoreGallery.qml"
            window.shell.activeNavigationKey = "smoke-canvas"
            stop()
        }
    }

    shell.applicationTitle: qsTr("UICore")
    shell.topNavigationBar.menuItems: [{
        "key": "overview",
        "label": qsTr("概览"),
        "iconName": "scene"
    }, {
        "key": "resources",
        "label": qsTr("资源"),
        "iconName": "resources"
    }, {
        "key": "menu-color-test",
        "label": qsTr("调色画布"),
        "iconName": "layer-config"
    }]
    shell.topNavigationBar.activeItemKey: "menu-color-test"
    shell.topNavigationBar.trailingContent: shell.topNavigationBar.activeItemKey
        === "menu-color-test" ? menuColorCanvasControls : null
    shell.bottomNavigationBar.menuItems: [{
        "key": "tasks",
        "label": qsTr("任务"),
        "iconName": "background-task"
    }, {
        "key": "status",
        "label": qsTr("状态"),
        "iconName": "workflow"
    }]
    shell.bottomNavigationBar.activeItemKey: "status"
    shell.navigationItems: [{
        "key": "layers",
        "label": qsTr("图层"),
        "iconName": "layers",
        "detail": qsTr("图层菜单视效样本")
    }, {
        "key": "scene",
        "label": qsTr("场景"),
        "iconName": "scene",
        "detail": qsTr("场景菜单视效样本")
    }, {
        "key": "scroll-test",
        "label": qsTr("滚动测试"),
        "iconName": "resources",
        "detail": qsTr("AppMenuPane 长内容")
    }]
    shell.activeNavigationKey: "layers"
    shell.leftPaneDisplayMode: Shell.AppSidebarPane.Hidden
    shell.leftPanelWidth: window.activeMenuModel.paneWidth
    shell.leftPaneContent: Component {
        Menus.AppMenuPane {
            menuKey: window.shell.activeNavigationKey
            paneController: window.activeMenuModel
            showHeader: menuKey !== "scene"
            surfaceTone: UiStyle.SurfaceTone.Surface
            surfaceOpacityScale: 1.0
        }
    }
    shell.canvasDelegateSource: shell.topNavigationBar.activeItemKey
        === "menu-color-test"
        ? "qrc:/UICore/qml/standalone/UICoreMenuColorCanvas.qml"
        : "qrc:/UICore/qml/standalone/UICoreGallery.qml"

    Component {
        id: menuColorCanvasControls

        Base.AppSegmentedControl {
            implicitWidth: 160
            options: [{
                "label": qsTr("纯黑"),
                "value": "black"
            }, {
                "label": qsTr("纯白"),
                "value": "white"
            }]
            value: window.menuColorCanvasTone
            onValueSelected: window.menuColorCanvasTone = nextValue
        }
    }

    Connections {
        target: window.shell

        function onSidebarOpenRequested(open) {
            window.shell.sidebarOpen = open
        }

        function onNavigationRequested(key) {
            if (window.shell.activeNavigationKey === key
                    && window.shell.leftPaneOpen) {
                window.shell.activeNavigationKey = ""
                window.shell.hideLeftPane()
                return
            }

            window.shell.activeNavigationKey = key
            window.shell.showLeftPane()
        }
    }

    Connections {
        target: window.shell.topNavigationBar

        function onItemTriggered(key) {
            window.shell.topNavigationBar.activeItemKey = key
        }
    }

    Connections {
        target: window.shell.bottomNavigationBar

        function onItemTriggered(key) {
            window.shell.bottomNavigationBar.activeItemKey = key
        }
    }
}
