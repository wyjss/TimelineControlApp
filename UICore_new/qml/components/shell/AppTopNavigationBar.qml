import QtQuick 2.14
import UICore.Style 1.0
import "../base" as Base
import "internal" as Internal

Internal.AppHorizontalNavigationBar {
    id: root

    property string title: qsTr("应用")

    edge: Qt.TopEdge
    implicitHeight: resolvedTheme.shell.topBarHeight
    leftPadding: resolvedTheme.shell.topBarPadding
    rightPadding: resolvedTheme.shell.topBarPadding
    contentSpacing: resolvedTheme.shell.topBarPadding
    surfaceTone: UiStyle.SurfaceTone.Surface
    shapeRole: UiStyle.ShapeRole.None
    strokeWidth: 0

    leadingContent: Component {
        Item {
            implicitWidth: titleLabel.implicitWidth
            implicitHeight: titleLabel.implicitHeight

            Base.AppText {
                id: titleLabel

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                styleRole: UiStyle.TypographyRole.BodyM
                overrideWeight: root.resolvedTheme.typography.weightBold
            }
        }
    }
}
