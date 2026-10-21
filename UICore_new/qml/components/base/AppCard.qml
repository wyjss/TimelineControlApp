import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0

AbstractButton {
    id: root

    default property alias cardContent: contentLayout.data

    property int surfaceTone: UiStyle.SurfaceTone.Section
    property int shapeRole: UiStyle.ShapeRole.Section
    property real surfaceOpacityScale: 1.0
    property bool compact: false
    property bool emphasizedSelection: false
    property Item selectionTransition: null
    property bool animated: true
    property bool animateScale: animated
    property int contentSpacing: cardSurface.densityValue("paneContentSpacing")

    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    ButtonGroup.group: selectionTransition
        ? selectionTransition.buttonGroup
        : null
    transformOrigin: Item.Center
    scale: animateScale && down ? cardSurface.pressScaleFactor : 1
    padding: compact
        ? cardSurface.densityValue("panePaddingCompact")
        : cardSurface.densityValue("panePadding")

    onPressed: root.forceActiveFocus(Qt.MouseFocusReason)

    Behavior on scale {
        enabled: root.animateScale

        NumberAnimation {
            duration: root.down
                ? cardSurface.resolvedTheme.motion.durationFast
                : cardSurface.resolvedTheme.motion.durationStandard
            easing.type: cardSurface.resolvedTheme.motion.easingStandard
        }
    }

    background: AppSurface {
        id: cardSurface

        readonly property color selectionColor: {
            var color = colorValue("highlightFill")
            return Qt.rgba(color.r, color.g, color.b, 0.85)
        }

        enabled: false
        sizeToContent: false
        surfaceTone: root.surfaceTone
        surfaceOpacityScale: root.surfaceOpacityScale
        shapeRole: root.shapeRole
        strokeWidth: densityValue("dividerThickness")
        active: root.checked && root.enabled
            && !(root.emphasizedSelection && root.selectionTransition)
        hoveredState: root.hovered && root.enabled
        pressedState: root.down && root.enabled
        animated: root.animated
        fillOverride: !root.enabled
            ? colorValue("disabledFill")
            : (root.checked && root.emphasizedSelection
                ? colorValue("highlightSoft")
                : undefined)
        borderOverride: !root.enabled
            ? colorValue("disabledBorder")
            : (root.visualFocus
                ? colorValue("highlightText")
                : (root.checked && root.emphasizedSelection
                        && !root.selectionTransition
                    ? selectionColor
                    : undefined))
        transitionDuration: root.down
            ? resolvedTheme.motion.durationFast
            : resolvedTheme.motion.durationStandard

        Rectangle {
            anchors.fill: parent
            anchors.margins: -cardSurface.densityValue("dividerThickness") * 2
            radius: cardSurface.resolvedRadius
                + cardSurface.densityValue("dividerThickness") * 2
            color: cardSurface.resolvedColorSpec("transparent")
            border.width: cardSurface.densityValue("dividerThickness") * 2
            border.color: cardSurface.selectionColor
            visible: root.emphasizedSelection && !root.selectionTransition
            opacity: root.checked && root.enabled ? 0.2 : 0

            Behavior on opacity {
                enabled: root.animated && !root.selectionTransition

                NumberAnimation {
                    duration: root.checked
                        ? cardSurface.resolvedTheme.motion.durationStandard
                        : cardSurface.resolvedTheme.motion.durationFast
                    easing.type: cardSurface.resolvedTheme.motion.easingStandard
                }
            }
        }

        Item {
            id: selectionIndicator

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: cardSurface.resolvedRadius / 2
            clip: true
            visible: root.emphasizedSelection && !root.selectionTransition
            opacity: root.checked && root.enabled ? 1 : 0

            Rectangle {
                width: cardSurface.width
                height: cardSurface.height
                radius: cardSurface.resolvedRadius
                color: cardSurface.resolvedColorSpec("transparent")
                border.width: selectionIndicator.width
                border.color: cardSurface.selectionColor
            }

            transform: Scale {
                origin.x: selectionIndicator.width / 2
                origin.y: selectionIndicator.height / 2
                yScale: root.checked && root.enabled ? 1 : 0

                Behavior on yScale {
                    enabled: root.animated && !root.selectionTransition

                    NumberAnimation {
                        duration: cardSurface.resolvedTheme.motion.durationStandard
                        easing.type: cardSurface.resolvedTheme.motion.easingEmphasized
                    }
                }
            }

            Behavior on opacity {
                enabled: root.animated && !root.selectionTransition

                NumberAnimation {
                    duration: root.checked
                        ? cardSurface.resolvedTheme.motion.durationStandard
                        : cardSurface.resolvedTheme.motion.durationFast
                    easing.type: cardSurface.resolvedTheme.motion.easingStandard
                }
            }
        }
    }

    contentItem: ColumnLayout {
        id: contentLayout

        spacing: root.contentSpacing
    }
}
