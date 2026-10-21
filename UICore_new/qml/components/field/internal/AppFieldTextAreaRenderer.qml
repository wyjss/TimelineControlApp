import QtQuick 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "../../base" as Base

AppFieldRendererBase {
    id: root

    readonly property var rawResolvedValue: bridge ? bridge.fieldValue("value", "") : ""
    readonly property string resolvedValue: rawResolvedValue === null || rawResolvedValue === undefined
        ? ""
        : String(rawResolvedValue)
    property bool syncingResolvedValue: false

    fieldControl: textAreaControl
    fieldContentFillWidth: true

    function syncResolvedValue() {
        if (!textAreaControl.activeFocus && textAreaControl.text !== resolvedValue) {
            syncingResolvedValue = true
            textAreaControl.text = resolvedValue
            syncingResolvedValue = false
        }
    }

    Base.AppTextArea {
        id: textAreaControl

        Accessible.name: root.fieldText("label")
        Accessible.description: root.fieldText("errorText")
        Layout.fillWidth: true
        surfaceTone: bridge
            ? bridge.fieldSurfaceTone(UiStyle.SurfaceTone.Control)
            : UiStyle.SurfaceTone.Control
        appearance: bridge
            ? bridge.fieldValue("appearance", root.defaultAppearance)
            : root.defaultAppearance
        placeholderText: root.fieldText("placeholderText")
        readOnly: bridge ? !!bridge.fieldValue("readOnly", false) : false

        onTextChanged: {
            if (bridge && !root.syncingResolvedValue)
                bridge.emitValueEdited(text)
        }

        onActiveFocusChanged: {
            if (!activeFocus)
                root.syncResolvedValue()
        }
    }

    onResolvedValueChanged: syncResolvedValue()
    Component.onCompleted: syncResolvedValue()
}
