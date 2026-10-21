#pragma once

#include <QObject>

namespace UICore {
namespace UiForm {

Q_NAMESPACE
Q_CLASSINFO("RegisterEnumClassesUnscoped", "false")

enum class SurfaceMode : int {
    Section = 0,
    Flat = 1,
    Bare = 2
};
Q_ENUM_NS(SurfaceMode)

enum class MenuBlockKind : int {
    Form = 0,
    Custom = 1
};
Q_ENUM_NS(MenuBlockKind)

enum class NodeKind : int {
    Form = 0,
    Section = 1,
    Field = 2
};
Q_ENUM_NS(NodeKind)

} // namespace UiForm
} // namespace UICore
