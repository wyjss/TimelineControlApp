import QtQuick 2.14
import QtQuick.Layouts 1.14
import "../base" as Base

Base.AppPanel {
    id: root

    property var selectionData: ({})

    readonly property string resolvedTitle: selectionData && selectionData.title !== undefined
        ? String(selectionData.title)
        : ""
    readonly property var lines: selectionData && selectionData.lines !== undefined
        ? selectionData.lines
        : []

    function lineValue(lineData, key, fallback) {
        if (lineData !== undefined && lineData !== null && lineData[key] !== undefined)
            return lineData[key]

        return fallback
    }

    function lineTextTone(lineData, fallback) {
        return String(lineValue(lineData, "textTone", fallback))
    }

    compact: true
    surfaceTone: "surface"
    bodyFillHeight: false
    title: resolvedTitle

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: root.lines

            delegate: Base.AppText {
                Layout.fillWidth: true
                text: String(root.lineValue(modelData, "text", ""))
                theme: root.theme
                styleRole: String(root.lineValue(modelData, "styleRole", "bodyS"))
                textTone: root.lineTextTone(modelData, "primary")
            }
        }
    }
}
