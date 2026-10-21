import QtQuick 2.14
import QtQuick.Layouts 1.14
import UICore.Fields 1.0
import UICore.Style 1.0
import "../../base" as Base

AppFieldRendererBase {
    id: root

    readonly property int valueType: bridge
        ? Number(bridge.fieldValue("valueType", BaseField.DoubleType))
        : BaseField.DoubleType
    readonly property bool integerMode: valueType === BaseField.IntType
    readonly property bool acceptsCustomValue: bridge
        && !!bridge.fieldValue("allowCustomValue", false)

    function decimalsForStep(rawStepSize) {
        var parts = String(Math.abs(Number(rawStepSize))).toLowerCase().split("e")
        var decimalIndex = parts[0].indexOf(".")
        var fractionDigits = decimalIndex < 0 ? 0 : parts[0].length - decimalIndex - 1
        return Math.max(0, fractionDigits - (parts.length > 1 ? Number(parts[1]) : 0))
    }

    fieldControl: numberFieldControl
    fieldContentFillWidth: true

    Base.AppNumberField {
        id: numberFieldControl

        Accessible.name: bridge ? String(bridge.fieldValue("label", "")) : ""
        Layout.fillWidth: true
        value: bridge ? Number(bridge.fieldValue("value", 0)) : 0
        integerMode: root.integerMode
        minimum: bridge ? Number(bridge.fieldValue("minimum", 0)) : 0
        maximum: bridge ? Number(bridge.fieldValue("maximum", 100)) : 100
        decimals: root.integerMode
            ? 0
            : Math.max(2, root.decimalsForStep(bridge ? bridge.fieldValue("stepSize", 1) : 1))
        suffix: bridge ? String(bridge.fieldValue("suffix", "")) : ""
        surfaceTone: bridge
            ? bridge.fieldSurfaceTone(UiStyle.SurfaceTone.Control)
            : UiStyle.SurfaceTone.Control
        appearance: bridge
            ? bridge.fieldValue("appearance", root.defaultAppearance)
            : root.defaultAppearance
        placeholderText: bridge ? String(bridge.fieldValue("placeholderText", "")) : ""
        options: root.acceptsCustomValue
            ? bridge.fieldValue("options", [])
            : []
        readOnly: bridge ? !!bridge.fieldValue("readOnly", false) : false

        onValueEdited: {
            if (bridge)
                bridge.emitValueEdited(nextValue)
        }
    }
}
