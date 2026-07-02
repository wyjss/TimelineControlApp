import QtQuick 2.14
import QtQuick.Layouts 1.14
import "qrc:/UiCore/qml/components/base" as Base

Item {
    id: root

    property QtObject theme
    property var fieldData: ({})
    readonly property string labelText: fieldData && fieldData.label !== undefined ? String(fieldData.label) : ""
    readonly property string subtitleText: fieldData && fieldData.subtitle !== undefined ? String(fieldData.subtitle) : ""
    readonly property string valueText: fieldData && fieldData.value !== undefined && fieldData.value !== null
        ? String(fieldData.value)
        : ""

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
                theme: root.theme
                styleRole: "bodyS"
                textTone: "secondary"
                elide: Text.ElideRight
            }

            Base.AppText {
                Layout.fillWidth: true
                visible: root.subtitleText.length > 0
                text: root.subtitleText
                theme: root.theme
                styleRole: "bodyS"
                textTone: "secondary"
                opacity: 0.72
                elide: Text.ElideRight
            }
        }

        Base.AppText {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: Math.max(104, root.width * 0.52)
            text: root.valueText
            theme: root.theme
            styleRole: "bodyM"
            textTone: "primary"
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
