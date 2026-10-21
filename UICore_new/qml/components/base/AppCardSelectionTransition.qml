import QtQuick 2.14
import QtQuick.Controls 2.14
import UICore.Style 1.0

Item {
    id: root

    property alias buttonGroup: cardGroup
    property bool animated: true

    enabled: false
    z: frameSurface.resolvedTheme.z.decoration

    readonly property var checkedButton: cardGroup.checkedButton
    readonly property bool selectionAvailable: !!(checkedButton
        && checkedButton.visible
        && checkedButton.enabled
        && checkedButton.emphasizedSelection)

    property rect targetGeometry: Qt.rect(0, 0, 0, 0)
    property rect selectionGeometry: Qt.rect(0, 0, 0, 0)
    property bool animateGeometry: false
    property bool pendingAnimation: false

    function scheduleSelectionUpdate(useAnimation) {
        pendingAnimation = pendingAnimation || !!useAnimation
        updateTimer.restart()
    }

    function scheduleGeometryUpdate() {
        if (!geometryAnimation.running)
            scheduleSelectionUpdate(false)
    }

    function updateSelection(useAnimation) {
        var button = cardGroup.checkedButton
        if (!button || !button.visible || !button.enabled || !button.emphasizedSelection) {
            geometryAnimation.stop()
            animateGeometry = false
            selectionFrame.visible = false
            targetGeometry = Qt.rect(0, 0, 0, 0)
            return
        }

        var topLeft = button.mapToItem(root, 0, 0)
        var bottomRight = button.mapToItem(root, button.width, button.height)
        var targetX = Math.min(topLeft.x, bottomRight.x)
        var targetY = Math.min(topLeft.y, bottomRight.y)
        var targetWidth = Math.abs(bottomRight.x - topLeft.x)
        var targetHeight = Math.abs(bottomRight.y - topLeft.y)

        animateGeometry = selectionFrame.visible
            && useAnimation
            && animated
            && button.animated
        if (!animateGeometry)
            geometryAnimation.stop()
        targetGeometry = Qt.rect(targetX, targetY, targetWidth, targetHeight)
        selectionGeometry = targetGeometry
        selectionFrame.visible = true
    }

    onWidthChanged: scheduleGeometryUpdate()
    onHeightChanged: scheduleGeometryUpdate()
    onSelectionAvailableChanged: {
        if (selectionFrame)
            scheduleSelectionUpdate(false)
    }

    Component.onCompleted: scheduleSelectionUpdate(false)

    ButtonGroup {
        id: cardGroup

        onCheckedButtonChanged: root.scheduleSelectionUpdate(selectionFrame.visible)
    }

    Timer {
        id: updateTimer

        interval: 0
        onTriggered: {
            var animate = root.pendingAnimation
            root.pendingAnimation = false
            root.updateSelection(animate)
        }
    }

    Connections {
        target: root.selectionAvailable ? root.checkedButton : null
        ignoreUnknownSignals: true

        function onXChanged() { root.scheduleGeometryUpdate() }
        function onYChanged() { root.scheduleGeometryUpdate() }
        function onWidthChanged() { root.scheduleGeometryUpdate() }
        function onHeightChanged() { root.scheduleGeometryUpdate() }
        function onScaleChanged() { root.scheduleGeometryUpdate() }
    }

    Connections {
        target: root.selectionAvailable && root.checkedButton.parent
            ? root.checkedButton.parent
            : null
        ignoreUnknownSignals: true

        function onXChanged() { root.scheduleGeometryUpdate() }
        function onYChanged() { root.scheduleGeometryUpdate() }
        function onWidthChanged() { root.scheduleGeometryUpdate() }
        function onHeightChanged() { root.scheduleGeometryUpdate() }
        function onScaleChanged() { root.scheduleGeometryUpdate() }
    }

    Item {
        id: selectionFrame

        x: root.selectionGeometry.x
        y: root.selectionGeometry.y
        width: root.selectionGeometry.width
        height: root.selectionGeometry.height
        visible: false

        Rectangle {
            anchors.fill: parent
            anchors.margins: -frameSurface.densityValue("dividerThickness") * 2
            radius: frameSurface.resolvedRadius
                + frameSurface.densityValue("dividerThickness") * 2
            color: frameSurface.resolvedColorSpec("transparent")
            border.width: frameSurface.densityValue("dividerThickness") * 2
            border.color: frameSurface.selectionColor
            opacity: 0.2
        }

        AppSurface {
            id: frameSurface

            readonly property color selectionColor: {
                var color = colorValue("highlightFill")
                return Qt.rgba(color.r, color.g, color.b, 0.85)
            }

            anchors.fill: parent
            enabled: false
            sizeToContent: false
            surfaceTone: UiStyle.SurfaceTone.Ghost
            shapeRole: root.checkedButton
                ? root.checkedButton.shapeRole
                : UiStyle.ShapeRole.Section
            surfaceOpacityScale: root.checkedButton
                ? root.checkedButton.surfaceOpacityScale
                : 1.0
            animated: false
            strokeWidth: densityValue("dividerThickness")
            borderOverride: selectionColor

            Item {
                id: selectionIndicator

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: frameSurface.resolvedRadius / 2
                clip: true

                Rectangle {
                    width: frameSurface.width
                    height: frameSurface.height
                    radius: frameSurface.resolvedRadius
                    color: frameSurface.resolvedColorSpec("transparent")
                    border.width: selectionIndicator.width
                    border.color: frameSurface.selectionColor
                }
            }
        }
    }

    Behavior on selectionGeometry {
        enabled: root.animateGeometry

        PropertyAnimation {
            id: geometryAnimation

            duration: frameSurface.resolvedTheme.motion.cardSelectionTransitionDuration
            easing.type: frameSurface.resolvedTheme.motion.easingEmphasized
            onFinished: root.scheduleSelectionUpdate(false)
        }
    }
}
