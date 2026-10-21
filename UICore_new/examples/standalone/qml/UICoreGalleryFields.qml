import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Fields 1.0
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/components/form" as Form

Base.AppScrollPane {
    id: root

    property Item gallery

    contentSpacing: gallery.density.sectionSpacing

    property var demoFormData: ({
        "layoutMode": UiStyle.LayoutMode.Horizontal,
        "horizontalBreakpoint": gallery.metrics.layoutBreakpointMd,
        "labelWidth": 140,
        "fieldSpacing": gallery.density.paneSpacing,
        "sectionSpacing": gallery.density.panePadding,
        "showFieldUnderline": true,
        "sections": [
            {
                "key": "general",
                "title": qsTr("常规字段"),
                "collapsible": true,
                "expanded": true,
                "controls": [
                    nameField,
                    descriptionField,
                    refreshField,
                    thresholdField,
                    regionField,
                    enabledField,
                    consentField,
                    intensityField
                ]
            },
            {
                "key": "renderers",
                "title": qsTr("其它 Renderer"),
                "collapsible": true,
                "expanded": true,
                "controls": [
                    summaryField,
                    segmentedField,
                    choiceField,
                    colorField,
                    chipsField,
                    customField,
                    actionField
                ]
            }
        ]
    })

    AppField {
        id: nameField

        kind: AppField.Kind.TextField
        valueType: BaseField.StringType
        key: "name"
        label: qsTr("名称")
        subtitle: qsTr("普通文本字段")
        value: qsTr("UICore 示例")
        placeholderText: qsTr("请输入名称")
    }

    AppField {
        id: refreshField

        kind: AppField.Kind.TextField
        valueType: BaseField.IntType
        key: "refreshRate"
        label: qsTr("刷新频率")
        subtitle: qsTr("候选值可选，也可以继续输入")
        value: 60
        minimum: 0
        maximum: 120
        stepSize: 30
        options: [30, 60, 90, 120]
        allowCustomValue: true
        suffix: " Hz"
    }

    AppField {
        id: descriptionField

        kind: AppField.Kind.TextArea
        valueType: BaseField.StringType
        key: "description"
        label: qsTr("说明")
        subtitle: qsTr("TextArea 与受控错误呈现")
        value: qsTr("字段 renderer 支持多行文本。")
        required: true
        errorText: qsTr("示例错误：请补充更完整的说明。")
    }

    AppField {
        id: thresholdField

        kind: AppField.Kind.TextField
        valueType: BaseField.DoubleType
        key: "threshold"
        label: qsTr("阈值")
        subtitle: qsTr("Double 数值字段")
        value: 0.75
        minimum: 0
        maximum: 1
        stepSize: 0.05
    }

    AppField {
        id: regionField

        kind: AppField.Kind.Select
        valueType: BaseField.EnumType
        key: "region"
        label: qsTr("区域")
        value: "east"
        options: [
            { "label": qsTr("东区"), "value": "east" },
            { "label": qsTr("西区"), "value": "west" },
            { "label": qsTr("中心区"), "value": "central" }
        ]
    }

    AppField {
        id: enabledField

        kind: AppField.Kind.Toggle
        valueType: BaseField.BoolType
        key: "enabled"
        label: qsTr("启用功能")
        subtitle: qsTr("布尔值 Toggle")
        value: true
    }

    AppField {
        id: intensityField

        kind: AppField.Kind.Slider
        valueType: BaseField.DoubleType
        key: "intensity"
        label: qsTr("强度")
        value: 42
        minimum: 0
        maximum: 100
        stepSize: 1
        suffix: "%"
    }

    AppField {
        id: consentField

        kind: AppField.Kind.CheckBox
        valueType: BaseField.BoolType
        key: "consent"
        label: qsTr("确认选项")
        subtitle: qsTr("显式 CheckBoxEditor 使用 CheckBox")
        value: true
    }

    AppField {
        id: summaryField

        kind: AppField.Kind.Summary
        key: "summary"
        label: qsTr("只读摘要")
        value: qsTr("适合显示状态、标识和较长的只读内容")
        readOnly: true
    }

    AppField {
        id: segmentedField

        kind: AppField.Kind.Segmented
        key: "quality"
        label: qsTr("质量")
        value: "balanced"
        options: [
            { "label": qsTr("性能"), "value": "fast" },
            { "label": qsTr("均衡"), "value": "balanced" },
            { "label": qsTr("质量"), "value": "quality" }
        ]
    }

    AppField {
        id: choiceField

        kind: AppField.Kind.Choice
        key: "accent"
        label: qsTr("强调色")
        value: "blue"
        options: [
            { "label": qsTr("蓝色"), "value": "blue", "color": "#60a5fa" },
            { "label": qsTr("绿色"), "value": "green", "color": "#34d399" },
            { "label": qsTr("橙色"), "value": "orange", "color": "#fb923c" }
        ]
    }

    AppField {
        id: colorField

        kind: AppField.Kind.Color
        key: "color"
        label: qsTr("颜色")
        value: "#7cb4ff"
        appearance: UiStyle.ControlAppearance.Ghost
    }

    AppField {
        id: chipsField

        kind: AppField.Kind.Chips
        key: "capabilities"
        label: qsTr("能力标签")
        items: [
            { "label": "QML", "active": true },
            { "label": "C++", "active": true },
            { "label": "Theme", "active": false }
        ]
        readOnly: true
    }

    AppField {
        id: customField

        kind: AppField.Kind.Custom
        key: "custom"
        label: qsTr("自定义字段")
        value: 0
        delegateSource: "qrc:/UICore/qml/standalone/UICoreGalleryCustomField.qml"
        customData: ({
            "note": qsTr("应用可以提供自己的字段 delegate")
        })
    }

    AppField {
        id: actionField

        kind: AppField.Kind.Button
        key: "action"
        value: qsTr("执行示例操作")
        actionId: "gallery.runAction"
        variant: UiStyle.ButtonVariant.Primary
        payload: ({ "source": "form" })
    }

    Base.AppSection {
        Layout.fillWidth: true
        title: qsTr("AppField 与 AppFormContent")
        subtitle: qsTr("覆盖 Text、TextArea、CheckBox、Int 候选输入、Select、Toggle、Slider、Summary、Segmented、Choice、Color、Chips、Custom 和 Button")
        showHeaderDivider: true
        clearFocusOnTap: true
        padding: 0
        contentSpacing: gallery.density.paneContentSpacing

        Form.AppFormContent {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            formData: root.demoFormData

            onFieldEdited: {
                switch (fieldKey) {
                case "name":
                    nameField.value = value
                    break
                case "refreshRate":
                    refreshField.value = value
                    break
                case "threshold":
                    thresholdField.value = value
                    break
                case "region":
                    regionField.value = value
                    break
                case "enabled":
                    enabledField.value = value
                    break
                case "intensity":
                    intensityField.value = value
                    break
                case "quality":
                    segmentedField.value = value
                    break
                case "accent":
                    choiceField.value = value
                    break
                case "color":
                    colorField.value = value
                    break
                case "custom":
                    customField.value = value
                    break
                default:
                    break
                }

                gallery.lastEvent = qsTr("字段 %1：%2").arg(fieldKey).arg(String(value))
            }

            onActionTriggered: {
                gallery.lastEvent = qsTr("Action：%1").arg(actionId)
                if (actionId === "gallery.runAction")
                    galleryPopup.open()
            }
        }
    }
}
