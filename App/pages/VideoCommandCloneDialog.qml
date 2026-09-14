import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base

Base.AppDialog {
    id: root
    objectName: "cloneVideoCommandDialog"

    property var timelineManager: null
    property var pcDevices: []
    property string sourceTimelineId: ""
    property string sourceCommandId: ""
    property string targetDeviceId: ""
    property string videoFile: ""
    property string errorText: ""
    readonly property var currentTimeline: timelineManager ? timelineManager.currentTimeline : null
    readonly property var commandModel: currentTimeline ? currentTimeline.commandModel : null
    readonly property bool editingEnabled: !!currentTimeline && timelineManager.playbackState === 0
        && currentTimeline.state === 0
    readonly property var sourceCommand: currentTimeline && currentTimeline.id === sourceTimelineId
        ? commandModel.commands.filter(function(command) {
            return command.id === sourceCommandId && command.targetCommand
                && command.targetCommand.commandType === "openVideo"
        })[0] || null : null
    readonly property var sourcePc: sourceCommand
        ? pcDevices.filter(function(pc) { return pc.id === sourceCommand.targetDeviceId })[0] || null : null
    readonly property var targetPc: pcDevices.filter(function(pc) { return pc.id === targetDeviceId })[0] || null
    readonly property var sourceParameters: {
        var values = {}
        if (!sourceCommand)
            return values
        var fields = sourceCommand.targetCommand.executionInputFields
        for (var i = 0; i < fields.length; ++i)
            values[fields[i].key] = fields[i].value
        Object.assign(values, sourceCommand.executionInputValues)
        if (sourceCommand.executionInputValues.play === undefined)
            values.play = true
        if (values.rect) {
            var rect = String(values.rect).split(",")
            if (rect.length === 4) {
                values.videoWindowX = Number(rect[0])
                values.videoWindowY = Number(rect[1])
                values.videoWindowW = Number(rect[2])
                values.videoWindowH = Number(rect[3])
            }
        }
        delete values.rect
        return values
    }
    readonly property var videoOptions: {
        var result = []
        var fields = targetPc && targetPc.loadCommand ? targetPc.loadCommand.executionInputFields : []
        for (var i = 0; i < fields.length; ++i) {
            if (fields[i].key !== "videoFile")
                continue
            var options = fields[i].options
            for (var j = 0; j < options.length; ++j) {
                var option = options[j]
                var value = option && typeof option === "object" ? option.value : option
                if (value !== undefined && value !== null && String(value).length)
                    result.push({ "value": String(value), "label": String(option.label || value) })
            }
        }
        return result
    }
    readonly property string invalidReason: !editingEnabled
        ? qsTr("时间线运行或暂停中，停止后可克隆")
        : !sourceCommand ? qsTr("原时间线或指令已不可用")
        : !targetPc || !targetPc.loadCommand ? qsTr("请选择配置了加载视频指令的设备")
        : !videoOptions.length ? qsTr("目标设备暂无可选视频")
        : !videoOptions.some(function(option) { return option.value === videoFile })
            ? qsTr("目标设备未提供原视频选项，请重新选择")
        : !cloneTime.acceptableInput ? qsTr("请输入有效的触发时间，格式为 时:分:秒.毫秒") : ""
    readonly property bool rectangleOutside: !!sourceCommand && !!targetPc
        && (Number(sourceParameters.videoWindowX || 0) < 0 || Number(sourceParameters.videoWindowY || 0) < 0
            || Number(sourceParameters.videoWindowX || 0) + Number(sourceParameters.videoWindowW || 1920) > targetPc.width
            || Number(sourceParameters.videoWindowY || 0) + Number(sourceParameters.videoWindowH || 1080) > targetPc.height)

    signal commandCloned(var command)

    width: Math.min(540, Math.max(0, parent ? parent.width - 32 : 540))
    x: parent ? (parent.width - width) / 2 : 0
    y: parent ? (parent.height - height) / 2 : 0
    title: qsTr("克隆指令")
    rejectText: qsTr("取消")
    acceptText: qsTr("克隆并编辑")
    closable: true
    closeOnAccepted: false
    initialFocusItem: cloneDeviceSelect
    acceptEnabled: invalidReason.length === 0

    onTargetDeviceIdChanged: {
        videoFile = String(sourceParameters.videoFile || "")
        errorText = ""
    }

    function openForCommand(commandId) {
        if (!editingEnabled)
            return
        sourceTimelineId = currentTimeline.id
        sourceCommandId = commandId
        if (!sourceCommand)
            return
        targetDeviceId = sourceCommand.targetDeviceId
        videoFile = String(sourceParameters.videoFile || "")
        var ms = Math.max(0, Math.round(sourceCommand.startTimeMs))
        cloneTime.text = ("0" + Math.floor(ms / 3600000)).slice(-2) + ":"
            + ("0" + Math.floor(ms / 60000) % 60).slice(-2) + ":"
            + ("0" + Math.floor(ms / 1000) % 60).slice(-2) + "." + ("00" + ms % 1000).slice(-3)
        errorText = ""
        open()
    }

    onAccepted: {
        if (!acceptEnabled)
            return
        var values = Object.assign({}, sourceParameters, { "videoFile": videoFile })
        var parts = cloneTime.text.split(/[:.]/)
        var timeMs = Number(parts[0]) * 3600000 + Number(parts[1]) * 60000
            + Number(parts[2]) * 1000 + Number(parts[3])
        var command = commandModel.addDeviceCommand(timeMs, targetPc.id, targetPc.loadCommand, values)
        if (!command) {
            errorText = qsTr("克隆指令失败")
            return
        }
        close()
        commandCloned(command)
    }

    Base.AppSurface {
        Layout.fillWidth: true
        Layout.preferredHeight: sourceInfo.implicitHeight + 24
        sizeToContent: false
        surfaceTone: UiStyle.SurfaceTone.Section
        ColumnLayout {
            id: sourceInfo
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6
            Base.AppText {
                Layout.fillWidth: true
                text: root.currentTimeline ? root.currentTimeline.name : ""
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
                elide: Text.ElideRight
            }
            RowLayout {
                Base.AppIcon { source: "../assets/icons/电脑.png"; tintSource: false }
                Base.AppText {
                    Layout.fillWidth: true
                    text: root.sourcePc ? root.sourcePc.name + " / "
                        + String(root.sourceParameters.videoFile || qsTr("未选择视频")).replace(/^\$/, "").split(/[\\/]/).pop() : ""
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        Base.AppText { text: qsTr("克隆到设备") }
        Base.AppSelect {
            id: cloneDeviceSelect
            objectName: "cloneVideoTargetDevice"
            Layout.fillWidth: true
            options: root.pcDevices.filter(function(pc) { return !!pc.loadCommand }).map(function(pc) {
                return { "label": pc.name + (root.sourceCommand && pc.id === root.sourceCommand.targetDeviceId
                    ? qsTr("（原设备）") : ""), "value": pc.id }
            })
            value: root.targetDeviceId
            placeholderText: qsTr("选择目标设备")
            onValueSelected: root.targetDeviceId = String(nextValue)
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        Base.AppText { text: qsTr("视频") }
        Base.AppSelect {
            objectName: "cloneVideoFile"
            Layout.fillWidth: true
            options: root.videoOptions
            value: root.videoFile
            placeholderText: optionCount ? qsTr("选择目标设备的视频") : qsTr("暂无可选视频")
            enabled: optionCount > 0
            onValueSelected: {
                root.videoFile = String(nextValue)
                root.errorText = ""
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Base.AppText { text: qsTr("触发时间") }
        Base.AppTextField {
            id: cloneTime
            objectName: "cloneVideoTime"
            Layout.fillWidth: true
            validator: RegularExpressionValidator { regularExpression: /\d{2}:[0-5]\d:[0-5]\d\.\d{3}/ }
        }
    }
    Base.AppText {
        Layout.fillWidth: true
        text: qsTr("沿用原指令的源矩形、目标矩形和播放选项")
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Secondary
        wrapMode: Text.WordWrap
    }
    Base.AppText {
        objectName: "cloneVideoBoundsWarning"
        Layout.fillWidth: true
        visible: root.rectangleOutside
        text: qsTr("矩形超出目标画布，将保留原参数；克隆后可调整。")
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Warning
        wrapMode: Text.WordWrap
    }
    Base.AppText {
        objectName: "cloneVideoValidation"
        Layout.fillWidth: true
        text: root.errorText || root.invalidReason
        visible: text.length > 0
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Warning
        wrapMode: Text.WordWrap
    }
}
