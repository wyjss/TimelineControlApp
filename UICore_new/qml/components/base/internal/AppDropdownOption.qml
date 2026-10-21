import QtQuick 2.14
import QtQuick.Controls 2.14
import UICore.Style 1.0
import ".." as Base

ItemDelegate {
    id: root

    property bool selected: false
    property int optionHeight: 36

    Accessible.role: Accessible.ListItem
    Accessible.name: text
    Accessible.selectable: true
    Accessible.selected: selected
    Accessible.onPressAction: {
        if (root.enabled)
            root.clicked()
    }

    implicitHeight: optionHeight
    padding: 0
    hoverEnabled: true

    background: Base.AppSurface {
        id: optionSurface

        enabled: false
        interactive: false
        surfaceTone: root.selected
            ? UiStyle.SurfaceTone.Highlight
            : UiStyle.SurfaceTone.Ghost
        shapeRole: UiStyle.ShapeRole.Control
        active: root.selected
        hoveredState: root.hovered
        strokeWidth: root.highlighted ? 1 : 0
        fillOverride: root.selected
            ? colorValue("highlightSoft")
            : (root.highlighted ? colorValue("backgroundWindowVariant") : "transparent")
        borderOverride: root.highlighted
            ? colorValue("highlightText")
            : "transparent"
        hoverOverlayColorOverride: colorValue("highlightText")
        hoverOverlayOpacity: root.selected ? 0 : 0.08
        activeOverlayOpacity: root.selected ? 0.04 : 0
    }

    contentItem: Item {
        Rectangle {
            width: 3
            height: parent.height - 16
            radius: width / 2
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            color: optionSurface.colorValue("highlightText")
            opacity: root.selected ? 1 : (root.highlighted ? 0.56 : (root.hovered ? 0.24 : 0))

            Behavior on opacity {
                NumberAnimation {
                    duration: optionSurface.resolvedTheme.motion.durationFast
                    easing.type: optionSurface.resolvedTheme.motion.easingStandard
                }
            }
        }

        Base.AppText {
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            styleRole: UiStyle.TypographyRole.BodyM
            textTone: root.selected
                ? UiStyle.TextTone.Accent
                : UiStyle.TextTone.Primary
            elide: Text.ElideRight
        }
    }
}
