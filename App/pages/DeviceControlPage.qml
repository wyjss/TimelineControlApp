import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/theme" as Theme

Item {
    id: root

    Theme.AppTheme {
        id: fallbackTheme
    }

    property QtObject pageTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : fallbackTheme
    property var appRuntime: typeof app !== "undefined" ? app : null
    property var deviceModel: appRuntime && appRuntime.deviceModel ? appRuntime.deviceModel : null
    readonly property var devices: deviceModel ? deviceModel.devices : []
    property var groups: []
    property string selectedGroupId: ""
    property bool editingMembers: false
    property string feedbackText: ""

    function loadGroups() {
        var storedGroups = appRuntime && appRuntime.settings
            ? appRuntime.settings.value("deviceControlGroups", [])
            : []
        var result = []
        for (var index = 0; index < storedGroups.length; ++index) {
            var storedGroup = storedGroups[index]
            var name = String(storedGroup.name || "").trim()
            if (name.length === 0)
                continue

            var deviceIds = []
            var storedDeviceIds = storedGroup.deviceIds || []
            for (var deviceIndex = 0; deviceIndex < storedDeviceIds.length; ++deviceIndex)
                deviceIds.push(String(storedDeviceIds[deviceIndex]))

            result.push({
                "id": String(storedGroup.id || Date.now() + "-" + index),
                "name": name,
                "deviceIds": deviceIds
            })
        }
        groups = result
        selectedGroupId = groups.length > 0 ? groups[0].id : ""
    }

    function saveGroups() {
        if (!appRuntime || !appRuntime.settings)
            return

        var values = appRuntime.settings.values
        values.deviceControlGroups = groups
        appRuntime.settings.values = values
    }

    function groupById(groupId) {
        for (var index = 0; index < groups.length; ++index) {
            if (String(groups[index].id) === String(groupId))
                return groups[index]
        }
        return null
    }

    function deviceInGroup(deviceId, groupId) {
        var group = groupById(groupId)
        if (!group)
            return false

        for (var index = 0; index < group.deviceIds.length; ++index) {
            if (String(group.deviceIds[index]) === String(deviceId))
                return true
        }
        return false
    }

    function deviceCountInGroup(groupId) {
        var count = 0
        for (var index = 0; index < devices.length; ++index) {
            if (deviceInGroup(devices[index].id, groupId))
                ++count
        }
        return count
    }

    function groupsForDevice(deviceId) {
        var names = []
        for (var index = 0; index < groups.length; ++index) {
            if (deviceInGroup(deviceId, groups[index].id))
                names.push(groups[index].name)
        }
        return names
    }

    function createGroup(groupName) {
        var name = String(groupName || "").trim()
        if (name.length === 0)
            return

        var nextGroups = groups.slice()
        var groupId = String(Date.now())
        nextGroups.push({ "id": groupId, "name": name, "deviceIds": [] })
        groups = nextGroups
        selectedGroupId = groupId
        editingMembers = true
        saveGroups()
    }

    function renameSelectedGroup(groupName) {
        var name = String(groupName || "").trim()
        if (name.length === 0)
            return

        var nextGroups = []
        for (var index = 0; index < groups.length; ++index) {
            var group = groups[index]
            nextGroups.push({
                "id": group.id,
                "name": String(group.id) === selectedGroupId ? name : group.name,
                "deviceIds": group.deviceIds.slice()
            })
        }
        groups = nextGroups
        saveGroups()
    }

    function removeSelectedGroup() {
        var nextGroups = []
        for (var index = 0; index < groups.length; ++index) {
            if (String(groups[index].id) !== selectedGroupId)
                nextGroups.push(groups[index])
        }
        groups = nextGroups
        selectedGroupId = groups.length > 0 ? groups[0].id : ""
        editingMembers = false
        saveGroups()
    }

    function toggleDevice(deviceId) {
        if (!editingMembers || selectedGroupId.length === 0)
            return

        var nextGroups = []
        for (var index = 0; index < groups.length; ++index) {
            var group = groups[index]
            var deviceIds = group.deviceIds.slice()
            if (String(group.id) === selectedGroupId) {
                var membershipIndex = deviceIds.indexOf(String(deviceId))
                if (membershipIndex < 0)
                    deviceIds.push(String(deviceId))
                else
                    deviceIds.splice(membershipIndex, 1)
            }
            nextGroups.push({ "id": group.id, "name": group.name, "deviceIds": deviceIds })
        }
        groups = nextGroups
        saveGroups()
    }

    function deviceAddress(device) {
        var values = device && device.configValues ? device.configValues : {}
        var ip = String(values.ip || "").trim()
        var port = String(values.port || "").trim()
        if (ip.length > 0)
            return port.length > 0 ? ip + ":" + port : ip

        var serialPort = String(values.serialPort || "").trim()
        return serialPort.length > 0 ? serialPort : qsTr("未分配地址")
    }

    Component.onCompleted: loadGroups()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pageTheme.density.panePaddingCompact
        spacing: root.pageTheme.density.controlGap

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.pageTheme.density.controlGap

            Base.AppSurface {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                sizeToContent: false
                surfaceTone: UiStyle.SurfaceTone.Surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Base.AppText {
                            Layout.fillWidth: true
                            text: qsTr("设备组")
                            styleRole: UiStyle.TypographyRole.SectionTitle
                        }

                        Base.AppText {
                            text: qsTr("%1 个").arg(root.groups.length)
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                        }

                        Base.AppButton {
                            raised: true
                            size: UiStyle.ButtonSize.Small
                            text: qsTr("新建")
                            onClicked: groupEditorPopupLoader.openForCreate()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Base.AppButton {
                            Layout.fillWidth: true
                            text: qsTr("组开机")
                            variant: UiStyle.ButtonVariant.Primary
                            enabled: root.groups.length > 0
                            onClicked: groupActionPopupLoader.openForAction("on")
                        }

                        Base.AppButton {
                            variant: UiStyle.ButtonVariant.Danger
                            Layout.fillWidth: true
                            text: qsTr("组关机")
                            enabled: root.groups.length > 0
                            onClicked: groupActionPopupLoader.openForAction("off")
                        }
                    }

                    Base.AppText {
                        visible: root.feedbackText.length > 0
                        Layout.fillWidth: true
                        text: root.feedbackText
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Secondary
                        elide: Text.ElideRight
                    }

                    Base.AppScrollPane {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentSpacing: 8
                        fillContentWidth: true

                        Repeater {
                            model: root.groups

                            delegate: Base.AppCard {
                                id: groupCard

                                readonly property bool selected: String(modelData.id) === root.selectedGroupId

                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                text: String(modelData.name)
                                padding: 12
                                contentSpacing: 3
                                checkable: true
                                autoExclusive: true
                                checked: selected
                                emphasizedSelection: true
                                onClicked: {
                                    root.selectedGroupId = String(modelData.id)
                                    root.editingMembers = false
                                }

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: String(modelData.name)
                                    styleRole: UiStyle.TypographyRole.BodyM
                                    elide: Text.ElideRight
                                }

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: qsTr("%1 台设备").arg(root.deviceCountInGroup(modelData.id))
                                    styleRole: UiStyle.TypographyRole.BodyS
                                    textTone: UiStyle.TextTone.Secondary
                                }
                            }
                        }

                        Base.AppText {
                            visible: root.groups.length === 0
                            Layout.fillWidth: true
                            text: qsTr("暂无设备组，请先新建组")
                            styleRole: UiStyle.TypographyRole.BodyM
                            textTone: UiStyle.TextTone.Secondary
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Base.AppButton {
                            raised: true
                            Layout.fillWidth: true
                            text: qsTr("重命名")
                            enabled: root.selectedGroupId.length > 0
                            onClicked: groupEditorPopupLoader.openForRename()
                        }

                        Base.AppButton {
                            variant: UiStyle.ButtonVariant.Danger
                            Layout.fillWidth: true
                            text: qsTr("删除")
                            enabled: root.selectedGroupId.length > 0
                            onClicked: removeGroupPopupLoader.open()
                        }
                    }
                }
            }

            Base.AppSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sizeToContent: false
                surfaceTone: UiStyle.SurfaceTone.Surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: qsTr("所有设备")
                                    styleRole: UiStyle.TypographyRole.SectionTitle
                                }

                                Base.AppText {
                                    text: qsTr("%1 台").arg(root.devices.length)
                                    styleRole: UiStyle.TypographyRole.BodyS
                                    textTone: UiStyle.TextTone.Secondary
                                }
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.selectedGroupId.length === 0
                                    ? qsTr("新建设备组后可管理设备归属")
                                    : (root.editingMembers
                                        ? qsTr("点击设备方块，将设备加入或移出“%1”").arg(root.groupById(root.selectedGroupId).name)
                                        : qsTr("选择“管理成员”后点击设备；同一设备可加入多个组"))
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                                elide: Text.ElideRight
                            }
                        }

                        Base.AppButton {
                            raised: true
                            text: root.editingMembers ? qsTr("完成") : qsTr("管理成员")
                            enabled: root.selectedGroupId.length > 0
                            highlighted: root.editingMembers
                            onClicked: root.editingMembers = !root.editingMembers
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        GridView {
                            id: deviceGrid

                            anchors.fill: parent
                            clip: true
                            model: root.devices
                            cellWidth: Math.max(200, width / Math.max(1, Math.floor(width / 220)))
                            cellHeight: 150

                            delegate: Item {
                                width: deviceGrid.cellWidth
                                height: deviceGrid.cellHeight
                                opacity: deviceData && deviceData.filteredOut ? 0.46 : 1

                                readonly property var deviceData: modelData
                                readonly property bool inSelectedGroup: root.selectedGroupId.length > 0
                                    && root.deviceInGroup(deviceData.id, root.selectedGroupId)

                                Behavior on opacity {
                                    NumberAnimation { duration: 120 }
                                }

                                Base.AppCard {
                                    anchors.fill: parent
                                    anchors.rightMargin: 10
                                    anchors.bottomMargin: 10
                                    text: String(deviceData.name || deviceData.id || qsTr("未命名设备"))
                                    padding: 14
                                    contentSpacing: 5
                                    checkable: root.editingMembers
                                    checked: inSelectedGroup
                                    emphasizedSelection: root.editingMembers
                                    animateScale: root.editingMembers
                                    hoverEnabled: root.editingMembers
                                    onClicked: {
                                        if (root.editingMembers)
                                            root.toggleDevice(deviceData.id)
                                    }

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: String(deviceData.name || deviceData.id || qsTr("未命名设备"))
                                        styleRole: UiStyle.TypographyRole.BodyM
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: String(deviceData.deviceType || qsTr("未设置类型"))
                                        styleRole: UiStyle.TypographyRole.BodyS
                                        textTone: UiStyle.TextTone.Secondary
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: root.deviceAddress(deviceData)
                                        styleRole: UiStyle.TypographyRole.BodyS
                                        textTone: UiStyle.TextTone.Secondary
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: root.groupsForDevice(deviceData.id).length > 0
                                            ? root.groupsForDevice(deviceData.id).join("、")
                                            : qsTr("未分组")
                                        styleRole: UiStyle.TypographyRole.BodyS
                                        textTone: inSelectedGroup ? UiStyle.TextTone.Accent : UiStyle.TextTone.Secondary
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        Base.AppText {
                            visible: root.devices.length === 0
                            anchors.centerIn: parent
                            text: qsTr("暂无设备")
                            styleRole: UiStyle.TypographyRole.BodyM
                            textTone: UiStyle.TextTone.Secondary
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: groupEditorPopupLoader

        active: false

        function openForCreate() {
            active = true
            item.openForCreate()
        }

        function openForRename() {
            active = true
            item.openForRename()
        }

        sourceComponent: Component {
            Base.AppDialog {
                id: groupEditorPopup
                parent: root
                onClosed: groupEditorPopupLoader.active = false

        property bool renaming: false
        property string groupName: ""

        function openForCreate() {
            renaming = false
            groupName = ""
            open()
            Qt.callLater(function() { groupNameField.forceActiveFocus() })
        }

        function openForRename() {
            var group = root.groupById(root.selectedGroupId)
            if (!group)
                return

            renaming = true
            groupName = group.name
            open()
            Qt.callLater(function() {
                groupNameField.forceActiveFocus()
                groupNameField.selectAll()
            })
        }

        function commit() {
            if (renaming)
                root.renameSelectedGroup(groupName)
            else
                root.createGroup(groupName)
            close()
        }

        width: Math.min(420, Math.max(320, parent ? parent.width - 96 : 380))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        title: renaming ? qsTr("重命名设备组") : qsTr("新建设备组")
        rejectText: qsTr("取消")
        acceptText: renaming ? qsTr("保存") : qsTr("创建")
        acceptEnabled: groupName.trim().length > 0
        initialFocusItem: groupNameField
        closeOnAccepted: false
        onAccepted: commit()

        Base.AppTextField {
            id: groupNameField

            Layout.fillWidth: true
            text: groupEditorPopup.groupName
            placeholderText: qsTr("组名称")
            onTextChanged: groupEditorPopup.groupName = text
        }
            }
        }
    }

    Loader {
        id: removeGroupPopupLoader

        active: false

        function open() {
            active = true
            item.open()
        }

        sourceComponent: Component {
            Base.AppDialog {
                id: removeGroupPopup
                parent: root
                onClosed: removeGroupPopupLoader.active = false

        width: Math.min(420, Math.max(320, parent ? parent.width - 96 : 380))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        title: qsTr("删除设备组")
        message: qsTr("确定删除“%1”？设备本身不会被删除。")
            .arg(root.groupById(root.selectedGroupId)
                ? root.groupById(root.selectedGroupId).name
                : "")
        rejectText: qsTr("取消")
        acceptText: qsTr("删除")
        acceptButtonVariant: UiStyle.ButtonVariant.Danger
        onAccepted: root.removeSelectedGroup()
            }
        }
    }

    Loader {
        id: groupActionPopupLoader

        active: false

        function openForAction(actionType) {
            active = true
            item.openForAction(actionType)
        }

        sourceComponent: Component {
            Base.AppDialog {
                id: groupActionPopup
                parent: root
                onClosed: groupActionPopupLoader.active = false

        property string actionType: "on"
        property var selectedGroupIds: []

        function openForAction(type) {
            actionType = type
            selectedGroupIds = []
            open()
        }

        function groupSelected(groupId) {
            return selectedGroupIds.indexOf(String(groupId)) >= 0
        }

        function toggleGroup(groupId) {
            var nextIds = selectedGroupIds.slice()
            var index = nextIds.indexOf(String(groupId))
            if (index < 0)
                nextIds.push(String(groupId))
            else
                nextIds.splice(index, 1)
            selectedGroupIds = nextIds
        }

        function confirmSelection() {
            root.feedbackText = qsTr("已选择 %1 个组，设备指令暂未执行").arg(selectedGroupIds.length)
        }

        width: Math.min(480, Math.max(340, parent ? parent.width - 96 : 420))
        maximumDialogHeight: Math.min(560, Math.max(320, parent ? parent.height - 96 : 440))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        title: actionType === "on" ? qsTr("组开机") : qsTr("组关机")
        message: qsTr("请选择一个或多个设备组")
        rejectText: qsTr("取消")
        acceptText: qsTr("确认")
        acceptEnabled: selectedGroupIds.length > 0
        acceptButtonVariant: actionType === "off"
            ? UiStyle.ButtonVariant.Danger
            : UiStyle.ButtonVariant.Primary
        onAccepted: confirmSelection()

        Base.AppDialogSection {
            Layout.fillWidth: true
            title: qsTr("设备组")
            compact: true
            bodyFillHeight: false

            Repeater {
                model: root.groups

                delegate: Base.AppCard {
                    id: actionGroupRow

                    readonly property bool selected: groupActionPopup.groupSelected(modelData.id)

                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    text: String(modelData.name)
                    padding: 12
                    checkable: true
                    checked: selected
                    emphasizedSelection: true
                    onClicked: groupActionPopup.toggleGroup(modelData.id)

                    Base.AppText {
                        Layout.fillWidth: true
                        text: qsTr("%1（%2 台设备）")
                            .arg(String(modelData.name))
                            .arg(root.deviceCountInGroup(modelData.id))
                        styleRole: UiStyle.TypographyRole.BodyM
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("暂不执行实际设备指令")
            styleRole: UiStyle.TypographyRole.BodyS
            textTone: UiStyle.TextTone.Secondary
        }
            }
        }
    }
}
