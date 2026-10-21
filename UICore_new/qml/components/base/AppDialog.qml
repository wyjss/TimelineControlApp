import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0

AppPopup {
    id: root

    default property alias dialogContent: bodyLayout.data

    property string title: ""
    property string message: ""
    property string acceptText: ""
    property string rejectText: ""
    property bool closable: false
    property bool closeOnAccepted: true
    property bool closeOnRejected: true
    property bool acceptEnabled: true
    property string acceptIconName: ""
    property int acceptButtonVariant: UiStyle.ButtonVariant.Primary
    property Item initialFocusItem: null
    property real maximumDialogHeight: parent
        ? Math.max(0, parent.height - resolvedTheme.density.pageMargin * 2)
        : 0
    property bool _actionHandled: false

    readonly property int visibleSectionCount: (headerRow.visible ? 1 : 0)
        + (bodyScrollPane.visible ? 1 : 0)
        + (footerRow.visible ? 1 : 0)
    readonly property real naturalContentHeight: (headerRow.visible ? headerRow.implicitHeight : 0)
        + (bodyScrollPane.visible ? bodyScrollPane.availableContentHeight : 0)
        + (footerRow.visible ? footerRow.implicitHeight : 0)
        + Math.max(0, visibleSectionCount - 1) * spacing
    readonly property real maximumContentHeight: maximumDialogHeight > 0
        ? Math.max(0, maximumDialogHeight - topPadding - bottomPadding)
        : naturalContentHeight
    readonly property real resolvedContentHeight: Math.min(
        naturalContentHeight,
        maximumContentHeight
    )

    signal accepted()
    signal rejected()

    modal: true
    focus: true
    showModalOverlay: true
    closePolicy: Popup.CloseOnEscape
    height: topPadding + resolvedContentHeight + bottomPadding

    onAboutToShow: _actionHandled = false
    onOpened: {
        var focusItem = initialFocusItem
        if (!focusItem || !focusItem.visible || !focusItem.enabled)
            focusItem = acceptButton.visible && acceptButton.enabled
                ? acceptButton
                : (rejectButton.visible ? rejectButton : closeButton)

        if (focusItem && focusItem.visible && focusItem.enabled)
            focusItem.forceActiveFocus(Qt.TabFocusReason)
    }
    onClosed: {
        if (!_actionHandled)
            rejected()
    }

    contentItem: ColumnLayout {
        id: dialogLayout

        spacing: root.spacing

        RowLayout {
            id: headerRow

            Layout.fillWidth: true
            visible: root.title.length > 0 || root.closable
            spacing: root.spacing

            AppText {
                Layout.fillWidth: true
                text: root.title
                styleRole: UiStyle.TypographyRole.SectionTitle
                wrapMode: Text.WordWrap
            }

            AppButton {
                id: closeButton

                visible: root.closable
                iconSymbol: "×"
                variant: UiStyle.ButtonVariant.Ghost
                size: UiStyle.ButtonSize.Small
                Accessible.name: qsTr("关闭")
                onClicked: {
                    root._actionHandled = true
                    root.rejected()
                    if (root.closeOnRejected)
                        root.close()
                }
            }
        }

        AppScrollPane {
            id: bodyScrollPane

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            Layout.preferredHeight: availableContentHeight
            visible: root.message.length > 0 || bodyLayout.children.length > 0
            contentSpacing: root.spacing
            showEdgeHints: true

            AppText {
                Layout.fillWidth: true
                visible: root.message.length > 0
                text: root.message
                styleRole: UiStyle.TypographyRole.BodyM
                textTone: UiStyle.TextTone.Secondary
                wrapMode: Text.WordWrap
            }

            ColumnLayout {
                id: bodyLayout

                Layout.fillWidth: true
                visible: children.length > 0
                spacing: root.spacing
            }
        }

        RowLayout {
            id: footerRow

            Layout.fillWidth: true
            visible: root.rejectText.length > 0 || root.acceptText.length > 0
            spacing: root.spacing

            Item {
                Layout.fillWidth: true
            }

            AppButton {
                id: rejectButton

                visible: root.rejectText.length > 0
                text: root.rejectText
                variant: UiStyle.ButtonVariant.Ghost
                onClicked: {
                    root._actionHandled = true
                    root.rejected()
                    if (root.closeOnRejected)
                        root.close()
                }
            }

            AppButton {
                id: acceptButton

                visible: root.acceptText.length > 0
                enabled: root.acceptEnabled
                text: root.acceptText
                iconName: root.acceptIconName
                variant: root.acceptButtonVariant
                onClicked: {
                    root._actionHandled = true
                    root.accepted()
                    if (root.closeOnAccepted)
                        root.close()
                }
            }
        }
    }
}
