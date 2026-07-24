import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UiCore/qml/components/base" as Base
import "qrc:/UiCore/qml/theme" as Theme

Item {
    id: root

    Theme.AppTheme {
        id: fallbackTheme
    }

    property QtObject pageTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : fallbackTheme
    readonly property int pageMargin: pageTheme && pageTheme.density ? pageTheme.density.pageMargin : 20
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
        anchors.margins: root.pageMargin
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Base.AppText {
                text: qsTr("设备控制")
                theme: root.pageTheme
                styleRole: "titleL"
            }

            Base.AppSurface {
                Layout.preferredHeight: 28
                sizeToContent: true
                theme: root.pageTheme
                surfaceTone: "section"
                padding: 10

                Base.AppText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("%1 台设备").arg(root.devices.length)
                    theme: root.pageTheme
                    styleRole: "bodyS"
                    textTone: "secondary"
                }
            }

            Base.AppSurface {
                Layout.preferredHeight: 28
                sizeToContent: true
                theme: root.pageTheme
                surfaceTone: "section"
                padding: 10

                Base.AppText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("%1 个组").arg(root.groups.length)
                    theme: root.pageTheme
                    styleRole: "bodyS"
                    textTone: "secondary"
                }
            }

            Base.AppText {
                visible: root.feedbackText.length > 0
                Layout.fillWidth: true
                text: root.feedbackText
                theme: root.pageTheme
                styleRole: "bodyS"
                textTone: "secondary"
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }

            Item {
                visible: root.feedbackText.length === 0
                Layout.fillWidth: true
            }

            Base.AppButton {
                text: qsTr("组开机")
                theme: root.pageTheme
                enabled: root.groups.length > 0
                onClicked: groupActionPopup.openForAction("on")
            }

            Base.AppButton {
                text: qsTr("组关机")
                theme: root.pageTheme
                enabled: root.groups.length > 0
                onClicked: groupActionPopup.openForAction("off")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            Base.AppSurface {
                Layout.preferredWidth: 280
                Layout.fillHeight: true
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

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
                            theme: root.pageTheme
                            styleRole: "sectionTitle"
                        }

                        Base.AppButton {
                            text: qsTr("新建")
                            theme: root.pageTheme
                            onClicked: groupEditorPopup.openForCreate()
                        }
                    }

                    Base.AppScrollPane {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        theme: root.pageTheme
                        contentSpacing: 8
                        fillContentWidth: true

                        Repeater {
                            model: root.groups

                            delegate: Base.AppSurface {
                                id: groupCard

                                readonly property bool selected: String(modelData.id) === root.selectedGroupId

                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                sizeToContent: false
                                theme: root.pageTheme
                                surfaceTone: selected ? "highlight" : "canvas"
                                active: selected
                                interactive: true

                                Column {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 3

                                    Base.AppText {
                                        width: parent.width
                                        text: String(modelData.name)
                                        theme: root.pageTheme
                                        styleRole: "bodyM"
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        width: parent.width
                                        text: qsTr("%1 台设备").arg(root.deviceCountInGroup(modelData.id))
                                        theme: root.pageTheme
                                        styleRole: "bodyS"
                                        textTone: "secondary"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        root.selectedGroupId = String(modelData.id)
                                        root.editingMembers = false
                                    }
                                }
                            }
                        }

                        Base.AppText {
                            visible: root.groups.length === 0
                            Layout.fillWidth: true
                            text: qsTr("暂无设备组，请先新建组")
                            theme: root.pageTheme
                            styleRole: "bodyM"
                            textTone: "secondary"
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Base.AppButton {
                            Layout.fillWidth: true
                            text: qsTr("重命名")
                            theme: root.pageTheme
                            enabled: root.selectedGroupId.length > 0
                            onClicked: groupEditorPopup.openForRename()
                        }

                        Base.AppButton {
                            Layout.fillWidth: true
                            text: qsTr("删除")
                            theme: root.pageTheme
                            enabled: root.selectedGroupId.length > 0
                            onClicked: removeGroupPopup.open()
                        }
                    }
                }
            }

            Base.AppSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

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

                            Base.AppText {
                                Layout.fillWidth: true
                                text: qsTr("所有设备")
                                theme: root.pageTheme
                                styleRole: "sectionTitle"
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.selectedGroupId.length === 0
                                    ? qsTr("新建设备组后可管理设备归属")
                                    : (root.editingMembers
                                        ? qsTr("点击设备方块，将设备加入或移出“%1”").arg(root.groupById(root.selectedGroupId).name)
                                        : qsTr("选择“管理成员”后点击设备；同一设备可加入多个组"))
                                theme: root.pageTheme
                                styleRole: "bodyS"
                                textTone: "secondary"
                                elide: Text.ElideRight
                            }
                        }

                        Base.AppButton {
                            text: root.editingMembers ? qsTr("完成") : qsTr("管理成员")
                            theme: root.pageTheme
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

                                readonly property var deviceData: modelData
                                readonly property bool inSelectedGroup: root.selectedGroupId.length > 0
                                    && root.deviceInGroup(deviceData.id, root.selectedGroupId)

                                Base.AppSurface {
                                    anchors.fill: parent
                                    anchors.rightMargin: 10
                                    anchors.bottomMargin: 10
                                    sizeToContent: false
                                    theme: root.pageTheme
                                    surfaceTone: inSelectedGroup ? "highlight" : "canvas"
                                    active: inSelectedGroup
                                    interactive: root.editingMembers
                                    strokeWidth: inSelectedGroup ? 2 : 1

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 5

                                        Base.AppText {
                                            width: parent.width - 28
                                            text: String(deviceData.name || deviceData.id || qsTr("未命名设备"))
                                            theme: root.pageTheme
                                            styleRole: "bodyM"
                                            elide: Text.ElideRight
                                        }

                                        Base.AppText {
                                            width: parent.width
                                            text: String(deviceData.deviceType || qsTr("未设置类型"))
                                            theme: root.pageTheme
                                            styleRole: "bodyS"
                                            textTone: "secondary"
                                            elide: Text.ElideRight
                                        }

                                        Base.AppText {
                                            width: parent.width
                                            text: root.deviceAddress(deviceData)
                                            theme: root.pageTheme
                                            styleRole: "bodyS"
                                            textTone: "secondary"
                                            elide: Text.ElideRight
                                        }

                                        Base.AppText {
                                            width: parent.width
                                            text: root.groupsForDevice(deviceData.id).length > 0
                                                ? root.groupsForDevice(deviceData.id).join("、")
                                                : qsTr("未分组")
                                            theme: root.pageTheme
                                            styleRole: "bodyS"
                                            textTone: inSelectedGroup ? "accent" : "secondary"
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Rectangle {
                                        visible: root.editingMembers
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 12
                                        width: 22
                                        height: 22
                                        radius: 5
                                        color: inSelectedGroup ? "#3b82f6" : "transparent"
                                        border.width: 1
                                        border.color: inSelectedGroup ? "#60a5fa" : "#64748b"

                                        Text {
                                            anchors.centerIn: parent
                                            text: inSelectedGroup ? "✓" : ""
                                            color: "#ffffff"
                                            font.pixelSize: 14
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: root.editingMembers
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleDevice(deviceData.id)
                                    }
                                }
                            }
                        }

                        Base.AppText {
                            visible: root.devices.length === 0
                            anchors.centerIn: parent
                            text: qsTr("暂无设备")
                            theme: root.pageTheme
                            styleRole: "bodyM"
                            textTone: "secondary"
                        }
                    }
                }
            }
        }
    }

    Base.AppPopup {
        id: groupEditorPopup

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

        modal: true
        focus: true
        width: Math.min(420, Math.max(320, parent ? parent.width - 96 : 380))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        padding: 18
        spacing: 14
        theme: root.pageTheme
        surfaceTone: "section"
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Base.AppText {
            Layout.fillWidth: true
            text: groupEditorPopup.renaming ? qsTr("重命名设备组") : qsTr("新建设备组")
            theme: root.pageTheme
            styleRole: "titleM"
        }

        Base.AppTextField {
            id: groupNameField

            Layout.fillWidth: true
            text: groupEditorPopup.groupName
            placeholderText: qsTr("组名称")
            theme: root.pageTheme
            onTextChanged: groupEditorPopup.groupName = text
            onAccepted: groupEditorPopup.commit()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.fillWidth: true
            }

            Base.AppButton {
                text: qsTr("取消")
                theme: root.pageTheme
                onClicked: groupEditorPopup.close()
            }

            Base.AppButton {
                text: groupEditorPopup.renaming ? qsTr("保存") : qsTr("创建")
                theme: root.pageTheme
                enabled: groupEditorPopup.groupName.trim().length > 0
                onClicked: groupEditorPopup.commit()
            }
        }
    }

    Base.AppPopup {
        id: removeGroupPopup

        modal: true
        focus: true
        width: Math.min(420, Math.max(320, parent ? parent.width - 96 : 380))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        padding: 18
        spacing: 14
        theme: root.pageTheme
        surfaceTone: "section"
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("删除设备组")
            theme: root.pageTheme
            styleRole: "titleM"
        }

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("确定删除“%1”？设备本身不会被删除。")
                .arg(root.groupById(root.selectedGroupId)
                    ? root.groupById(root.selectedGroupId).name
                    : "")
            theme: root.pageTheme
            styleRole: "bodyM"
            textTone: "secondary"
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.fillWidth: true
            }

            Base.AppButton {
                text: qsTr("取消")
                theme: root.pageTheme
                onClicked: removeGroupPopup.close()
            }

            Base.AppButton {
                text: qsTr("删除")
                theme: root.pageTheme
                onClicked: {
                    root.removeSelectedGroup()
                    removeGroupPopup.close()
                }
            }
        }
    }

    Base.AppPopup {
        id: groupActionPopup

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
            close()
        }

        modal: true
        focus: true
        width: Math.min(480, Math.max(340, parent ? parent.width - 96 : 420))
        height: Math.min(560, Math.max(320, parent ? parent.height - 96 : 440))
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        padding: 18
        spacing: 14
        theme: root.pageTheme
        surfaceTone: "section"
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Base.AppText {
            Layout.fillWidth: true
            text: groupActionPopup.actionType === "on" ? qsTr("组开机") : qsTr("组关机")
            theme: root.pageTheme
            styleRole: "titleM"
        }

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("请选择一个或多个设备组")
            theme: root.pageTheme
            styleRole: "bodyS"
            textTone: "secondary"
        }

        Base.AppScrollPane {
            Layout.fillWidth: true
            Layout.fillHeight: true
            theme: root.pageTheme
            contentSpacing: 8
            fillContentWidth: true

            Repeater {
                model: root.groups

                delegate: Base.AppSurface {
                    id: actionGroupRow

                    readonly property bool selected: groupActionPopup.groupSelected(modelData.id)

                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    sizeToContent: false
                    theme: root.pageTheme
                    surfaceTone: selected ? "highlight" : "canvas"
                    active: selected
                    interactive: true

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            radius: 5
                            color: actionGroupRow.selected ? "#3b82f6" : "transparent"
                            border.width: 1
                            border.color: actionGroupRow.selected ? "#60a5fa" : "#64748b"

                            Text {
                                anchors.centerIn: parent
                                text: actionGroupRow.selected ? "✓" : ""
                                color: "#ffffff"
                                font.pixelSize: 13
                            }
                        }

                        Base.AppText {
                            width: parent.width - 30
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("%1（%2 台设备）")
                                .arg(String(modelData.name))
                                .arg(root.deviceCountInGroup(modelData.id))
                            theme: root.pageTheme
                            styleRole: "bodyM"
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: groupActionPopup.toggleGroup(modelData.id)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("暂不执行实际设备指令")
                theme: root.pageTheme
                styleRole: "bodyS"
                textTone: "secondary"
            }

            Base.AppButton {
                text: qsTr("取消")
                theme: root.pageTheme
                onClicked: groupActionPopup.close()
            }

            Base.AppButton {
                text: qsTr("确认")
                theme: root.pageTheme
                enabled: groupActionPopup.selectedGroupIds.length > 0
                onClicked: groupActionPopup.confirmSelection()
            }
        }
    }
}
