import QtQuick 2.14

Item {
    id: root

    property var control
    property bool expanded: true
    property bool initialized: false
    property real pulseScale: 1.0

    readonly property bool resolvedAnimated: control && control.animated !== undefined
        ? !!control.animated
        : true
    readonly property int resolvedDuration: control && control.transitionDuration !== undefined
        ? Number(control.transitionDuration)
        : 180
    readonly property int resolvedEasing: control && control.transitionEasing !== undefined
        ? Number(control.transitionEasing)
        : Easing.OutCubic
    readonly property int resolvedEmphasizedEasing: control
        && control.theme
        && control.theme.motion
        && control.theme.motion.easingEmphasized !== undefined
        ? Number(control.theme.motion.easingEmphasized)
        : Easing.OutQuint
    readonly property int buttonSize: control && control.densityValue !== undefined
        ? Number(control.densityValue("controlHeightSm", 32))
        : 32
    readonly property int iconSize: Math.max(11, Math.round(buttonSize * 0.36))
    readonly property bool hovered: disclosureTap.hovered

    property color backgroundColor: expanded
        ? controlColor("highlightSoft", "#182b45")
        : controlColor("windowAccent", "#222b36")
    property color outlineColor: expanded
        ? controlColor("highlightText", "#7cb4ff")
        : controlColor("border", "#334155")
    property color iconColor: expanded
        ? controlColor("highlightText", "#7cb4ff")
        : (hovered
            ? controlColor("text", "#e6edf3")
            : controlColor("subtleText", "#97a3b6"))
    property real backgroundOpacity: expanded ? 0.96 : (hovered ? 0.84 : 0)
    property real outlineOpacity: expanded ? 0.68 : (hovered ? 0.46 : 0)
    property real glowOpacity: expanded ? 0.16 : 0
    property real glowScale: expanded ? pulseScale : 0.78

    signal toggleRequested(bool nextExpanded)

    function controlColor(name, fallback) {
        if (control && control.colorValue !== undefined)
            return control.colorValue(name, fallback)

        return fallback
    }

    onExpandedChanged: {
        if (!initialized || !resolvedAnimated)
            return

        pulseAnimation.restart()
    }

    Component.onCompleted: initialized = true

    objectName: "paneDisclosure"
    implicitWidth: buttonSize
    implicitHeight: buttonSize

    Behavior on backgroundColor {
        enabled: root.resolvedAnimated
        ColorAnimation {
            duration: root.resolvedDuration
            easing.type: root.resolvedEasing
        }
    }

    Behavior on outlineColor {
        enabled: root.resolvedAnimated
        ColorAnimation {
            duration: root.resolvedDuration
            easing.type: root.resolvedEasing
        }
    }

    Behavior on iconColor {
        enabled: root.resolvedAnimated
        ColorAnimation {
            duration: root.resolvedDuration
            easing.type: root.resolvedEasing
        }
    }

    Behavior on backgroundOpacity {
        enabled: root.resolvedAnimated
        NumberAnimation {
            duration: root.resolvedDuration
            easing.type: root.resolvedEasing
        }
    }

    Behavior on outlineOpacity {
        enabled: root.resolvedAnimated
        NumberAnimation {
            duration: root.resolvedDuration
            easing.type: root.resolvedEasing
        }
    }

    Behavior on glowOpacity {
        enabled: root.resolvedAnimated
        NumberAnimation {
            duration: root.resolvedDuration
            easing.type: root.resolvedEasing
        }
    }

    Behavior on glowScale {
        enabled: root.resolvedAnimated
        NumberAnimation {
            duration: root.resolvedDuration
            easing.type: root.resolvedEmphasizedEasing
        }
    }

    SequentialAnimation {
        id: pulseAnimation

        running: false

        NumberAnimation {
            target: root
            property: "pulseScale"
            from: 0.90
            to: 1.08
            duration: Math.max(60, Math.round(root.resolvedDuration * 0.42))
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "pulseScale"
            to: 1.0
            duration: Math.max(80, Math.round(root.resolvedDuration * 0.58))
            easing.type: root.resolvedEmphasizedEasing
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 8
        height: width
        radius: width * 0.5
        color: root.controlColor("highlightText", "#7cb4ff")
        opacity: root.glowOpacity
        scale: root.glowScale
        antialiasing: true
    }

    Rectangle {
        anchors.fill: parent
        radius: width * 0.5
        color: root.backgroundColor
        opacity: root.backgroundOpacity
        antialiasing: true
    }

    Rectangle {
        anchors.fill: parent
        radius: width * 0.5
        color: "transparent"
        border.width: 1
        border.color: root.outlineColor
        opacity: root.outlineOpacity
        antialiasing: true
    }

    Item {
        id: chevronWrap

        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        rotation: root.expanded ? 0 : -90
        scale: (root.expanded ? 1.0 : 0.94) * root.pulseScale

        Behavior on rotation {
            enabled: root.resolvedAnimated
            NumberAnimation {
                duration: root.resolvedDuration
                easing.type: root.resolvedEmphasizedEasing
            }
        }

        Behavior on scale {
            enabled: root.resolvedAnimated
            NumberAnimation {
                duration: root.resolvedDuration
                easing.type: root.resolvedEmphasizedEasing
            }
        }
    }

    Canvas {
        id: chevronCanvas

        anchors.fill: chevronWrap
        contextType: "2d"

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: root

            function onIconColorChanged() {
                chevronCanvas.requestPaint()
            }
        }

        onPaint: {
            var ctx = getContext("2d")
            var inset = Math.max(1.8, width * 0.18)
            var topY = height * 0.34
            var midY = height * 0.66

            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = root.iconColor
            ctx.lineWidth = Math.max(1.8, width * 0.15)
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.beginPath()
            ctx.moveTo(inset, topY)
            ctx.lineTo(width * 0.5, midY)
            ctx.lineTo(width - inset, topY)
            ctx.stroke()
        }
    }

    AppTapRegion {
        id: disclosureTap

        anchors.fill: parent
        onTapped: root.toggleRequested(!root.expanded)
    }
}
