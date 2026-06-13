import QtQuick 2.14
import QtQuick.Controls 2.14
import "../../foundation"
import "../base" as Base

Button {
    id: root

    property QtObject theme
    property string iconName: ""
    property string iconSymbol: ""
    property string systemGlyph: ""
    property bool active: false
    property bool danger: false
    property int buttonSize: theme && theme.shell ? theme.shell.topBarIconButtonSize : 30
    property bool animated: true

    readonly property bool useSystemGlyph: systemGlyph.length > 0
    readonly property color baseTint: danger
        ? "#fda4af"
        : (active
            ? colorValue("highlightText", "#7cb4ff")
            : (hovered ? colorValue("text", "#e6edf3") : colorValue("subtleText", "#97a3b6")))
    readonly property color baseFill: active
        ? Qt.rgba(baseTint.r, baseTint.g, baseTint.b, 0.12)
        : "transparent"
    readonly property color hoverFill: danger
        ? Qt.rgba(0.96, 0.27, 0.38, 0.18)
        : colorValue("windowAccent", "#222b36")

    function colorValue(name, fallback) {
        return theme && theme.colors && theme.colors[name] !== undefined
            ? theme.colors[name]
            : fallback
    }

    flat: true
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitWidth: buttonSize
    implicitHeight: buttonSize

    onPressed: root.forceActiveFocus(Qt.MouseFocusReason)

    background: Base.AppSurface {
        enabled: false
        theme: root.theme
        surfaceTone: "ghost"
        shapeRole: AppUiEnums.ShapeRole.Control
        strokeWidth: 0
        interactive: root.enabled
        hoveredState: root.hovered
        pressedState: root.down
        animated: root.animated
        animateScale: false
        fillOverride: root.baseFill
        hoverOverlayColorOverride: root.hoverFill
        hoverOverlayOpacity: root.danger ? 1 : 0.12
        activeOverlayColorOverride: root.hoverFill
        activeOverlayOpacity: root.danger ? 0.9 : 0.12
        transitionDuration: root.theme ? root.theme.motion.durationStandard : 160
    }

    contentItem: Item {
        implicitWidth: root.buttonSize
        implicitHeight: root.buttonSize

        Canvas {
            id: systemGlyphCanvas
            anchors.centerIn: parent
            width: 12
            height: 12
            visible: root.useSystemGlyph

            onVisibleChanged: requestPaint()

            Connections {
                target: root
                function onBaseTintChanged() {
                    systemGlyphCanvas.requestPaint()
                }
                function onSystemGlyphChanged() {
                    systemGlyphCanvas.requestPaint()
                }
            }

            onPaint: {
                var ctx = getContext("2d")

                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = root.baseTint
                ctx.fillStyle = root.baseTint
                ctx.lineWidth = 1.4
                ctx.lineCap = "square"
                ctx.lineJoin = "miter"

                switch (root.systemGlyph) {
                case "minimize":
                    ctx.beginPath()
                    ctx.moveTo(2, 8.5)
                    ctx.lineTo(10, 8.5)
                    ctx.stroke()
                    break
                case "maximize":
                    ctx.strokeRect(2, 2, 8, 8)
                    break
                case "restore":
                    ctx.strokeRect(4, 2, 6, 6)
                    ctx.beginPath()
                    ctx.moveTo(4, 4)
                    ctx.lineTo(2, 4)
                    ctx.lineTo(2, 10)
                    ctx.lineTo(8, 10)
                    ctx.lineTo(8, 8)
                    ctx.stroke()
                    break
                case "close":
                    ctx.beginPath()
                    ctx.moveTo(2.5, 2.5)
                    ctx.lineTo(9.5, 9.5)
                    ctx.moveTo(9.5, 2.5)
                    ctx.lineTo(2.5, 9.5)
                    ctx.stroke()
                    break
                }
            }
        }

        Base.AppIcon {
            anchors.centerIn: parent
            visible: !root.useSystemGlyph
            theme: root.theme
            name: root.iconName
            symbol: root.iconSymbol
            size: 16
            color: root.baseTint
        }
    }
}
