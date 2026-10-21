import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "../base" as Base

AppNavigationBar {
    id: root

    property Component headerContent: null
    property Component footerContent: null
    property bool opened: true
    property bool showItemLabels: true
    property bool autoHideEnabled: false
    property bool autoHideSuspended: false
    property bool autoHideTriggerActive: false
    property int revealDelay: resolvedTheme.motion.shellPanelRevealDelay
    property int hideDelay: resolvedTheme.motion.shellPanelHideDelay

    readonly property real occupiedWidth: opened && !autoHideEnabled ? width : 0

    signal openRequested(bool opened)
    signal itemActivated(string key, var itemData)

    orientation: Qt.Vertical
    leadingContent: headerContent
    trailingContent: footerContent
    x: opened ? 0 : -width
    interactive: autoHideEnabled
    implicitWidth: resolvedTheme.shell.railWidth
    leftPadding: resolvedTheme.shell.railPadding / 2
    rightPadding: resolvedTheme.shell.railPadding / 2
    topPadding: resolvedTheme.shell.railPadding
    bottomPadding: resolvedTheme.shell.railPadding
    contentSpacing: resolvedTheme.shell.railPadding
    surfaceTone: UiStyle.SurfaceTone.Surface
    shapeRole: UiStyle.ShapeRole.None
    strokeWidth: 0
    hoverOverlayOpacity: 0
    clipContent: true

    onAutoHideEnabledChanged: {
        if (!autoHideEnabled && !opened)
            openRequested(true)
    }

    Base.AppAutoHideController {
        enabled: root.autoHideEnabled
        suspended: root.autoHideSuspended
        opened: root.opened
        triggerActive: root.autoHideTriggerActive || root.effectiveHovered
        revealDelay: root.revealDelay
        hideDelay: root.hideDelay
        onOpenRequested: function(opened) {
            root.openRequested(opened)
        }
    }

    itemDelegate: Component {
        AppRailButton {
            id: railButton

            readonly property string itemKey: modelData && modelData.key !== undefined
                ? String(modelData.key)
                : ""
            readonly property string itemLabel: modelData && modelData.label !== undefined
                ? String(modelData.label)
                : ""

            Layout.fillWidth: true
            buttonSize: root.resolvedTheme.shell.railButtonSize
            animated: root.animated
            text: itemLabel
            showText: root.showItemLabels
            iconName: modelData && modelData.iconName !== undefined
                ? String(modelData.iconName)
                : ""
            active: itemKey === root.activeItemKey
            enabled: !modelData || modelData.enabled === undefined || !!modelData.enabled
            visible: !modelData || modelData.visible === undefined || !!modelData.visible
            onClicked: {
                root.itemActivated(itemKey, modelData)
                root.itemTriggered(itemKey)
            }
            onDoubleClicked: railButton.clicked()

            resources: [
                Loader {
                    active: !root.showItemLabels && railButton.itemLabel.length > 0

                    sourceComponent: Base.AppToolTip {
                        parent: railButton
                        visible: railButton.hovered
                        text: railButton.itemLabel
                    }
                }
            ]
        }
    }

    Behavior on x {
        enabled: root.animated

        NumberAnimation {
            duration: root.resolvedTheme.motion.durationStandard
            easing.type: root.resolvedTheme.motion.easingStandard
        }
    }

    Rectangle {
        parent: root
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: root.resolvedTheme.density.dividerThickness
        color: root.resolvedTheme.colors.border
        opacity: 0.52
        z: 1
    }
}
