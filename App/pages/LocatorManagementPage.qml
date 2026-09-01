import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import LocatorViewer 1.0
import "location"

Item {
    id: root

    property bool managementMode: true
    property var deviceModel: null
    property var fenceManager: null
    property var targetItems: []
    property var displayedFenceHandles: []
    property string currentFenceHandle: ""
    property string pendingFenceHandle: ""
    property string pendingFenceName: ""

    function refreshTargets() {
        targetItems = deviceModel
            ? deviceModel.deviceOptionsForDeviceType(qsTr("定位器"))
            : []
    }

    function restoreFences() {
        for (var oldIndex = 0; oldIndex < displayedFenceHandles.length; ++oldIndex)
            viewer.removeObject(displayedFenceHandles[oldIndex])

        var handles = []
        var fences = fenceManager ? fenceManager.fences : []
        for (var index = 0; index < fences.length; ++index) {
            var fence = fences[index]
            viewer.updateLine(fence.handle,
                              fence.startLongitude,
                              fence.startLatitude,
                              fence.endLongitude,
                              fence.endLatitude)
            handles.push(String(fence.handle))
        }
        displayedFenceHandles = handles
        if (currentFenceHandle.length > 0
                && displayedFenceHandles.indexOf(currentFenceHandle) < 0)
            currentFenceHandle = ""
    }

    function createFence() {
        pendingFenceHandle = "fence." + Date.now()
        pendingFenceName = qsTr("栅栏 %1").arg((fenceManager ? fenceManager.fences.length : 0) + 1)
        viewer.startLineDrawing(pendingFenceHandle)
    }

    LocatorViewer {
        id: viewer

        anchors.fill: parent
        editable: root.managementMode
        onLineChanged: {
            if (!finished || !root.fenceManager || name !== root.pendingFenceHandle)
                return

            var fenceName = root.pendingFenceName
            root.pendingFenceHandle = ""
            root.pendingFenceName = ""
            root.fenceManager.upsertFence(name,
                                          fenceName,
                                          startLongitude,
                                          startLatitude,
                                          endLongitude,
                                          endLatitude)
            root.currentFenceHandle = name
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 12
        width: Math.min(300, parent.width - 24)
        visible: root.managementMode
        color: "#e6202935"
        radius: 8
        z: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                TabBar {
                    id: listTabs

                    Layout.fillWidth: true

                    TabButton { text: qsTr("目标") }
                    TabButton { text: qsTr("栅栏") }
                }

                Button {
                    visible: listTabs.currentIndex === 1
                    text: qsTr("创建")
                    onClicked: root.createFence()
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: listTabs.currentIndex

                ListView {
                    clip: true
                    spacing: 4
                    model: root.targetItems

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 40
                        radius: 4
                        color: root.deviceModel
                            && root.deviceModel.currentDeviceId === String(modelData.value)
                            ? "#405f8f"
                            : "#26313f"

                        Label {
                            anchors.fill: parent
                            anchors.margins: 10
                            text: String(modelData.label)
                            color: "white"
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.deviceModel.selectDevice(String(modelData.value))
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: parent.count === 0
                        text: qsTr("暂无目标")
                        color: "#aab4c0"
                    }
                }

                FenceListPanel {
                    fences: root.fenceManager ? root.fenceManager.fences : []
                    currentHandle: root.currentFenceHandle
                    onSelected: root.currentFenceHandle = handle
                    onRemoveRequested: {
                        if (root.fenceManager)
                            root.fenceManager.removeFence(handle)
                    }
                }
            }
        }
    }

    Connections {
        target: root.deviceModel
        function onDevicesChanged() { root.refreshTargets() }
    }

    Connections {
        target: root.fenceManager
        function onFencesChanged() { root.restoreFences() }
    }

    Component.onCompleted: {
        refreshTargets()
        restoreFences()
    }
}
