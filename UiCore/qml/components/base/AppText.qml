import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14
import "internal/AppThemeUtils.js" as ThemeUtils

Label {
    id: root

    property QtObject theme
    property string styleRole: "body"
    property string textTone: "primary"

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
    readonly property QtObject resolvedTheme: theme
        ? theme
        : (applicationWindowTheme ? applicationWindowTheme : windowTheme)
    property int transitionDuration: resolvedTheme ? resolvedTheme.motion.durationStandard : 180
    property int transitionEasing: resolvedTheme ? resolvedTheme.motion.easingStandard : Easing.OutCubic
    readonly property string resolvedTextTone: textTone
    readonly property var pixelSizeTokenByRole: ({
        "titleXL": "titleXL",
        "titleL": "titleL",
        "titleM": "titleM",
        "sectionTitle": "sectionTitle",
        "bodyM": "bodyM",
        "bodyS": "bodyS",
        "label": "bodyL"
    })
    readonly property var weightTokenByRole: ({
        "titleXL": "weightBold",
        "titleL": "weightBold",
        "titleM": "weightBold",
        "sectionTitle": "weightBold",
        "label": "weightStrong"
    })

    function typographyValue(name, fallback) {
        return ThemeUtils.numericTypographyValue(resolvedTheme, name, fallback)
    }

    function colorValue(name, fallback) {
        return ThemeUtils.colorValue(resolvedTheme, name, fallback)
    }

    function textToneColorSpec(name) {
        if (!resolvedTheme)
            return undefined

        if (resolvedTheme.textToneColors && resolvedTheme.textToneColors[name] !== undefined)
            return resolvedTheme.textToneColors[name]

        if (resolvedTheme.colors && resolvedTheme.colors[name] !== undefined)
            return resolvedTheme.colors[name]

        return undefined
    }

    function resolvedColorFromSpec(colorSpec, fallback) {
        return ThemeUtils.resolvedColorSpec(resolvedTheme, colorSpec, fallback)
    }

    function resolvedPixelSize() {
        if (overridePixelSize >= 0)
            return overridePixelSize

        var tokenName = pixelSizeTokenByRole[styleRole]
        return typographyValue(tokenName !== undefined ? tokenName : "bodyL", 14)
    }

    function resolvedWeight() {
        if (overrideWeight >= 0)
            return overrideWeight

        var tokenName = weightTokenByRole[styleRole]
        return typographyValue(tokenName !== undefined ? tokenName : "weightRegular", Font.Normal)
    }

    function resolvedColor() {
        if (colorOverride !== undefined)
            return colorOverride

        return resolvedColorFromSpec(
            textToneColorSpec(resolvedTextTone),
            colorValue("text", "#e6edf3")
        )
    }

    font.family: familyOverride.length > 0
        ? familyOverride
        : (resolvedTheme && resolvedTheme.typography ? resolvedTheme.typography.familySans : "Microsoft YaHei UI")
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
