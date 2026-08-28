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
    readonly property int timeColumnWidth: 92
    readonly property int deviceColumnWidth: showDeviceName ? 112 : 36
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

    function formatTime(ms) {
        var totalMs = Math.max(0, Math.round(Number(ms || 0)))
        var totalSeconds = Math.floor(totalMs / 1000)
        var hours = Math.floor(totalSeconds / 3600)
        var minutes = Math.floor(totalSeconds / 60) % 60
        var seconds = totalSeconds % 60
        return "%1:%2:%3.%4"
            .arg(padNumber(hours, 2))
            .arg(padNumber(minutes, 2))
            .arg(padNumber(seconds, 2))
            .arg(padNumber(totalMs % 1000, 3))
    }

    function resultColor(command) {
        if (commandFilteredOut(command))
            return root.colorValue("neutralBorder", "#45576b")

        return command && command.stateColor
            ? String(command.stateColor)
            : root.colorValue("neutralBorder", "#45576b")
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
                    Layout.preferredWidth: root.deviceColumnWidth
                    horizontalAlignment: root.showDeviceName
                        ? Text.AlignLeft
                        : Text.AlignHCenter
                    text: qsTr("设备")
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                }

                Base.AppText {
                    Layout.fillWidth: true
                    text: qsTr("名称")
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

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 0
            model: root.visibleCommands
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
                height: 40
                opacity: filteredOut ? 0.46 : 1
                leftPadding: 10
                rightPadding: 10
                topPadding: 0
                bottomPadding: 0
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                onClicked: root.commandSelected(commandData)

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
                            : 0)
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: UiStyle.TextTone.Secondary
                        elide: Text.ElideRight
                    }

                    Item {
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

                            MouseArea {
                                id: typeHover

                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            ToolTip.visible: typeHover.containsMouse
                            ToolTip.text: String(commandRow.targetDevice
                                && commandRow.targetDevice.deviceType
                                ? commandRow.targetDevice.deviceType
                                : qsTr("未知类型"))
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

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Base.AppText {
                            Layout.fillWidth: true
                            text: String(commandRow.commandData && commandRow.commandData.commandName
                                ? commandRow.commandData.commandName
                                : qsTr("指令"))
                            styleRole: UiStyle.TypographyRole.BodyM
                            textTone: commandRow.filteredOut
                                ? UiStyle.TextTone.Secondary
                                : UiStyle.TextTone.Primary
                            elide: Text.ElideRight

                            MouseArea {
                                id: nameHover

                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            ToolTip.visible: nameHover.containsMouse
                                && commandRow.commandData
                                && String(commandRow.commandData.commandName || "").length > 0
                            ToolTip.delay: 700
                            ToolTip.text: root.deviceName(commandRow.commandData
                                ? commandRow.commandData.targetDeviceId
                                : "")
                        }

                        Base.AppButton {
                            Layout.preferredWidth: 28
                            visible: commandRow.hovered && root.editingEnabled
                            size: UiStyle.ButtonSize.Small
                            variant: UiStyle.ButtonVariant.Ghost
                            iconSymbol: "✎"
                            onClicked: root.editRequested(commandRow.commandData)
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("编辑")
                        }

                        Base.AppButton {
                            Layout.preferredWidth: 28
                            visible: commandRow.hovered && root.editingEnabled
                            size: UiStyle.ButtonSize.Small
                            variant: UiStyle.ButtonVariant.Danger
                            iconSymbol: "×"
                            onClicked: root.removeRequested(commandRow.commandData)
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("删除")
                        }
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

                            MouseArea {
                                id: resultHover

                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            ToolTip.visible: resultHover.containsMouse
                            ToolTip.text: String(commandRow.commandData
                                && commandRow.commandData.stateText
                                ? commandRow.commandData.stateText
                                : qsTr("待执行"))
                        }
                    }
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
