import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14
import "internal/AppThemeUtils.js" as ThemeUtils

Item {
    id: root

    property Flickable target: null
    property bool active: true
    property bool autoHide: true
    property int autoHideDelay: resolvedTheme.motion.scrollEdgeHintHideDelay
    property int extent: ThemeUtils.densityValue(resolvedTheme, "scrollEdgeHintExtent")
    property real hintOpacity: 1.0
    property color hintColor: colorWithAlpha(colorValue("highlightText"), 0.16)
    property bool revealActive: false
    property bool hovered: false

    readonly property QtObject applicationWindowTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : null
    readonly property QtObject windowTheme: Window.window && Window.window.appTheme
        ? Window.window.appTheme
        : null
    readonly property QtObject currentWindowTheme: applicationWindowTheme
        ? applicationWindowTheme
        : windowTheme
    property QtObject _retainedTheme: currentWindowTheme
    readonly property QtObject resolvedTheme: _retainedTheme
    readonly property bool canScrollUp: target ? !target.atYBeginning : false
    readonly property bool canScrollDown: target ? !target.atYEnd : false
    readonly property bool targetMoving: target ? target.movingVertically : false
    readonly property bool hintsActive: active
        && target
        && target.contentHeight > target.height + 1
    readonly property bool hintsVisible: hintsActive
        && (!autoHide || revealActive || targetMoving)

    function reveal() {
        revealActive = hintsActive

        if (autoHide && revealActive && !targetMoving)
            hideTimer.restart()
        else
            hideTimer.stop()
    }

    onTargetChanged: reveal()
    onHintsActiveChanged: reveal()
    onTargetMovingChanged: {
        if (autoHide && targetMoving && hintsActive) {
            revealActive = true
            hideTimer.stop()
        } else if (autoHide && hintsActive) {
            hideTimer.restart()
        }
    }
    onAutoHideChanged: reveal()
    onHoveredChanged: {
        if (hovered)
            reveal()
    }
    onCurrentWindowThemeChanged: {
        if (currentWindowTheme)
            _retainedTheme = currentWindowTheme
    }

    Component.onCompleted: reveal()

    function colorValue(name) {
        return ThemeUtils.colorValue(resolvedTheme, name)
    }

    function colorWithAlpha(colorSpec, alpha) {
        return Qt.rgba(colorSpec.r, colorSpec.g, colorSpec.b, alpha)
    }

    Timer {
        id: hideTimer

        interval: root.autoHideDelay
        onTriggered: root.revealActive = false
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.min(root.extent, parent.height * 0.5)
        visible: opacity > 0.001
        opacity: root.hintsVisible && root.canScrollUp ? root.hintOpacity : 0

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: root.hintColor
            }

            GradientStop {
                position: 1.0
                color: root.colorWithAlpha(root.hintColor, 0)
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.resolvedTheme.motion.durationFast
                easing.type: root.resolvedTheme.motion.easingStandard
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.min(root.extent, parent.height * 0.5)
        visible: opacity > 0.001
        opacity: root.hintsVisible && root.canScrollDown ? root.hintOpacity : 0

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: root.colorWithAlpha(root.hintColor, 0)
            }

            GradientStop {
                position: 1.0
                color: root.hintColor
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.resolvedTheme.motion.durationFast
                easing.type: root.resolvedTheme.motion.easingStandard
            }
        }
    }
}
