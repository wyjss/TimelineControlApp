import QtQuick 2.14
import QtQuick.Controls 2.14

AbstractButton {
    id: root

    property var control
    property bool expanded: true
    property string accessibleName: qsTr("面板")

    readonly property bool resolvedAnimated: control.animated
    readonly property int resolvedDuration: control.transitionDuration
    readonly property int resolvedEasing: control.transitionEasing
    readonly property int resolvedEmphasizedEasing: control.resolvedTheme.motion.easingEmphasized
    readonly property int buttonSize: control.densityValue("controlHeightSm")
    readonly property int iconSize: Math.max(11, Math.round(buttonSize * 0.36))

    property color iconColor: hovered || visualFocus
        ? controlColor("highlightText")
        : controlColor("subtleText")

    signal toggleRequested(bool nextExpanded)

    function controlColor(name) {
        return control.colorValue(name)
    }

    objectName: "paneDisclosure"
    implicitWidth: buttonSize
    implicitHeight: buttonSize
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.Button
    Accessible.name: qsTr("%1，%2").arg(accessibleName).arg(
        expanded ? qsTr("已展开") : qsTr("已折叠")
    )
    Accessible.description: expanded ? qsTr("按下可折叠") : qsTr("按下可展开")
    Accessible.checkable: true
    Accessible.checked: expanded
    Accessible.focusable: enabled
    Accessible.focused: activeFocus
    Accessible.onPressAction: {
        if (root.enabled)
            root.toggleRequested(!root.expanded)
    }

    onClicked: toggleRequested(!expanded)

    Keys.onPressed: {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
            return

        event.accepted = true
        if (!event.isAutoRepeat)
            root.toggleRequested(!root.expanded)
    }

    Behavior on iconColor {
        enabled: root.resolvedAnimated
        ColorAnimation {
            duration: root.resolvedDuration
            easing.type: root.resolvedEasing
        }
    }

    background: Rectangle {
        radius: root.control.shapeValue("controlRadius")
        color: root.controlColor("highlightSoft")
        opacity: root.hovered || root.pressed ? 0.72 : 0
        border.width: root.visualFocus ? 2 : 0
        border.color: root.controlColor("highlightText")
        antialiasing: true

        Behavior on opacity {
            enabled: root.resolvedAnimated
            NumberAnimation {
                duration: root.resolvedDuration
                easing.type: root.resolvedEasing
            }
        }
    }

    contentItem: Item {
        Canvas {
            id: chevronCanvas

            anchors.centerIn: parent
            width: root.iconSize
            height: root.iconSize
            rotation: root.expanded ? 0 : -90
            contextType: "2d"

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            Behavior on rotation {
                enabled: root.resolvedAnimated
                NumberAnimation {
                    duration: root.resolvedDuration
                    easing.type: root.resolvedEmphasizedEasing
                }
            }

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
    }

}
