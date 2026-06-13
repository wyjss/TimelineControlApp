import QtQuick 2.14
import "internal" as Internal

Internal.AppControlBase {
    id: root

    default property alias contentData: backdropContent.data

    property bool showGradient: true
    property bool showPrimaryGlow: true
    property bool showSecondaryGlow: true

    property color gradientStartColor: resolvedTheme && resolvedTheme.colors
        ? resolvedTheme.colors.window
        : "#0f141b"
    property color gradientEndColor: resolvedTheme && resolvedTheme.colors
        ? resolvedTheme.colors.windowAccent
        : "#222b36"
    property real gradientOpacity: 1

    property color primaryGlowColor: resolvedTheme && resolvedTheme.colors
        ? resolvedTheme.colors.glow
        : "#173056"
    property real primaryGlowOpacity: 0.34
    property real primaryGlowDiameter: Math.max(0, width * 0.38)
    property real primaryGlowX: width - primaryGlowDiameter * 0.68
    property real primaryGlowY: -primaryGlowDiameter * 0.40

    property color secondaryGlowColor: resolvedTheme && resolvedTheme.colors
        ? resolvedTheme.colors.secondaryGlow
        : "#121d2b"
    property real secondaryGlowOpacity: 0.22
    property real secondaryGlowDiameter: Math.max(0, width * 0.24)
    property real secondaryGlowX: -secondaryGlowDiameter * 0.22
    property real secondaryGlowY: height * 0.64

    property real decorationScale: 1

    transitionDuration: resolvedTheme ? resolvedTheme.motion.durationSlow : 260
    transitionEasing: resolvedTheme ? resolvedTheme.motion.easingEmphasized : Easing.OutQuint

    animateScale: animated
    padding: 0
    implicitWidth: 360
    implicitHeight: 240
    clip: root.clipContent

    background: Item {
        Rectangle {
            anchors.fill: parent
            visible: root.showGradient
            opacity: root.gradientOpacity
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.gradientStartColor }
                GradientStop { position: 1.0; color: root.gradientEndColor }
            }

            Behavior on opacity {
                enabled: root.animateOpacity
                NumberAnimation {
                    duration: root.transitionDuration
                    easing.type: root.transitionEasing
                }
            }
        }

        Rectangle {
            visible: root.showPrimaryGlow && opacity > 0
            width: root.primaryGlowDiameter
            height: width
            radius: width / 2
            x: root.primaryGlowX
            y: root.primaryGlowY
            color: root.primaryGlowColor
            opacity: root.primaryGlowOpacity
            scale: root.decorationScale

            Behavior on opacity {
                enabled: root.animateOpacity
                NumberAnimation {
                    duration: root.transitionDuration
                    easing.type: root.transitionEasing
                }
            }

            Behavior on scale {
                enabled: root.animateScale
                NumberAnimation {
                    duration: root.transitionDuration
                    easing.type: root.transitionEasing
                }
            }
        }

        Rectangle {
            visible: root.showSecondaryGlow && opacity > 0
            width: root.secondaryGlowDiameter
            height: width
            radius: width / 2
            x: root.secondaryGlowX
            y: root.secondaryGlowY
            color: root.secondaryGlowColor
            opacity: root.secondaryGlowOpacity
            scale: root.decorationScale

            Behavior on opacity {
                enabled: root.animateOpacity
                NumberAnimation {
                    duration: root.transitionDuration
                    easing.type: root.transitionEasing
                }
            }

            Behavior on scale {
                enabled: root.animateScale
                NumberAnimation {
                    duration: root.transitionDuration
                    easing.type: root.transitionEasing
                }
            }
        }
    }

    contentItem: Item {
        id: backdropContent

        clip: root.clipContent
    }
}
