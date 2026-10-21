#pragma once

#include <QObject>

namespace UICore {
namespace UiStyle {

Q_NAMESPACE
Q_CLASSINFO("RegisterEnumClassesUnscoped", "false")

enum class LayoutMode : int {
    Auto = 0,
    Vertical = 1,
    Horizontal = 2
};
Q_ENUM_NS(LayoutMode)

enum class ControlAppearance : int {
    Filled = 0,
    Ghost = 1
};
Q_ENUM_NS(ControlAppearance)

enum class ButtonVariant : int {
    Primary = 0,
    Secondary = 1,
    Tonal = 2,
    Ghost = 3,
    Nav = 4,
    Danger = 5,
    Subtle = 6
};
Q_ENUM_NS(ButtonVariant)

enum class ButtonSize : int {
    Small = 0,
    Medium = 1,
    Large = 2
};
Q_ENUM_NS(ButtonSize)

enum class ShapeRole : int {
    Auto = -1,
    None = 0,
    Control = 1,
    Section = 2,
    Panel = 3,
    Shell = 4,
    Canvas = 5,
    Overlay = 6,
    Pill = 7
};
Q_ENUM_NS(ShapeRole)

enum class SurfaceTone : int {
    Surface = 0,
    Window = 1,
    SurfaceOverlay = 2,
    Section = 3,
    SectionOverlay = 4,
    Canvas = 5,
    Highlight = 6,
    Success = 7,
    Warning = 8,
    Info = 9,
    Neutral = 10,
    Danger = 11,
    Ghost = 12,
    Popup = 13,
    DialogSection = 14,
    Control = 15
};
Q_ENUM_NS(SurfaceTone)

enum class TextTone : int {
    Primary = 0,
    Secondary = 1,
    Accent = 2,
    Success = 3,
    Warning = 4,
    Info = 5,
    Neutral = 6,
    Danger = 7,
    Inverse = 8
};
Q_ENUM_NS(TextTone)

enum class TypographyRole : int {
    BodyL = 0,
    BodyM = 1,
    BodyS = 2,
    Label = 3,
    SectionTitle = 4,
    TitleM = 5,
    TitleL = 6,
    TitleXL = 7
};
Q_ENUM_NS(TypographyRole)

} // namespace UiStyle
} // namespace UICore
