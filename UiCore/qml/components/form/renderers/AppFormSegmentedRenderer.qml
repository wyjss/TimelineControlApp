import QtQuick 2.14
import QtQuick.Layouts 1.14
import QtQml 2.14
import "../../base" as Base

AppFormFieldRendererBase {
    id: root
    fieldControl: segmentedControl
    fieldContentFillWidth: true

    Base.AppSegmentedControl {
        id: segmentedControl

        Layout.fillWidth: true
        theme: root.theme
        surfaceTone: bridge ? bridge.controlSurfaceTone(controlDataRef, "surface") : "surface"
        options: bridge ? bridge.controlValue(controlDataRef, "options", []) : []

        onValueSelected: {
            if (bridge)
                bridge.emitFieldEdited(bridge.controlKey(controlDataRef), nextValue)
        }
    }

    resources: [
        Binding {
            target: segmentedControl
            property: "value"
            value: bridge ? bridge.controlValue(controlDataRef, "value", undefined) : undefined
        }
    ]
}
