import QtQuick 2.14
import QtQuick.Layouts 1.14
import "../../../foundation"
import "../../base" as Base

AppFormFieldRendererBase {
    id: root

    readonly property var chipItems: bridge ? bridge.controlValue(controlDataRef, "items", []) : []
    fieldControl: chipsRow
    fieldContentFillWidth: true

    RowLayout {
        id: chipsRow

        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: root.chipItems

            delegate: Base.AppSurface {
                Layout.fillWidth: true
                Layout.preferredHeight: root.theme && root.theme.density
                    ? root.theme.density.chipHeight
                    : 32
                sizeToContent: false
                theme: root.theme
                surfaceTone: modelData && modelData.active ? "highlight" : "section"
                shapeRole: AppUiEnums.ShapeRole.Pill
                strokeWidth: modelData && modelData.active ? 0 : 1

                Base.AppText {
                    anchors.centerIn: parent
                    text: modelData && modelData.label !== undefined ? String(modelData.label) : ""
                    theme: root.theme
                    styleRole: "bodyS"
                    textTone: modelData && modelData.active ? "accent" : "secondary"
                }
            }
        }
    }
}
