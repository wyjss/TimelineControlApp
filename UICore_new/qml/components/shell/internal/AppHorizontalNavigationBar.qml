import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import ".." as Shell
import "../../base" as Base

Shell.AppNavigationBar {
    id: root

    property int edge: Qt.TopEdge

    orientation: Qt.Horizontal

    itemDelegate: Component {
        Base.AppButton {
            id: navigationButton

            readonly property string itemKey: modelData && modelData.key !== undefined
                ? String(modelData.key)
                : ""

            Layout.alignment: Qt.AlignVCenter
            variant: UiStyle.ButtonVariant.Ghost
            size: UiStyle.ButtonSize.Small
            text: modelData && modelData.label !== undefined ? String(modelData.label) : ""
            iconName: modelData && modelData.iconName !== undefined ? String(modelData.iconName) : ""
            highlighted: itemKey === root.activeItemKey
            enabled: !modelData || modelData.enabled === undefined || !!modelData.enabled
            visible: !modelData || modelData.visible === undefined || !!modelData.visible
            animated: root.animated
            animateScale: false
            onClicked: root.itemTriggered(itemKey)

            Rectangle {
                parent: navigationButton
                x: 0
                y: root.edge === Qt.TopEdge ? parent.height - height : 0
                width: parent.width
                height: root.resolvedTheme.density.dividerThickness * 2
                color: root.resolvedTheme.colors.highlightText
                opacity: navigationButton.highlighted ? 1 : 0
            }
        }
    }

    Rectangle {
        x: -root.leftPadding
        y: root.edge === Qt.TopEdge ? root.height - height : 0
        width: root.width
        height: root.resolvedTheme.density.dividerThickness
        color: root.resolvedTheme.colors.border
        opacity: 0.52
    }
}
