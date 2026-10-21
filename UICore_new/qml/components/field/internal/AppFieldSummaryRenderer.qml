import QtQuick 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "../../base" as Base

AppFieldRendererBase {
    id: root
    fieldControl: summarySurface
    fieldContentFillWidth: true
    showUnderline: false

    Base.AppSurface {
        id: summarySurface

        readonly property string displayText: bridge
            ? String(bridge.fieldValue("value", bridge.fieldValue("text", "")))
            : ""

        Layout.fillWidth: true
        surfaceTone: bridge
            ? bridge.fieldSurfaceTone(UiStyle.SurfaceTone.Control)
            : UiStyle.SurfaceTone.Control
        shapeRole: UiStyle.ShapeRole.Control
        padding: 8
        strokeWidth: 1
        interactive: false
        clipContent: true

        HoverHandler {
            id: summaryHover
        }

        resources: [
            Loader {
                active: summaryText.truncated

                sourceComponent: Base.AppToolTip {
                    parent: summarySurface
                    text: summarySurface.displayText
                    visible: summaryHover.hovered && summaryText.truncated
                }
            }
        ]

        Base.AppText {
            id: summaryText
            objectName: bridge ? "summaryText:" + bridge.fieldKey() : ""
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: summarySurface.displayText
            styleRole: UiStyle.TypographyRole.BodyM
            textTone: bridge
                ? bridge.fieldValue(
                    "textTone",
                    UiStyle.TextTone.Primary
                )
                : UiStyle.TextTone.Primary
            elide: Text.ElideRight
        }
    }
}
