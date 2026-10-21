import QtQuick 2.14
import UICore.Style 1.0

AppSurface {
    id: root

    property string text: ""
    property int textTone: UiStyle.TextTone.Secondary
    property var textColorOverride: undefined

    surfaceTone: UiStyle.SurfaceTone.Section
    shapeRole: UiStyle.ShapeRole.Pill
    strokeWidth: 0
    sizeToContent: false
    implicitWidth: leftPadding + rightPadding + badgeText.implicitWidth
    implicitHeight: themeReady ? resolvedTheme.density.chipHeight : 0
    leftPadding: themeReady ? resolvedTheme.density.controlPaddingXSm : 0
    rightPadding: leftPadding

    // 保留父组件的内容容器，避免异步创建时替换并销毁已登记的对象。
    AppText {
        id: badgeText

        anchors.fill: parent

        text: root.text
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: root.textTone
        colorOverride: root.textColorOverride
        animateColor: root.animateColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
