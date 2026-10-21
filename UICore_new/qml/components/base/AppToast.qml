import QtQuick 2.14
import QtQuick.Controls 2.14
import UICore.Style 1.0

AppPopup {
    id: root

    property string title: ""
    property string message: ""
    property string iconName: ""
    property string iconSymbol: defaultIconSymbol()
    property string actionText: ""
    property int timeout: 4000
    property bool closable: true
    property bool closeOnAction: true
    property bool _timedOut: false

    signal actionTriggered()
    signal closeRequested()

    readonly property int statusTextTone: surfaceTone === UiStyle.SurfaceTone.Success
        ? UiStyle.TextTone.Success
        : (surfaceTone === UiStyle.SurfaceTone.Warning
            ? UiStyle.TextTone.Warning
            : (surfaceTone === UiStyle.SurfaceTone.Danger
                ? UiStyle.TextTone.Danger
                : (surfaceTone === UiStyle.SurfaceTone.Info
                    ? UiStyle.TextTone.Info
                    : UiStyle.TextTone.Primary)))

    function defaultIconSymbol() {
        switch (surfaceTone) {
        case UiStyle.SurfaceTone.Success:
            return "✓"
        case UiStyle.SurfaceTone.Warning:
            return "!"
        case UiStyle.SurfaceTone.Danger:
            return "×"
        case UiStyle.SurfaceTone.Info:
            return "i"
        default:
            return ""
        }
    }

    function show() {
        if (opened)
            dismissTimer.restart()
        else
            open()
    }

    modal: false
    focus: false
    showModalOverlay: false
    closePolicy: Popup.NoAutoClose
    surfaceTone: UiStyle.SurfaceTone.Info
    padding: resolvedTheme.density.panePaddingCompact
    revealOrigin: Item.Top
    revealOffsetY: -resolvedTheme.motion.transitionOffset
    dismissDuration: _timedOut
        ? resolvedTheme.motion.toastDismissDuration
        : resolvedTheme.motion.durationFast
    z: resolvedTheme.z.toast

    onAboutToShow: _timedOut = false

    contentItem: Item {
        implicitHeight: Math.max(
            statusIcon.visible ? statusIcon.implicitHeight : 0,
            toastTextColumn.height,
            actionButtonLoader.item ? actionButtonLoader.item.implicitHeight : 0,
            closeButton.visible ? closeButton.implicitHeight : 0
        )

        Row {
            anchors.fill: parent
            spacing: root.spacing

            Timer {
                id: dismissTimer

                interval: root.timeout
                repeat: false
                running: root.opened && root.timeout > 0 && !toastHover.hovered
                onTriggered: {
                    root._timedOut = true
                    root.close()
                }
            }

            HoverHandler {
                id: toastHover
            }

            AppIcon {
                id: statusIcon

                visible: root.iconName.length > 0 || root.iconSymbol.length > 0
                name: root.iconName
                symbol: root.iconSymbol
                size: root.resolvedTheme.metrics.iconSizeLg
                color: titleText.color
            }

            Column {
                id: toastTextColumn

                width: Math.max(0, root.availableWidth
                    - (statusIcon.visible ? statusIcon.width + root.spacing : 0)
                    - (actionButtonLoader.visible ? actionButtonLoader.width + root.spacing : 0)
                    - (closeButton.visible ? closeButton.width + root.spacing : 0))
                height: (titleText.visible ? titleText.implicitHeight : 0)
                    + (messageText.visible ? messageText.implicitHeight : 0)
                    + (titleText.visible && messageText.visible ? spacing : 0)
                spacing: root.spacing

                AppText {
                    id: titleText

                    width: parent.width
                    visible: root.title.length > 0
                    text: root.title
                    styleRole: UiStyle.TypographyRole.Label
                    textTone: root.statusTextTone
                    wrapMode: Text.WordWrap
                }

                AppText {
                    id: messageText

                    width: parent.width
                    visible: root.message.length > 0
                    text: root.message
                    styleRole: UiStyle.TypographyRole.BodyM
                    textTone: root.title.length > 0
                        ? UiStyle.TextTone.Secondary
                        : root.statusTextTone
                    wrapMode: Text.WordWrap
                }
            }

            Loader {
                id: actionButtonLoader

                active: root.actionText.length > 0
                visible: active

                sourceComponent: AppButton {
                    text: root.actionText
                    variant: UiStyle.ButtonVariant.Ghost
                    size: UiStyle.ButtonSize.Small
                    onClicked: {
                        root.actionTriggered()
                        if (root.closeOnAction)
                            root.close()
                    }
                }
            }

            AppButton {
                id: closeButton

                visible: root.closable
                iconSymbol: "×"
                variant: UiStyle.ButtonVariant.Ghost
                size: UiStyle.ButtonSize.Small
                Accessible.name: qsTr("关闭")
                onClicked: {
                    root.closeRequested()
                    root.close()
                }
            }
        }
    }
}
