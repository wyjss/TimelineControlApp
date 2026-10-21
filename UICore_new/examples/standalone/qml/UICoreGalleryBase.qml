import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base

Base.AppScrollPane {
    id: root

    property Item gallery

    contentSpacing: gallery.density.sectionSpacing
    Base.AppSection {
        Layout.fillWidth: true
        title: qsTr("排版与图标")
        subtitle: qsTr("TypographyRole、TextTone 与内置资源图标")
        showHeaderDivider: true
        clearFocusOnTap: true
        padding: 0
        contentSpacing: gallery.density.paneContentSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Base.AppText {
                text: qsTr("Title XL / 页面主标题")
                styleRole: UiStyle.TypographyRole.TitleXL
            }

            Base.AppText {
                text: qsTr("Title L / 内容标题")
                styleRole: UiStyle.TypographyRole.TitleL
            }

            Base.AppText {
                text: qsTr("Title M / 小标题")
                styleRole: UiStyle.TypographyRole.TitleM
            }

            Base.AppText {
                text: qsTr("Section Title / 分区标题")
                styleRole: UiStyle.TypographyRole.SectionTitle
            }

            Base.AppText {
                text: qsTr("Body L / 大号正文")
                styleRole: UiStyle.TypographyRole.BodyL
            }

            Base.AppText {
                text: qsTr("Body M / 正文文本")
                styleRole: UiStyle.TypographyRole.BodyM
                textTone: UiStyle.TextTone.Secondary
            }

            Base.AppText {
                text: qsTr("Success · Warning · Danger · Info")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Success
            }

            Base.AppText {
                text: qsTr("Label / 标签文本")
                styleRole: UiStyle.TypographyRole.Label
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: childrenRect.height
            spacing: gallery.density.paneSpacing

            Repeater {
                model: [
                    { "label": qsTr("Primary"), "tone": UiStyle.TextTone.Primary },
                    { "label": qsTr("Secondary"), "tone": UiStyle.TextTone.Secondary },
                    { "label": qsTr("Accent"), "tone": UiStyle.TextTone.Accent },
                    { "label": qsTr("Success"), "tone": UiStyle.TextTone.Success },
                    { "label": qsTr("Warning"), "tone": UiStyle.TextTone.Warning },
                    { "label": qsTr("Info"), "tone": UiStyle.TextTone.Info },
                    { "label": qsTr("Neutral"), "tone": UiStyle.TextTone.Neutral },
                    { "label": qsTr("Danger"), "tone": UiStyle.TextTone.Danger },
                    { "label": qsTr("Inverse"), "tone": UiStyle.TextTone.Inverse }
                ]

                delegate: Base.AppText {
                    text: modelData.label
                    styleRole: UiStyle.TypographyRole.BodyM
                    textTone: modelData.tone
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: childrenRect.height
            spacing: gallery.density.panePadding

            Repeater {
                model: ["workflow", "layers", "resources", "weather", "play", "pause", "stop", "background-task"]

                delegate: Column {
                    spacing: 5

                    Base.AppSurface {
                        width: 44
                        height: 44
                        sizeToContent: false
                        surfaceTone: UiStyle.SurfaceTone.Section
                        shapeRole: UiStyle.ShapeRole.Control

                        Base.AppIcon {
                            anchors.centerIn: parent
                            name: modelData
                            size: 20
                        }
                    }

                    Base.AppText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Secondary
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: gallery.density.panePadding

            Base.AppText {
                text: qsTr("Source")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }

            Base.AppIcon {
                source: "qrc:/UICore/assets/icons/play.svg"
                size: 20
            }

            Base.AppText {
                text: qsTr("Symbol")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }

            Base.AppIcon {
                symbol: "★"
                size: 20
            }

            Base.AppText {
                text: qsTr("Missing/Fallback")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }

            Base.AppIcon {
                symbol: "?"
                size: 20
            }

            Base.AppText {
                text: qsTr("No Tint")
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }

            Base.AppIcon {
                source: "qrc:/UICore/assets/icons/weather.svg"
                tintSource: false
                size: 20
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }

    Base.AppSection {
        Layout.fillWidth: true
        title: qsTr("表面与按钮")
        subtitle: qsTr("语义表面、按钮 Variant、尺寸、选中和禁用状态")
        showHeaderDivider: true
        clearFocusOnTap: true
        padding: 0
        contentSpacing: gallery.density.paneContentSpacing

        GridLayout {
            Layout.fillWidth: true
            columns: gallery.width >= gallery.metrics.layoutBreakpointLg
                ? 4
                : (gallery.width >= gallery.metrics.layoutBreakpointSm ? 2 : 1)
            columnSpacing: gallery.density.paneSpacing
            rowSpacing: gallery.density.paneSpacing

            Repeater {
                model: [
                    { "label": qsTr("Surface"), "tone": UiStyle.SurfaceTone.Surface },
                    { "label": qsTr("Window"), "tone": UiStyle.SurfaceTone.Window },
                    { "label": qsTr("Surface Overlay"), "tone": UiStyle.SurfaceTone.SurfaceOverlay },
                    { "label": qsTr("Popup"), "tone": UiStyle.SurfaceTone.Popup },
                    { "label": qsTr("Section"), "tone": UiStyle.SurfaceTone.Section },
                    { "label": qsTr("Control"), "tone": UiStyle.SurfaceTone.Control },
                    { "label": qsTr("Section Overlay"), "tone": UiStyle.SurfaceTone.SectionOverlay },
                    { "label": qsTr("Canvas"), "tone": UiStyle.SurfaceTone.Canvas },
                    { "label": qsTr("Highlight"), "tone": UiStyle.SurfaceTone.Highlight },
                    { "label": qsTr("Success"), "tone": UiStyle.SurfaceTone.Success },
                    { "label": qsTr("Warning"), "tone": UiStyle.SurfaceTone.Warning },
                    { "label": qsTr("Info"), "tone": UiStyle.SurfaceTone.Info },
                    { "label": qsTr("Neutral"), "tone": UiStyle.SurfaceTone.Neutral },
                    { "label": qsTr("Danger"), "tone": UiStyle.SurfaceTone.Danger },
                    { "label": qsTr("Ghost"), "tone": UiStyle.SurfaceTone.Ghost }
                ]

                delegate: Base.AppSurface {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    sizeToContent: false
                    surfaceTone: modelData.tone
                    shapeRole: UiStyle.ShapeRole.Section
                    padding: gallery.density.panePaddingCompact

                    Base.AppText {
                        anchors.centerIn: parent
                        text: modelData.label
                        styleRole: UiStyle.TypographyRole.Label
                    }
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: childrenRect.height
            spacing: gallery.density.controlGap

            Base.AppButton {
                text: qsTr("Primary")
                variant: UiStyle.ButtonVariant.Primary
                onClicked: gallery.lastEvent = qsTr("点击 Primary")
            }

            Base.AppButton {
                text: qsTr("Danger")
                variant: UiStyle.ButtonVariant.Danger
                onClicked: gallery.lastEvent = qsTr("点击 Danger")
            }

            Base.AppButton {
                text: qsTr("Secondary")
                variant: UiStyle.ButtonVariant.Secondary
                onClicked: gallery.lastEvent = qsTr("点击 Secondary")
            }

            Base.AppButton {
                text: qsTr("Tonal")
                variant: UiStyle.ButtonVariant.Tonal
                onClicked: gallery.lastEvent = qsTr("点击 Tonal")
            }

            Base.AppButton {
                text: qsTr("Subtle")
                variant: UiStyle.ButtonVariant.Subtle
                onClicked: gallery.lastEvent = qsTr("点击 Subtle")
            }

            Base.AppButton {
                text: qsTr("Ghost")
                variant: UiStyle.ButtonVariant.Ghost
                onClicked: gallery.lastEvent = qsTr("点击 Ghost")
            }

            Base.AppButton {
                text: qsTr("Nav / Active")
                variant: UiStyle.ButtonVariant.Nav
                checkable: true
                checked: true
            }

            Base.AppButton {
                text: qsTr("Small")
                size: UiStyle.ButtonSize.Small
                iconName: "play"
            }

            Base.AppButton {
                text: qsTr("Large")
                size: UiStyle.ButtonSize.Large
                iconName: "workflow"
            }

            Base.AppButton {
                text: qsTr("Disabled")
                enabled: false
            }

            Base.AppButton {
                text: qsTr("Checkable")
                checkable: true
            }

            Base.AppButton {
                iconName: "weather"
                Accessible.name: qsTr("纯图标按钮")
            }

            Base.AppButton {
                text: qsTr("Start Aligned")
                iconName: "layers"
                minWidth: 170
                contentAlignment: "start"
            }

            Base.AppButton {
                text: qsTr("Highlighted")
                highlighted: true
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: childrenRect.height
            spacing: gallery.density.controlGap

            Base.AppButton {
                id: raisedToggle

                text: checked ? qsTr("微浮：开启") : qsTr("微浮：关闭")
                checkable: true
                checked: true
                onToggled: gallery.lastEvent = checked ? qsTr("开启微浮效果") : qsTr("关闭微浮效果")
            }

            Repeater {
                model: [
                    { "label": qsTr("Primary"), "variant": UiStyle.ButtonVariant.Primary },
                    { "label": qsTr("Secondary"), "variant": UiStyle.ButtonVariant.Secondary },
                    { "label": qsTr("Tonal"), "variant": UiStyle.ButtonVariant.Tonal },
                    { "label": qsTr("Subtle"), "variant": UiStyle.ButtonVariant.Subtle },
                    { "label": qsTr("Ghost"), "variant": UiStyle.ButtonVariant.Ghost },
                    { "label": qsTr("Nav"), "variant": UiStyle.ButtonVariant.Nav },
                    { "label": qsTr("Danger"), "variant": UiStyle.ButtonVariant.Danger }
                ]

                delegate: Base.AppButton {
                    text: modelData.label
                    variant: modelData.variant
                    raised: raisedToggle.checked
                    onClicked: gallery.lastEvent = qsTr("点击微浮 %1").arg(text)
                }
            }
        }

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("上排为默认外观，下排随微浮开关切换。悬停、按下或用 Tab 切换焦点可查看反馈；Ghost、Nav 仅交互或选中时显示微浮。")
            styleRole: UiStyle.TypographyRole.BodyS
            textTone: UiStyle.TextTone.Secondary
        }
    }
}
