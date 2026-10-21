import QtQuick 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0

AppSurface {
    id: root

    property string title: ""
    property string message: ""
    property string iconName: ""
    property string iconSymbol: defaultIconSymbol()
    property string actionText: ""
    property bool closable: false
    property bool compact: false

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

    surfaceTone: UiStyle.SurfaceTone.Info
    shapeRole: UiStyle.ShapeRole.Section
    padding: compact
        ? densityValue("panePaddingCompact")
        : densityValue("panePadding")

    contentItem: RowLayout {
        spacing: root.densityValue("controlGap")

        AppIcon {
            Layout.alignment: Qt.AlignTop
            visible: root.iconName.length > 0 || root.iconSymbol.length > 0
            name: root.iconName
            symbol: root.iconSymbol
            size: root.resolvedTheme.metrics.iconSizeLg
            color: titleText.color
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.densityValue("paneHeaderSpacing")

            AppText {
                id: titleText

                Layout.fillWidth: true
                visible: root.title.length > 0
                text: root.title
                styleRole: UiStyle.TypographyRole.Label
                textTone: root.statusTextTone
                wrapMode: Text.WordWrap
            }

            AppText {
                Layout.fillWidth: true
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
            Layout.alignment: Qt.AlignTop
            active: root.actionText.length > 0
            visible: active

            sourceComponent: AppButton {
                text: root.actionText
                variant: UiStyle.ButtonVariant.Ghost
                size: UiStyle.ButtonSize.Small
                onClicked: root.actionTriggered()
            }
        }

        Loader {
            Layout.alignment: Qt.AlignTop
            active: root.closable
            visible: active

            sourceComponent: AppButton {
                iconSymbol: "×"
                variant: UiStyle.ButtonVariant.Ghost
                size: UiStyle.ButtonSize.Small
                Accessible.name: qsTr("关闭")
                onClicked: root.closeRequested()
            }
        }
    }
}
