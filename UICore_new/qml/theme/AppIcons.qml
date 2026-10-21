import QtQuick 2.14

QtObject {
    readonly property url root: Qt.resolvedUrl("../../assets/icons/")
    readonly property string defaultExtension: ".svg"

    function icon(name) {
        return Qt.resolvedUrl("../../assets/icons/" + String(name) + defaultExtension)
    }
}
