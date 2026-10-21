import QtQuick 2.14
import QtQuick.Layouts 1.14
import QtQml 2.14
import UICore.Fields 1.0
import "../../foundation/AppBridgeUtils.js" as BridgeUtils
import "internal" as Internal

Item {
    id: root

    property var fieldData: null
    property bool active: true

    signal valueEdited(var value)
    signal actionTriggered(string actionId, var payload)

    function fieldValue(key, fallback) {
        return BridgeUtils.controlValue(fieldData, key, fallback)
    }

    function fieldKey() {
        return BridgeUtils.controlKey(fieldData)
    }

    function fieldSurfaceTone(fallback) {
        return fieldValue("surfaceTone", fallback)
    }

    function objectPayload(payload) {
        return BridgeUtils.objectPayload(payload)
    }

    function emitValueEdited(value) {
        root.valueEdited(BridgeUtils.normalizedValue(value))
    }

    readonly property int kind: fieldValue("kind", AppField.Kind.TextField)
    readonly property int valueType: fieldValue("valueType", BaseField.VariantType)
    readonly property bool numberField: kind === AppField.Kind.TextField
        && (valueType === BaseField.IntType || valueType === BaseField.DoubleType)

    Layout.fillWidth: true
    implicitWidth: fieldLoader.item ? fieldLoader.item.implicitWidth : 0
    implicitHeight: fieldLoader.item ? fieldLoader.item.implicitHeight : 0

    Loader {
        id: fieldLoader

        anchors.fill: parent
        enabled: root.kind === AppField.Kind.TextField
            || root.kind === AppField.Kind.TextArea
            || root.kind === AppField.Kind.Select
            || !root.fieldValue("readOnly", false)
        active: root.active && root.fieldData !== null && root.fieldData !== undefined
        sourceComponent: {
            switch (root.kind) {
            case AppField.Kind.Summary:
                return summaryComponent
            case AppField.Kind.Segmented:
                return segmentedComponent
            case AppField.Kind.Choice:
                return choiceComponent
            case AppField.Kind.Toggle:
                return toggleComponent
            case AppField.Kind.Slider:
                return sliderComponent
            case AppField.Kind.Color:
                return colorComponent
            case AppField.Kind.Custom:
                return customComponent
            case AppField.Kind.Chips:
                return chipsComponent
            case AppField.Kind.Select:
                return selectComponent
            case AppField.Kind.Button:
                return buttonComponent
            case AppField.Kind.TextArea:
                return textAreaComponent
            case AppField.Kind.CheckBox:
                return checkBoxComponent
            default:
                return root.numberField ? numberFieldComponent : textFieldComponent
            }
        }

        Binding {
            when: !!fieldLoader.item
            target: fieldLoader.item
            property: "fieldBridge"
            value: root
            restoreMode: Binding.RestoreBinding
        }
    }

    Component {
        id: summaryComponent

        Internal.AppFieldSummaryRenderer {
        }
    }

    Component {
        id: segmentedComponent

        Internal.AppFieldSegmentedRenderer {
        }
    }

    Component {
        id: choiceComponent

        Internal.AppFieldChoiceRenderer {
        }
    }

    Component {
        id: toggleComponent

        Internal.AppFieldToggleRenderer {
        }
    }

    Component {
        id: sliderComponent

        Internal.AppFieldSliderRenderer {
        }
    }

    Component {
        id: colorComponent

        Internal.AppFieldColorRenderer {
        }
    }

    Component {
        id: customComponent

        Internal.AppFieldCustomRenderer {
        }
    }

    Component {
        id: textFieldComponent

        Internal.AppFieldTextFieldRenderer {
        }
    }

    Component {
        id: numberFieldComponent

        Internal.AppFieldNumberRenderer {
        }
    }

    Component {
        id: selectComponent

        Internal.AppFieldSelectRenderer {
        }
    }

    Component {
        id: chipsComponent

        Internal.AppFieldChipsRenderer {
        }
    }

    Component {
        id: buttonComponent

        Internal.AppFieldButtonRenderer {
        }
    }

    Component {
        id: textAreaComponent

        Internal.AppFieldTextAreaRenderer {
        }
    }

    Component {
        id: checkBoxComponent

        Internal.AppFieldCheckBoxRenderer {
        }
    }
}
