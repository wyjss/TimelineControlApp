import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14
import UICore.Style 1.0
import "internal/AppThemeUtils.js" as ThemeUtils

Label {
    id: root

    property int styleRole: UiStyle.TypographyRole.BodyL
    property int textTone: UiStyle.TextTone.Primary

    property string familyOverride: ""
    property int overridePixelSize: -1
    property int overrideWeight: -1
    property var colorOverride: undefined

    property bool animateColor: true
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

    onCurrentWindowThemeChanged: {
        if (currentWindowTheme)
            _retainedTheme = currentWindowTheme
    }

    property int transitionDuration: resolvedTheme.motion.durationStandard
    property int transitionEasing: resolvedTheme.motion.easingStandard
    function typographyValue(name) {
        return ThemeUtils.numericTypographyValue(resolvedTheme, name)
    }

    function colorValue(name) {
        return ThemeUtils.colorValue(resolvedTheme, name)
    }

    function textToneColorSpec(tone) {
        switch (tone) {
        case UiStyle.TextTone.Secondary:
            return "subtleText"
        case UiStyle.TextTone.Accent:
            return "highlightText"
        case UiStyle.TextTone.Success:
            return "successText"
        case UiStyle.TextTone.Warning:
            return "warningText"
        case UiStyle.TextTone.Info:
            return "infoText"
        case UiStyle.TextTone.Neutral:
            return "neutralText"
        case UiStyle.TextTone.Danger:
            return "dangerText"
        case UiStyle.TextTone.Inverse:
            return "inverseText"
        default:
            return "text"
        }
    }

    function resolvedColorFromSpec(colorSpec) {
        return ThemeUtils.resolvedColorSpec(resolvedTheme, colorSpec)
    }

    function resolvedPixelSize() {
        if (overridePixelSize >= 0)
            return overridePixelSize

        switch (styleRole) {
        case UiStyle.TypographyRole.TitleXL:
            return typographyValue("titleXL")
        case UiStyle.TypographyRole.TitleL:
            return typographyValue("titleL")
        case UiStyle.TypographyRole.TitleM:
            return typographyValue("titleM")
        case UiStyle.TypographyRole.SectionTitle:
            return typographyValue("sectionTitle")
        case UiStyle.TypographyRole.BodyM:
            return typographyValue("bodyM")
        case UiStyle.TypographyRole.BodyS:
            return typographyValue("bodyS")
        default:
            return typographyValue("bodyL")
        }
    }

    function resolvedWeight() {
        if (overrideWeight >= 0)
            return overrideWeight

        switch (styleRole) {
        case UiStyle.TypographyRole.TitleXL:
        case UiStyle.TypographyRole.TitleL:
        case UiStyle.TypographyRole.TitleM:
        case UiStyle.TypographyRole.SectionTitle:
            return typographyValue("weightBold")
        case UiStyle.TypographyRole.Label:
            return typographyValue("weightStrong")
        default:
            return typographyValue("weightRegular")
        }
    }

    function resolvedColor() {
        if (colorOverride !== undefined)
            return colorOverride

        return resolvedColorFromSpec(textToneColorSpec(textTone))
    }

    font.family: familyOverride.length > 0
        ? familyOverride
        : resolvedTheme.typography.familySans
    font.pixelSize: resolvedPixelSize()
    font.weight: resolvedWeight()
    color: resolvedColor()

    Behavior on color {
        enabled: root.animateColor
        ColorAnimation {
            duration: root.transitionDuration
            easing.type: root.transitionEasing
        }
    }
}
