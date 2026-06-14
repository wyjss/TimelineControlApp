import QtQuick 2.14
import "qrc:/UiCore/qml/components/base" as Base
import "qrc:/UiCore/qml/components/base/internal/AppThemeUtils.js" as ThemeUtils

Item {
    id: root

    property QtObject theme
    property var ruler
    property int rowHeight: 56
    property int rowSpacing: 8
    property var tracks: [
        {
            "name": "Lighting",
            "commands": [
                { "name": "Fade In", "startMs": 3000, "durationMs": 8000, "color": "#2563eb" },
                { "name": "Hold", "startMs": 18000, "durationMs": 14000, "color": "#0891b2" }
            ]
        },
        {
            "name": "Screen",
            "commands": [
                { "name": "Show Logo", "startMs": 7000, "durationMs": 12000, "color": "#16a34a" },
                { "name": "Scene B", "startMs": 26000, "durationMs": 16000, "color": "#4f46e5" }
            ]
        },
        {
            "name": "Camera",
            "commands": [
                { "name": "Move", "startMs": 12000, "durationMs": 10000, "color": "#d97706" },
                { "name": "Zoom", "startMs": 34000, "durationMs": 9000, "color": "#be123c" }
            ]
        }
    ]

    implicitHeight: Math.max(220, tracks.length * (rowHeight + rowSpacing) - rowSpacing)
    clip: true

    function colorValue(name, fallback) {
        return ThemeUtils.colorValue(theme, name, fallback)
    }

    function timeToX(ms) {
        return ruler ? ruler.timeToX(ms) : 0
    }

    function durationToWidth(ms) {
        var pixelsPerSecond = ruler ? ruler.effectivePixelsPerSecond : 1
        return Math.max(1, ms / 1000 * pixelsPerSecond)
    }

    Repeater {
        model: root.tracks

        delegate: Item {
            id: trackRow

            property var trackData: modelData

            x: 0
            y: index * (root.rowHeight + root.rowSpacing)
            width: root.width
            height: root.rowHeight

            Rectangle {
                anchors.fill: parent
                color: root.colorValue("surface", "#0f172a")
                border.color: root.colorValue("border", "#334155")
                border.width: 1
                radius: 6
                opacity: 0.88
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                y: Math.round(parent.height / 2)
                height: 1
                color: root.colorValue("border", "#334155")
                opacity: 0.28
            }

            Base.AppText {
                x: 12
                y: 8
                width: 104
                text: trackRow.trackData.name
                theme: root.theme
                styleRole: "bodyS"
                textTone: "secondary"
                elide: Text.ElideRight
            }

            Repeater {
                model: trackRow.trackData.commands

                delegate: Rectangle {
                    id: commandBlock

                    property var commandData: modelData

                    x: root.timeToX(commandData.startMs)
                    y: 14
                    width: root.durationToWidth(commandData.durationMs)
                    height: 28
                    radius: 4
                    color: commandData.color
                    opacity: 0.9

                    Base.AppText {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        text: commandBlock.commandData.name
                        theme: root.theme
                        styleRole: "bodyS"
                        textTone: "inverse"
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    Rectangle {
        x: ruler ? Math.round(ruler.currentTimeX) : 0
        y: 0
        width: 1
        height: parent.height
        color: "#ef4444"
        opacity: 0.55
        visible: ruler && x >= 0 && x <= parent.width
    }
}
