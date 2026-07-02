import QtQuick 2.14
import QtQuick.Layouts 1.14
import "qrc:/UiCore/qml/components/base" as Base

Item {
    id: root

    property QtObject theme
    property var fieldData: ({})
    readonly property var customData: fieldData && fieldData.customData ? fieldData.customData : ({})

    function textValue(key) {
        return customData && customData[key] !== undefined && customData[key] !== null
            ? String(customData[key])
            : ""
    }

    width: parent ? parent.width : 0
    implicitHeight: pairLayout.implicitHeight + 1

    ColumnLayout {
        id: pairLayout

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Base.AppText {
                Layout.fillWidth: true
                text: root.textValue("leftLabel")
                theme: root.theme
                styleRole: "bodyS"
                textTone: "secondary"
                elide: Text.ElideRight
            }

            Base.AppText {
                Layout.maximumWidth: Math.max(104, root.width * 0.52)
                text: root.textValue("leftValue")
                theme: root.theme
                styleRole: "bodyM"
                textTone: "primary"
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Base.AppText {
                Layout.fillWidth: true
                text: root.textValue("rightLabel")
                theme: root.theme
                styleRole: "bodyS"
                textTone: "secondary"
                elide: Text.ElideRight
            }

            Base.AppText {
                Layout.maximumWidth: Math.max(104, root.width * 0.52)
                text: root.textValue("rightValue")
                theme: root.theme
                styleRole: "bodyM"
                textTone: "primary"
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
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
