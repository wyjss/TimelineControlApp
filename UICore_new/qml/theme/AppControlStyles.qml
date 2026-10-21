import QtQuick 2.14
import UICore.Style 1.0

QtObject {
    readonly property real buttonRaisedIdleOpacity: 0.648
    readonly property real buttonRaisedHoverOpacity: 0.765
    readonly property real buttonRaisedPressedOpacity: 0.117

    function buttonSizeSpec(size) {
        switch (size) {
        case UiStyle.ButtonSize.Small:
            return {
                "heightToken": "controlHeightSm",
                "paddingToken": "controlPaddingXSm",
                "iconToken": "iconSizeSm",
                "textStyleRole": UiStyle.TypographyRole.BodyM
            }
        case UiStyle.ButtonSize.Large:
            return {
                "heightToken": "controlHeightLg",
                "paddingToken": "controlPaddingXLg",
                "iconToken": "iconSizeLg",
                "textStyleRole": UiStyle.TypographyRole.Label
            }
        default:
            return {
                "heightToken": "controlHeightMd",
                "paddingToken": "controlPaddingXMd",
                "iconToken": "iconSizeMd",
                "textStyleRole": UiStyle.TypographyRole.Label
            }
        }
    }

    function buttonVariantSpec(variant) {
        switch (variant) {
        case UiStyle.ButtonVariant.Primary:
            return {
                "idleFill": "highlightFill",
                "activeFill": "highlightFill",
                "disabledFill": "disabledFill",
                "idleBorder": "transparent",
                "emphasisBorder": "transparent",
                "textTone": UiStyle.TextTone.Inverse,
                "emphasisTextTone": UiStyle.TextTone.Inverse,
                "idleIconColor": "inverseText",
                "emphasisIconColor": "inverseText",
                "hoverOverlayColor": "inverseText",
                "activeOverlayColor": "backgroundSurface",
                "hoverOpacity": 0.08,
                "activeOpacity": 0.08,
                "idleStrokeWidth": 1,
                "emphasisStrokeWidth": 1,
                "disabledStrokeWidth": 0
            }
        case UiStyle.ButtonVariant.Danger:
            return {
                "idleFill": "dangerFill",
                "activeFill": "dangerFill",
                "disabledFill": "disabledFill",
                "idleBorder": "transparent",
                "emphasisBorder": "transparent",
                "textTone": UiStyle.TextTone.Inverse,
                "emphasisTextTone": UiStyle.TextTone.Inverse,
                "idleIconColor": "inverseText",
                "emphasisIconColor": "inverseText",
                "hoverOverlayColor": "inverseText",
                "activeOverlayColor": "backgroundSurface",
                "hoverOpacity": 0.08,
                "activeOpacity": 0.08,
                "idleStrokeWidth": 1,
                "emphasisStrokeWidth": 1,
                "disabledStrokeWidth": 0
            }
        case UiStyle.ButtonVariant.Tonal:
            return {
                "idleFill": "highlightSoft",
                "activeFill": "highlightSoft",
                "disabledFill": "backgroundSection",
                "idleBorder": "transparent",
                "emphasisBorder": "transparent",
                "textTone": UiStyle.TextTone.Accent,
                "emphasisTextTone": UiStyle.TextTone.Accent,
                "idleIconColor": "highlightText",
                "emphasisIconColor": "highlightText",
                "hoverOverlayColor": "highlightText",
                "activeOverlayColor": "highlightText",
                "hoverOpacity": 0.08,
                "activeOpacity": 0.12,
                "idleStrokeWidth": 0,
                "emphasisStrokeWidth": 0,
                "disabledStrokeWidth": 0
            }
        case UiStyle.ButtonVariant.Subtle:
            return {
                "idleFill": "backgroundSectionOverlay",
                "activeFill": "backgroundSectionOverlay",
                "disabledFill": "backgroundSectionOverlay",
                "idleBorder": "transparent",
                "emphasisBorder": "transparent",
                "textTone": UiStyle.TextTone.Primary,
                "emphasisTextTone": UiStyle.TextTone.Accent,
                "idleIconColor": "text",
                "emphasisIconColor": "highlightText",
                "hoverOverlayColor": "highlightText",
                "activeOverlayColor": "highlightText",
                "hoverOpacity": 0.06,
                "activeOpacity": 0.09,
                "idleStrokeWidth": 0,
                "emphasisStrokeWidth": 0,
                "disabledStrokeWidth": 0
            }
        case UiStyle.ButtonVariant.Ghost:
            return {
                "idleFill": "transparent",
                "activeFill": "highlightSoft",
                "disabledFill": "transparent",
                "idleBorder": "transparent",
                "emphasisBorder": "transparent",
                "textTone": UiStyle.TextTone.Primary,
                "emphasisTextTone": UiStyle.TextTone.Accent,
                "idleIconColor": "text",
                "emphasisIconColor": "highlightText",
                "hoverOverlayColor": "highlightText",
                "activeOverlayColor": "highlightSoft",
                "hoverOpacity": 0.09,
                "activeOpacity": 0.10,
                "idleStrokeWidth": 0,
                "emphasisStrokeWidth": 0,
                "disabledStrokeWidth": 0
            }
        case UiStyle.ButtonVariant.Nav:
            return {
                "idleFill": "transparent",
                "activeFill": "highlightSoft",
                "disabledFill": "transparent",
                "idleBorder": "transparent",
                "emphasisBorder": "transparent",
                "textTone": UiStyle.TextTone.Primary,
                "emphasisTextTone": UiStyle.TextTone.Accent,
                "idleIconColor": "text",
                "emphasisIconColor": "highlightText",
                "hoverOverlayColor": "highlightText",
                "activeOverlayColor": "highlightSoft",
                "hoverOpacity": 0.09,
                "activeOpacity": 0.12,
                "idleStrokeWidth": 0,
                "emphasisStrokeWidth": 0,
                "disabledStrokeWidth": 0
            }
        default:
            return {
                "idleFill": "backgroundSurface",
                "activeFill": "highlightSoft",
                "disabledFill": "backgroundSurface",
                "idleBorder": "controlBorder",
                "emphasisBorder": "controlBorder",
                "textTone": UiStyle.TextTone.Primary,
                "emphasisTextTone": UiStyle.TextTone.Accent,
                "idleIconColor": "text",
                "emphasisIconColor": "highlightText",
                "hoverOverlayColor": "highlightText",
                "activeOverlayColor": "highlightSoft",
                "hoverOpacity": 0.09,
                "activeOpacity": 0.12,
                "idleStrokeWidth": 1,
                "emphasisStrokeWidth": 1,
                "disabledStrokeWidth": 1
            }
        }
    }

    function toneSpec(fill, border, hoverOverlay, activeOverlay) {
        return {
            "fill": fill,
            "border": border,
            "hoverOverlay": hoverOverlay,
            "activeOverlay": activeOverlay
        }
    }

    function surfaceToneSpec(surfaceTone, active) {
        var standardBorder = active ? "highlightFill" : "border"

        switch (surfaceTone) {
        case UiStyle.SurfaceTone.Window:
            return toneSpec("backgroundWindow", standardBorder, "backgroundWindowVariant", "highlightSoft")
        case UiStyle.SurfaceTone.SurfaceOverlay:
            return toneSpec("backgroundSurfaceOverlay", "borderOverlay", "backgroundWindowVariant", "highlightSoft")
        case UiStyle.SurfaceTone.Popup:
            return toneSpec("backgroundPopup", "borderPopup", "highlightText", "highlightSoft")
        case UiStyle.SurfaceTone.DialogSection:
            return toneSpec("backgroundDialogSection", "borderDialogSection", "backgroundWindowVariant", "highlightSoft")
        case UiStyle.SurfaceTone.Control:
            return toneSpec("backgroundControl", active ? "highlightFill" : "controlBorder", "highlightText", "highlightSoft")
        case UiStyle.SurfaceTone.Section:
            return toneSpec("backgroundSection", standardBorder, "backgroundWindowVariant", "highlightSoft")
        case UiStyle.SurfaceTone.SectionOverlay:
            return toneSpec("backgroundSectionOverlay", "borderOverlay", "backgroundWindowVariant", "highlightSoft")
        case UiStyle.SurfaceTone.Canvas:
            return toneSpec("backgroundCanvas", standardBorder, "backgroundWindowVariant", "highlightSoft")
        case UiStyle.SurfaceTone.Highlight:
            return toneSpec("highlightSoft", "highlightText", "highlightText", "highlightSoft")
        case UiStyle.SurfaceTone.Success:
            return toneSpec("successSoft", "successBorder", "successText", "successBorder")
        case UiStyle.SurfaceTone.Warning:
            return toneSpec("warningSoft", "warningBorder", "warningText", "warningBorder")
        case UiStyle.SurfaceTone.Info:
            return toneSpec("infoSoft", "infoBorder", "infoText", "infoBorder")
        case UiStyle.SurfaceTone.Neutral:
            return toneSpec("neutralSoft", "neutralBorder", "neutralText", "neutralBorder")
        case UiStyle.SurfaceTone.Danger:
            return toneSpec("dangerSoft", "dangerBorder", "dangerText", "dangerBorder")
        case UiStyle.SurfaceTone.Ghost:
            return toneSpec("transparent", "transparent", "backgroundWindowVariant", "highlightSoft")
        default:
            return toneSpec("backgroundSurface", standardBorder, "backgroundWindowVariant", "highlightSoft")
        }
    }

    function taskPhaseSpec(phaseName) {
        switch (String(phaseName)) {
        case "running":
            return {
                "text": "infoText",
                "fill": "infoSoft"
            }
        case "succeeded":
            return {
                "text": "successText",
                "fill": "successSoft"
            }
        case "failed":
            return {
                "text": "dangerText",
                "fill": "dangerSoft"
            }
        case "cancelled":
            return {
                "text": "warningText",
                "fill": "warningSoft"
            }
        case "ready":
        default:
            return {
                "text": "neutralText",
                "fill": "neutralSoft"
            }
        }
    }

    function inputChromeSpec(appearance, hasSelection) {
        var ghost = appearance === UiStyle.ControlAppearance.Ghost

        return {
            "ghost": ghost,
            "shapeRole": UiStyle.ShapeRole.Control,
            "idleStrokeWidth": ghost ? 0 : 1,
            "activeStrokeWidth": 1,
            "hoverOverlayOpacity": ghost ? 0.05 : 0.06,
            "activeOverlayOpacity": hasSelection ? 0.10 : 0.08
        }
    }
}
