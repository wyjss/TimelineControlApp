import QtQuick 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "../../base" as Base

AppFieldRendererBase {
    id: root
    fieldControl: sliderControl
    fieldContentFillWidth: true

    Base.AppSliderControl {
        id: sliderControl

        Layout.fillWidth: true
        surfaceTone: bridge
            ? bridge.fieldSurfaceTone(UiStyle.SurfaceTone.Control)
            : UiStyle.SurfaceTone.Control
        from: bridge
            ? Number(bridge.fieldValue("min", bridge.fieldValue("minimum", 0)))
            : 0
        to: bridge
            ? Number(bridge.fieldValue("max", bridge.fieldValue("maximum", 100)))
            : 100
        value: bridge ? Number(bridge.fieldValue("value", 0)) : 0
        stepSize: bridge ? Number(bridge.fieldValue("stepSize", 1)) : 1
        suffix: bridge ? String(bridge.fieldValue("suffix", "")) : ""

        onValueEdited: {
            if (bridge)
                bridge.emitValueEdited(nextValue)
        }
    }
}
