import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14
import UICore.Style 1.0

ToolTip {
    id: root

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

    onCurrentWindowThemeChanged: {
        if (currentWindowTheme)
            _retainedTheme = currentWindowTheme
    }

    delay: themeReady ? resolvedTheme.motion.tooltipDelay : 0
    timeout: themeReady ? resolvedTheme.motion.tooltipTimeout : 0
    leftPadding: themeReady ? resolvedTheme.density.controlPaddingXSm : 0
    rightPadding: leftPadding
    topPadding: themeReady ? resolvedTheme.density.controlGap / 2 : 0
    bottomPadding: topPadding

    background: AppSurface {
        _retainedTheme: root.resolvedTheme
        surfaceTone: UiStyle.SurfaceTone.Popup
        shapeRole: UiStyle.ShapeRole.Control
        strokeWidth: 1
        sizeToContent: false
    }

    contentItem: AppText {
        _retainedTheme: root.resolvedTheme
        text: root.text
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Primary
    }
}
