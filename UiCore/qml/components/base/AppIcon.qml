import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14
import QtGraphicalEffects 1.14

Control {
    id: root

    property QtObject theme
    property string name: ""
    property url source: ""
    property string symbol: fallbackSymbol()
    readonly property QtObject applicationWindowTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : null
    readonly property QtObject windowTheme: Window.window && Window.window.appTheme
        ? Window.window.appTheme
        : null
    readonly property QtObject resolvedTheme: theme
        ? theme
        : (applicationWindowTheme ? applicationWindowTheme : windowTheme)
    property color color: resolvedTheme && resolvedTheme.colors ? resolvedTheme.colors.text : "#e6edf3"
    property int size: 16
    property bool tintSource: true

    readonly property url resolvedSource: source.toString().length > 0
        ? source
        : ((resolvedTheme && resolvedTheme.icons && name.length > 0) ? resolvedTheme.icons.icon(name) : "")

    function fallbackSymbol() {
        return name.length > 0 ? name.charAt(0).toUpperCase() : ""
    }

    padding: 0
    width: size
    height: size
    implicitWidth: size
    implicitHeight: size

    background: null

    contentItem: Item {
        implicitWidth: root.size
        implicitHeight: root.size

        Image {
            id: iconImage
            anchors.fill: parent
            source: root.resolvedSource
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            visible: status === Image.Ready
            layer.enabled: root.tintSource && status === Image.Ready
            layer.effect: ColorOverlay {
                color: root.color
            }
        }

        Text {
            anchors.centerIn: parent
            visible: iconImage.status !== Image.Ready
            text: root.symbol
            color: root.color
            font.family: root.resolvedTheme && root.resolvedTheme.typography
                ? root.resolvedTheme.typography.familySans
                : ""
            font.pixelSize: Math.max(10, Math.round(root.size * 0.72))
            font.weight: root.resolvedTheme && root.resolvedTheme.typography
                ? root.resolvedTheme.typography.weightBold
                : Font.Bold
        }
    }
}
