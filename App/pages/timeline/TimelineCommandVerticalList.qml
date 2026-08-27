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

    signal commandSelected(var command)
    signal editRequested(var command)
    signal removeRequested(var command)

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

    function formatTime(ms) {
        var totalMs = Math.max(0, Math.round(Number(ms || 0)))
        var totalSeconds = Math.floor(totalMs / 1000)
        var minutes = Math.floor(totalSeconds / 60)
        var seconds = totalSeconds % 60
        var milliseconds = totalMs % 1000
        return qsTr("%1:%2.%3")
            .arg(minutes)
            .arg(seconds < 10 ? "0" + seconds : seconds)
            .arg(milliseconds < 10 ? "00" + milliseconds
                : (milliseconds < 100 ? "0" + milliseconds : milliseconds))
    }

    function executionSummary(command) {
        var values = command && command.commandParams
            ? command.commandParams.executionInputFields || {}
            : {}
        var parts = []
        Object.keys(values).forEach(function(key) {
            var value = values[key]
            if (value === undefined || value === null || String(value).length === 0)
                return
            if (typeof value === "boolean")
                value = value ? qsTr("是") : qsTr("否")
            parts.push(String(value))
        })
        return parts.join(" / ")
    }

    ListView {
        id: commandList

        anchors.fill: parent
        anchors.margins: 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: 2
        model: root.visibleCommands
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: Base.AppCard {
            id: commandRow

            readonly property var commandData: modelData
            readonly property bool selected: String(commandData && commandData.id || "")
                === root.selectedCommandId
            readonly property string parameterText: root.executionSummary(commandData)

            width: commandList.width
            height: parameterText.length > 0 ? 66 : 50
            surfaceTone: UiStyle.SurfaceTone.Ghost
            shapeRole: UiStyle.ShapeRole.Control
            padding: 0
            checkable: true
            checked: selected
            emphasizedSelection: true
            selectionTransition: commandSelectionTransition
            animateScale: false
            onClicked: root.commandSelected(commandData)

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 3
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: parent.height - 14
                radius: 2
                color: commandRow.commandData && commandRow.commandData.stateColor
                    ? commandRow.commandData.stateColor
                    : (root.theme ? root.theme.colors.border : "#334155")
                opacity: commandRow.selected ? 1 : (commandRow.hovered ? 0.62 : 0.28)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 10

                Base.AppText {
                    Layout.preferredWidth: 72
                    text: root.formatTime(commandRow.commandData ? commandRow.commandData.startTimeMs : 0)
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: commandRow.selected
                        ? UiStyle.TextTone.Inverse
                        : UiStyle.TextTone.Secondary
                    elide: Text.ElideRight
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Base.AppText {
                        Layout.fillWidth: true
                        text: String(commandRow.commandData && commandRow.commandData.commandName
                            ? commandRow.commandData.commandName
                            : qsTr("指令"))
                        styleRole: UiStyle.TypographyRole.BodyM
                        textTone: commandRow.selected
                            ? UiStyle.TextTone.Inverse
                            : UiStyle.TextTone.Primary
                        elide: Text.ElideRight
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        text: root.deviceName(commandRow.commandData
                            ? commandRow.commandData.targetDeviceId
                            : "") + " / " + String(commandRow.commandData && commandRow.commandData.stateText
                                ? commandRow.commandData.stateText
                                : qsTr("待执行"))
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: commandRow.selected
                            ? UiStyle.TextTone.Inverse
                            : UiStyle.TextTone.Secondary
                        elide: Text.ElideRight
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        visible: commandRow.parameterText.length > 0
                        text: commandRow.parameterText
                        styleRole: UiStyle.TypographyRole.BodyS
                        textTone: commandRow.selected
                            ? UiStyle.TextTone.Inverse
                            : UiStyle.TextTone.Accent
                        elide: Text.ElideRight
                    }
                }

                RowLayout {
                    visible: commandRow.hovered
                    spacing: 4

                    Base.AppButton {
                        text: qsTr("编辑")
                        enabled: root.editingEnabled
                        onClicked: root.editRequested(commandRow.commandData)
                    }

                    Base.AppButton {
                        text: qsTr("删除")
                        variant: UiStyle.ButtonVariant.Danger
                        enabled: root.editingEnabled
                        onClicked: root.removeRequested(commandRow.commandData)
                    }
                }
            }
        }
    }

    Base.AppCardSelectionTransition {
        id: commandSelectionTransition

        anchors.fill: commandList
        clip: true
    }

    Base.AppText {
        anchors.centerIn: parent
        visible: root.count === 0
        text: qsTr("暂无时间线指令")
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Secondary
    }
}
