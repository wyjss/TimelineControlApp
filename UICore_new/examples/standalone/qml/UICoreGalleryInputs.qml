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
        integerNumberField.text = "25"
        integerNumberField.commitText()
        doubleNumberField.text = "0.333"
        doubleNumberField.commitText()
        if (gallery.integerInputValue !== 20
                || gallery.doubleInputValue !== 0.33) {
            throw new Error("AppNumberField smoke test failed")
        }
    }

    Base.AppSection {
        Layout.fillWidth: true
        title: qsTr("输入与选择")
        subtitle: qsTr("单行、多行、CheckBox、Ghost、候选输入、只读、禁用和不同选择形态")
        showHeaderDivider: true
        clearFocusOnTap: true
        padding: 0
        contentSpacing: gallery.density.paneContentSpacing

        GridLayout {
            Layout.fillWidth: true
            columns: gallery.width >= gallery.metrics.layoutBreakpointMd ? 2 : 1
            columnSpacing: gallery.density.panePadding
            rowSpacing: gallery.density.paneSpacing

            ColumnLayout {
                Layout.fillWidth: true
                spacing: gallery.density.controlGap

                Base.AppText {
                    text: qsTr("文本输入")
                    styleRole: UiStyle.TypographyRole.Label
                }

                Base.AppTextField {
                    Layout.fillWidth: true
                    placeholderText: qsTr("普通输入")
                    onTextChanged: gallery.lastEvent = qsTr("文本：%1").arg(text)
                }

                Base.AppTextField {
                    Layout.fillWidth: true
                    text: "60"
                    options: [30, 60, 90, 120]
                    placeholderText: qsTr("候选值仍可编辑")
                }

                Base.AppTextField {
                    Layout.fillWidth: true
                    text: qsTr("Ghost 外观")
                    appearance: UiStyle.ControlAppearance.Ghost
                }

                Base.AppTextArea {
                    Layout.fillWidth: true
                    text: gallery.notesValue
                    placeholderText: qsTr("多行说明")
                    onTextChanged: gallery.notesValue = text
                }

                Base.AppNumberField {
                    id: integerNumberField

                    Layout.fillWidth: true
                    value: gallery.integerInputValue
                    integerMode: true
                    minimum: -20
                    maximum: 20
                    onValueEdited: gallery.integerInputValue = nextValue
                }

                Base.AppNumberField {
                    id: doubleNumberField

                    Layout.fillWidth: true
                    value: gallery.doubleInputValue
                    minimum: 0
                    maximum: 1
                    decimals: 2
                    suffix: "%"
                    onValueEdited: gallery.doubleInputValue = nextValue
                }

                RowLayout {
                    Layout.fillWidth: true

                    Base.AppTextField {
                        Layout.fillWidth: true
                        text: qsTr("只读")
                        readOnly: true
                    }

                    Base.AppTextField {
                        Layout.fillWidth: true
                        text: qsTr("禁用")
                        enabled: false
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: gallery.density.controlGap

                Base.AppText {
                    text: qsTr("Select 与开关")
                    styleRole: UiStyle.TypographyRole.Label
                }

                Base.AppSelect {
                    Layout.fillWidth: true
                    value: gallery.selectedRegion
                    placeholderText: qsTr("选择区域")
                    options: [
                        { "label": qsTr("东区"), "value": "east" },
                        { "label": qsTr("西区"), "value": "west" },
                        { "label": qsTr("中心区"), "value": "central" }
                    ]
                    onValueSelected: {
                        gallery.selectedRegion = nextValue
                        gallery.lastEvent = qsTr("区域：%1").arg(nextValue)
                    }
                }

                Base.AppSegmentedControl {
                    Layout.fillWidth: true
                    value: gallery.selectedMode
                    options: [
                        { "label": qsTr("性能"), "value": "fast" },
                        { "label": qsTr("均衡"), "value": "balanced" },
                        { "label": qsTr("质量"), "value": "quality" }
                    ]
                    onValueSelected: {
                        gallery.selectedMode = nextValue
                        gallery.lastEvent = qsTr("模式：%1").arg(nextValue)
                    }
                }

                Base.AppChoiceControl {
                    Layout.fillWidth: true
                    value: gallery.selectedChoice
                    options: [
                        { "label": qsTr("蓝色"), "value": "blue", "color": "#60a5fa" },
                        { "label": qsTr("绿色"), "value": "green", "color": "#34d399" },
                        { "label": qsTr("橙色"), "value": "orange", "color": "#fb923c" }
                    ]
                    onValueSelected: {
                        gallery.selectedChoice = nextValue
                        gallery.lastEvent = qsTr("选项：%1").arg(nextValue)
                    }
                }

                Base.AppCheckBox {
                    text: qsTr("使用 CheckBox 呈现")
                    checked: gallery.checkBoxValue
                    onToggled: {
                        gallery.checkBoxValue = checked
                        gallery.lastEvent = checked ? qsTr("CheckBox 已选中") : qsTr("CheckBox 已取消")
                    }
                }

                RowLayout {
                    spacing: gallery.density.controlGap

                    Base.AppToggleControl {
                        checked: gallery.featureEnabled
                        onToggled: {
                            gallery.featureEnabled = checked
                            gallery.lastEvent = checked ? qsTr("功能已启用") : qsTr("功能已关闭")
                        }
                    }

                    Base.AppText {
                        text: gallery.featureEnabled ? qsTr("已启用") : qsTr("已关闭")
                        styleRole: UiStyle.TypographyRole.BodyM
                        textTone: gallery.featureEnabled
                            ? UiStyle.TextTone.Success
                            : UiStyle.TextTone.Secondary
                    }

                    Base.AppToggleControl {
                        checked: true
                        enabled: false
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: gallery.width >= gallery.metrics.layoutBreakpointMd ? 2 : 1
            columnSpacing: gallery.density.panePadding
            rowSpacing: gallery.density.paneSpacing

            Base.AppSliderControl {
                Layout.fillWidth: true
                value: gallery.intensityValue
                from: 0
                to: 100
                stepSize: 1
                suffix: "%"
                onValueEdited: {
                    gallery.intensityValue = nextValue
                    gallery.lastEvent = qsTr("强度：%1%").arg(Math.round(nextValue))
                }
            }

            Base.AppColorControl {
                Layout.fillWidth: true
                value: gallery.selectedColor
                onValueEdited: {
                    gallery.selectedColor = String(nextValue)
                    gallery.lastEvent = qsTr("颜色：%1").arg(String(nextValue))
                }
            }

            Base.AppProgressBar {
                Layout.fillWidth: true
                value: 0.5
            }

            Base.AppProgressBar {
                Layout.fillWidth: true
                indeterminate: true
            }
        }
    }

    Base.AppSection {
        Layout.fillWidth: true
        title: qsTr("输入组件状态矩阵")
        subtitle: qsTr("空值、强调、插槽、禁用、无选中、长内容和边界值")
        showHeaderDivider: true
        clearFocusOnTap: true
        padding: 0
        contentSpacing: gallery.density.paneContentSpacing

        Base.AppText {
            text: qsTr("TextField")
            styleRole: UiStyle.TypographyRole.Label
        }

        GridLayout {
            Layout.fillWidth: true
            columns: gallery.width >= gallery.metrics.layoutBreakpointLg
                ? 3
                : (gallery.width >= gallery.metrics.layoutBreakpointSm ? 2 : 1)
            columnSpacing: gallery.density.paneSpacing
            rowSpacing: gallery.density.paneSpacing

            Base.AppTextField {
                Layout.fillWidth: true
                placeholderText: qsTr("空值 / Placeholder")
            }

            Base.AppTextField {
                Layout.fillWidth: true
                text: qsTr("强调状态")
                emphasized: true
            }

            Base.AppTextField {
                Layout.fillWidth: true
                text: qsTr("带前后插槽")
                leadingContent: [
                    Base.AppIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "resources"
                        size: 16
                    }
                ]
                trailingContent: [
                    Base.AppText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Ctrl E")
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Secondary
                    }
                ]
            }

            Base.AppTextField {
                Layout.fillWidth: true
                text: qsTr("只读状态")
                readOnly: true
            }

            Base.AppTextField {
                Layout.fillWidth: true
                text: qsTr("禁用状态")
                enabled: false
            }

            Base.AppTextField {
                Layout.fillWidth: true
                placeholderText: qsTr("点击并输入以验证 Focus")
                options: [qsTr("候选一"), qsTr("候选二"), qsTr("候选三")]
            }
        }

        Base.AppText {
            text: qsTr("Select")
            styleRole: UiStyle.TypographyRole.Label
        }

        GridLayout {
            Layout.fillWidth: true
            columns: gallery.width >= gallery.metrics.layoutBreakpointLg
                ? 3
                : (gallery.width >= gallery.metrics.layoutBreakpointSm ? 2 : 1)
            columnSpacing: gallery.density.paneSpacing
            rowSpacing: gallery.density.paneSpacing

            Base.AppSelect {
                Layout.fillWidth: true
                value: gallery.placeholderSelectValue
                placeholderText: qsTr("空值 / Placeholder")
                options: [
                    { "label": qsTr("选项 A"), "value": "a" },
                    { "label": qsTr("选项 B"), "value": "b" }
                ]
                onValueSelected: gallery.placeholderSelectValue = nextValue
            }

            Base.AppSelect {
                Layout.fillWidth: true
                value: gallery.ghostSelectValue
                appearance: UiStyle.ControlAppearance.Ghost
                options: [
                    { "label": qsTr("Ghost A"), "value": "a" },
                    { "label": qsTr("Ghost B"), "value": "b" }
                ]
                onValueSelected: gallery.ghostSelectValue = nextValue
            }

            Base.AppSelect {
                Layout.fillWidth: true
                value: "b"
                readOnly: true
                options: [
                    { "label": qsTr("只读 A"), "value": "a" },
                    { "label": qsTr("只读 B"), "value": "b" }
                ]
            }

            Base.AppSelect {
                Layout.fillWidth: true
                value: "b"
                enabled: false
                options: [
                    { "label": qsTr("禁用 A"), "value": "a" },
                    { "label": qsTr("禁用 B"), "value": "b" }
                ]
            }

            Base.AppSelect {
                Layout.fillWidth: true
                value: gallery.longSelectValue
                maxPopupHeight: 120
                options: [
                    { "label": qsTr("长列表项目 01"), "value": "item-1" },
                    { "label": qsTr("长列表项目 02"), "value": "item-2" },
                    { "label": qsTr("长列表项目 03"), "value": "item-3" },
                    { "label": qsTr("长列表项目 04"), "value": "item-4" },
                    { "label": qsTr("长列表项目 05"), "value": "item-5" },
                    { "label": qsTr("长列表项目 06"), "value": "item-6" },
                    { "label": qsTr("长列表项目 07"), "value": "item-7" },
                    { "label": qsTr("长列表项目 08"), "value": "item-8" }
                ]
                onValueSelected: gallery.longSelectValue = nextValue
            }

            Base.AppSelect {
                Layout.fillWidth: true
                value: gallery.emphasizedSelectValue
                emphasized: true
                options: [
                    { "label": qsTr("地球"), "value": "earth" },
                    { "label": qsTr("资源"), "value": "resource" }
                ]
                leadingContent: [
                    Base.AppIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "scene"
                        size: 16
                    }
                ]
                trailingContent: [
                    Base.AppText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("推荐")
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Success
                    }
                ]
                onValueSelected: gallery.emphasizedSelectValue = nextValue
            }
        }

        Base.AppText {
            text: qsTr("Segmented 与 Choice")
            styleRole: UiStyle.TypographyRole.Label
        }

        GridLayout {
            Layout.fillWidth: true
            columns: gallery.width >= gallery.metrics.layoutBreakpointMd ? 2 : 1
            columnSpacing: gallery.density.paneSpacing
            rowSpacing: gallery.density.paneSpacing

            Base.AppSegmentedControl {
                Layout.fillWidth: true
                value: ""
                options: [
                    { "label": qsTr("无选中 A"), "value": "a" },
                    { "label": qsTr("无选中 B"), "value": "b" }
                ]
            }

            Base.AppSegmentedControl {
                Layout.fillWidth: true
                value: "a"
                enabled: false
                options: [
                    { "label": qsTr("禁用 A"), "value": "a" },
                    { "label": qsTr("禁用 B"), "value": "b" }
                ]
            }

            Base.AppSegmentedControl {
                Layout.fillWidth: true
                value: "balanced"
                options: [
                    { "label": qsTr("较长的性能优先"), "value": "fast" },
                    { "label": qsTr("较长的均衡模式"), "value": "balanced" },
                    { "label": qsTr("较长的质量优先"), "value": "quality" }
                ]
            }

            Base.AppChoiceControl {
                Layout.fillWidth: true
                value: ""
                options: [
                    { "label": qsTr("无选中"), "value": "none" },
                    { "label": qsTr("纯文字"), "value": "text" }
                ]
            }

            Base.AppChoiceControl {
                Layout.fillWidth: true
                value: "play"
                options: [
                    { "label": qsTr("播放"), "value": "play", "iconName": "play" },
                    { "label": qsTr("暂停"), "value": "pause", "iconName": "pause" },
                    { "label": qsTr("停止"), "value": "stop", "iconName": "stop" }
                ]
            }

            Base.AppChoiceControl {
                Layout.fillWidth: true
                value: "a"
                enabled: false
                options: [
                    { "label": qsTr("禁用 A"), "value": "a", "color": "#60a5fa" },
                    { "label": qsTr("禁用 B"), "value": "b", "color": "#34d399" }
                ]
            }
        }

        Base.AppText {
            text: qsTr("Toggle")
            styleRole: UiStyle.TypographyRole.Label
        }

        Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: childrenRect.height
            spacing: gallery.density.panePadding

            Row {
                spacing: gallery.density.controlGap

                Base.AppToggleControl {
                    checked: false
                }

                Base.AppText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("关闭")
                    styleRole: UiStyle.TypographyRole.BodyS
                }
            }

            Row {
                spacing: gallery.density.controlGap

                Base.AppToggleControl {
                    checked: true
                }

                Base.AppText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("开启")
                    styleRole: UiStyle.TypographyRole.BodyS
                }
            }

            Row {
                spacing: gallery.density.controlGap

                Base.AppToggleControl {
                    checked: false
                    enabled: false
                }

                Base.AppText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("禁用关闭")
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                }
            }

            Row {
                spacing: gallery.density.controlGap

                Base.AppToggleControl {
                    checked: true
                    enabled: false
                }

                Base.AppText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("禁用开启")
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                }
            }
        }

        Base.AppText {
            text: qsTr("Slider")
            styleRole: UiStyle.TypographyRole.Label
        }

        GridLayout {
            Layout.fillWidth: true
            columns: gallery.width >= gallery.metrics.layoutBreakpointLg
                ? 3
                : (gallery.width >= gallery.metrics.layoutBreakpointSm ? 2 : 1)
            columnSpacing: gallery.density.panePadding
            rowSpacing: gallery.density.paneSpacing

            Repeater {
                model: [
                    { "value": 0, "from": 0, "to": 100, "step": 1, "suffix": "%", "enabled": true, "showLabel": true },
                    { "value": 50, "from": 0, "to": 100, "step": 1, "suffix": "%", "enabled": true, "showLabel": true },
                    { "value": 100, "from": 0, "to": 100, "step": 1, "suffix": "%", "enabled": true, "showLabel": true },
                    { "value": 70, "from": 0, "to": 100, "step": 1, "suffix": "%", "enabled": false, "showLabel": true },
                    { "value": 0.35, "from": 0, "to": 1, "step": 0.05, "suffix": "", "enabled": true, "showLabel": true },
                    { "value": 40, "from": 0, "to": 100, "step": 1, "suffix": "", "enabled": true, "showLabel": false }
                ]

                delegate: Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: stateSlider.implicitHeight
                    property real currentValue: Number(modelData.value)

                    Base.AppSliderControl {
                        id: stateSlider

                        anchors.fill: parent
                        value: parent.currentValue
                        from: Number(modelData.from)
                        to: Number(modelData.to)
                        stepSize: Number(modelData.step)
                        suffix: String(modelData.suffix)
                        enabled: !!modelData.enabled
                        showValueLabel: !!modelData.showLabel
                        onValueEdited: parent.currentValue = nextValue
                    }
                }
            }
        }

        Base.AppText {
            text: qsTr("Color")
            styleRole: UiStyle.TypographyRole.Label
        }

        GridLayout {
            Layout.fillWidth: true
            columns: gallery.width >= gallery.metrics.layoutBreakpointLg
                ? 4
                : (gallery.width >= gallery.metrics.layoutBreakpointSm ? 2 : 1)
            columnSpacing: gallery.density.paneSpacing
            rowSpacing: gallery.density.paneSpacing

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: emptyColorControl.implicitHeight

                Base.AppColorControl {
                    id: emptyColorControl

                    anchors.fill: parent
                    value: ""
                    placeholderText: qsTr("空值")
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: invalidColorControl.implicitHeight

                Base.AppColorControl {
                    id: invalidColorControl

                    anchors.fill: parent
                    value: "NOT-A-COLOR"
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: opaqueColorControl.implicitHeight

                Base.AppColorControl {
                    id: opaqueColorControl

                    anchors.fill: parent
                    value: "#807CB4FF"
                    showAlphaChannel: false
                    appearance: UiStyle.ControlAppearance.Ghost
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: disabledColorControl.implicitHeight

                Base.AppColorControl {
                    id: disabledColorControl

                    anchors.fill: parent
                    value: "#7CB4FF"
                    enabled: false
                }
            }
        }
    }
}
