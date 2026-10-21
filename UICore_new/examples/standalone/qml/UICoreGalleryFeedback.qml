import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base

Base.AppScrollPane {
    id: root

    property Item gallery

    contentSpacing: gallery.density.sectionSpacing

    function openSimpleDialog() {
        simpleDialog.open()
    }

    function runSmokeTest() {
        complexDialog.open()
    }

    Base.AppSection {
        Layout.fillWidth: true
        title: qsTr("字段块、背景、滚动与反馈")
        subtitle: qsTr("独立 AppFieldBlock、Backdrop、滚动边界、Alert、Toast、Dialog 和 Popup")
        showHeaderDivider: true
        clearFocusOnTap: true
        padding: 0
        contentSpacing: gallery.density.paneContentSpacing

        Base.AppText {
            text: qsTr("AppFieldBlock")
            styleRole: UiStyle.TypographyRole.Label
        }

        GridLayout {
            Layout.fillWidth: true
            columns: gallery.width >= gallery.metrics.layoutBreakpointMd ? 2 : 1
            columnSpacing: gallery.density.panePadding
            rowSpacing: gallery.density.paneSpacing

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: horizontalFieldBlock.implicitHeight

                Base.AppFieldBlock {
                    id: horizontalFieldBlock

                    width: parent.width
                    height: implicitHeight
                    inheritFormDefaults: false
                    label: qsTr("水平字段")
                    subtitle: qsTr("字段范围下划线")
                    layoutMode: UiStyle.LayoutMode.Horizontal
                    labelWidth: 120
                    showUnderline: true
                    underlineScope: "field"
                    fieldControl: standaloneHorizontalField
                    fieldContentFillWidth: true

                    Base.AppTextField {
                        id: standaloneHorizontalField

                        Layout.fillWidth: true
                        text: qsTr("Horizontal")
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: verticalFieldBlock.implicitHeight

                Base.AppFieldBlock {
                    id: verticalFieldBlock

                    width: parent.width
                    height: implicitHeight
                    inheritFormDefaults: false
                    label: qsTr("垂直字段")
                    subtitle: qsTr("整行 Divider")
                    layoutMode: UiStyle.LayoutMode.Vertical
                    showDivider: true
                    fieldControl: standaloneVerticalField

                    Base.AppSelect {
                        id: standaloneVerticalField

                        Layout.fillWidth: true
                        value: gallery.verticalSelectValue
                        options: [
                            { "label": qsTr("选项 A"), "value": "a" },
                            { "label": qsTr("选项 B"), "value": "b" }
                        ]
                        onValueSelected: gallery.verticalSelectValue = nextValue
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: disabledFieldBlock.implicitHeight

                Base.AppFieldBlock {
                    id: disabledFieldBlock

                    width: parent.width
                    height: implicitHeight
                    inheritFormDefaults: false
                    label: qsTr("禁用字段")
                    subtitle: qsTr("禁用状态下划线")
                    layoutMode: UiStyle.LayoutMode.Horizontal
                    labelWidth: 120
                    showUnderline: true
                    fieldControl: standaloneDisabledField
                    fieldContentFillWidth: true

                    Base.AppTextField {
                        id: standaloneDisabledField

                        Layout.fillWidth: true
                        text: qsTr("Disabled")
                        enabled: false
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: labelFreeFieldBlock.implicitHeight

                Base.AppFieldBlock {
                    id: labelFreeFieldBlock

                    width: parent.width
                    height: implicitHeight
                    inheritFormDefaults: false
                    showLabel: false
                    showSubtitle: false
                    layoutMode: UiStyle.LayoutMode.Vertical
                    fieldControl: standaloneLabelFreeField

                    Base.AppTextField {
                        id: standaloneLabelFreeField

                        Layout.fillWidth: true
                        placeholderText: qsTr("无 Label 字段")
                    }
                }
            }
        }

        Base.AppText {
            text: qsTr("AppBackdrop")
            styleRole: UiStyle.TypographyRole.Label
        }

        GridLayout {
            Layout.fillWidth: true
            columns: gallery.width >= gallery.metrics.layoutBreakpointMd ? 2 : 1
            columnSpacing: gallery.density.paneSpacing
            rowSpacing: gallery.density.paneSpacing

            Base.AppBackdrop {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                sizeToContent: false
                clipContent: true

                Base.AppText {
                    anchors.centerIn: parent
                    text: qsTr("Gradient + Primary/Secondary Glow")
                    styleRole: UiStyle.TypographyRole.Label
                }
            }

            Base.AppBackdrop {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                sizeToContent: false
                clipContent: true
                showGradient: false
                showPrimaryGlow: false
                showSecondaryGlow: false

                Base.AppSurface {
                    anchors.fill: parent
                    sizeToContent: false
                    surfaceTone: UiStyle.SurfaceTone.Window
                    shapeRole: UiStyle.ShapeRole.Section

                    Base.AppText {
                        anchors.centerIn: parent
                        text: qsTr("Decorations Off")
                        styleRole: UiStyle.TypographyRole.Label
                        textTone: UiStyle.TextTone.Secondary
                    }
                }
            }
        }

        Base.AppText {
            text: qsTr("AppScrollPane")
            styleRole: UiStyle.TypographyRole.Label
        }

        GridLayout {
            Layout.fillWidth: true
            columns: gallery.width >= gallery.metrics.layoutBreakpointLg ? 3 : 1
            columnSpacing: gallery.density.paneSpacing
            rowSpacing: gallery.density.paneSpacing

            Base.AppSurface {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                sizeToContent: false
                surfaceTone: UiStyle.SurfaceTone.Surface
                shapeRole: UiStyle.ShapeRole.Section

                Base.AppScrollPane {
                    anchors.fill: parent
                    contentPadding: gallery.density.panePaddingCompact
                    showEdgeHints: true

                    Base.AppText {
                        Layout.fillWidth: true
                        text: qsTr("无溢出：不显示滚动条和边缘提示。")
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Secondary
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Base.AppSurface {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                sizeToContent: false
                surfaceTone: UiStyle.SurfaceTone.Surface
                shapeRole: UiStyle.ShapeRole.Section

                Base.AppScrollPane {
                    anchors.fill: parent
                    contentPadding: gallery.density.panePaddingCompact
                    contentSpacing: gallery.density.paneHeaderSpacing
                    showEdgeHints: true

                    Repeater {
                        model: 8

                        delegate: Base.AppText {
                            Layout.fillWidth: true
                            text: qsTr("纵向滚动项目 %1").arg(index + 1)
                            styleRole: UiStyle.TypographyRole.BodyS
                        }
                    }
                }
            }

            Base.AppSurface {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                sizeToContent: false
                surfaceTone: UiStyle.SurfaceTone.Surface
                shapeRole: UiStyle.ShapeRole.Section

                Base.AppScrollPane {
                    anchors.fill: parent
                    contentPadding: gallery.density.panePaddingCompact
                    fillContentWidth: false
                    allowHorizontalScroll: true
                    showEdgeHints: false

                    Base.AppSurface {
                        Layout.preferredWidth: 720
                        Layout.preferredHeight: 54
                        sizeToContent: false
                        surfaceTone: UiStyle.SurfaceTone.Highlight
                        shapeRole: UiStyle.ShapeRole.Control

                        Base.AppText {
                            anchors.centerIn: parent
                            text: qsTr("横向内容宽度 720px，可左右拖动")
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Accent
                        }
                    }
                }
            }
        }

        Base.AppAlert {
            Layout.fillWidth: true
            visible: gallery.alertVisible
            surfaceTone: UiStyle.SurfaceTone.Warning
            title: qsTr("页面内持续提示")
            message: qsTr("AppAlert 参与正常布局，适合需要持续显示的状态或问题说明。")
            actionText: qsTr("处理")
            closable: true
            onActionTriggered: gallery.lastEvent = qsTr("已触发 Alert 操作")
            onCloseRequested: {
                gallery.alertVisible = false
                gallery.lastEvent = qsTr("Alert 已关闭")
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: childrenRect.height
            spacing: gallery.density.controlGap

            Base.AppButton {
                text: qsTr("简单 Dialog")
                variant: UiStyle.ButtonVariant.Primary
                onClicked: simpleDialog.open()
            }

            Base.AppButton {
                text: qsTr("复杂 Dialog")
                variant: UiStyle.ButtonVariant.Secondary
                onClicked: complexDialog.open()
            }

            Base.AppButton {
                text: qsTr("显示 Toast")
                variant: UiStyle.ButtonVariant.Tonal
                onClicked: galleryToast.show()
            }

            Base.AppButton {
                text: qsTr("打开非模态 Popup")
                variant: UiStyle.ButtonVariant.Secondary
                onClicked: nonModalPopup.open()
            }

            Base.AppBadge {
                text: qsTr("默认 Badge")
            }

            Base.AppBadge {
                text: qsTr("强调 Badge")
                surfaceTone: UiStyle.SurfaceTone.Highlight
                textTone: UiStyle.TextTone.Accent
            }

            Base.AppButton {
                id: tooltipDemoButton

                text: qsTr("悬停查看 ToolTip")

                Base.AppToolTip {
                    parent: tooltipDemoButton
                    visible: tooltipDemoButton.hovered
                    text: qsTr("使用 UICore 主题 Token 的 ToolTip")
                }
            }
        }
    }

Base.AppDialog {
    id: simpleDialog

    parent: gallery
    x: Math.max(16, (gallery.width - width) / 2)
    y: Math.max(16, (gallery.height - height) / 2)
    width: Math.min(420, gallery.width - 32)
    maximumDialogHeight: gallery.density.controlHeightLg * 9
    title: qsTr("保存设置")
    message: qsTr("Dialog 使用独立的 Popup 背景，输入控件保持默认 Section 配色。")
    rejectText: qsTr("取消")
    acceptText: qsTr("应用")
    acceptEnabled: gallery.simpleDialogName.trim().length > 0
    acceptIconName: "workflow"
    initialFocusItem: simpleDialogNameField
    onAccepted: gallery.lastEvent = qsTr("简单 Dialog 已确认")
    onRejected: gallery.lastEvent = qsTr("简单 Dialog 已取消")

    Base.AppTextField {
        id: simpleDialogNameField

        Layout.fillWidth: true
        placeholderText: qsTr("名称")
        onTextEdited: gallery.simpleDialogName = text
    }

    Base.AppSelect {
        Layout.fillWidth: true
        value: gallery.simpleDialogMode
        options: [
            { "label": qsTr("标准"), "value": "standard" },
            { "label": qsTr("紧凑"), "value": "compact" }
        ]
        onValueSelected: gallery.simpleDialogMode = nextValue
    }

    RowLayout {
        Layout.fillWidth: true

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("启用自动保存")
            styleRole: UiStyle.TypographyRole.BodyM
        }

        Base.AppToggleControl {
            checked: true
        }
    }
}

Base.AppDialog {
    id: complexDialog

    parent: gallery
    x: Math.max(16, (gallery.width - width) / 2)
    y: Math.max(16, (gallery.height - height) / 2)
    width: Math.min(760, gallery.width - 32)
    maximumDialogHeight: gallery.density.controlHeightLg * 13
    title: qsTr("方案设置")
    message: qsTr("Popup 外壳承载三个 DialogSection，二级表面可独立调整主题。")
    rejectText: qsTr("取消")
    acceptText: qsTr("保存")
    acceptIconName: "workflow"
    onAccepted: gallery.lastEvent = qsTr("复杂 Dialog 已保存")
    onRejected: gallery.lastEvent = qsTr("复杂 Dialog 已取消")

    GridLayout {
        id: complexRegionGrid

        Layout.fillWidth: true
        columns: complexDialog.width >= gallery.metrics.layoutBreakpointSm ? 2 : 1
        columnSpacing: gallery.density.controlGap
        rowSpacing: gallery.density.controlGap

        Base.AppDialogSection {
            Layout.fillWidth: true
            Layout.columnSpan: complexRegionGrid.columns
            title: qsTr("输入源")
            bodyFillHeight: false
            compact: true
            padding: gallery.density.panePaddingCompact
            contentSpacing: gallery.density.controlGap
            headerActions: [
                Base.AppButton {
                    text: qsTr("文件")
                    size: UiStyle.ButtonSize.Small
                    variant: UiStyle.ButtonVariant.Tonal
                },
                Base.AppButton {
                    text: qsTr("目录")
                    size: UiStyle.ButtonSize.Small
                    variant: UiStyle.ButtonVariant.Ghost
                }
            ]

            Base.AppTextField {
                Layout.fillWidth: true
                text: qsTr("示例输入源")
            }
        }

        Base.AppDialogSection {
            Layout.fillWidth: true
            title: qsTr("参数")
            bodyFillHeight: false
            compact: true
            padding: gallery.density.panePaddingCompact
            contentSpacing: gallery.density.controlGap

            Base.AppTextField {
                Layout.fillWidth: true
                placeholderText: qsTr("方案名称")
            }

            Base.AppSelect {
                Layout.fillWidth: true
                value: gallery.complexDialogMode
                options: [
                    { "label": qsTr("性能优先"), "value": "fast" },
                    { "label": qsTr("均衡"), "value": "balanced" },
                    { "label": qsTr("质量优先"), "value": "quality" }
                ]
                onValueSelected: gallery.complexDialogMode = nextValue
            }

            RowLayout {
                Layout.fillWidth: true

                Base.AppText {
                    Layout.fillWidth: true
                    text: qsTr("启用限制")
                    styleRole: UiStyle.TypographyRole.BodyM
                }

                Base.AppToggleControl {
                    checked: true
                }
            }
        }

        Base.AppDialogSection {
            Layout.fillWidth: true
            title: qsTr("解析结果")
            bodyFillHeight: false
            compact: true
            padding: gallery.density.panePaddingCompact
            contentSpacing: gallery.density.controlGap

            Base.AppAlert {
                Layout.fillWidth: true
                surfaceTone: UiStyle.SurfaceTone.Success
                message: qsTr("输入源已加载，参数解析成功。")
            }

            Base.AppSurface {
                Layout.fillWidth: true
                surfaceTone: UiStyle.SurfaceTone.Section
                shapeRole: UiStyle.ShapeRole.Section
                padding: gallery.density.panePaddingCompact

                Base.AppText {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: qsTr("{\n  \"mode\": \"balanced\",\n  \"enabled\": true\n}")
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }
}

Base.AppToast {
    id: galleryToast

    parent: gallery
    x: Math.max(16, (gallery.width - width) / 2)
    y: gallery.density.pageMargin
    width: Math.min(400, gallery.width - 32)
    surfaceTone: UiStyle.SurfaceTone.Success
    title: qsTr("操作完成")
    message: qsTr("Toast 不阻塞页面，并会在悬停结束后自动关闭。")
    actionText: qsTr("查看")
    onActionTriggered: gallery.lastEvent = qsTr("已触发 Toast 操作")
    onCloseRequested: gallery.lastEvent = qsTr("Toast 已手动关闭")
}

Base.AppPopup {
    id: nonModalPopup

    parent: gallery
    x: Math.max(16, gallery.width - width - 24)
    y: 72
    width: Math.min(320, gallery.width - 32)
    height: topPadding
        + popupTitle.implicitHeight
        + popupMessage.implicitHeight
        + popupCloseButton.implicitHeight
        + spacing * 2
        + bottomPadding
    modal: false
    showModalOverlay: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    surfaceTone: UiStyle.SurfaceTone.Popup

    Base.AppText {
        id: popupTitle

        Layout.fillWidth: true
        text: qsTr("非模态弹层")
        styleRole: UiStyle.TypographyRole.SectionTitle
    }

    Base.AppText {
        id: popupMessage

        Layout.fillWidth: true
        text: qsTr("不创建遮罩，可以继续操作页面中的其他控件。")
        styleRole: UiStyle.TypographyRole.BodyM
        textTone: UiStyle.TextTone.Secondary
        wrapMode: Text.WordWrap
    }

    Base.AppButton {
        id: popupCloseButton

        Layout.alignment: Qt.AlignRight
        text: qsTr("关闭")
        variant: UiStyle.ButtonVariant.Ghost
        onClicked: nonModalPopup.close()
    }
}
}
