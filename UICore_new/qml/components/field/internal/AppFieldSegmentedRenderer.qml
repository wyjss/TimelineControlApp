import QtQuick 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "../../base" as Base

AppFieldRendererBase {
    id: root
    fieldControl: segmentedControl
    fieldContentFillWidth: true

    Base.AppSegmentedControl {
        id: segmentedControl

        Accessible.name: bridge ? String(bridge.fieldValue("label", "")) : ""
        Layout.fillWidth: true
        surfaceTone: bridge
            ? bridge.fieldSurfaceTone(UiStyle.SurfaceTone.Control)
            : UiStyle.SurfaceTone.Control
        options: bridge ? bridge.fieldValue("options", []) : []
        value: bridge ? bridge.fieldValue("value", undefined) : undefined

        onValueSelected: {
            if (bridge)
                bridge.emitValueEdited(nextValue)
        }
    }
}
