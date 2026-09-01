import QtQuick 2.14
import ragis.quick 1.0
import LocatorViewer 1.0

Item {
    id: root

    property bool editable: true
    signal lineChanged(string name,
                       double startLongitude,
                       double startLatitude,
                       double endLongitude,
                       double endLatitude,
                       bool finished)

    function updateLine(name, startLongitude, startLatitude, endLongitude, endLatitude) {
        return controller.updateLine(
            name, startLongitude, startLatitude, endLongitude, endLatitude)
    }

    function startLineDrawing(name) {
        return editable && controller.startLineDrawing(name)
    }

    function removeObject(name) {
        return controller.removeTarget(name)
    }

    clip: true

    LocatorViewerController {
        id: controller

        onLineChanged: root.lineChanged(
            name, startLongitude, startLatitude, endLongitude, endLatitude, finished)
    }

    RAGisQuickTextureItem {
        anchors.fill: parent
        focus: true
        viewName: "default2D"
    }

}
