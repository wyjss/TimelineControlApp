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
    readonly property var deviceTypes: deviceManager ? deviceManager.deviceTypes : []
    readonly property var manualDeviceTypes: deviceManager ? deviceManager.manualDeviceTypes : []
    readonly property var selectedDevice: deviceManager ? deviceManager.currentDevice : ({})
    property string deviceDisplayMode: "template"
    property string selectedTemplateName: deviceTemplates.length > 0 ? String(deviceTemplates[0].name) : ""
    property string selectedDeviceType: deviceTypes.length > 0 ? String(deviceTypes[0]) : ""
    readonly property var selectedTemplate: findTemplate(selectedTemplateName)
    readonly property var groupItems: deviceDisplayMode === "type" ? deviceTypes : deviceTemplates
    readonly property var filteredDevices: buildFilteredDevices()
    readonly property bool selectedDeviceInCurrentView: selectedDevice
        && selectedDevice.id !== undefined
        && (deviceDisplayMode === "type"
            ? (selectedDevice.deviceType !== undefined && String(selectedDevice.deviceType) === selectedDeviceType)
            : (selectedDevice.templateName !== undefined && String(selectedDevice.templateName) === selectedTemplateName))
    readonly property var protocolOptions: [
        { "label": "DMX512", "value": "DMX512" },
        { "label": "HTTP", "value": "HTTP" },
        { "label": "Serial", "value": "Serial" },
        { "label": "VISCA", "value": "VISCA" },
        { "label": "OSC", "value": "OSC" },
        { "label": "Modbus", "value": "Modbus" }
    ]
    readonly property var statusOptions: [
        { "label": qsTr("Online"), "value": qsTr("Online") },
        { "label": qsTr("Standby"), "value": qsTr("Standby") },
        { "label": qsTr("Offline"), "value": qsTr("Offline") }
    ]

    onDeviceTypesChanged: {
        if (selectedDeviceType.length === 0 && deviceTypes.length > 0)
            selectedDeviceType = String(deviceTypes[0])
    }

    onFilteredDevicesChanged: ensureSelectedDeviceForView()

    function objectValue(object, field, fallback) {
        if (!object || object[field] === undefined || object[field] === null)
            return fallback

        return String(object[field])
    }

    function deviceValue(field, fallback) {
        if (!selectedDeviceInCurrentView)
            return fallback

        return objectValue(selectedDevice, field, fallback)
    }

    function templateValue(field, fallback) {
        return objectValue(selectedTemplate, field, fallback)
    }

    function findTemplate(templateName) {
        var normalizedTemplateName = String(templateName || "")
        for (var index = 0; index < deviceTemplates.length; ++index) {
            if (String(deviceTemplates[index].name) === normalizedTemplateName)
                return deviceTemplates[index]
        }

        return deviceTemplates.length > 0 ? deviceTemplates[0] : null
    }

    function buildFilteredDevices() {
        var result = []
        for (var index = 0; index < devices.length; ++index) {
            var device = devices[index]
            if (deviceDisplayMode === "type") {
                if (String(device.deviceType || "") === selectedDeviceType)
                    result.push(device)
            } else if (String(device.templateName) === selectedTemplateName) {
                result.push(device)
            }
        }

        return result
    }

    function ensureSelectedDeviceForView() {
        if (!deviceManager || filteredDevices.length === 0 || selectedDeviceInCurrentView)
            return

        deviceManager.selectDevice(String(filteredDevices[0].id))
    }

    function selectTemplate(templateName) {
        var normalizedTemplateName = String(templateName)
        if (selectedTemplateName === normalizedTemplateName)
            return

        selectedTemplateName = normalizedTemplateName
    }

    function selectDeviceType(deviceType) {
        var normalizedDeviceType = String(deviceType || "")
        if (selectedDeviceType === normalizedDeviceType)
            return

        selectedDeviceType = normalizedDeviceType
    }

    function setDeviceDisplayMode(mode) {
        if (deviceDisplayMode === mode)
            return

        deviceDisplayMode = mode
        if (deviceDisplayMode === "type" && selectedDeviceType.length === 0 && deviceTypes.length > 0)
            selectedDeviceType = String(deviceTypes[0])
        ensureSelectedDeviceForView()
    }

    function selectGroup(groupData) {
        if (deviceDisplayMode === "type")
            selectDeviceType(groupData)
        else
            selectTemplate(groupData.name)
    }

    function groupName(groupData) {
        return deviceDisplayMode === "type"
            ? String(groupData || "")
            : String(groupData.name || "")
    }

    function groupDescription(groupData) {
        if (deviceDisplayMode === "type")
            return qsTr("%1 devices").arg(deviceCountForType(groupData))

        return String(groupData.protocol || "") + " - " + String(groupData.description || "")
    }

    function groupFootnote(groupData) {
        if (deviceDisplayMode === "type")
            return qsTr("Device type")

        return qsTr("%1 config").arg(groupData.configSpecs ? groupData.configSpecs.length : 0)
    }

    function groupSelected(groupData) {
        return deviceDisplayMode === "type"
            ? String(groupData || "") === selectedDeviceType
            : String(groupData.name || "") === selectedTemplateName
    }

    function deviceCountForType(deviceType) {
        var count = 0
        for (var index = 0; index < devices.length; ++index) {
            if (String(devices[index].deviceType || "") === String(deviceType || ""))
                ++count
        }

        return count
    }

    function selectDevice(deviceId) {
        if (deviceManager)
            deviceManager.selectDevice(String(deviceId))
    }

    function initialInputSpecs(deviceTemplate) {
        var specs = deviceTemplate && deviceTemplate.configSpecs ? deviceTemplate.configSpecs : []
        var result = []

        for (var index = 0; index < specs.length; ++index) {
            if (!specs[index].readOnly)
                result.push(specs[index])
        }

        return result
    }

    function createDeviceFromSelectedTemplate() {
        if (!deviceManager || !selectedTemplate)
            return

        createDevicePopup.openForTemplate(selectedTemplate, initialInputSpecs(selectedTemplate))
    }

    function updateField(field, value) {
        if (deviceManager)
            deviceManager.updateCurrentDeviceField(field, value)
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
                visible: root.deviceDisplayMode === "template"
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
                        text: root.deviceDisplayMode === "type" ? qsTr("Device Types") : qsTr("Device Templates")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Base.AppButton {
                            Layout.fillWidth: true
                            text: qsTr("Templates")
                            theme: root.pageTheme
                            highlighted: root.deviceDisplayMode === "template"
                            onClicked: root.setDeviceDisplayMode("template")
                        }

                        Base.AppButton {
                            Layout.fillWidth: true
                            text: qsTr("Types")
                            theme: root.pageTheme
                            highlighted: root.deviceDisplayMode === "type"
                            onClicked: root.setDeviceDisplayMode("type")
                        }
                    }

                    Base.AppScrollPane {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        theme: root.pageTheme
                        contentSpacing: 8
                        fillContentWidth: true

                        Repeater {
                            model: root.groupItems

                            delegate: Base.AppSurface {
                                id: groupRow

                                readonly property bool selected: root.groupSelected(modelData)

                                Layout.fillWidth: true
                                Layout.preferredHeight: 92
                                sizeToContent: false
                                theme: root.pageTheme
                                surfaceTone: selected ? "highlight" : "surface"
                                active: selected
                                hoveredState: groupMouse.containsMouse
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
                                        text: root.groupName(modelData)
                                        theme: root.pageTheme
                                        styleRole: "bodyM"
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: root.groupDescription(modelData)
                                        theme: root.pageTheme
                                        styleRole: "bodyS"
                                        textTone: "secondary"
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: root.groupFootnote(modelData)
                                        theme: root.pageTheme
                                        styleRole: "bodyS"
                                        textTone: selected ? "accent" : "secondary"
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: groupMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: root.selectGroup(modelData)
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
                        text: root.deviceDisplayMode === "type" ? qsTr("Type Detail") : qsTr("Template Detail")
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
                                text: root.deviceDisplayMode === "type"
                                    ? (root.selectedDeviceType.length > 0 ? root.selectedDeviceType : qsTr("No type"))
                                    : root.templateValue("name", qsTr("No template"))
                                theme: root.pageTheme
                                styleRole: "bodyM"
                                elide: Text.ElideRight
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.deviceDisplayMode === "type"
                                    ? qsTr("%1 devices").arg(root.filteredDevices.length)
                                    : root.templateValue("protocol", "") + " - " + root.templateValue("description", "")
                                theme: root.pageTheme
                                styleRole: "bodyS"
                                textTone: "secondary"
                                elide: Text.ElideRight
                            }

                            Base.AppButton {
                                Layout.fillWidth: true
                                visible: root.deviceDisplayMode === "template"
                                text: qsTr("Create Device From Template")
                                theme: root.pageTheme
                                iconName: "resources"
                                onClicked: root.createDeviceFromSelectedTemplate()
                            }
                        }
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        visible: root.deviceDisplayMode === "template"
                        text: qsTr("Fixed Config")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        visible: root.deviceDisplayMode === "template"
                            && (!root.selectedTemplate || !root.selectedTemplate.configSpecs || root.selectedTemplate.configSpecs.length === 0)
                        text: qsTr("No fixed config")
                        theme: root.pageTheme
                        styleRole: "bodyS"
                        textTone: "secondary"
                    }

                    Repeater {
                        model: root.deviceDisplayMode === "template" && root.selectedTemplate && root.selectedTemplate.configSpecs
                            ? root.selectedTemplate.configSpecs
                            : []

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
                            text: root.deviceValue("templateName", "")
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Base.AppText {
                            text: qsTr("Device Type")
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }

                        Base.AppTextField {
                            Layout.fillWidth: true
                            enabled: false
                            theme: root.pageTheme
                            text: root.deviceValue("deviceType", "")
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
                            enabled: false
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
                                enabled: false
                                theme: root.pageTheme
                                options: root.protocolOptions
                                value: root.deviceValue("protocol", "DMX512")
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
                                enabled: false
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
                            enabled: false
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
                            enabled: false
                            theme: root.pageTheme
                            text: root.deviceValue("capabilities", "")
                            onEditingFinished: root.updateField("capabilities", text)
                        }
                    }
                }
            }
        }
    }

    Base.AppPopup {
        id: createDevicePopup

        property var deviceTemplate: null
        property var fieldSpecs: []
        property var fieldValues: ({})
        property string deviceName: ""
        property string deviceType: ""
        readonly property bool templateHasDeviceType: templateDeviceType(deviceTemplate).length > 0
        readonly property var deviceTypeOptions: buildDeviceTypeOptions()
        readonly property bool formValid: isFormValid()

        function openForTemplate(nextTemplate, nextFieldSpecs) {
            deviceTemplate = nextTemplate
            fieldSpecs = nextFieldSpecs || []
            deviceName = defaultDeviceName(nextTemplate)
            deviceType = defaultDeviceType(nextTemplate)
            resetValues()
            open()
        }

        function defaultDeviceName(nextTemplate) {
            return nextTemplate ? qsTr("New %1").arg(String(nextTemplate.name)) : qsTr("New Device")
        }

        function templateDeviceType(nextTemplate) {
            if (!nextTemplate || nextTemplate.deviceType === undefined || nextTemplate.deviceType === null)
                return ""

            return String(nextTemplate.deviceType).trim()
        }

        function defaultDeviceType(nextTemplate) {
            var lockedType = templateDeviceType(nextTemplate)
            if (lockedType.length > 0)
                return lockedType

            if (root.deviceDisplayMode === "type" && root.selectedDeviceType.length > 0)
                return root.selectedDeviceType

            return root.manualDeviceTypes.length > 0 ? String(root.manualDeviceTypes[0]) : ""
        }

        function buildDeviceTypeOptions() {
            var result = []
            for (var index = 0; index < root.manualDeviceTypes.length; ++index) {
                var nextType = String(root.manualDeviceTypes[index])
                result.push({ "label": nextType, "value": nextType })
            }
            return result
        }

        function resetValues() {
            var nextValues = {}
            for (var index = 0; index < fieldSpecs.length; ++index) {
                var spec = fieldSpecs[index]
                nextValues[spec.key] = spec.defaultValue !== undefined ? spec.defaultValue : ""
            }
            fieldValues = nextValues
        }

        function fieldValue(key, fallback) {
            if (fieldValues && fieldValues[key] !== undefined && fieldValues[key] !== null)
                return fieldValues[key]
            return fallback !== undefined ? fallback : ""
        }

        function setFieldValue(key, value) {
            var nextValues = {}
            for (var name in fieldValues)
                nextValues[name] = fieldValues[name]
            nextValues[key] = value
            fieldValues = nextValues
        }

        function editorForSpec(spec) {
            if (spec.options && spec.options.length > 0)
                return "select"
            if (String(spec.type) === "bool")
                return "toggle"
            return "text"
        }

        function sizeText(value) {
            if (value === undefined || value === null)
                return ""

            if (value.width !== undefined && value.height !== undefined)
                return String(Math.round(Number(value.width))) + "x" + String(Math.round(Number(value.height)))

            var text = String(value).trim()
            var match = text.match(/(-?\d+)\D+(-?\d+)/)
            if (match)
                return match[1] + "x" + match[2]

            return text
        }

        function displayValue(spec, rawValue) {
            if (String(spec.type) === "size")
                return sizeText(rawValue)
            return rawValue
        }

        function parsedSize(value) {
            if (value && value.width !== undefined && value.height !== undefined)
                return Qt.size(Math.round(Number(value.width)), Math.round(Number(value.height)))

            var match = String(value).trim().match(/^(\d+)\s*[xX,]\s*(\d+)$/)
            if (!match)
                return Qt.size(0, 0)

            return Qt.size(Math.round(Number(match[1])), Math.round(Number(match[2])))
        }

        function normalizedValue(spec, rawValue) {
            if (String(spec.type) === "int")
                return Math.round(Number(rawValue))
            if (String(spec.type) === "double")
                return Number(rawValue)
            if (String(spec.type) === "bool")
                return !!rawValue
            if (String(spec.type) === "size")
                return parsedSize(rawValue)
            return rawValue
        }

        function isBlank(value) {
            return value === undefined || value === null || String(value).trim().length === 0
        }

        function fieldInvalidReason(spec) {
            var value = fieldValue(spec.key, spec.defaultValue)
            if (spec.required && isBlank(value))
                return qsTr("%1 is required").arg(spec.label)

            if (isBlank(value))
                return ""

            if (String(spec.type) === "size") {
                if (!/^(\d+)\s*[xX,]\s*(\d+)$/.test(sizeText(value)))
                    return qsTr("%1 must use width x height").arg(spec.label)
            }

            if (spec.pattern !== undefined && spec.pattern !== "") {
                try {
                    var pattern = new RegExp(String(spec.pattern))
                    if (!pattern.test(String(value)))
                        return qsTr("%1 has an invalid format").arg(spec.label)
                } catch (error) {
                    return qsTr("%1 has an invalid pattern").arg(spec.label)
                }
            }

            if (String(spec.type) === "int" || String(spec.type) === "double") {
                var numberValue = Number(value)
                if (isNaN(numberValue))
                    return qsTr("%1 must be numeric").arg(spec.label)

                if (spec.minimum !== undefined && numberValue < Number(spec.minimum))
                    return qsTr("%1 is below minimum").arg(spec.label)

                if (spec.maximum !== undefined && numberValue > Number(spec.maximum))
                    return qsTr("%1 is above maximum").arg(spec.label)
            }

            return ""
        }

        function firstInvalidReason() {
            if (deviceManager) {
                var creationReason = deviceManager.validateDeviceCreation(
                    deviceType,
                    deviceName,
                    deviceTemplate ? String(deviceTemplate.name) : ""
                )
                if (creationReason.length > 0)
                    return creationReason
            } else if (isBlank(deviceName)) {
                return qsTr("Device name is required")
            }

            for (var index = 0; index < fieldSpecs.length; ++index) {
                var reason = fieldInvalidReason(fieldSpecs[index])
                if (reason.length > 0)
                    return reason
            }
            return ""
        }

        function isFormValid() {
            if (firstInvalidReason().length > 0)
                return false

            for (var index = 0; index < fieldSpecs.length; ++index) {
                if (fieldInvalidReason(fieldSpecs[index]).length > 0)
                    return false
            }
            return true
        }

        function buildConfigValues() {
            var values = {}
            for (var index = 0; index < fieldSpecs.length; ++index) {
                var spec = fieldSpecs[index]
                values[spec.key] = normalizedValue(spec, fieldValue(spec.key, spec.defaultValue))
            }
            return values
        }

        function commit() {
            if (!deviceManager || !deviceTemplate || !formValid)
                return

            var created = deviceManager.createDeviceFromTemplate(
                String(deviceTemplate.name),
                buildConfigValues(),
                deviceName,
                deviceType
            )
            if (created) {
                root.selectedDeviceType = deviceType
                close()
            }
        }

        modal: true
        focus: true
        width: Math.min(560, Math.max(420, parent ? parent.width - 96 : 520))
        height: Math.min(620, Math.max(360, parent ? parent.height - 96 : 480))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        padding: 18
        spacing: 14
        theme: root.pageTheme
        surfaceTone: "section"
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Base.AppText {
                    Layout.fillWidth: true
                    text: qsTr("Create Device")
                    theme: root.pageTheme
                    styleRole: "titleM"
                    elide: Text.ElideRight
                }

                Base.AppText {
                    Layout.fillWidth: true
                    text: createDevicePopup.deviceTemplate
                        ? String(createDevicePopup.deviceTemplate.name) + " / " + String(createDevicePopup.deviceTemplate.protocol)
                        : ""
                    theme: root.pageTheme
                    styleRole: "bodyS"
                    textTone: "secondary"
                    elide: Text.ElideRight
                }
            }

            Base.AppButton {
                text: qsTr("Cancel")
                theme: root.pageTheme
                onClicked: createDevicePopup.close()
            }

            Base.AppButton {
                text: qsTr("Create")
                theme: root.pageTheme
                enabled: createDevicePopup.formValid
                iconName: "resources"
                onClicked: createDevicePopup.commit()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Base.AppText {
                text: qsTr("Name") + " *"
                theme: root.pageTheme
                styleRole: "bodyS"
                textTone: "secondary"
            }

            Base.AppTextField {
                Layout.fillWidth: true
                theme: root.pageTheme
                text: createDevicePopup.deviceName
                placeholderText: qsTr("Device name")
                onTextChanged: createDevicePopup.deviceName = text
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Base.AppText {
                text: qsTr("Device Type") + " *"
                theme: root.pageTheme
                styleRole: "bodyS"
                textTone: "secondary"
            }

            Base.AppTextField {
                visible: createDevicePopup.templateHasDeviceType
                Layout.fillWidth: true
                enabled: false
                theme: root.pageTheme
                text: createDevicePopup.deviceType
            }

            RowLayout {
                visible: !createDevicePopup.templateHasDeviceType
                Layout.fillWidth: true
                spacing: 8

                Base.AppSelect {
                    visible: createDevicePopup.deviceTypeOptions.length > 0
                    Layout.preferredWidth: 180
                    theme: root.pageTheme
                    placeholderText: qsTr("Existing type")
                    options: createDevicePopup.deviceTypeOptions
                    value: createDevicePopup.deviceType
                    onValueSelected: createDevicePopup.deviceType = String(nextValue)
                }

                Base.AppTextField {
                    Layout.fillWidth: true
                    theme: root.pageTheme
                    text: createDevicePopup.deviceType
                    placeholderText: qsTr("Device type")
                    onTextChanged: createDevicePopup.deviceType = text
                }
            }
        }

        Base.AppText {
            Layout.fillWidth: true
            visible: text.length > 0
            text: createDevicePopup.firstInvalidReason()
            theme: root.pageTheme
            styleRole: "bodyS"
            colorOverride: "#ef4444"
            elide: Text.ElideRight
        }

        Base.AppScrollPane {
            Layout.fillWidth: true
            Layout.fillHeight: true
            theme: root.pageTheme
            contentSpacing: 12
            fillContentWidth: true

            Base.AppText {
                Layout.fillWidth: true
                visible: createDevicePopup.fieldSpecs.length === 0
                text: qsTr("No initial parameters")
                theme: root.pageTheme
                styleRole: "bodyS"
                textTone: "secondary"
                elide: Text.ElideRight
            }

            Repeater {
                model: createDevicePopup.fieldSpecs

                delegate: ColumnLayout {
                    id: createFieldRow

                    property var fieldSpec: modelData
                    readonly property string editor: createDevicePopup.editorForSpec(fieldSpec)
                    readonly property string invalidReason: createDevicePopup.fieldInvalidReason(fieldSpec)

                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Base.AppText {
                            Layout.fillWidth: true
                            text: createFieldRow.fieldSpec.label + (createFieldRow.fieldSpec.required ? " *" : "")
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                            elide: Text.ElideRight
                        }

                        Base.AppText {
                            text: String(createFieldRow.fieldSpec.type || "")
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: createFieldRow.invalidReason.length > 0 ? "primary" : "secondary"
                            colorOverride: createFieldRow.invalidReason.length > 0 ? "#ef4444" : undefined
                        }
                    }

                    Base.AppTextField {
                        visible: createFieldRow.editor === "text"
                        Layout.fillWidth: true
                        theme: root.pageTheme
                        text: String(createDevicePopup.displayValue(
                            createFieldRow.fieldSpec,
                            createDevicePopup.fieldValue(createFieldRow.fieldSpec.key, createFieldRow.fieldSpec.defaultValue)
                        ))
                        placeholderText: createFieldRow.fieldSpec.type === "size"
                            ? qsTr("width x height")
                            : String(createFieldRow.fieldSpec.placeholderText || "")
                        inputMethodHints: createFieldRow.fieldSpec.type === "int"
                            ? Qt.ImhDigitsOnly
                            : (createFieldRow.fieldSpec.type === "double" ? Qt.ImhFormattedNumbersOnly : Qt.ImhNone)
                        onEditingFinished: createDevicePopup.setFieldValue(createFieldRow.fieldSpec.key, text)
                    }

                    Base.AppSelect {
                        visible: createFieldRow.editor === "select"
                        Layout.fillWidth: true
                        theme: root.pageTheme
                        options: createFieldRow.fieldSpec.options || []
                        value: createDevicePopup.fieldValue(createFieldRow.fieldSpec.key, createFieldRow.fieldSpec.defaultValue)
                        onValueSelected: createDevicePopup.setFieldValue(createFieldRow.fieldSpec.key, nextValue)
                    }

                    RowLayout {
                        visible: createFieldRow.editor === "toggle"
                        Layout.fillWidth: true
                        spacing: 10

                        Base.AppToggleControl {
                            theme: root.pageTheme
                            checked: !!createDevicePopup.fieldValue(createFieldRow.fieldSpec.key, createFieldRow.fieldSpec.defaultValue)
                            onToggled: createDevicePopup.setFieldValue(createFieldRow.fieldSpec.key, nextChecked)
                        }

                        Base.AppText {
                            Layout.fillWidth: true
                            text: createDevicePopup.fieldValue(createFieldRow.fieldSpec.key, createFieldRow.fieldSpec.defaultValue)
                                ? qsTr("Enabled")
                                : qsTr("Disabled")
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }
                    }

                    Base.AppText {
                        visible: createFieldRow.invalidReason.length > 0
                        Layout.fillWidth: true
                        text: createFieldRow.invalidReason
                        theme: root.pageTheme
                        styleRole: "bodyS"
                        colorOverride: "#ef4444"
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
