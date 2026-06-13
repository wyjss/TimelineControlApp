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

    readonly property var runRows: [
        { "name": "Current Run", "time": "00:14.000", "state": "Armed" },
        { "name": "Rehearsal A", "time": "02:18.420", "state": "Finished" },
        { "name": "Device Sync", "time": "00:31.120", "state": "Finished" },
        { "name": "Dry Run", "time": "01:02.000", "state": "Cancelled" }
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
                text: qsTr("Runs")
                theme: root.pageTheme
                styleRole: "titleL"
            }

            Item {
                Layout.fillWidth: true
            }

            Base.AppButton {
                text: qsTr("Export")
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
                        text: qsTr("Execution History")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    Repeater {
                        model: root.runRows

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
                                        text: modelData.time
                                        theme: root.pageTheme
                                        styleRole: "bodyS"
                                        textTone: "secondary"
                                    }
                                }

                                Base.AppText {
                                    Layout.preferredWidth: 78
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
                        text: qsTr("Live State")
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
                                text: qsTr("Clock")
                                theme: root.pageTheme
                                styleRole: "bodyS"
                                textTone: "secondary"
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: qsTr("00:14.000")
                                theme: root.pageTheme
                                styleRole: "titleM"
                                textTone: "accent"
                            }
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        sizeToContent: false
                        theme: root.pageTheme
                        surfaceTone: "surface"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            Base.AppText {
                                text: qsTr("Next Cue")
                                theme: root.pageTheme
                                styleRole: "bodyS"
                                textTone: "secondary"
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: qsTr("Audio Cue")
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
