import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "../../foundation/AppBridgeUtils.js" as BridgeUtils
import "../base" as Base
import "../form" as Form

Base.AppPanel {
    id: root

    property QtObject inspectorObject: null
    property var inspectorData: ({})

    signal fieldEdited(string fieldKey, var value)
    signal actionTriggered(string actionId, var payload)

    function controlValue(controlData, key, fallback) {
        return BridgeUtils.controlValue(controlData, key, fallback)
    }

    readonly property var resolvedInspectorSource: inspectorObject !== null ? inspectorObject : inspectorData

    readonly property string resolvedTitle: String(controlValue(resolvedInspectorSource, "title", ""))
    readonly property string resolvedSubtitle: String(controlValue(resolvedInspectorSource, "subtitle", ""))
    readonly property bool resolvedCollapsible: !!controlValue(resolvedInspectorSource, "collapsible", false)
    readonly property bool resolvedExpanded: !!controlValue(resolvedInspectorSource, "expanded", true)
    readonly property bool showFieldDividers: !!controlValue(resolvedInspectorSource, "showFieldDividers", false)
    readonly property bool hasExplicitHeaderDivider: !!controlValue(resolvedInspectorSource, "hasExplicitHeaderDivider", false)
    readonly property bool resolvedHeaderDivider: hasExplicitHeaderDivider
        ? !!controlValue(resolvedInspectorSource, "showHeaderDivider", false)
        : showFieldDividers

    function commitExpanded(target, nextExpanded) {
        return BridgeUtils.commitExpanded(target, nextExpanded)
    }

    compact: true
    surfaceTone: "surfaceOverlay"
    contentSpacing: 0
    title: resolvedTitle
    subtitle: resolvedSubtitle
    collapsible: resolvedCollapsible
    showHeaderDivider: resolvedHeaderDivider
    property bool expandedState: resolvedExpanded
    onResolvedExpandedChanged: {
        if (expandedState !== resolvedExpanded)
            expandedState = resolvedExpanded
    }
    onToggled: {
        expandedState = expanded
        root.commitExpanded(root.resolvedInspectorSource, expanded)
        root.actionTriggered("inspector.expandedChanged", {
            "expanded": !!expanded
        })
    }

    Binding {
        target: root
        property: "expanded"
        value: root.expandedState
    }

    Base.AppScrollPane {
        id: rightPanelScroll

        Layout.fillWidth: true
        Layout.fillHeight: true
        theme: root.resolvedTheme
        contentSpacing: 0

        Form.AppFormContent {
            Layout.fillWidth: true
            theme: root.resolvedTheme
            formData: root.resolvedInspectorSource
            onFieldEdited: function(fieldKey, value) {
                root.fieldEdited(fieldKey, value)
            }
            onActionTriggered: function(actionId, payload) {
                root.actionTriggered(actionId, payload)
            }
        }
    }
}

