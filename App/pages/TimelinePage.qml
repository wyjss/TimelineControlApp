import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UiCore/qml/components/base" as Base
import "qrc:/UiCore/qml/theme" as Theme
import "timeline" as Timeline

Item {
    id: root

    focus: true
    Theme.AppTheme {
        id: fallbackTheme
    }

    property QtObject pageTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : fallbackTheme
    property int timelineDurationMs: 1800000
    property int timelineCurrentTimeMs: 0
    property real timelineScrollX: 0
    property real timelineTimeScale: 1.0

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

                    Timeline.TimelineRuler {
                        id: timelineRuler

                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        theme: root.pageTheme
                        durationMs: root.timelineDurationMs
                        currentTimeMs: root.timelineCurrentTimeMs
                        scrollX: root.timelineScrollX
                        startTimeX: width / 2
                        timeScale: root.timelineTimeScale
                        onScrollXChangeRequested: function(nextScrollX) {
                            root.timelineScrollX = nextScrollX
                        }
                        onCurrentTimeMsChangeRequested: function(nextCurrentTimeMs) {
                            root.timelineCurrentTimeMs = nextCurrentTimeMs
                        }
                        onTimeScaleChangeRequested: function(nextTimeScale) {
                            root.timelineTimeScale = nextTimeScale
                        }
                    }

                    Timeline.TimelineTrackArea {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 220
                        theme: root.pageTheme
                        ruler: timelineRuler
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
