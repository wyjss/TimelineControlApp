import QtQuick 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "../../base" as Base

Base.AppFieldBlock {
    id: root

    property var fieldBridge: null

    readonly property var bridge: fieldBridge
    readonly property int defaultAppearance: inheritedFieldFormContext
        && inheritedFieldFormContext.fieldAppearance !== undefined
        ? inheritedFieldFormContext.fieldAppearance
        : UiStyle.ControlAppearance.Filled

    function fieldText(key) {
        var value = bridge ? bridge.fieldValue(key, "") : ""
        return value === null || value === undefined ? "" : String(value)
    }

    objectName: bridge ? "field:" + bridge.fieldKey() : ""
    Layout.fillWidth: true
    label: fieldText("label")
    subtitle: fieldText("subtitle")
    required: bridge ? !!bridge.fieldValue("required", false) : false
    errorText: fieldText("errorText")
}
