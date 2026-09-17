import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UICore/qml/components/base" as Base
import "../../components" as AppComponents

Item {
    id: root

    property QtObject theme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : null
    property var commands: []
    property var devices: []
    property string deviceIdFilter: ""
    property string selectedCommandId: ""
    property bool editingEnabled: true
    property bool showDeviceName: false
    readonly property var visibleCommands: filterCommands()
    readonly property int count: visibleCommands.length
    readonly property bool compact: width < 600
    readonly property int timeColumnWidth: 100
    readonly property int deviceColumnWidth: showDeviceName ? 112 : 36
    readonly property int nameColumnWidth: 180
    readonly property int resultColumnWidth: 32

    signal commandSelected(var command)
    signal editRequested(var command)
    signal removeRequested(var command)

    function colorValue(name, fallback) {
        return theme && theme.colors && theme.colors[name] !== undefined
            ? theme.colors[name]
            : fallback
    }

    function filterCommands() {
        if (deviceIdFilter.length === 0)
            return commands || []

        return (commands || []).filter(function(command) {
            return String(command && command.targetDeviceId || "") === deviceIdFilter
        })
    }

    function deviceForId(deviceId) {
        var normalizedDeviceId = String(deviceId || "")
        for (var index = 0; index < devices.length; ++index) {
            var device = devices[index]
            if (String(device.id || "") === normalizedDeviceId)
                return device
        }
        return null
    }

    function deviceName(deviceId) {
        var device = deviceForId(deviceId)
        var name = String(device && device.name || "").trim()
        return name.length > 0 ? name : String(deviceId || qsTr("未分配"))
    }

    function commandFilteredOut(command) {
        if (command && command.filteredOut)
            return true
        var device = deviceForId(command ? command.targetDeviceId : "")
        return device && device.filteredOut
    }

    function padNumber(value, width) {
        var text = String(value)
        while (text.length < width)
            text = "0" + text
        return text
    }

    function formatTime(ms, showMilliseconds) {
        var totalMs = Math.max(0, Math.round(Number(ms || 0)))
        var totalSeconds = Math.floor(totalMs / 1000)
        var hours = Math.floor(totalSeconds / 3600)
        var minutes = Math.floor(totalSeconds / 60) % 60
        var seconds = totalSeconds % 60
        return (hours > 0 ? padNumber(hours, 2) + ":" : "")
            + padNumber(minutes, 2) + ":" + padNumber(seconds, 2)
            + (showMilliseconds ? "." + padNumber(totalMs % 1000, 3) : "")
    }

    function resultColor(command) {
        if (commandFilteredOut(command))
            return root.colorValue("neutralBorder", "#45576b")

        return command && command.stateColor
            ? String(command.stateColor)
            : root.colorValue("neutralBorder", "#45576b")
    }

    function executionParameters(command, compactDisplay) {
        var values = command ? command.executionInputValues || {} : {}
        var fields = command && command.targetCommand
            ? command.targetCommand.executionInputFields || []
            : []
        var parts = []
        for (var index = 0; index < fields.length; ++index) {
            var key = String(fields[index].key || "")
            var value = values[key]
            if (key.length === 0 || value === undefined || value === null
                    || String(value).length === 0)
                continue
            if (typeof value === "boolean")
                value = value ? qsTr("是") : qsTr("否")
            if (compactDisplay && key === "videoFile")
                value = String(value).replace(/^\$/, "").split(/[\\/]/).pop()
            parts.push(String(fields[index].label || key) + "：" + String(value))
        }
        return parts.length > 0 ? parts.join(" · ") : (compactDisplay ? "" : qsTr("无"))
    }

    function commandInfo(command) {
        if (!command)
            return ""
        return qsTr("时间：%1\n设备：%2\n名称：%3\n执行参数：%4\n结果：%5")
            .arg(formatTime(command.startTimeMs, true))
            .arg(deviceName(command.targetDeviceId))
            .arg(String(command.commandName || qsTr("指令")))
            .arg(executionParameters(command))
            .arg(String(command.stateText || qsTr("待执行")))
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            color: root.colorValue("backgroundSurfaceOverlay", "#20262c")

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                Base.AppText {
                    Layout.preferredWidth: root.timeColumnWidth
                    text: qsTr("时间")
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                }

                Base.AppText {
                    visible: !root.compact
                    Layout.preferredWidth: root.deviceColumnWidth
                    horizontalAlignment: root.showDeviceName
                        ? Text.AlignLeft
                        : Text.AlignHCenter
                    text: qsTr("设备")
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                }

                Base.AppText {
                    Layout.fillWidth: root.compact
                    Layout.preferredWidth: root.nameColumnWidth
                    text: root.compact ? qsTr("指令 / 设备") : qsTr("名称")
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                }

                Base.AppText {
                    visible: !root.compact
                    Layout.fillWidth: true
                    text: qsTr("执行参数")
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                }

                Base.AppText {
                    Layout.preferredWidth: root.resultColumnWidth
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("结果")
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: root.colorValue("border", "#334155")
            }
        }

        ListView {
            id: commandList
            objectName: "timelineCommandList"

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 0
            model: root.visibleCommands
            currentIndex: root.visibleCommands.findIndex(function(command) {
                return String(command && command.id || "") === root.selectedCommandId
            })
            onVisibleChanged: {
                if (visible && currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain)
            }
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: AbstractButton {
                id: commandRow

                readonly property var commandData: modelData
                readonly property var targetDevice: root.deviceForId(commandData
                    ? commandData.targetDeviceId
                    : "")
                readonly property bool selected: String(commandData && commandData.id || "")
                    === root.selectedCommandId
                readonly property bool filteredOut: root.commandFilteredOut(commandData)
                width: commandList.width
                height: (root.compact ? 60 : 40) + bottomPadding
                opacity: filteredOut ? 0.46 : 1
                leftPadding: 10
                rightPadding: 10
                topPadding: 0
                bottomPadding: compactExecutionParameters.visible
                    ? compactExecutionParameters.implicitHeight + 4 : 0
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                onClicked: root.commandSelected(commandData)
                ToolTip.visible: hovered && !editButton.hovered && !removeButton.hovered
                ToolTip.delay: 500
                ToolTip.text: root.commandInfo(commandData)

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }

                background: Rectangle {
                    color: commandRow.selected
                        ? root.colorValue("highlightSoft", "#162d4a")
                        : (commandRow.hovered
                            ? root.colorValue("backgroundSectionOverlay", "#242b31")
                            : "transparent")

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 3
                        color: root.colorValue("highlightText", "#78afff")
                        visible: commandRow.selected
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: root.colorValue("border", "#334155")
                        opacity: 0.72
                    }
                }

                contentItem: RowLayout {
                    spacing: 8

                    Base.AppText {
                        Layout.preferredWidth: root.timeColumnWidth
                        text: root.formatTime(commandRow.commandData
                            ? commandRow.commandData.startTimeMs
                            : 0, true)
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Secondary
                        elide: Text.ElideRight
                    }

                    Item {
                        visible: !root.compact
                        Layout.preferredWidth: root.deviceColumnWidth
                        Layout.fillHeight: true

                        AppComponents.DeviceIcon {
                            id: deviceIcon

                            x: root.showDeviceName ? 0 : Math.round((parent.width - width) / 2)
                            anchors.verticalCenter: parent.verticalCenter
                            size: 18
                            name: String(commandRow.targetDevice
                                && commandRow.targetDevice.deviceType
                                ? commandRow.targetDevice.deviceType
                                : "")
                        }

                        Base.AppText {
                            visible: root.showDeviceName
                            anchors.left: deviceIcon.right
                            anchors.leftMargin: 6
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.deviceName(commandRow.commandData
                                ? commandRow.commandData.targetDeviceId
                                : "")
                            styleRole: UiStyle.TypographyRole.BodyS
                            textTone: UiStyle.TextTone.Secondary
                            elide: Text.ElideRight
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: root.compact
                        Layout.preferredWidth: root.nameColumnWidth
                        Layout.minimumWidth: 72
                        spacing: 4

                        Base.AppText {
                            objectName: "commandNameLabel"
                            Layout.fillWidth: true
                            text: String(commandRow.commandData
                                && commandRow.commandData.commandName
                                ? commandRow.commandData.commandName : qsTr("指令"))
                            styleRole: UiStyle.TypographyRole.BodyM
                            textTone: commandRow.filteredOut
                                ? UiStyle.TextTone.Secondary : UiStyle.TextTone.Primary
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            visible: root.compact
                            Layout.fillWidth: true
                            spacing: 6

                            AppComponents.DeviceIcon {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                name: String(commandRow.targetDevice
                                    && commandRow.targetDevice.deviceType || "")
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: root.deviceName(commandRow.commandData
                                    ? commandRow.commandData.targetDeviceId : "")
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Base.AppText {
                        visible: !root.compact
                        Layout.fillWidth: true
                        text: root.executionParameters(commandRow.commandData)
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Secondary
                        elide: Text.ElideRight
                    }

                    Item {
                        Layout.preferredWidth: root.resultColumnWidth
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.centerIn: parent
                            width: 18
                            height: 5
                            radius: height / 2
                            color: root.resultColor(commandRow.commandData)
                        }
                    }
                }

                Base.AppText {
                    id: compactExecutionParameters

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: commandRow.leftPadding
                    anchors.rightMargin: commandRow.rightPadding
                    anchors.bottomMargin: 4
                    visible: root.compact && text.length > 0
                    text: root.compact ? root.executionParameters(commandRow.commandData, true) : ""
                    textFormat: Text.PlainText
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    elide: Text.ElideRight
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    width: 66
                    height: 34
                    radius: 4
                    visible: commandRow.hovered && root.editingEnabled
                    color: root.colorValue("backgroundSurfaceOverlay", "#20262c")
                    opacity: 0.96
                    z: 1
                }

                Base.AppButton {
                    id: editButton

                    anchors.right: removeButton.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    minWidth: 28
                    size: UiStyle.ButtonSize.Small
                    variant: UiStyle.ButtonVariant.Ghost
                    iconSymbol: "✎"
                    visible: commandRow.hovered && root.editingEnabled
                    z: 2
                    onClicked: root.editRequested(commandRow.commandData)
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("编辑")
                }

                Base.AppButton {
                    id: removeButton

                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    minWidth: 28
                    size: UiStyle.ButtonSize.Small
                    variant: UiStyle.ButtonVariant.Danger
                    iconSymbol: "×"
                    visible: commandRow.hovered && root.editingEnabled
                    z: 2
                    onClicked: root.removeRequested(commandRow.commandData)
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("删除")
                }
            }
        }
    }

    Base.AppText {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 17
        visible: root.count === 0
        text: qsTr("暂无时间线指令")
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Secondary
    }
}
