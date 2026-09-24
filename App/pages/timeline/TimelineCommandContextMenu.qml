import QtQuick 2.14
import QtQuick.Controls 2.14

Menu {
    id: root
    objectName: "timelineCommandContextMenu"

    property var timelineCommand: null
    property bool locatingEnabled: false

    signal testRequested(var command)
    signal locateRequested(var command)

    onClosed: timelineCommand = null

    MenuItem {
        objectName: "testTimelineCommandMenuItem"
        text: qsTr("测试")
        enabled: root.timelineCommand !== null
        onTriggered: root.testRequested(root.timelineCommand)
    }

    MenuItem {
        objectName: "locateTimelineCommandMenuItem"
        text: qsTr("定位")
        enabled: root.locatingEnabled && root.timelineCommand !== null
        onTriggered: root.locateRequested(root.timelineCommand)
    }
}
