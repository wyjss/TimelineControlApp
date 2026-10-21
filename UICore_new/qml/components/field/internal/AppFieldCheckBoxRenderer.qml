import QtQuick 2.14
import QtQuick.Layouts 1.14
import QtQml 2.14
import UICore.Style 1.0
import "../../base" as Base

AppFieldRendererBase {
    id: root

    fieldControl: checkBoxControl
    fieldContentFillWidth: false
    fieldContentAlignment: "end"

    Base.AppCheckBox {
        id: checkBoxControl

        Accessible.name: root.fieldText("label")
        Accessible.description: root.fieldText("errorText")
        surfaceTone: bridge
            ? bridge.fieldSurfaceTone(UiStyle.SurfaceTone.Control)
            : UiStyle.SurfaceTone.Control

        onToggled: {
            if (bridge)
                bridge.emitValueEdited(checked)
        }
    }

    resources: [
        Binding {
            target: checkBoxControl
            property: "checked"
            value: bridge ? !!bridge.fieldValue("value", false) : false
        }
    ]
}
