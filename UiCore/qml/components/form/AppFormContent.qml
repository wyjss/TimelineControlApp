import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtQml 2.14
import QtQuick.Window 2.14
import "../../foundation"
import "../../foundation/AppBridgeUtils.js" as BridgeUtils
import "../base" as Base
import "renderers" as Renderers

Item {
    id: root

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
    property var formData: ({})
    // true: 折叠 section 中的字段 renderer 不创建，展开时再按需加载。
    property bool lazyCollapsedSections: true

    signal fieldEdited(string fieldKey, var value)
    signal actionTriggered(string actionId, var payload)

    function controlValue(controlData, key, fallback) {
        return BridgeUtils.controlValue(controlData, key, fallback)
    }

    function controlKind(controlData) {
        return AppUiEnums.normalizeFormFieldKind(
            controlValue(
                controlData,
                "kind",
                AppUiEnums.FormFieldKind.TextField
            )
        )
    }

    function formNodeKind(nodeData) {
        var explicitKind = controlValue(nodeData, "formNodeKind", -1)

        return explicitKind === -1
            ? -1
            : AppUiEnums.normalizeFormNodeKind(explicitKind)
    }

    function isTypedFormNode(nodeData, expectedKind) {
        return formNodeKind(nodeData) === expectedKind
    }

    function controlKey(controlData) {
        return BridgeUtils.controlKey(controlData)
    }

    function layoutModeName(value) {
        switch (AppUiEnums.normalizeLayoutMode(value)) {
        case AppUiEnums.LayoutMode.Horizontal:
            return "horizontal"
        case AppUiEnums.LayoutMode.Vertical:
            return "vertical"
        default:
            return "auto"
        }
    }

    function normalizeFieldValue(value) {
        return BridgeUtils.normalizeFieldValue(value)
    }

    function normalizeActionPayload(payload) {
        return BridgeUtils.objectPayload(payload)
    }

    function controlTextTone(controlData, fallback) {
        return String(controlValue(controlData, "textTone", fallback))
    }

    function controlSurfaceTone(controlData, fallback) {
        return String(controlValue(controlData, "surfaceTone", fallback))
    }

    function emitFieldEdited(fieldKey, value) {
        root.fieldEdited(fieldKey, normalizeFieldValue(value))
    }

    function colorValue(name, fallback) {
        return resolvedTheme && resolvedTheme.colors && resolvedTheme.colors[name] !== undefined
            ? resolvedTheme.colors[name]
            : fallback
    }

    function commitExpanded(target, nextExpanded) {
        return BridgeUtils.commitExpanded(target, nextExpanded)
    }

    function sectionExpansionPayload(sectionData, sectionIndex, nextExpanded) {
        return {
            "sectionIndex": Number(sectionIndex),
            "sectionKey": root.controlKey(sectionData),
            "sectionTitle": String(root.controlValue(sectionData, "title", "")),
            "expanded": !!nextExpanded
        }
    }

    function nodeCount(source, countKey, listKey) {
        var explicitCount = Number(controlValue(source, countKey, -1))
        if (explicitCount >= 0)
            return explicitCount

        var values = controlValue(source, listKey, [])
        return values && values.length !== undefined ? values.length : 0
    }

    function nodeAt(source, index, getterName, listKey) {
        try {
            if (source !== undefined && source !== null && source[getterName] !== undefined)
                return source[getterName](index)
        } catch (error) {
        }

        var values = controlValue(source, listKey, [])
        return values && index >= 0 && index < values.length ? values[index] : ({})
    }

    function sectionControlCount(sectionData) {
        if (isTypedFormNode(sectionData, AppUiEnums.FormNodeKind.Section))
            return nodeCount(sectionData, "fieldCount", "fields")

        var explicitCount = Number(controlValue(sectionData, "controlCount", -1))
        if (explicitCount >= 0)
            return explicitCount

        var controls = controlValue(sectionData, "controls", null)
        if (controls !== null && controls !== undefined && controls.length !== undefined)
            return controls.length

        return nodeCount(sectionData, "fieldCount", "fields")
    }

    function sectionControlAt(sectionData, index) {
        try {
            if (sectionData !== undefined && sectionData !== null && sectionData.fieldAt !== undefined)
                return sectionData.fieldAt(index)
        } catch (error) {
        }

        var controls = controlValue(sectionData, "controls", null)
        if (controls !== null && controls !== undefined)
            return index >= 0 && index < controls.length ? controls[index] : ({})

        return nodeAt(sectionData, index, "fieldAt", "fields")
    }

    readonly property int sectionModelCount: nodeCount(formData, "sectionCount", "sections")
    readonly property int resolvedLayoutModeValue: AppUiEnums.normalizeLayoutMode(
        controlValue(formData, "layoutMode", AppUiEnums.LayoutMode.Horizontal)
    )
    readonly property string resolvedLayoutMode: layoutModeName(resolvedLayoutModeValue)
    readonly property int horizontalBreakpoint: Number(controlValue(formData, "horizontalBreakpoint", 840))
    readonly property int labelWidth: Number(controlValue(formData, "labelWidth", 156))
    readonly property int fieldSpacing: Number(controlValue(formData, "fieldSpacing", 12))
    readonly property int sectionSpacing: Number(controlValue(formData, "sectionSpacing", 12))
    readonly property bool showFieldDividers: !!controlValue(formData, "showFieldDividers", false)
    readonly property bool showFieldUnderline: !!controlValue(formData, "showFieldUnderline", false)
    readonly property string fieldUnderlineScope: String(controlValue(formData, "underlineScope", "field"))
    readonly property int fieldDividerGap: 8
    readonly property int fieldDividerThickness: 1

    implicitHeight: formColumn.implicitHeight

    ColumnLayout {
        id: formColumn

        anchors.left: parent ? parent.left : undefined
        anchors.right: parent ? parent.right : undefined
        anchors.top: parent ? parent.top : undefined
        spacing: root.sectionSpacing

        Repeater {
            model: root.sectionModelCount

            delegate: Base.AppSection {
                id: sectionPane

                readonly property var sectionData: root.nodeAt(root.formData, index, "sectionAt", "sections")
                readonly property string sectionTitle: root.controlValue(sectionData, "title", "")
                readonly property int controlCount: root.sectionControlCount(sectionData)
                readonly property bool sectionCollapsible: !!root.controlValue(sectionData, "collapsible", false)
                readonly property bool modelExpanded: !!root.controlValue(sectionData, "expanded", true)
                property bool sectionExpandedState: modelExpanded

                objectName: "section:" + root.controlKey(sectionData)
                Layout.fillWidth: true
                theme: root.resolvedTheme
                surfaced: false
                compact: true
                padding: 0
                spacing: sectionTitle.length > 0 || sectionCollapsible
                    ? (root.showFieldDividers ? 8 : 0)
                    : 0
                contentSpacing: root.showFieldDividers ? 0 : 8
                title: sectionTitle
                titleRole: "label"
                showSubtitle: false
                collapsible: sectionCollapsible
                onToggled: {
                    sectionExpandedState = expanded
                    root.commitExpanded(sectionData, expanded)
                    root.actionTriggered(
                        "form.sectionExpandedChanged",
                        root.sectionExpansionPayload(sectionData, index, expanded)
                    )
                }

                onModelExpandedChanged: {
                    if (sectionExpandedState !== modelExpanded)
                        sectionExpandedState = modelExpanded
                }

                Binding {
                    target: sectionPane
                    property: "expanded"
                    value: sectionPane.sectionExpandedState
                }

                AppFieldForm {
                    Layout.fillWidth: true
                    theme: root.resolvedTheme
                    layoutMode: root.controlValue(sectionData, "layoutMode", root.resolvedLayoutModeValue)
                    horizontalBreakpoint: Number(
                        root.controlValue(sectionData, "horizontalBreakpoint", root.horizontalBreakpoint)
                    )
                    labelWidth: Number(root.controlValue(sectionData, "labelWidth", root.labelWidth))
                    fieldSpacing: Number(root.controlValue(sectionData, "fieldSpacing", root.fieldSpacing))
                    sectionSpacing: Number(
                        root.controlValue(
                            sectionData,
                            "sectionSpacing",
                            root.showFieldDividers ? 0 : root.fieldSpacing
                        )
                    )
                    contentPadding: 0
                    maxContentWidth: -1
                    showDivider: false
                    showUnderline: !!root.controlValue(
                        sectionData,
                        "showFieldUnderline",
                        root.showFieldUnderline
                    )
                    underlineScope: String(
                        root.controlValue(
                            sectionData,
                            "underlineScope",
                            root.fieldUnderlineScope
                        )
                    )

                    Repeater {
                        model: sectionPane.controlCount

                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            readonly property var controlData: root.sectionControlAt(sectionPane.sectionData, index)
                            readonly property bool showDivider: !!root.controlValue(
                                sectionPane.sectionData,
                                "showFieldDividers",
                                root.showFieldDividers
                            ) && index < sectionPane.controlCount - 1

                            Item {
                                Layout.fillWidth: true
                                Layout.bottomMargin: showDivider ? root.fieldDividerGap : 0
                                implicitHeight: controlLoader.item ? controlLoader.item.implicitHeight : 0

                                Loader {
                                    id: controlLoader

                                    width: parent ? parent.width : 0
                                    height: item ? item.implicitHeight : 0
                                    active: !root.lazyCollapsedSections
                                        || !sectionPane.sectionCollapsible
                                        || sectionPane.expanded

                                    readonly property var controlData: root.sectionControlAt(sectionPane.sectionData, index)
                                    sourceComponent: {
                                        if (!active)
                                            return null

                                        switch (root.controlKind(controlData)) {
                                        case AppUiEnums.FormFieldKind.Summary:
                                            return summaryComponent
                                        case AppUiEnums.FormFieldKind.Segmented:
                                            return segmentedComponent
                                        case AppUiEnums.FormFieldKind.Choice:
                                            return choiceComponent
                                        case AppUiEnums.FormFieldKind.Toggle:
                                            return toggleComponent
                                        case AppUiEnums.FormFieldKind.Slider:
                                            return sliderComponent
                                        case AppUiEnums.FormFieldKind.Color:
                                            return colorComponent
                                        case AppUiEnums.FormFieldKind.Custom:
                                            return customComponent
                                        case AppUiEnums.FormFieldKind.Chips:
                                            return chipsComponent
                                        case AppUiEnums.FormFieldKind.Select:
                                            return selectComponent
                                        case AppUiEnums.FormFieldKind.Button:
                                            return buttonComponent
                                        default:
                                            return textFieldComponent
                                        }
                                    }

                                    Binding {
                                        when: !!controlLoader.item && controlLoader.item.width !== undefined
                                        target: controlLoader.item
                                        property: "width"
                                        value: controlLoader.width
                                    }

                                    Binding {
                                        when: !!controlLoader.item
                                            && controlLoader.item.formBridge !== undefined
                                        target: controlLoader.item
                                        property: "formBridge"
                                        value: root
                                    }

                                    Binding {
                                        when: !!controlLoader.item
                                            && controlLoader.item.controlData !== undefined
                                        target: controlLoader.item
                                        property: "controlData"
                                        value: controlLoader.controlData
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.fieldDividerThickness
                                Layout.bottomMargin: showDivider ? root.fieldDividerGap : 0
                                visible: showDivider
                                color: root.colorValue("border", "#334155")
                                opacity: 0.58
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: summaryComponent

        Renderers.AppFormSummaryRenderer {
        }
    }

    Component {
        id: segmentedComponent

        Renderers.AppFormSegmentedRenderer {
        }
    }

    Component {
        id: choiceComponent

        Renderers.AppFormChoiceRenderer {
        }
    }

    Component {
        id: toggleComponent

        Renderers.AppFormToggleRenderer {
        }
    }

    Component {
        id: sliderComponent

        Renderers.AppFormSliderRenderer {
        }
    }

    Component {
        id: colorComponent

        Renderers.AppFormColorRenderer {
        }
    }

    Component {
        id: customComponent

        Renderers.AppFormCustomFieldRenderer {
        }
    }

    Component {
        id: textFieldComponent

        Renderers.AppFormTextFieldRenderer {
        }
    }

    Component {
        id: selectComponent

        Renderers.AppFormSelectRenderer {
        }
    }

    Component {
        id: chipsComponent

        Renderers.AppFormChipsRenderer {
        }
    }

    Component {
        id: buttonComponent

        Renderers.AppFormButtonRenderer {
        }
    }
}
