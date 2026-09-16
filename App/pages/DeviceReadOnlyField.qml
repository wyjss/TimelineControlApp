import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UICore/qml/components/base" as Base

Item {
    id: root

    property QtObject theme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : null
    property var fieldData: ({})
    readonly property string labelText: fieldData && fieldData.label !== undefined ? String(fieldData.label) : ""
    readonly property string subtitleText: fieldData && fieldData.subtitle !== undefined ? String(fieldData.subtitle) : ""
    readonly property string valueText: {
        var value = fieldData && fieldData.value !== undefined && fieldData.value !== null
            ? String(fieldData.value) : ""
        return value.trim().length > 0 ? value : qsTr("空")
    }

    width: parent ? parent.width : 0
    implicitHeight: contentRow.implicitHeight + 1

    RowLayout {
        id: contentRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            Base.AppText {
                Layout.fillWidth: true
                text: root.labelText
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
                elide: Text.ElideRight
            }

            Base.AppText {
                Layout.fillWidth: true
                visible: root.subtitleText.length > 0
                text: root.subtitleText
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
                opacity: 0.72
                elide: Text.ElideRight
            }
        }

        Base.AppText {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: Math.max(104, root.width * 0.52)
            text: root.valueText
            styleRole: UiStyle.TypographyRole.BodyM
            textTone: UiStyle.TextTone.Primary
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.theme && root.theme.colors ? root.theme.colors.border : "#334155"
        opacity: 0.42
    }
}
