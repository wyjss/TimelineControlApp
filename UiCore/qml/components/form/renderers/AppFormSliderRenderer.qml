import QtQuick 2.14
import QtQuick.Layouts 1.14
import QtQml 2.14
import "../../base" as Base

AppFormFieldRendererBase {
    id: root
    fieldControl: sliderControl
    fieldContentFillWidth: true

    Base.AppSliderControl {
        id: sliderControl

        Layout.fillWidth: true
        theme: root.theme
        surfaceTone: bridge ? bridge.controlSurfaceTone(controlDataRef, "section") : "section"
        from: bridge
            ? Number(bridge.controlValue(controlDataRef, "min", bridge.controlValue(controlDataRef, "minimum", 0)))
            : 0
        to: bridge
            ? Number(bridge.controlValue(controlDataRef, "max", bridge.controlValue(controlDataRef, "maximum", 100)))
            : 100
        stepSize: bridge ? Number(bridge.controlValue(controlDataRef, "stepSize", 1)) : 1
        suffix: bridge ? String(bridge.controlValue(controlDataRef, "suffix", "")) : ""

        onValueEdited: {
            if (bridge)
                bridge.emitFieldEdited(bridge.controlKey(controlDataRef), nextValue)
        }
    }

    resources: [
        Binding {
            target: sliderControl
            property: "value"
            value: bridge ? Number(bridge.controlValue(controlDataRef, "value", 0)) : 0
        }
    ]
}
