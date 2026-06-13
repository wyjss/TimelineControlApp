import QtQuick 2.14
import QtQuick.Layouts 1.14
import "../../../foundation"
import "../../base" as Base

AppFormFieldRendererBase {
    id: root

    readonly property string resolvedValue: bridge ? String(bridge.controlValue(controlDataRef, "value", "")) : ""
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

        Layout.fillWidth: true
        theme: root.theme
        surfaceTone: bridge ? bridge.controlSurfaceTone(controlDataRef, "section") : "section"
        appearance: bridge
            ? bridge.controlValue(
                controlDataRef,
                "appearance",
                AppUiEnums.ControlAppearance.Filled
            )
            : AppUiEnums.ControlAppearance.Filled
        placeholderText: bridge ? String(bridge.controlValue(controlDataRef, "placeholderText", "")) : ""
        readOnly: bridge ? !!bridge.controlValue(controlDataRef, "readOnly", false) : false

        onTextChanged: {
            if (bridge && !root.syncingResolvedValue)
                bridge.emitFieldEdited(bridge.controlKey(controlDataRef), text)
        }

        onActiveFocusChanged: {
            if (!activeFocus)
                root.syncResolvedValue()
        }
    }

    onResolvedValueChanged: syncResolvedValue()
    Component.onCompleted: syncResolvedValue()
}
