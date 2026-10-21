import QtQuick 2.14
import QtQuick.Layouts 1.14
import QtQml 2.14
import "../../base" as Base

AppFieldRendererBase {
    id: root
    fieldControl: toggleControl
    fieldContentFillWidth: false
    fieldContentAlignment: "end"

    Base.AppToggleControl {
        id: toggleControl

        Accessible.name: bridge ? String(bridge.fieldValue("label", "")) : ""

        onToggled: {
            if (bridge)
                bridge.emitValueEdited(toggleControl.checked)
        }
    }

    resources: [
        Binding {
            target: toggleControl
            property: "checked"
            value: bridge ? !!bridge.fieldValue("value", false) : false
        }
    ]
}
