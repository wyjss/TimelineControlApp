import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14
import "internal/AppThemeUtils.js" as ThemeUtils

ProgressBar {
    id: root

    property var fillOverride: undefined
    property var trackOverride: undefined

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
    readonly property bool themeReady: !!resolvedTheme
    readonly property color fillColor: fillOverride !== undefined
        ? fillOverride
        : (themeReady ? ThemeUtils.colorValue(resolvedTheme, "highlightFill") : "transparent")
    readonly property color trackColor: trackOverride !== undefined
        ? trackOverride
        : (themeReady ? ThemeUtils.colorValue(resolvedTheme, "backgroundWindowVariant") : "transparent")
    readonly property int trackHeight: themeReady ? resolvedTheme.density.progressTrackHeight : 0

    onCurrentWindowThemeChanged: {
        if (currentWindowTheme)
            _retainedTheme = currentWindowTheme
    }

    implicitWidth: themeReady ? resolvedTheme.density.controlHeightMd * 4 : 0
    implicitHeight: trackHeight
    padding: 0

    background: Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.trackHeight
        radius: height * 0.5
        color: root.trackColor
    }

    contentItem: Item {
        implicitHeight: root.trackHeight
        clip: true

        Rectangle {
            id: progressFill

            property real indeterminateProgress: 0
            readonly property real resolvedWidth: root.indeterminate
                ? Math.min(parent.width, Math.max(root.trackHeight * 2, parent.width * 0.3))
                : parent.width * root.position
            readonly property real indeterminateX: -width
                + (parent.width + width) * indeterminateProgress

            x: root.indeterminate
                ? (root.mirrored ? parent.width - indeterminateX - width : indeterminateX)
                : (root.mirrored ? parent.width - width : 0)
            width: resolvedWidth
            height: root.trackHeight
            anchors.verticalCenter: parent.verticalCenter
            radius: height * 0.5
            color: root.fillColor

            Behavior on width {
                enabled: !root.indeterminate
                NumberAnimation {
                    duration: root.themeReady ? root.resolvedTheme.motion.durationStandard : 0
                    easing.type: root.themeReady ? root.resolvedTheme.motion.easingStandard : Easing.Linear
                }
            }

            NumberAnimation on indeterminateProgress {
                from: 0
                to: 1
                loops: Animation.Infinite
                duration: root.themeReady ? root.resolvedTheme.motion.progressIndeterminateDuration : 0
                running: root.indeterminate && root.visible && root.themeReady
            }
        }
    }
}
