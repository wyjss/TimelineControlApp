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
    property var commands: []
    property var devices: []
    property string deviceIdFilter: ""
    property string selectedCommandId: ""
    property bool editingEnabled: true
    readonly property var visibleCommands: filterCommands()
    readonly property int count: visibleCommands.length
    readonly property int timeColumnWidth: 92
    readonly property int typeColumnWidth: 68
    readonly property int resultColumnWidth: 44

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

    function deviceName(deviceId) {
        var normalizedDeviceId = String(deviceId || "")
        for (var index = 0; index < devices.length; ++index) {
            var device = devices[index]
            if (String(device.id || "") !== normalizedDeviceId)
                continue

            var name = String(device.name || "").trim()
            return name.length > 0 ? name : normalizedDeviceId
        }
        return normalizedDeviceId.length > 0 ? normalizedDeviceId : qsTr("未分配")
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

    function commandProtocol(command) {
        return String(command && command.commandParams
            ? command.commandParams.protocol || ""
            : "").toLowerCase()
    }

    function protocolLabel(command) {
        switch (commandProtocol(command)) {
        case "internal": return qsTr("无协议")
        case "udp": return "UDP"
        case "http": return "HTTP"
        case "pc": return "PC"
        case "serial": return qsTr("串口")
        case "osc": return "OSC"
        case "dmx512": return "DMX"
        default: return qsTr("其他")
        }
    }

    function protocolColor(command) {
        switch (commandProtocol(command)) {
        case "internal": return "#8b5cf6"
        case "udp": return "#0ea5e9"
        case "http": return "#06b6d4"
        case "pc": return "#3b82f6"
        case "serial": return "#f59e0b"
        case "osc": return "#a855f7"
        case "dmx512": return "#22c55e"
        default: return root.colorValue("neutralText", "#94a3b8")
        }
    }

    function resultColor(command) {
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
                    Layout.preferredWidth: root.typeColumnWidth
                    text: qsTr("类型")
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
                readonly property bool selected: String(commandData && commandData.id || "")
                    === root.selectedCommandId

                width: commandList.width
                height: 40
                leftPadding: 10
                rightPadding: 10
                topPadding: 0
                bottomPadding: 0
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                onClicked: root.commandSelected(commandData)

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
                        Layout.preferredWidth: root.typeColumnWidth
                        Layout.fillHeight: true

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 2
                                color: root.protocolColor(commandRow.commandData)
                                rotation: root.commandProtocol(commandRow.commandData) === "osc" ? 45 : 0
                            }

                            Base.AppText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.protocolLabel(commandRow.commandData)
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                            }
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
                            textTone: UiStyle.TextTone.Primary
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
