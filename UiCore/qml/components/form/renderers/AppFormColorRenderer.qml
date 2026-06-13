import QtQuick 2.14
import QtQuick.Layouts 1.14
import QtQml 2.14
import "../../base" as Base

AppFormFieldRendererBase {
    id: root
    fieldControl: colorControl
    fieldContentFillWidth: true

    Base.AppColorControl {
        id: colorControl

        Layout.fillWidth: true
        theme: root.theme
        surfaceTone: bridge ? bridge.controlSurfaceTone(controlDataRef, "section") : "section"
        placeholderText: bridge
            ? String(bridge.controlValue(controlDataRef, "placeholderText", "#A8C7FA"))
            : "#A8C7FA"

        onValueEdited: {
            if (bridge)
                bridge.emitFieldEdited(bridge.controlKey(controlDataRef), nextValue)
        }
    }

    resources: [
        Binding {
            target: colorControl
            property: "value"
            value: bridge ? bridge.controlValue(controlDataRef, "value", "") : ""
        }
    ]
}
