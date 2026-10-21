import QtQuick 2.14
import QtQuick.Layouts 1.14
import UICore.Fields 1.0
import UICore.Style 1.0
import "../../base" as Base

AppFieldRendererBase {
    id: root

    readonly property int valueType: bridge
        ? Number(bridge.fieldValue("valueType", BaseField.VariantType))
        : BaseField.VariantType
    readonly property bool acceptsCustomValue: valueType !== BaseField.EnumType
        && bridge
        && !!bridge.fieldValue("allowCustomValue", false)
    readonly property string resolvedValue: bridge ? String(bridge.fieldValue("value", "")) : ""
    property bool syncingResolvedValue: false

    fieldControl: textFieldControl
    fieldContentFillWidth: true

    function syncResolvedValue() {
        if (!textFieldControl.activeFocus && textFieldControl.text !== resolvedValue) {
            syncingResolvedValue = true
            textFieldControl.text = resolvedValue
            syncingResolvedValue = false
        }
    }

    Base.AppTextField {
        id: textFieldControl

        Accessible.name: bridge ? String(bridge.fieldValue("label", "")) : ""
        Layout.fillWidth: true
        surfaceTone: bridge
            ? bridge.fieldSurfaceTone(UiStyle.SurfaceTone.Control)
            : UiStyle.SurfaceTone.Control
        appearance: bridge
            ? bridge.fieldValue(
                "appearance",
                root.defaultAppearance
            )
            : root.defaultAppearance
        placeholderText: bridge ? String(bridge.fieldValue("placeholderText", "")) : ""
        options: root.acceptsCustomValue
            ? bridge.fieldValue("options", [])
            : []
        readOnly: bridge ? !!bridge.fieldValue("readOnly", false) : false

        onTextChanged: {
            if (!bridge || root.syncingResolvedValue)
                return

            switch (root.valueType) {
            case BaseField.IntType:
                if (/^[+-]?\d+$/.test(text))
                    bridge.emitValueEdited(parseInt(text, 10))
                break
            case BaseField.DoubleType:
                if (text.trim().length > 0 && !isNaN(Number(text)))
                    bridge.emitValueEdited(Number(text))
                break
            default:
                bridge.emitValueEdited(text)
                break
            }
        }

        onActiveFocusChanged: {
            if (!activeFocus)
                root.syncResolvedValue()
        }
    }

    onResolvedValueChanged: syncResolvedValue()
    Component.onCompleted: syncResolvedValue()
}
