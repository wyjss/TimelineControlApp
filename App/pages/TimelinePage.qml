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

    readonly property var cueRows: [
        { "time": "00:00.000", "name": "Prepare", "target": "All devices", "state": "Armed" },
        { "time": "00:03.200", "name": "Lights On", "target": "Lighting group", "state": "Ready" },
        { "time": "00:08.500", "name": "Camera Move", "target": "PTZ-01", "state": "Ready" },
        { "time": "00:14.000", "name": "Audio Cue", "target": "Mixer", "state": "Draft" }
    ]

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
                text: qsTr("Timeline")
                theme: root.pageTheme
                styleRole: "titleL"
            }

            Item {
                Layout.fillWidth: true
            }

            Base.AppButton {
                text: qsTr("Add Cue")
                theme: root.pageTheme
                iconName: "workflow"
            }

            Base.AppButton {
                text: qsTr("Run")
                theme: root.pageTheme
                iconName: "background-task"
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
                Layout.minimumWidth: 520
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Base.AppText {
                        text: qsTr("Control Track")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    Repeater {
                        model: root.cueRows

                        delegate: Base.AppSurface {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            sizeToContent: false
                            theme: root.pageTheme
                            surfaceTone: index === 0 ? "highlight" : "surface"
                            strokeWidth: index === 0 ? 0 : 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12

                                Base.AppText {
                                    Layout.preferredWidth: 76
                                    text: modelData.time
                                    theme: root.pageTheme
                                    styleRole: "bodyS"
                                    textTone: "secondary"
                                }

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
                                        text: modelData.target
                                        theme: root.pageTheme
                                        styleRole: "bodyS"
                                        textTone: "secondary"
                                        elide: Text.ElideRight
                                    }
                                }

                                Base.AppText {
                                    Layout.preferredWidth: 68
                                    text: modelData.state
                                    theme: root.pageTheme
                                    styleRole: "bodyS"
                                    textTone: index === 0 ? "accent" : "secondary"
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }

            Base.AppSurface {
                Layout.preferredWidth: 340
                Layout.fillHeight: true
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    Base.AppText {
                        text: qsTr("Command Editor")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 76
                        sizeToContent: false
                        theme: root.pageTheme
                        surfaceTone: "surface"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            Base.AppText {
                                text: qsTr("Target")
                                theme: root.pageTheme
                                styleRole: "bodyS"
                                textTone: "secondary"
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: qsTr("Lighting group")
                                theme: root.pageTheme
                                styleRole: "bodyM"
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 118
                        sizeToContent: false
                        theme: root.pageTheme
                        surfaceTone: "surface"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            Base.AppText {
                                text: qsTr("Payload")
                                theme: root.pageTheme
                                styleRole: "bodyS"
                                textTone: "secondary"
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: qsTr("intensity: 80%")
                                theme: root.pageTheme
                                styleRole: "bodyM"
                                elide: Text.ElideRight
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: qsTr("duration: 2.4s")
                                theme: root.pageTheme
                                styleRole: "bodyM"
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
        }
    }
}
