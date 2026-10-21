import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base

Item {
    id: root

    readonly property QtObject density: ApplicationWindow.window.appTheme.density
    readonly property QtObject metrics: ApplicationWindow.window.appTheme.metrics
    readonly property bool smokeTest:
        Qt.application.arguments.indexOf("--smoke-test") >= 0
    readonly property var categoryOptions: [
        { "label": qsTr("总览"), "value": "overview" },
        { "label": qsTr("Shell"), "value": "shell" },
        { "label": qsTr("基础"), "value": "base" },
        { "label": qsTr("输入"), "value": "input" },
        { "label": qsTr("容器"), "value": "container" },
        { "label": qsTr("反馈"), "value": "feedback" },
        { "label": qsTr("字段"), "value": "field" },
        { "label": qsTr("all"), "value": "all" }
    ]
    readonly property var allCategorySources: [
        "qrc:/UICore/qml/standalone/UICoreGalleryShell.qml",
        "qrc:/UICore/qml/standalone/UICoreGalleryBase.qml",
        "qrc:/UICore/qml/standalone/UICoreGalleryInputs.qml",
        "qrc:/UICore/qml/standalone/UICoreGalleryContainers.qml",
        "qrc:/UICore/qml/standalone/UICoreGalleryFeedback.qml",
        "qrc:/UICore/qml/standalone/UICoreGalleryFields.qml"
    ]
    readonly property var smokeCategories:
        ["base", "input", "container", "feedback", "field"]
    readonly property string activeCategorySource:
        activeCategory === "overview" || activeCategory === "all"
            ? ""
            : activeCategory === "shell"
                ? "qrc:/UICore/qml/standalone/UICoreGalleryShell.qml"
                : activeCategory === "input"
                    ? "qrc:/UICore/qml/standalone/UICoreGalleryInputs.qml"
                    : activeCategory === "container"
                        ? "qrc:/UICore/qml/standalone/UICoreGalleryContainers.qml"
                        : activeCategory === "feedback"
                            ? "qrc:/UICore/qml/standalone/UICoreGalleryFeedback.qml"
                            : activeCategory === "field"
                                ? "qrc:/UICore/qml/standalone/UICoreGalleryFields.qml"
                                : "qrc:/UICore/qml/standalone/UICoreGalleryBase.qml"

    property string lastEvent: qsTr("等待交互")
    property string activeCategory: "overview"
    property int smokeCategoryIndex: 0
    property string selectedMode: "balanced"
    property string selectedRegion: "east"
    property string selectedChoice: "green"
    property string selectedColor: "#7CB4FF"
    property string notesValue: qsTr("支持多行输入和自动换行。")
    property bool checkBoxValue: true
    property bool featureEnabled: true
    property real intensityValue: 42
    property string placeholderSelectValue: ""
    property string ghostSelectValue: "a"
    property string longSelectValue: "item-1"
    property string emphasizedSelectValue: "earth"
    property string verticalSelectValue: "a"
    property bool alertVisible: true
    property int integerInputValue: 12
    property real doubleInputValue: 0.75
    property string simpleDialogName: ""
    property string simpleDialogMode: "standard"
    property string complexDialogMode: "balanced"

    Component.onCompleted: {
        if (smokeTest)
            activeCategory = smokeCategories[0]
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.density.panePadding
        spacing: root.density.sectionSpacing

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("UICore 组件陈列")
            styleRole: UiStyle.TypographyRole.TitleL
            textTone: UiStyle.TextTone.Primary
        }

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("按类别加载主题角色、基础控件、组合容器和字段渲染。所有组件都从窗口自动读取 appTheme。")
            styleRole: UiStyle.TypographyRole.BodyM
            textTone: UiStyle.TextTone.Secondary
            wrapMode: Text.WordWrap
        }

        Base.AppSurface {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            sizeToContent: false
            surfaceTone: UiStyle.SurfaceTone.Info
            shapeRole: UiStyle.ShapeRole.Section
            strokeWidth: 0
            padding: root.density.panePaddingCompact

            RowLayout {
                anchors.fill: parent
                spacing: root.density.controlGap

                Base.AppIcon {
                    name: "workflow"
                    size: 18
                }

                Base.AppText {
                    Layout.fillWidth: true
                    text: root.lastEvent
                    styleRole: UiStyle.TypographyRole.BodyM
                    textTone: UiStyle.TextTone.Info
                    elide: Text.ElideRight
                }

                Base.AppButton {
                    text: qsTr("打开弹层")
                    size: UiStyle.ButtonSize.Small
                    variant: UiStyle.ButtonVariant.Tonal
                    onClicked: {
                        root.activeCategory = "feedback"
                        Qt.callLater(function() {
                            if (categoryLoader.item)
                                categoryLoader.item.openSimpleDialog()
                        })
                    }
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: childrenRect.height
            spacing: root.density.controlGap

            Repeater {
                model: root.categoryOptions

                delegate: Base.AppButton {
                    readonly property string categoryValue: String(modelData.value)

                    text: String(modelData.label)
                    size: UiStyle.ButtonSize.Small
                    variant: UiStyle.ButtonVariant.Ghost
                    highlighted: root.activeCategory === categoryValue
                    animateScale: false
                    onClicked: root.activeCategory = categoryValue
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.activeCategory === "overview"
            spacing: root.density.controlGap

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("按类别创建")
                styleRole: UiStyle.TypographyRole.SectionTitle
            }

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("只实例化当前类别，切换后释放上一类别的组件。选择上方类别查看对应示例。")
                textTone: UiStyle.TextTone.Secondary
                wrapMode: Text.WordWrap
            }

            Item {
                Layout.fillHeight: true
            }
        }

        Loader {
            id: categoryLoader

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.activeCategorySource.length > 0
            onLoaded: {
                if (!root.smokeTest
                        || root.smokeCategoryIndex >= root.smokeCategories.length)
                    return

                if (typeof item.runSmokeTest === "function")
                    item.runSmokeTest()

                ++root.smokeCategoryIndex
                if (root.smokeCategoryIndex < root.smokeCategories.length)
                    root.activeCategory = root.smokeCategories[root.smokeCategoryIndex]
            }
        }

        Base.AppScrollPane {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.activeCategory === "all"
            contentSpacing: root.density.sectionSpacing

            Repeater {
                model: root.activeCategory === "all"
                    ? root.allCategorySources
                    : []

                delegate: Loader {
                    Layout.fillWidth: true
                    Layout.preferredHeight: item ? item.availableContentHeight : 0

                    Component.onCompleted:
                        setSource(String(modelData), { "gallery": root })
                }
            }
        }
    }

    Connections {
        target: root

        function onActiveCategoryChanged() {
            if (root.activeCategorySource.length > 0)
                categoryLoader.setSource(root.activeCategorySource, { "gallery": root })
            else
                categoryLoader.source = ""
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton
        onClicked: root.forceActiveFocus(Qt.MouseFocusReason)
    }
}
