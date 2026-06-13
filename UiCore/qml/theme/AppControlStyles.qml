import QtQuick 2.14
import "../foundation"

QtObject {
    function buttonSizeSpec(size) {
        switch (AppUiEnums.normalizeButtonSize(size)) {
        case AppUiEnums.ButtonSize.Small:
            return {
                "heightToken": "controlHeightSm",
                "heightFallback": 32,
                "paddingToken": "controlPaddingXSm",
                "paddingFallback": 10,
                "iconToken": "iconSizeSm",
                "iconFallback": 14,
                "textStyleRole": "bodyM"
            }
        case AppUiEnums.ButtonSize.Large:
            return {
                "heightToken": "controlHeightLg",
                "heightFallback": 42,
                "paddingToken": "controlPaddingXLg",
                "paddingFallback": 16,
                "iconToken": "iconSizeLg",
                "iconFallback": 18,
                "textStyleRole": "label"
            }
        default:
            return {
                "heightToken": "controlHeightMd",
                "heightFallback": 36,
                "paddingToken": "controlPaddingXMd",
                "paddingFallback": 12,
                "iconToken": "iconSizeMd",
                "iconFallback": 16,
                "textStyleRole": "label"
            }
        }
    }

    function buttonVariantSpec(variant) {
        switch (AppUiEnums.normalizeButtonVariant(variant)) {
        case AppUiEnums.ButtonVariant.Primary:
            return {
                "idleFill": "highlightFill",
                "activeFill": "highlightFill",
                "disabledFill": "windowAccent",
                "idleBorder": "transparent",
                "emphasisBorder": "transparent",
                "textTone": "inverse",
                "emphasisTextTone": "inverse",
                "idleIconColor": "inverseText",
                "emphasisIconColor": "inverseText",
                "hoverOverlayColor": "inverseText",
                "activeOverlayColor": "surface",
                "hoverOpacity": 0.08,
                "activeOpacity": 0.08,
                "idleStrokeWidth": 1,
                "emphasisStrokeWidth": 1,
                "disabledStrokeWidth": 1
            }
        case AppUiEnums.ButtonVariant.Tonal:
            return {
                "idleFill": "section",
                "activeFill": "highlightSoft",
                "disabledFill": "section",
                "idleBorder": "transparent",
                "emphasisBorder": "highlightText",
                "textTone": "primary",
                "emphasisTextTone": "accent",
                "idleIconColor": "text",
                "emphasisIconColor": "highlightText",
                "hoverOverlayColor": "highlightText",
                "activeOverlayColor": "highlightSoft",
                "hoverOpacity": 0.09,
                "activeOpacity": 0.12,
                "idleStrokeWidth": 1,
                "emphasisStrokeWidth": 2,
                "disabledStrokeWidth": 1
            }
        case AppUiEnums.ButtonVariant.Ghost:
            return {
                "idleFill": "transparent",
                "activeFill": "highlightSoft",
                "disabledFill": "transparent",
                "idleBorder": "transparent",
                "emphasisBorder": "highlightText",
                "textTone": "primary",
                "emphasisTextTone": "accent",
                "idleIconColor": "text",
                "emphasisIconColor": "highlightText",
                "hoverOverlayColor": "highlightText",
                "activeOverlayColor": "highlightSoft",
                "hoverOpacity": 0.09,
                "activeOpacity": 0.10,
                "idleStrokeWidth": 0,
                "emphasisStrokeWidth": 1,
                "disabledStrokeWidth": 1
            }
        case AppUiEnums.ButtonVariant.Nav:
            return {
                "idleFill": "section",
                "activeFill": "highlightSoft",
                "disabledFill": "section",
                "idleBorder": "border",
                "emphasisBorder": "highlightText",
                "textTone": "primary",
                "emphasisTextTone": "accent",
                "idleIconColor": "text",
                "emphasisIconColor": "highlightText",
                "hoverOverlayColor": "highlightText",
                "activeOverlayColor": "highlightSoft",
                "hoverOpacity": 0.09,
                "activeOpacity": 0.12,
                "idleStrokeWidth": 1,
                "emphasisStrokeWidth": 2,
                "disabledStrokeWidth": 1
            }
        default:
            return {
                "idleFill": "surface",
                "activeFill": "highlightSoft",
                "disabledFill": "surface",
                "idleBorder": "border",
                "emphasisBorder": "highlightText",
                "textTone": "primary",
                "emphasisTextTone": "accent",
                "idleIconColor": "text",
                "emphasisIconColor": "highlightText",
                "hoverOverlayColor": "highlightText",
                "activeOverlayColor": "highlightSoft",
                "hoverOpacity": 0.09,
                "activeOpacity": 0.12,
                "idleStrokeWidth": 1,
                "emphasisStrokeWidth": 2,
                "disabledStrokeWidth": 1
            }
        }
    }

    function toneSpec(fill, fillFallback, border, borderFallback, hoverOverlay,
            hoverOverlayFallback, activeOverlay, activeOverlayFallback) {
        return {
            "fill": fill,
            "fillFallback": fillFallback,
            "border": border,
            "borderFallback": borderFallback,
            "hoverOverlay": hoverOverlay,
            "hoverOverlayFallback": hoverOverlayFallback,
            "activeOverlay": activeOverlay,
            "activeOverlayFallback": activeOverlayFallback
        }
    }

    function surfaceToneSpec(surfaceTone, active) {
        var tone = String(surfaceTone)
        var standardBorder = active ? "highlightText" : "border"
        var standardBorderFallback = active ? "#7cb4ff" : "#334155"

        switch (tone) {
        case "window":
            return toneSpec("window", "#0f141b", standardBorder, standardBorderFallback,
                            "windowAccent", "#222b36", "highlightSoft", "#182b45")
        case "surfaceOverlay":
            return toneSpec("surfaceOverlay", "#B8171D25", "borderOverlay", "#99334155",
                            "windowAccent", "#222b36", "highlightSoft", "#182b45")
        case "section":
            return toneSpec("section", "#1e2631", standardBorder, standardBorderFallback,
                            "windowAccent", "#222b36", "highlightSoft", "#182b45")
        case "sectionOverlay":
            return toneSpec("sectionOverlay", "#A61E2631", "borderOverlay", "#99334155",
                            "windowAccent", "#222b36", "highlightSoft", "#182b45")
        case "canvas":
            return toneSpec("canvas", "#070d12", standardBorder, standardBorderFallback,
                            "windowAccent", "#222b36", "highlightSoft", "#182b45")
        case "highlight":
            return toneSpec("highlightSoft", "#182b45", "highlightText", "#7cb4ff",
                            "highlightText", "#7cb4ff", "highlightSoft", "#182b45")
        case "success":
            return toneSpec("successSoft", "#14271f", "successBorder", "#2f8a67",
                            "successText", "#7ee2b7", "successBorder", "#2f8a67")
        case "warning":
            return toneSpec("warningSoft", "#312813", "warningBorder", "#8a6a1f",
                            "warningText", "#d29922", "warningBorder", "#8a6a1f")
        case "info":
            return toneSpec("infoSoft", "#182b45", "infoBorder", "#3b82f6",
                            "infoText", "#A8C7FA", "infoBorder", "#3b82f6")
        case "neutral":
            return toneSpec("neutralSoft", "#202a36", "neutralBorder", "#475569",
                            "neutralText", "#cbd5e1", "neutralBorder", "#475569")
        case "danger":
            return toneSpec("dangerSoft", "#2b1a21", "dangerBorder", "#b46076",
                            "dangerText", "#ff9eb2", "dangerBorder", "#b46076")
        case "ghost":
            return toneSpec("transparent", "transparent", "transparent", "transparent",
                            "windowAccent", "#222b36", "highlightSoft", "#182b45")
        default:
            return toneSpec("surface", "#171d25", standardBorder, standardBorderFallback,
                            "windowAccent", "#222b36", "highlightSoft", "#182b45")
        }
    }

    function taskPhaseSpec(phaseName) {
        switch (String(phaseName)) {
        case "running":
            return {
                "text": "infoText",
                "textFallback": "#A8C7FA",
                "fill": "infoSoft",
                "fillFallback": "#182b45"
            }
        case "succeeded":
            return {
                "text": "successText",
                "textFallback": "#7ee2b7",
                "fill": "successSoft",
                "fillFallback": "#14271f"
            }
        case "failed":
            return {
                "text": "dangerText",
                "textFallback": "#ff9eb2",
                "fill": "dangerSoft",
                "fillFallback": "#2b1a21"
            }
        case "cancelled":
            return {
                "text": "warningText",
                "textFallback": "#d29922",
                "fill": "warningSoft",
                "fillFallback": "#312813"
            }
        case "ready":
        default:
            return {
                "text": "neutralText",
                "textFallback": "#cbd5e1",
                "fill": "neutralSoft",
                "fillFallback": "#202a36"
            }
        }
    }

    function inputChromeSpec(appearance, hasSelection) {
        var ghost = AppUiEnums.normalizeAppearance(appearance) === AppUiEnums.ControlAppearance.Ghost

        return {
            "ghost": ghost,
            "shapeRole": AppUiEnums.ShapeRole.Control,
            "idleStrokeWidth": ghost ? 0 : 1,
            "activeStrokeWidth": ghost ? 0 : 2,
            "hoverOverlayOpacity": ghost ? 0 : 0.10,
            "activeOverlayOpacity": ghost ? 0 : (hasSelection ? 0.14 : 0.08),
            "disabledOpacity": 0.74
        }
    }
}
