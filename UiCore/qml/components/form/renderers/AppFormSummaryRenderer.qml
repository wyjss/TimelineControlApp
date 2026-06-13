import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "../../../foundation"
import "../../base" as Base

AppFormFieldRendererBase {
    id: root
    fieldControl: summarySurface
    fieldContentFillWidth: true
    showUnderline: false

    Base.AppSurface {
        id: summarySurface

        readonly property string displayText: bridge
            ? String(bridge.controlValue(controlDataRef, "value", bridge.controlValue(controlDataRef, "text", "")))
            : ""

        Layout.fillWidth: true
        theme: root.theme
        surfaceTone: bridge ? bridge.controlSurfaceTone(controlDataRef, "section") : "section"
        shapeRole: AppUiEnums.ShapeRole.Control
        padding: 8
        strokeWidth: 1
        interactive: false
        clipContent: true
        ToolTip.text: displayText
        ToolTip.visible: summaryHover.hovered && summaryText.truncated
        ToolTip.delay: 450
        ToolTip.timeout: 5000

        HoverHandler {
            id: summaryHover
        }

        Base.AppText {
            id: summaryText
            objectName: bridge ? "summaryText:" + bridge.controlKey(controlDataRef) : ""
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: summarySurface.displayText
            theme: root.theme
            styleRole: "bodyM"
            textTone: bridge ? bridge.controlTextTone(controlDataRef, "primary") : "primary"
            elide: Text.ElideRight
        }
    }
}
