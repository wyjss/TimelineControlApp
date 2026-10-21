import QtQuick 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "../../base" as Base

AppFieldRendererBase {
    id: root
    fieldControl: colorControl
    fieldContentFillWidth: true

    Base.AppColorControl {
        id: colorControl

        Layout.fillWidth: true
        surfaceTone: bridge
            ? bridge.fieldSurfaceTone(UiStyle.SurfaceTone.Control)
            : UiStyle.SurfaceTone.Control
        appearance: bridge
            ? bridge.fieldValue("appearance", root.defaultAppearance)
            : root.defaultAppearance
        placeholderText: bridge
            ? String(bridge.fieldValue("placeholderText", "#A8C7FA"))
            : "#A8C7FA"
        value: bridge ? bridge.fieldValue("value", "") : ""

        onValueEdited: {
            if (bridge)
                bridge.emitValueEdited(nextValue)
        }
    }
}
