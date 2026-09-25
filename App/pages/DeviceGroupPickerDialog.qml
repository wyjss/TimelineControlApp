import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UICore/qml/components/base" as Base

Base.AppDialog {
    id: root
    objectName: "deviceAddToGroupsDialog"

    property var availableGroupNames: []
    property int selectedDeviceCount: 0
    property var groupNames: []
    property QtObject pageTheme: resolvedTheme

    width: Math.min(520, Math.max(420, parent ? parent.width - 96 : 480))
    maximumDialogHeight: Math.min(520, Math.max(360, parent ? parent.height - 96 : 480))
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0
    title: qsTr("加入分组")
    message: qsTr("为已选 %1 台设备添加分组，保留其他分组归属").arg(root.selectedDeviceCount)
    rejectText: qsTr("取消")
    acceptText: qsTr("加入")
    acceptEnabled: root.selectedDeviceCount > 0 && groupNames.length > 0
    onAboutToShow: {
        groupNames = []
        batchGroupSearchInput.clear()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: root.pageTheme.density.controlGap

        Base.AppTextField {
            id: batchGroupSearchInput
            objectName: "deviceBatchGroupSearchInput"
            Layout.fillWidth: true
            placeholderText: qsTr("搜索分组或输入新组名")
        }

        Base.AppButton {
            objectName: "deviceBatchCreateGroupButton"
            text: qsTr("新建并选中")
            enabled: batchGroupSearchInput.text.length > 0
                && root.availableGroupNames.indexOf(batchGroupSearchInput.text) < 0
                && root.groupNames.indexOf(batchGroupSearchInput.text) < 0
            onClicked: {
                root.groupNames = root.groupNames.concat([batchGroupSearchInput.text])
                batchGroupSearchInput.clear()
            }
        }
    }

    Base.AppText {
        Layout.fillWidth: true
        text: qsTr("点击组名选择，可多选（已选 %1 个）").arg(root.groupNames.length)
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Secondary
    }

    Flow {
        id: batchGroupTags
        objectName: "deviceBatchGroupTags"
        Layout.fillWidth: true
        spacing: root.pageTheme.density.controlGap

        Repeater {
            model: {
                var names = root.availableGroupNames.slice(0)
                for (var index = 0; index < root.groupNames.length; ++index) {
                    var name = root.groupNames[index]
                    if (names.indexOf(name) < 0)
                        names.push(name)
                }
                var matches = []
                var query = batchGroupSearchInput.text.toLowerCase()
                for (var nameIndex = 0; nameIndex < names.length; ++nameIndex) {
                    if (root.groupNames.indexOf(names[nameIndex]) >= 0
                        || names[nameIndex].toLowerCase().indexOf(query) >= 0)
                        matches.push(names[nameIndex])
                }
                return matches
            }
            delegate: Base.AppButton {
                objectName: "deviceBatchGroupTag_" + modelData
                width: Math.min(implicitWidth, batchGroupTags.width)
                text: modelData
                size: UiStyle.ButtonSize.Small
                checkable: true
                checked: root.groupNames.indexOf(String(modelData)) >= 0
                variant: checked ? UiStyle.ButtonVariant.Primary : UiStyle.ButtonVariant.Secondary
                onClicked: {
                    var names = root.groupNames.slice(0)
                    if (checked)
                        names.push(String(modelData))
                    else
                        names.splice(names.indexOf(String(modelData)), 1)
                    root.groupNames = names
                }
            }
        }
    }
}
