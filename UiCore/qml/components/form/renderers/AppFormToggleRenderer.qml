import QtQuick 2.14
import QtQuick.Layouts 1.14
import QtQml 2.14
import "../../base" as Base

AppFormFieldRendererBase {
    id: root
    fieldControl: toggleControl
    fieldContentFillWidth: false
    fieldContentAlignment: "end"

    Base.AppToggleControl {
        id: toggleControl

        theme: root.theme

        onToggled: {
            if (bridge)
                bridge.emitFieldEdited(bridge.controlKey(controlDataRef), nextChecked)
        }
    }

    resources: [
        Binding {
            target: toggleControl
            property: "checked"
            value: bridge ? !!bridge.controlValue(controlDataRef, "value", false) : false
        }
    ]
}
