import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UiCore/qml/components/base" as Base
import "qrc:/UiCore/qml/theme" as Theme

Item {
    id: root

    focus: true

    Theme.AppTheme {
        id: fallbackTheme
    }

    property QtObject pageTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : fallbackTheme
    property var appRuntime: typeof app !== "undefined" ? app : null
    property var deviceManager: appRuntime && appRuntime.deviceManager ? appRuntime.deviceManager : null

    readonly property var devices: deviceManager ? deviceManager.devices : []
    readonly property var deviceTemplates: deviceManager ? deviceManager.deviceTemplates : []
    readonly property var selectedDevice: deviceManager ? deviceManager.currentDevice : ({})
    property string selectedTemplateId: deviceTemplates.length > 0 ? String(deviceTemplates[0].id) : ""
    readonly property var selectedTemplate: findTemplate(selectedTemplateId)
    readonly property var filteredDevices: buildFilteredDevices()
    readonly property bool selectedDeviceInSelectedTemplate: selectedDevice
        && selectedDevice.templateId !== undefined
        && String(selectedDevice.templateId) === selectedTemplateId
    readonly property var protocolOptions: [
        { "label": "DMX", "value": "DMX" },
        { "label": "HTTP", "value": "HTTP" },
        { "label": "VISCA", "value": "VISCA" },
        { "label": "OSC", "value": "OSC" },
        { "label": "Modbus", "value": "Modbus" }
    ]
    readonly property var statusOptions: [
        { "label": qsTr("Online"), "value": qsTr("Online") },
        { "label": qsTr("Standby"), "value": qsTr("Standby") },
        { "label": qsTr("Offline"), "value": qsTr("Offline") }
    ]

    onFilteredDevicesChanged: ensureSelectedDeviceForTemplate()

    function objectValue(object, field, fallback) {
        if (!object || object[field] === undefined || object[field] === null)
            return fallback

        return String(object[field])
    }

    function deviceValue(field, fallback) {
        if (!selectedDeviceInSelectedTemplate)
            return fallback

        return objectValue(selectedDevice, field, fallback)
    }

    function templateValue(field, fallback) {
        return objectValue(selectedTemplate, field, fallback)
    }

    function findTemplate(templateId) {
        var normalizedTemplateId = String(templateId || "")
        for (var index = 0; index < deviceTemplates.length; ++index) {
            if (String(deviceTemplates[index].id) === normalizedTemplateId)
                return deviceTemplates[index]
        }

        return deviceTemplates.length > 0 ? deviceTemplates[0] : null
    }

    function buildFilteredDevices() {
        var result = []
        for (var index = 0; index < devices.length; ++index) {
            var device = devices[index]
            if (String(device.templateId) === selectedTemplateId)
                result.push(device)
        }

        return result
    }

    function ensureSelectedDeviceForTemplate() {
        if (!deviceManager || filteredDevices.length === 0 || selectedDeviceInSelectedTemplate)
            return

        deviceManager.selectDevice(String(filteredDevices[0].id))
    }

    function selectTemplate(templateId) {
        var normalizedTemplateId = String(templateId)
        if (selectedTemplateId === normalizedTemplateId)
            return

        selectedTemplateId = normalizedTemplateId
    }

    function selectDevice(deviceId) {
        if (deviceManager)
            deviceManager.selectDevice(String(deviceId))
    }

    function createDeviceFromSelectedTemplate() {
        if (deviceManager && selectedTemplate)
            deviceManager.createDeviceFromTemplate(String(selectedTemplate.id))
    }

    function updateField(field, value) {
        if (deviceManager)
            deviceManager.updateCurrentDeviceField(field, value)
    }

    function commandParamSummary(commandTemplate) {
        var params = commandTemplate && commandTemplate.params ? commandTemplate.params : []
        if (!params || params.length === 0)
            return qsTr("No parameters")

        var labels = []
        for (var index = 0; index < params.length; ++index)
            labels.push(String(params[index].label || params[index].key || ""))

        return labels.join(", ")
    }

    function configSpecSummary(configSpec) {
        var defaultText = configSpec.defaultValue === undefined || configSpec.defaultValue === null
            ? qsTr("Empty")
            : String(configSpec.defaultValue)
        return String(configSpec.type) + " / " + defaultText
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 32
        anchors.rightMargin: 32
        anchors.topMargin: 64
        anchors.bottomMargin: 44
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Base.AppText {
                text: qsTr("Devices")
                theme: root.pageTheme
                styleRole: "titleL"
            }

            Base.AppSurface {
                Layout.preferredHeight: 28
                sizeToContent: true
                theme: root.pageTheme
                surfaceTone: "section"
                padding: 10

                Base.AppText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("%1 templates").arg(root.deviceTemplates.length)
                    theme: root.pageTheme
                    styleRole: "bodyS"
                    textTone: "secondary"
                }
            }

            Base.AppSurface {
                Layout.preferredHeight: 28
                sizeToContent: true
                theme: root.pageTheme
                surfaceTone: "section"
                padding: 10

                Base.AppText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("%1 devices").arg(root.filteredDevices.length)
                    theme: root.pageTheme
                    styleRole: "bodyS"
                    textTone: "secondary"
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Base.AppButton {
                text: qsTr("Create Device")
                theme: root.pageTheme
                iconName: "resources"
                onClicked: root.createDeviceFromSelectedTemplate()
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            columnSpacing: 14
            rowSpacing: 14

            Base.AppSurface {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Base.AppText {
                        text: qsTr("Device Templates")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    Base.AppScrollPane {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        theme: root.pageTheme
                        contentSpacing: 8
                        fillContentWidth: true

                        Repeater {
                            model: root.deviceTemplates

                            delegate: Base.AppSurface {
                                id: templateRow

                                readonly property bool selected: String(modelData.id) === root.selectedTemplateId

                                Layout.fillWidth: true
                                Layout.preferredHeight: 92
                                sizeToContent: false
                                theme: root.pageTheme
                                surfaceTone: selected ? "highlight" : "surface"
                                active: selected
                                hoveredState: templateMouse.containsMouse
                                interactive: true
                                strokeWidth: 1
                                borderOverride: selected ? "transparent" : undefined

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 10
                                    anchors.bottomMargin: 10
                                    spacing: 4

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        theme: root.pageTheme
                                        styleRole: "bodyM"
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: modelData.protocol + " - " + modelData.description
                                        theme: root.pageTheme
                                        styleRole: "bodyS"
                                        textTone: "secondary"
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: qsTr("%1 config / %2 commands")
                                            .arg(modelData.configSpecs ? modelData.configSpecs.length : 0)
                                            .arg(modelData.commandTemplates ? modelData.commandTemplates.length : 0)
                                        theme: root.pageTheme
                                        styleRole: "bodyS"
                                        textTone: selected ? "accent" : "secondary"
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: templateMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: root.selectTemplate(modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            Base.AppSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 420
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Base.AppText {
                            Layout.fillWidth: true
                            text: qsTr("Device Instances")
                            theme: root.pageTheme
                            styleRole: "sectionTitle"
                        }

                        Base.AppText {
                            Layout.preferredWidth: 90
                            text: qsTr("Protocol")
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }

                        Base.AppText {
                            Layout.preferredWidth: 88
                            text: qsTr("Status")
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Base.AppScrollPane {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        theme: root.pageTheme
                        contentSpacing: 8
                        fillContentWidth: true

                        Repeater {
                            model: root.filteredDevices

                            delegate: Base.AppSurface {
                                id: deviceRow

                                readonly property bool selected: modelData.id === root.deviceValue("id", "")

                                Layout.fillWidth: true
                                Layout.preferredHeight: 66
                                sizeToContent: false
                                theme: root.pageTheme
                                surfaceTone: selected ? "highlight" : "surface"
                                active: selected
                                hoveredState: rowMouse.containsMouse
                                interactive: true
                                strokeWidth: 1
                                borderOverride: selected ? "transparent" : undefined

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 12

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Base.AppText {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            theme: root.pageTheme
                                            styleRole: "bodyM"
                                            elide: Text.ElideRight
                                        }

                                        Base.AppText {
                                            Layout.fillWidth: true
                                            text: modelData.address
                                            theme: root.pageTheme
                                            styleRole: "bodyS"
                                            textTone: "secondary"
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Base.AppText {
                                        Layout.preferredWidth: 90
                                        text: modelData.protocol
                                        theme: root.pageTheme
                                        styleRole: "bodyS"
                                        textTone: "secondary"
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        Layout.preferredWidth: 88
                                        text: modelData.status
                                        theme: root.pageTheme
                                        styleRole: "bodyS"
                                        textTone: modelData.status === qsTr("Online") ? "accent" : "secondary"
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: rowMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: root.selectDevice(modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            Base.AppSurface {
                Layout.preferredWidth: 380
                Layout.fillHeight: true
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

                Base.AppScrollPane {
                    anchors.fill: parent
                    anchors.margins: 18
                    theme: root.pageTheme
                    contentSpacing: 14
                    fillContentWidth: true

                    Base.AppText {
                        Layout.fillWidth: true
                        text: qsTr("Template Detail")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 96
                        sizeToContent: false
                        theme: root.pageTheme
                        surfaceTone: "surface"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.templateValue("name", qsTr("No template"))
                                theme: root.pageTheme
                                styleRole: "bodyM"
                                elide: Text.ElideRight
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.templateValue("protocol", "") + " - " + root.templateValue("description", "")
                                theme: root.pageTheme
                                styleRole: "bodyS"
                                textTone: "secondary"
                                elide: Text.ElideRight
                            }

                            Base.AppButton {
                                Layout.fillWidth: true
                                text: qsTr("Create Device From Template")
                                theme: root.pageTheme
                                iconName: "resources"
                                onClicked: root.createDeviceFromSelectedTemplate()
                            }
                        }
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        text: qsTr("Fixed Config")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        visible: !root.selectedTemplate || !root.selectedTemplate.configSpecs || root.selectedTemplate.configSpecs.length === 0
                        text: qsTr("No fixed config")
                        theme: root.pageTheme
                        styleRole: "bodyS"
                        textTone: "secondary"
                    }

                    Repeater {
                        model: root.selectedTemplate && root.selectedTemplate.configSpecs ? root.selectedTemplate.configSpecs : []

                        delegate: Base.AppSurface {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 54
                            sizeToContent: false
                            theme: root.pageTheme
                            surfaceTone: "surface"

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                anchors.topMargin: 7
                                anchors.bottomMargin: 7
                                spacing: 2

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    theme: root.pageTheme
                                    styleRole: "bodyM"
                                    elide: Text.ElideRight
                                }

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: root.configSpecSummary(modelData)
                                    theme: root.pageTheme
                                    styleRole: "bodyS"
                                    textTone: "secondary"
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        text: qsTr("Template Commands")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    Repeater {
                        model: root.selectedTemplate && root.selectedTemplate.commandTemplates ? root.selectedTemplate.commandTemplates : []

                        delegate: Base.AppSurface {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            sizeToContent: false
                            theme: root.pageTheme
                            surfaceTone: "surface"

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                anchors.topMargin: 8
                                anchors.bottomMargin: 8
                                spacing: 2

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    theme: root.pageTheme
                                    styleRole: "bodyM"
                                    elide: Text.ElideRight
                                }

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: modelData.action + " - " + root.commandParamSummary(modelData)
                                    theme: root.pageTheme
                                    styleRole: "bodyS"
                                    textTone: "secondary"
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        text: qsTr("Device Profile")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Base.AppText {
                            text: qsTr("Template")
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }

                        Base.AppTextField {
                            Layout.fillWidth: true
                            enabled: false
                            theme: root.pageTheme
                            text: root.deviceValue("templateId", "")
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Base.AppText {
                            text: qsTr("Name")
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }

                        Base.AppTextField {
                            Layout.fillWidth: true
                            theme: root.pageTheme
                            text: root.deviceValue("name", "")
                            onEditingFinished: root.updateField("name", text)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Base.AppText {
                                text: qsTr("Protocol")
                                theme: root.pageTheme
                                styleRole: "bodyS"
                                textTone: "secondary"
                            }

                            Base.AppSelect {
                                Layout.fillWidth: true
                                theme: root.pageTheme
                                options: root.protocolOptions
                                value: root.deviceValue("protocol", "DMX")
                                onValueSelected: root.updateField("protocol", nextValue)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Base.AppText {
                                text: qsTr("Status")
                                theme: root.pageTheme
                                styleRole: "bodyS"
                                textTone: "secondary"
                            }

                            Base.AppSelect {
                                Layout.fillWidth: true
                                theme: root.pageTheme
                                options: root.statusOptions
                                value: root.deviceValue("status", qsTr("Offline"))
                                onValueSelected: root.updateField("status", nextValue)
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Base.AppText {
                            text: qsTr("Address")
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }

                        Base.AppTextField {
                            Layout.fillWidth: true
                            theme: root.pageTheme
                            text: root.deviceValue("address", "")
                            onEditingFinished: root.updateField("address", text)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Base.AppText {
                            text: qsTr("Capabilities")
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }

                        Base.AppTextField {
                            Layout.fillWidth: true
                            theme: root.pageTheme
                            text: root.deviceValue("capabilities", "")
                            onEditingFinished: root.updateField("capabilities", text)
                        }
                    }
                }
            }
        }
    }
}
