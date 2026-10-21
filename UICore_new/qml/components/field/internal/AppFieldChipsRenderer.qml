import QtQuick 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "../../base" as Base

AppFieldRendererBase {
    id: root

    readonly property var chipItems: bridge ? bridge.fieldValue("items", []) : []
    fieldControl: chipsRow
    fieldContentFillWidth: true

    RowLayout {
        id: chipsRow

        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: root.chipItems

            delegate: Base.AppBadge {
                Layout.fillWidth: true
                surfaceTone: modelData && modelData.active
                    ? UiStyle.SurfaceTone.Highlight
                    : UiStyle.SurfaceTone.Control
                strokeWidth: modelData && modelData.active ? 0 : 1
                text: modelData && modelData.label !== undefined ? String(modelData.label) : ""
                textTone: modelData && modelData.active
                    ? UiStyle.TextTone.Accent
                    : UiStyle.TextTone.Secondary
            }
        }
    }
}
