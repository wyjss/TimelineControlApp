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
    property var lastCommand: null

    function protocolLabel(protocol) {
        switch (String(protocol)) {
        case "dmx512":
            return qsTr("DMX512")
        case "http":
            return qsTr("HTTP")
        case "pc":
            return qsTr("PC")
        case "serial":
            return qsTr("Serial")
        default:
            return String(protocol)
        }
    }

    function commandParam(key, fallback) {
        if (!lastCommand || !lastCommand.params || lastCommand.params[key] === undefined || lastCommand.params[key] === null)
            return fallback

        return lastCommand.params[key]
    }

    function commandSummary(command) {
        if (!command)
            return qsTr("intensity: 80%")

        switch (String(command.protocol)) {
        case "dmx512":
            return qsTr("channel %1 -> %2").arg(commandParam("channel", 1)).arg(commandParam("value", 255))
        case "http":
            return String(commandParam("method", "POST")) + " " + String(commandParam("address", "")) + String(commandParam("path", "/"))
        case "pc":
            return String(commandParam("path", "/"))
        case "serial":
            return (commandParam("hex", true) ? "HEX " : "TEXT ") + String(commandParam("payload", ""))
        default:
            return String(command.name || qsTr("Command"))
        }
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
                onClicked: addCommandDialog.openForTime(root.timelineCurrentTimeMs)
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
                                text: root.lastCommand
                                    ? root.protocolLabel(root.lastCommand.protocol)
                                    : qsTr("Lighting group")
                                theme: root.pageTheme
                                styleRole: "bodyM"
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 138
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
                                text: root.lastCommand
                                    ? String(root.lastCommand.name || qsTr("Command"))
                                    : qsTr("intensity: 80%")
                                theme: root.pageTheme
                                styleRole: "bodyM"
                                elide: Text.ElideRight
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.lastCommand
                                    ? root.commandSummary(root.lastCommand)
                                    : qsTr("duration: 2.4s")
                                theme: root.pageTheme
                                styleRole: "bodyM"
                                elide: Text.ElideRight
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.lastCommand
                                    ? qsTr("time: %1 ms / duration: %2 ms").arg(root.lastCommand.startTimeMs).arg(root.lastCommand.durationMs)
                                    : qsTr("duration: 2.4s")
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

    Timeline.AddCommandDialog {
        id: addCommandDialog

        parent: root
        theme: root.pageTheme
        onCommandAccepted: function(command) {
            root.lastCommand = command
        }
    }
}
