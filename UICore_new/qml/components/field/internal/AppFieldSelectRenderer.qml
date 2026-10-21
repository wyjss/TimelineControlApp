import QtQuick 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "../../base" as Base

AppFieldRendererBase {
    id: root
    fieldControl: selectControl
    fieldContentFillWidth: true

    Base.AppSelect {
        id: selectControl

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
        options: bridge ? bridge.fieldValue("options", []) : []
        placeholderText: bridge ? String(bridge.fieldValue("placeholderText", "")) : ""
        readOnly: bridge ? !!bridge.fieldValue("readOnly", false) : false
        value: bridge ? bridge.fieldValue("value", undefined) : undefined

        onValueSelected: {
            if (bridge)
                bridge.emitValueEdited(nextValue)
        }
    }
}
