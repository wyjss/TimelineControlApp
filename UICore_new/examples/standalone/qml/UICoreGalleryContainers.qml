import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base

Base.AppScrollPane {
    id: root

    property Item gallery

    contentSpacing: gallery.density.sectionSpacing

    function runSmokeTest() {
        if (cardSelectionTransition.buttonGroup.buttons.length > 1)
            cardSelectionTransition.buttonGroup.buttons[1].checked = true

        var componentsIndex = treeModel.index(0, 0, treeList.rootIndex)
        var controlsIndex = treeModel.index(0, 0, componentsIndex)
        treeList.expand(componentsIndex)
        treeList.expand(controlsIndex)
        if (!treeList.isExpanded(componentsIndex)
                || !treeList.isExpanded(controlsIndex)) {
            throw new Error("AppTreeList initial expansion smoke test failed")
        }
        treeList.collapse(controlsIndex)
        if (treeList.isExpanded(controlsIndex))
            throw new Error("AppTreeList collapse smoke test failed")
        treeList.expand(controlsIndex)
        if (!treeList.isExpanded(controlsIndex))
            throw new Error("AppTreeList expand smoke test failed")
        if (!treeList.customContentDelegateLoaded)
            throw new Error("AppTreeList content delegate smoke test failed")
    }

    Base.AppSection {
        Layout.fillWidth: true
        title: qsTr("容器与折叠")
        subtitle: qsTr("Card、Panel、Section、header actions 和折叠动画")
        showHeaderDivider: true
        clearFocusOnTap: true
        padding: 0
        contentSpacing: gallery.density.paneContentSpacing

        GridLayout {
            Layout.fillWidth: true
            columns: gallery.width >= gallery.metrics.layoutBreakpointMd ? 2 : 1
            columnSpacing: gallery.density.paneSpacing
            rowSpacing: gallery.density.paneSpacing

            Base.AppCard {
                Layout.fillWidth: true
                text: qsTr("操作卡片")
                onClicked: gallery.lastEvent = qsTr("点击 AppCard")

                Base.AppText {
                    Layout.fillWidth: true
                    text: qsTr("操作卡片")
                    styleRole: UiStyle.TypographyRole.SectionTitle
                }

                Base.AppText {
                    Layout.fillWidth: true
                    text: qsTr("整张卡片使用统一的 Hover、Pressed 和 Focus 状态。")
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    wrapMode: Text.WordWrap
                }
            }

            Base.AppCard {
                id: selectableCard

                Layout.fillWidth: true
                text: qsTr("选择卡片")
                checkable: true

                Base.AppText {
                    Layout.fillWidth: true
                    text: selectableCard.checked ? qsTr("已选择") : qsTr("未选择")
                    styleRole: UiStyle.TypographyRole.SectionTitle
                    textTone: selectableCard.checked
                        ? UiStyle.TextTone.Accent
                        : UiStyle.TextTone.Primary
                }

                Base.AppText {
                    Layout.fillWidth: true
                    text: qsTr("选择状态直接使用 AbstractButton.checked。")
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    wrapMode: Text.WordWrap
                }
            }
        }

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("列表强调选中")
            styleRole: UiStyle.TypographyRole.Label
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: cardListLayout.implicitHeight

            ColumnLayout {
                id: cardListLayout

                anchors.fill: parent
                spacing: gallery.density.controlGap

                Repeater {
                    model: [
                        { "title": qsTr("概览"), "detail": qsTr("实底、描边和左侧指示条强化选中状态。") },
                        { "title": qsTr("资源"), "detail": qsTr("高亮边框和指示条会一起转移到当前选中项。") },
                        { "title": qsTr("设置"), "detail": qsTr("AppCardSelectionTransition 保证互斥并管理选中动画。") }
                    ]

                    delegate: Base.AppCard {
                        id: listCard

                        Layout.fillWidth: true
                        text: modelData.title
                        checkable: true
                        checked: index === 0
                        emphasizedSelection: true
                        selectionTransition: cardSelectionTransition
                        animateScale: false
                        compact: true

                        Base.AppText {
                            Layout.fillWidth: true
                            text: modelData.title
                            styleRole: UiStyle.TypographyRole.SectionTitle
                            textTone: listCard.checked
                                ? UiStyle.TextTone.Accent
                                : UiStyle.TextTone.Primary
                        }

                        Base.AppText {
                            Layout.fillWidth: true
                            text: modelData.detail
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            Base.AppCardSelectionTransition {
                id: cardSelectionTransition

                anchors.fill: parent
            }
        }

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("多级树状列表")
            styleRole: UiStyle.TypographyRole.Label
        }

        Base.AppTreeList {
            id: treeList

            property bool customContentDelegateLoaded: false

            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            model: treeModel
            contentDelegate: Component {
                RowLayout {
                    property QtObject treeItem

                    spacing: treeList.densityValue("controlGap")

                    onTreeItemChanged: if (treeItem)
                        treeList.customContentDelegateLoaded = true

                    Base.AppIcon {
                        Layout.preferredWidth: treeList.metricValue("iconSizeMd")
                        Layout.preferredHeight: treeList.metricValue("iconSizeMd")
                        name: treeItem ? treeItem.iconName : ""
                        size: treeList.metricValue("iconSizeMd")
                        color: treeItem && treeItem.selected
                            ? treeList.colorValue("highlightText")
                            : treeList.colorValue("subtleText")
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        text: treeItem ? String(treeItem.value) : ""
                        styleRole: UiStyle.TypographyRole.BodyM
                        textTone: treeItem && treeItem.selected
                            ? UiStyle.TextTone.Accent
                            : UiStyle.TextTone.Primary
                        elide: Text.ElideRight
                    }
                }
            }
            onClicked: gallery.lastEvent = qsTr("选择树节点：")
                + String(treeModel.data(index))
            onExpanded: gallery.lastEvent = qsTr("展开树节点：")
                + String(treeModel.data(index))
            onCollapsed: gallery.lastEvent = qsTr("收起树节点：")
                + String(treeModel.data(index))

            Component.onCompleted: Qt.callLater(function() {
                var componentsIndex = treeModel.index(0, 0, rootIndex)
                expand(componentsIndex)
                expand(treeModel.index(0, 0, componentsIndex))
            })
        }

        Base.AppPanel {
            Layout.fillWidth: true
            title: qsTr("可折叠 Panel")
            subtitle: qsTr("标题、描述、Header Action 和正文内容")
            collapsible: true
            expanded: true
            bodyFillHeight: false
            surfaceTone: UiStyle.SurfaceTone.SurfaceOverlay
            padding: gallery.density.panePaddingCompact
            contentSpacing: gallery.density.paneContentSpacing
            headerActions: [
                Base.AppButton {
                    text: qsTr("操作")
                    size: UiStyle.ButtonSize.Small
                    variant: UiStyle.ButtonVariant.Ghost
                    onClicked: gallery.lastEvent = qsTr("点击 Panel Header Action")
                }
            ]

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("Panel 适合承载独立工具、详情块或浮层内容。点击标题右侧的折叠按钮可以查看展开动画。")
                styleRole: UiStyle.TypographyRole.BodyM
                textTone: UiStyle.TextTone.Secondary
                wrapMode: Text.WordWrap
            }
        }

        Base.AppSection {
            Layout.fillWidth: true
            title: qsTr("嵌套 Section")
            subtitle: qsTr("Flat 内容也可以按需切换 surfaced")
            surfaced: false
            compact: true
            padding: 0

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("这个 Section 不创建额外表面，适合页面内部的轻量分组。")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
                wrapMode: Text.WordWrap
            }
        }

        Base.AppPanel {
            Layout.fillWidth: true
            title: qsTr("初始收起 Panel")
            subtitle: qsTr("用于检查收起高度和再次展开")
            collapsible: true
            expanded: false
            bodyFillHeight: false
            surfaceTone: UiStyle.SurfaceTone.SectionOverlay
            padding: gallery.density.panePaddingCompact

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("展开后显示的正文内容。")
                styleRole: UiStyle.TypographyRole.BodyM
            }
        }

        Base.AppSection {
            Layout.fillWidth: true
            surfaced: true
            padding: gallery.density.panePaddingCompact

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("无标题 Section：只有正文，不创建空标题栏。")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }
        }

        Base.AppSection {
            Layout.fillWidth: true
            title: qsTr("多 Header Action")
            surfaced: false
            compact: true
            padding: 0
            headerActions: [
                Base.AppButton {
                    iconName: "play"
                    size: UiStyle.ButtonSize.Small
                    variant: UiStyle.ButtonVariant.Ghost
                    Accessible.name: qsTr("播放")
                },
                Base.AppButton {
                    iconName: "stop"
                    size: UiStyle.ButtonSize.Small
                    variant: UiStyle.ButtonVariant.Ghost
                    Accessible.name: qsTr("停止")
                }
            ]

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("用于检查多个标题操作与正文的布局。")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }
        }
    }
}
