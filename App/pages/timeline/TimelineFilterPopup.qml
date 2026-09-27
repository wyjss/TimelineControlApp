import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base
import "../../components" as AppComponents

Base.AppPopup {
    id: root
    objectName: "timelineFilterPopup"

    property var timelineManager: null
    property var deviceModel: null
    property Item anchorItem: null
    readonly property var devices: deviceModel ? deviceModel.devices : []
    readonly property var selectedDeviceIds: timelineManager ? timelineManager.filterDeviceIds : []
    readonly property var selectedGroupNames: timelineManager ? timelineManager.filterGroupNames : []
    readonly property bool filterActive: selectedDeviceIds.length > 0 || selectedGroupNames.length > 0
    readonly property bool timelineStopped: !timelineManager || timelineManager.playbackState === 0
    readonly property bool selectionEditable: timelineStopped || !timelineManager.executionFilterEnabled
    readonly property int matchedDeviceCount: devices.filter(function(device) {
        return !root.filterActive || root.selectedDeviceIds.indexOf(device.id) >= 0
            || device.groupNames.some(function(name) {
                return root.selectedGroupNames.indexOf(name) >= 0
            })
    }).length
    readonly property var groupNames: {
        var names = deviceModel ? deviceModel.groupNames.slice(0) : []
        // 保留已选但已不存在的组，便于取消条件。
        for (var index = 0; index < selectedGroupNames.length; ++index) {
            if (names.indexOf(selectedGroupNames[index]) < 0)
                names.push(selectedGroupNames[index])
        }
        return names
    }

    width: Math.min(460, parent ? Math.max(0, parent.width - 24) : 460)
    height: Math.min(740, parent ? Math.max(0, parent.height - 24) : 740)
    x: parent && anchorItem
        ? Math.max(12, Math.min(anchorItem.mapToItem(parent, anchorItem.width, 0).x - width,
                               parent.width - width - 12)) : 0
    y: parent && anchorItem
        ? Math.max(12, Math.min(anchorItem.mapToItem(parent, 0, anchorItem.height + 8).y,
                               parent.height - height - 12)) : 0
    padding: 20
    spacing: 12
    modal: false
    focus: true
    enabled: !!timelineManager
    showModalOverlay: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onAboutToShow: deviceSearchInput.clear()

    RowLayout {
        Layout.fillWidth: true

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("设备范围")
            styleRole: UiStyle.TypographyRole.SectionTitle
        }

        Base.AppButton {
            objectName: "timelineFilterCloseButton"
            iconSymbol: "×"
            size: UiStyle.ButtonSize.Small
            variant: UiStyle.ButtonVariant.Ghost
            Accessible.name: qsTr("关闭设备范围面板")
            onClicked: root.close()
        }
    }

    Base.AppText {
        Layout.fillWidth: true
        text: qsTr("选中设备与组内设备共同组成范围；未设置条件时包含全部设备。")
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Secondary
        wrapMode: Text.Wrap
    }

    Base.AppScrollPane {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentSpacing: 12
        contentRightPadding: 8

        RowLayout {
            Layout.fillWidth: true

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("分组")
                styleRole: UiStyle.TypographyRole.BodyM
            }

            Base.AppText {
                text: qsTr("已选 %1 组").arg(root.selectedGroupNames.length)
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }
        }

        Flow {
            id: groupTags
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.groupNames

                delegate: Base.AppButton {
                    readonly property string groupName: String(modelData)
                    readonly property int deviceCount: root.devices.filter(function(device) {
                        return device.groupNames.indexOf(groupName) >= 0
                    }).length
                    objectName: "timelineFilterGroup_" + groupName
                    width: Math.min(implicitWidth, groupTags.width)
                    text: groupName + "  " + deviceCount
                    iconSymbol: checked ? "✓" : ""
                    size: UiStyle.ButtonSize.Small
                    checkable: true
                    enabled: root.selectionEditable
                    checked: root.selectedGroupNames.indexOf(groupName) >= 0
                    variant: checked ? UiStyle.ButtonVariant.Primary : UiStyle.ButtonVariant.Secondary
                    onClicked: {
                        var names = root.selectedGroupNames.slice(0)
                        var selectedIndex = names.indexOf(groupName)
                        if (selectedIndex < 0)
                            names.push(groupName)
                        else
                            names.splice(selectedIndex, 1)
                        root.timelineManager.filterGroupNames = names
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: groupName
                }
            }
        }

        Base.AppText {
            Layout.fillWidth: true
            visible: root.groupNames.length === 0
            text: qsTr("暂无分组，可直接选择设备")
            styleRole: UiStyle.TypographyRole.BodyS
            textTone: UiStyle.TextTone.Secondary
        }

        RowLayout {
            Layout.fillWidth: true

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("指定设备")
                styleRole: UiStyle.TypographyRole.BodyM
            }

            Base.AppText {
                text: qsTr("已选 %1 台").arg(root.selectedDeviceIds.length)
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
            }
        }

        Base.AppTextField {
            id: deviceSearchInput
            objectName: "timelineFilterSearchInput"
            Layout.fillWidth: true
            placeholderText: qsTr("搜索设备名称或地址")
        }

        Flow {
            id: selectedDeviceTags
            Layout.fillWidth: true
            visible: root.selectedDeviceIds.length > 0
            spacing: 6

            Repeater {
                model: root.selectedDeviceIds

                delegate: Base.AppButton {
                    readonly property string deviceId: String(modelData)
                    objectName: "timelineFilterRemoveDevice_" + deviceId
                    width: Math.min(implicitWidth, selectedDeviceTags.width)
                    text: {
                        for (var index = 0; index < root.devices.length; ++index) {
                            if (root.devices[index].id === deviceId)
                                return root.devices[index].name || deviceId
                        }
                        return qsTr("已移除设备")
                    }
                    iconSymbol: "×"
                    size: UiStyle.ButtonSize.Small
                    variant: UiStyle.ButtonVariant.Tonal
                    enabled: root.selectionEditable
                    onClicked: {
                        var ids = root.selectedDeviceIds.slice(0)
                        ids.splice(ids.indexOf(deviceId), 1)
                        root.timelineManager.filterDeviceIds = ids
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("取消选择：%1").arg(text === qsTr("已移除设备") ? deviceId : text)
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                id: deviceCards
                model: {
                    var query = deviceSearchInput.text.trim().toLowerCase()
                    return root.devices.filter(function(device) {
                        var values = device.configValues || {}
                        return String(device.name || "").toLowerCase().indexOf(query) >= 0
                            || String(values.ip || "").toLowerCase().indexOf(query) >= 0
                            || String(values.serialPort || "").toLowerCase().indexOf(query) >= 0
                    })
                }

                delegate: Base.AppCard {
                    id: deviceCard
                    readonly property var device: modelData
                    objectName: "timelineFilterDevice_" + device.id
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 76
                    padding: 10
                    compact: true
                    animateScale: false
                    checkable: true
                    enabled: root.selectionEditable
                    checked: root.selectedDeviceIds.indexOf(device.id) >= 0
                    Accessible.name: device.name || device.id
                    onClicked: {
                        var ids = root.selectedDeviceIds.slice(0)
                        var selectedIndex = ids.indexOf(device.id)
                        if (selectedIndex < 0)
                            ids.push(device.id)
                        else
                            ids.splice(selectedIndex, 1)
                        root.timelineManager.filterDeviceIds = ids
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        AppComponents.DeviceIcon {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            name: deviceCard.device.deviceType
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 4

                            Base.AppText {
                                Layout.fillWidth: true
                                text: deviceCard.device.name || deviceCard.device.id
                                styleRole: UiStyle.TypographyRole.BodyS
                                elide: Text.ElideRight
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: deviceCard.device.configValues.ip
                                    || deviceCard.device.configValues.serialPort || qsTr("未分配地址")
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                                elide: Text.ElideRight
                            }
                        }

                        Base.AppText {
                            text: deviceCard.checked ? "✓" : ""
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Accent
                        }
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: device.name || device.id
                }
            }
        }

        Base.AppText {
            Layout.fillWidth: true
            visible: deviceCards.count === 0
            text: root.devices.length === 0 ? qsTr("暂无设备") : qsTr("没有匹配的设备")
            styleRole: UiStyle.TypographyRole.BodyS
            textTone: UiStyle.TextTone.Secondary
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: root.resolvedTheme.colors.border
    }

    RowLayout {
        Layout.fillWidth: true

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("显示未选中项")
            styleRole: UiStyle.TypographyRole.BodyM
        }

        Base.AppToggleControl {
            objectName: "timelineFilterShowExcludedToggle"
            checked: root.timelineManager ? root.timelineManager.showFilteredOut : true
            Accessible.name: qsTr("显示未选中项")
            onToggled: root.timelineManager.showFilteredOut = checked
        }
    }

    Base.AppText {
        Layout.fillWidth: true
        text: root.timelineManager && root.timelineManager.showFilteredOut
            ? qsTr("未选中的设备及指令置灰") : qsTr("未选中的设备及指令隐藏")
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Secondary
    }

    RowLayout {
        Layout.fillWidth: true

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("仅向范围内设备发送播放指令")
            styleRole: UiStyle.TypographyRole.BodyM
            wrapMode: Text.Wrap
        }

        Base.AppToggleControl {
            objectName: "timelineFilterExecutionToggle"
            checked: root.timelineManager ? root.timelineManager.executionFilterEnabled : false
            enabled: root.timelineStopped
            Accessible.name: qsTr("仅向范围内设备发送播放指令")
            onToggled: root.timelineManager.executionFilterEnabled = checked
        }
    }

    Base.AppText {
        Layout.fillWidth: true
        text: !root.timelineStopped
            ? (root.selectionEditable ? qsTr("播放期间不可修改执行开关；显示范围可调整")
                                      : qsTr("播放期间已锁定执行范围，仍可调整显示方式"))
            : (root.timelineManager && root.timelineManager.executionFilterEnabled
                ? qsTr("范围外设备不参与时间轴播放") : qsTr("全部设备参与时间轴播放"))
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Secondary
        wrapMode: Text.Wrap
    }

    Base.AppText {
        objectName: "timelineFilterSummary"
        Layout.fillWidth: true
        text: qsTr("当前范围：%1 / %2 台设备").arg(root.matchedDeviceCount).arg(root.devices.length)
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Secondary
    }

    RowLayout {
        Layout.fillWidth: true

        Base.AppButton {
            objectName: "timelineFilterClearButton"
            text: qsTr("清空筛选")
            variant: UiStyle.ButtonVariant.Ghost
            enabled: root.selectionEditable && (root.filterActive || deviceSearchInput.text.length > 0)
            onClicked: {
                root.timelineManager.filterDeviceIds = []
                root.timelineManager.filterGroupNames = []
                deviceSearchInput.clear()
            }
        }

        Item { Layout.fillWidth: true }

        Base.AppButton {
            objectName: "timelineFilterDoneButton"
            text: qsTr("完成")
            variant: UiStyle.ButtonVariant.Primary
            onClicked: root.close()
        }
    }
}
