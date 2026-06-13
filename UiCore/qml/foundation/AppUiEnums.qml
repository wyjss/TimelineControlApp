pragma Singleton
import QtQuick 2.14

QtObject {
    enum LayoutMode {
        Auto,
        Vertical,
        Horizontal
    }

    enum SurfaceMode {
        Section,
        Flat,
        Bare
    }

    enum ControlAppearance {
        Filled,
        Ghost
    }

    enum ButtonVariant {
        Primary,
        Secondary,
        Tonal,
        Ghost,
        Nav
    }

    enum ButtonSize {
        Small,
        Medium,
        Large
    }

    enum FormFieldKind {
        TextField,
        Summary,
        Segmented,
        Choice,
        Toggle,
        Slider,
        Color,
        Custom,
        Chips,
        Select,
        Button
    }

    enum MenuBlockKind {
        Form,
        Custom
    }

    enum FormNodeKind {
        Form,
        Section,
        Field
    }

    enum ShapeRole {
        None,
        Control,
        Section,
        Panel,
        Shell,
        Canvas,
        Overlay,
        Pill
    }

    function normalizeLayoutMode(value) {
        if (value === 1 || String(value).toLowerCase() === "vertical")
            return 1

        if (value === 2 || String(value).toLowerCase() === "horizontal")
            return 2

        return 0
    }

    function normalizeSurfaceMode(value) {
        if (typeof value === "number" && value >= 0 && value <= 2)
            return value

        switch (String(value).toLowerCase()) {
        case "bare":
            return 2
        case "flat":
            return 1
        case "section":
        default:
            return 0
        }
    }

    function normalizeAppearance(value) {
        return value === 1 || String(value).toLowerCase() === "ghost"
            ? 1
            : 0
    }

    function normalizeButtonVariant(value) {
        if (typeof value === "number" && value >= 0 && value <= 4)
            return value

        switch (String(value).toLowerCase()) {
        case "primary":
            return 0
        case "secondary":
            return 1
        case "tonal":
            return 2
        case "ghost":
            return 3
        case "nav":
            return 4
        default:
            return 1
        }
    }

    function normalizeButtonSize(value) {
        if (typeof value === "number" && value >= 0 && value <= 2)
            return value

        switch (String(value).toLowerCase()) {
        case "sm":
        case "small":
            return 0
        case "lg":
        case "large":
            return 2
        case "md":
        case "medium":
        default:
            return 1
        }
    }

    function normalizeFormFieldKind(value) {
        if (typeof value === "number" && value >= 0 && value <= 10)
            return value

        if (value !== undefined && value !== null && typeof value !== "string") {
            var numericValue = Number(value)

            if (!isNaN(numericValue) && numericValue >= 0 && numericValue <= 10)
                return numericValue
        }

        return 0
    }

    function normalizeMenuBlockKind(value) {
        if (typeof value === "number" && value >= 0 && value <= 1)
            return value

        switch (String(value).toLowerCase()) {
        case "custom":
            return 1
        case "form":
        default:
            return 0
        }
    }

    function normalizeFormNodeKind(value) {
        if (typeof value === "number" && value >= 0 && value <= 2)
            return value

        switch (String(value).toLowerCase()) {
        case "section":
            return 1
        case "field":
            return 2
        case "form":
        default:
            return 0
        }
    }

    function normalizeShapeRole(value) {
        if (typeof value === "number" && value >= 0 && value <= 7)
            return value

        switch (String(value).toLowerCase()) {
        case "none":
            return 0
        case "control":
            return 1
        case "section":
            return 2
        case "panel":
            return 3
        case "shell":
            return 4
        case "canvas":
            return 5
        case "overlay":
            return 6
        case "pill":
            return 7
        default:
            return 3
        }
    }
}
