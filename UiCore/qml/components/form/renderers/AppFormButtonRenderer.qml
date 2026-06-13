import QtQuick 2.14
import QtQuick.Layouts 1.14
import "../../../foundation"
import "../../base" as Base

Base.AppButton {
    id: root

    property var formBridge: null
    property var controlData: ({})

    readonly property var bridge: formBridge
    readonly property var controlDataRef: controlData

    objectName: bridge
        ? "action:" + String(bridge.controlValue(controlDataRef, "actionId", ""))
        : ""
    Layout.fillWidth: true
    theme: bridge ? bridge.resolvedTheme : null
    variant: bridge
        ? bridge.controlValue(
            controlDataRef,
            "variant",
            AppUiEnums.ButtonVariant.Secondary
        )
        : AppUiEnums.ButtonVariant.Secondary
    text: bridge
        ? String(bridge.controlValue(controlDataRef, "text", bridge.controlValue(controlDataRef, "value", "")))
        : ""

    onClicked: {
        if (bridge) {
            bridge.actionTriggered(
                String(bridge.controlValue(controlDataRef, "actionId", "")),
                bridge.normalizeActionPayload(bridge.controlValue(controlDataRef, "payload", ({})))
            )
        }
    }
}
