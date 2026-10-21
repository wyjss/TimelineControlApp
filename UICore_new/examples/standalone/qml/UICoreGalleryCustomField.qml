import QtQuick 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base

Item {
    id: root

    property var fieldData: null

    signal fieldEdited(var nextValue)
    signal actionTriggered(string actionId, var payload)

    implicitHeight: customRow.implicitHeight

    RowLayout {
        id: customRow

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        Base.AppSurface {
            Layout.fillWidth: true
            surfaceTone: UiStyle.SurfaceTone.Section
            shapeRole: UiStyle.ShapeRole.Control
            padding: 10

            contentItem: Base.AppText {
                text: root.fieldData && root.fieldData.customData
                    ? String(root.fieldData.customData.note || "")
                    : ""
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }
        }

        Base.AppButton {
            text: qsTr("触发")
            size: UiStyle.ButtonSize.Small
            variant: UiStyle.ButtonVariant.Tonal
            onClicked: {
                var nextValue = root.fieldData ? Number(root.fieldData.value || 0) + 1 : 1
                root.fieldEdited(nextValue)
                root.actionTriggered("gallery.customTriggered", { "count": nextValue })
            }
        }
    }
}
