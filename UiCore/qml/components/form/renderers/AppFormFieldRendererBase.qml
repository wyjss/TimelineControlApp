import QtQuick 2.14
import QtQuick.Layouts 1.14
import "../../base" as Base

Base.AppFieldBlock {
    id: root

    property var formBridge: null
    property var controlData: ({})

    readonly property var bridge: formBridge
    readonly property var controlDataRef: controlData

    objectName: bridge ? "field:" + bridge.controlKey(controlDataRef) : ""
    Layout.fillWidth: true
    theme: bridge ? bridge.resolvedTheme : null
    label: bridge ? String(bridge.controlValue(controlDataRef, "label", "")) : ""
    subtitle: bridge ? String(bridge.controlValue(controlDataRef, "subtitle", "")) : ""
}
