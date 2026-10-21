import QtQuick 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "../../base" as Base

Base.AppButton {
    id: root

    property var fieldBridge: null

    readonly property var bridge: fieldBridge

    objectName: bridge
        ? "action:" + String(bridge.fieldValue("actionId", ""))
        : ""
    Layout.fillWidth: true
    variant: bridge
        ? bridge.fieldValue(
            "variant",
            UiStyle.ButtonVariant.Subtle
        )
        : UiStyle.ButtonVariant.Subtle
    text: bridge
        ? String(bridge.fieldValue("text", bridge.fieldValue("value", "")))
        : ""

    onClicked: {
        if (bridge) {
            bridge.actionTriggered(
                String(bridge.fieldValue("actionId", "")),
                bridge.objectPayload(bridge.fieldValue("payload", ({})))
            )
        }
    }
}
