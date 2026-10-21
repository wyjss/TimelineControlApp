import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtQml 2.14
import QtQuick.Window 2.14
import UICore.Forms 1.0
import UICore.Style 1.0
import "../../foundation/AppBridgeUtils.js" as BridgeUtils
import "../base" as Base
import "../field" as Field

Item {
    id: root

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
    property var formData: ({})
    property real surfaceOpacityScale: 1.0
    // true: 折叠 section 中的字段 renderer 不创建，展开时再按需加载。
    property bool lazyCollapsedSections: true

    onCurrentWindowThemeChanged: {
        if (currentWindowTheme)
            _retainedTheme = currentWindowTheme
    }

    signal fieldEdited(string fieldKey, var value)
    signal actionTriggered(string actionId, var payload)

    function controlValue(controlData, key, fallback) {
        return BridgeUtils.controlValue(controlData, key, fallback)
    }

    function controlKey(controlData) {
        return BridgeUtils.controlKey(controlData)
    }

    function emitFieldEdited(fieldKey, value) {
        root.fieldEdited(fieldKey, BridgeUtils.normalizedValue(value))
    }

    function colorValue(name) {
        return resolvedTheme.colors[name]
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
        if (controlValue(sectionData, "formNodeKind", -1) === UiForm.NodeKind.Section)
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
    readonly property int resolvedLayoutModeValue: controlValue(
        formData,
        "layoutMode",
        UiStyle.LayoutMode.Horizontal
    )
    readonly property int horizontalBreakpoint: Number(controlValue(
        formData,
        "horizontalBreakpoint",
        resolvedTheme.metrics.layoutBreakpointMd
    ))
    readonly property int labelWidth: Number(controlValue(formData, "labelWidth", 156))
    readonly property int fieldSpacing: Number(controlValue(
        formData,
        "fieldSpacing",
        resolvedTheme.density.paneSpacing
    ))
    readonly property int sectionSpacing: Number(controlValue(
        formData,
        "sectionSpacing",
        resolvedTheme.density.paneSpacing
    ))
    readonly property bool showFieldDividers: !!controlValue(formData, "showFieldDividers", false)
    readonly property bool showFieldUnderline: !!controlValue(formData, "showFieldUnderline", false)
    readonly property string fieldUnderlineScope: String(controlValue(formData, "underlineScope", "field"))
    readonly property int fieldAppearance: controlValue(
        formData,
        "fieldAppearance",
        UiStyle.ControlAppearance.Filled
    )
    readonly property int fieldDividerGap: resolvedTheme.density.controlGap
    readonly property int fieldDividerThickness: resolvedTheme.density.dividerThickness

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
                readonly property bool fieldContentActive: !root.lazyCollapsedSections
                    || !sectionCollapsible
                    || expanded
                    || bodyVisible
                readonly property bool resolvedShowFieldDividers: !!root.controlValue(
                    sectionData,
                    "showFieldDividers",
                    root.showFieldDividers
                )
                property bool sectionExpandedState: modelExpanded

                objectName: "section:" + root.controlKey(sectionData)
                Layout.fillWidth: true
                surfaced: false
                surfaceOpacityScale: root.surfaceOpacityScale
                compact: true
                padding: 0
                spacing: sectionTitle.length > 0 || sectionCollapsible
                    ? root.resolvedTheme.density.controlGap * sectionPane.animatedBodyReveal
                    : 0
                contentSpacing: root.showFieldDividers
                    ? 0
                    : root.resolvedTheme.density.paneContentSpacing
                title: sectionTitle
                titleRole: UiStyle.TypographyRole.Label
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
                    layoutMode: root.controlValue(
                        sectionData,
                        "layoutMode",
                        root.resolvedLayoutModeValue
                    )
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
                    fieldAppearance: root.controlValue(
                        sectionData,
                        "fieldAppearance",
                        root.fieldAppearance
                    )

                    Repeater {
                        model: sectionPane.fieldContentActive ? sectionPane.controlCount : 0

                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            readonly property var controlData: root.sectionControlAt(sectionPane.sectionData, index)
                            readonly property bool showDivider: sectionPane.resolvedShowFieldDividers
                                && index < sectionPane.controlCount - 1

                            Field.AppFieldControl {
                                Layout.fillWidth: true
                                Layout.bottomMargin: showDivider ? root.fieldDividerGap : 0
                                fieldData: controlData

                                onValueEdited: {
                                    root.emitFieldEdited(root.controlKey(controlData), value)
                                }

                                onActionTriggered: {
                                    root.actionTriggered(actionId, payload)
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.fieldDividerThickness
                                Layout.bottomMargin: showDivider ? root.fieldDividerGap : 0
                                visible: showDivider
                                color: root.colorValue("border")
                                opacity: 0.52 * root.surfaceOpacityScale
                            }
                        }
                    }
                }
            }
        }
    }

}
