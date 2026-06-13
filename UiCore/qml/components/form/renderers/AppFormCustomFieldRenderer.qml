import QtQuick 2.14
import QtQuick.Layouts 1.14
import QtQml 2.14

Item {
    id: root

    property var formBridge: null
    property var controlData: ({})

    readonly property var bridge: formBridge
    readonly property var controlDataRef: controlData

    objectName: bridge ? "field:" + bridge.controlKey(controlDataRef) : ""
    Layout.fillWidth: true
    implicitHeight: Math.max(0, customLoader.item ? customLoader.item.implicitHeight : 0)

    Loader {
        id: customLoader

        width: parent ? parent.width : 0
        source: bridge ? bridge.controlValue(controlDataRef, "delegateSource", "") : ""
    }

    resources: [
        Binding {
            when: !!customLoader.item && customLoader.item.theme !== undefined
            target: customLoader.item
            property: "theme"
            value: bridge ? bridge.resolvedTheme : null
        },

        Binding {
            when: !!customLoader.item && customLoader.item.fieldData !== undefined
            target: customLoader.item
            property: "fieldData"
            value: root.controlDataRef
        },

        Connections {
            target: customLoader.item
            ignoreUnknownSignals: true

            function onFieldEdited(nextValue) {
                if (bridge)
                    bridge.emitFieldEdited(bridge.controlKey(root.controlDataRef), nextValue)
            }

            function onActionTriggered(actionId, payload) {
                if (bridge)
                    bridge.actionTriggered(actionId, bridge.normalizeActionPayload(payload))
            }
        }
    ]
}
