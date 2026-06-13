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
    readonly property var selectedDevice: deviceManager ? deviceManager.currentDevice : ({})
    readonly property var protocolOptions: [
        { "label": "DMX", "value": "DMX" },
        { "label": "VISCA", "value": "VISCA" },
        { "label": "OSC", "value": "OSC" },
        { "label": "Modbus", "value": "Modbus" }
    ]
    readonly property var statusOptions: [
        { "label": qsTr("Online"), "value": qsTr("Online") },
        { "label": qsTr("Standby"), "value": qsTr("Standby") },
        { "label": qsTr("Offline"), "value": qsTr("Offline") }
    ]

    function deviceValue(field, fallback) {
        if (!selectedDevice || selectedDevice[field] === undefined || selectedDevice[field] === null)
            return fallback

        return String(selectedDevice[field])
    }

    function selectDevice(deviceId) {
        if (deviceManager)
            deviceManager.selectDevice(String(deviceId))
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
                    text: qsTr("%1 devices").arg(root.devices.length)
                    theme: root.pageTheme
                    styleRole: "bodyS"
                    textTone: "secondary"
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Base.AppTextField {
                Layout.preferredWidth: 240
                theme: root.pageTheme
                placeholderText: qsTr("Search devices")
            }

            Base.AppButton {
                text: qsTr("Create Device")
                theme: root.pageTheme
                iconName: "resources"
                onClicked: {
                    if (root.deviceManager)
                        root.deviceManager.createDevice()
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            columnSpacing: 14
            rowSpacing: 14

            Base.AppSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 620
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
                            text: qsTr("Device Registry")
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
                            model: root.devices

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
                        text: qsTr("Device Profile")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
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

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 70
                        sizeToContent: false
                        theme: root.pageTheme
                        surfaceTone: "surface"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            Base.AppText {
                                text: qsTr("Last Seen")
                                theme: root.pageTheme
                                styleRole: "bodyS"
                                textTone: "secondary"
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.deviceValue("lastSeen", qsTr("Never"))
                                theme: root.pageTheme
                                styleRole: "bodyM"
                                textTone: root.deviceValue("status", "") === qsTr("Online") ? "accent" : "primary"
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        text: qsTr("Command Templates")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    Repeater {
                        model: root.selectedDevice && root.selectedDevice.commandTemplates ? root.selectedDevice.commandTemplates : []

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
                                    text: modelData.action + " · " + root.commandParamSummary(modelData)
                                    theme: root.pageTheme
                                    styleRole: "bodyS"
                                    textTone: "secondary"
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
