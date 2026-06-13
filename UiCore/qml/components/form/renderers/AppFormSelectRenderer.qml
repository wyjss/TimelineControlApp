import QtQuick 2.14
import QtQuick.Layouts 1.14
import QtQml 2.14
import "../../../foundation"
import "../../base" as Base

AppFormFieldRendererBase {
    id: root
    fieldControl: selectControl
    fieldContentFillWidth: true

    Base.AppSelect {
        id: selectControl

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
        options: bridge ? bridge.controlValue(controlDataRef, "options", []) : []
        placeholderText: bridge ? String(bridge.controlValue(controlDataRef, "placeholderText", "")) : ""

        onValueSelected: {
            if (bridge)
                bridge.emitFieldEdited(bridge.controlKey(controlDataRef), nextValue)
        }
    }

    resources: [
        Binding {
            target: selectControl
            property: "value"
            value: bridge ? bridge.controlValue(controlDataRef, "value", undefined) : undefined
        }
    ]
}
