import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14
import UICore.Internal 1.0

Control {
    id: root

    property string name: ""
    property url source: ""
    property string symbol: fallbackSymbol()
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
    property color color: resolvedTheme.colors.text
    property bool animateColor: true
    property int size: resolvedTheme.metrics.iconSizeMd
    property bool tintSource: true
    property bool mipmap: false

    readonly property url resolvedSource: source.toString().length > 0
        ? source
        : (name.length > 0 ? resolvedTheme.icons.icon(name) : "")

    onCurrentWindowThemeChanged: {
        if (currentWindowTheme)
            _retainedTheme = currentWindowTheme
    }

    function fallbackSymbol() {
        return name.length > 0 ? name.charAt(0).toUpperCase() : ""
    }

    padding: 0
    width: size
    height: size
    implicitWidth: size
    implicitHeight: size

    background: null

    Behavior on color {
        enabled: root.animateColor
        ColorAnimation {
            duration: root.resolvedTheme.motion.durationStandard
            easing.type: root.resolvedTheme.motion.easingStandard
        }
    }

    contentItem: Item {
        implicitWidth: root.size
        implicitHeight: root.size

        AppIconPaintedItem {
            id: paintedIcon
            anchors.fill: parent
            source: root.resolvedSource
            sourceSize: Qt.size(Math.round(root.size * Screen.devicePixelRatio),
                                Math.round(root.size * Screen.devicePixelRatio))
            color: root.color
            tintSource: root.tintSource
            mipmap: root.mipmap
            smooth: true
            visible: ready
        }

        Text {
            anchors.centerIn: parent
            visible: !paintedIcon.ready
            text: root.symbol
            color: root.color
            font.family: root.resolvedTheme.typography.familySans
            font.pixelSize: Math.max(10, Math.round(root.size * 0.72))
            font.weight: root.resolvedTheme.typography.weightBold
        }
    }
}
