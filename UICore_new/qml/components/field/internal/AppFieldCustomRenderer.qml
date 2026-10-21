import QtQuick 2.14
import QtQuick.Layouts 1.14
import QtQml 2.14

Item {
    id: root

    property var fieldBridge: null

    readonly property var bridge: fieldBridge

    objectName: bridge ? "field:" + bridge.fieldKey() : ""
    Layout.fillWidth: true
    implicitHeight: Math.max(0, customLoader.item ? customLoader.item.implicitHeight : 0)

    Loader {
        id: customLoader

        width: parent ? parent.width : 0
        source: bridge ? bridge.fieldValue("delegateSource", "") : ""
    }

    resources: [
        Binding {
            when: !!customLoader.item && customLoader.item.fieldData !== undefined
            target: customLoader.item
            property: "fieldData"
            value: bridge ? bridge.fieldData : null
        },

        Connections {
            target: customLoader.item
            ignoreUnknownSignals: true

            function onFieldEdited(nextValue) {
                if (bridge)
                    bridge.emitValueEdited(nextValue)
            }

            function onActionTriggered(actionId, payload) {
                if (bridge)
                    bridge.actionTriggered(actionId, bridge.objectPayload(payload))
            }
        }
    ]
}
