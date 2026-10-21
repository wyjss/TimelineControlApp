import QtQuick 2.14
import UICore.Style 1.0
import "internal" as Internal

Internal.AppHorizontalNavigationBar {
    edge: Qt.BottomEdge
    implicitHeight: resolvedTheme.shell.bottomBarHeight
    leftPadding: resolvedTheme.shell.bottomBarPadding
    rightPadding: resolvedTheme.shell.bottomBarPadding
    contentSpacing: resolvedTheme.shell.bottomBarPadding
    surfaceTone: UiStyle.SurfaceTone.Surface
    shapeRole: UiStyle.ShapeRole.None
    strokeWidth: 0
}
