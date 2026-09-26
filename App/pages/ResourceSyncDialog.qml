import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base

Base.AppDialog {
    id: root
    objectName: "resourceSyncDialog"

    property var resourceSyncManager: null
    property var deviceModel: null
    property var initialDeviceIds: []
    property var selectedResourceKeys: []
    property var selectedDeviceIds: []
    property bool selectingResources: true
    property string expandedDeviceId: ""
    property QtObject pageTheme: resolvedTheme

    readonly property bool syncBusy: resourceSyncManager ? resourceSyncManager.busy : false
    readonly property var jobs: resourceSyncManager ? resourceSyncManager.jobs : []
    readonly property var targetResults: {
        var results = []
        for (var index = 0; index < jobs.length; ++index) {
            var job = jobs[index]
            var target = results.length > 0 ? results[results.length - 1] : null
            if (!target || target.deviceId !== job.deviceId) {
                target = {deviceId: job.deviceId, name: job.deviceName, ip: job.ip,
                    totalBytes: 0, sentBytes: 0, succeeded: 0, failed: 0, cancelled: 0,
                    uploading: false, files: []}
                results.push(target)
            }
            target.totalBytes += Number(job.size)
            target.sentBytes += Number(job.sentBytes)
            target.succeeded += job.state === "succeeded" ? 1 : 0
            target.failed += job.state === "failed" ? 1 : 0
            target.cancelled += job.state === "cancelled" ? 1 : 0
            target.uploading = target.uploading || job.state === "uploading"
            target.files.push(job)
        }
        return results
    }
    readonly property int failedCount: {
        var count = 0
        for (var index = 0; index < targetResults.length; ++index)
            count += targetResults[index].failed
        return count
    }
    readonly property var resources: resourceSyncManager ? resourceSyncManager.resources : []
    readonly property var pcDevices: {
        var result = []
        var devices = deviceModel ? deviceModel.devices : []
        for (var index = 0; index < devices.length; ++index) {
            if (devices[index].supportedProtocols.indexOf("pc") >= 0)
                result.push(devices[index])
        }
        return result
    }
    readonly property var selectableResourceKeys: {
        var keys = []
        for (var index = 0; index < resources.length; ++index) {
            if (resources[index].readable)
                keys.push(resources[index].key)
        }
        return keys
    }
    readonly property var selectableDeviceIds: {
        var ids = []
        for (var index = 0; index < pcDevices.length; ++index) {
            var device = pcDevices[index]
            if (device.online && String(device.configValues.ip || "").trim().length > 0)
                ids.push(String(device.id))
        }
        return ids
    }
    readonly property real selectedBytes: {
        var bytes = 0
        for (var index = 0; index < resources.length; ++index) {
            if (selectedResourceKeys.indexOf(resources[index].key) >= 0)
                bytes += Number(resources[index].size)
        }
        return bytes
    }
    readonly property real listHeight: Math.max(160, Math.min(360,
        (parent ? parent.height : 720) - 320))

    width: Math.min(960, Math.max(0, parent ? parent.width - 32 : 960))
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0
    title: qsTr("资源同步")
    closable: true
    rejectText: qsTr("关闭")
    acceptText: selectingResources ? qsTr("开始同步") : ""
    acceptEnabled: selectingResources && !syncBusy && resourceSyncManager
        && selectedResourceKeys.length > 0 && selectedDeviceIds.length > 0
    closeOnAccepted: false

    onAccepted: {
        if (acceptEnabled && resourceSyncManager.startSync(selectedResourceKeys, selectedDeviceIds)) {
            selectingResources = false
            expandedDeviceId = ""
        }
    }
    onAboutToShow: {
        if (syncBusy || jobs.length > 0) {
            selectingResources = false
            return
        }
        selectingResources = true
        if (resourceSyncManager)
            resourceSyncManager.refreshResources()
        selectedResourceKeys = []
        var ids = []
        for (var index = 0; index < selectableDeviceIds.length; ++index) {
            if (initialDeviceIds.indexOf(selectableDeviceIds[index]) >= 0)
                ids.push(selectableDeviceIds[index])
        }
        selectedDeviceIds = ids
    }
    onSelectableResourceKeysChanged: {
        var keys = []
        for (var index = 0; index < selectedResourceKeys.length; ++index) {
            if (selectableResourceKeys.indexOf(selectedResourceKeys[index]) >= 0)
                keys.push(selectedResourceKeys[index])
        }
        selectedResourceKeys = keys
    }
    onSelectableDeviceIdsChanged: {
        var ids = []
        for (var index = 0; index < selectedDeviceIds.length; ++index) {
            if (selectableDeviceIds.indexOf(selectedDeviceIds[index]) >= 0)
                ids.push(selectedDeviceIds[index])
        }
        selectedDeviceIds = ids
    }

    function formatBytes(bytes) {
        var units = ["B", "KiB", "MiB", "GiB", "TiB"]
        var unit = 0
        while (bytes >= 1024 && unit < units.length - 1) {
            bytes /= 1024
            ++unit
        }
        return Number(bytes).toLocaleString(Qt.locale(), 'f', unit === 0 ? 0 : 1)
            + " " + units[unit]
    }

    Base.AppText {
        Layout.fillWidth: true
        text: root.selectingResources ? qsTr("将所选资源发送到每台所选 PC")
            : root.syncBusy ? qsTr("正在同步；关闭窗口后仍会继续") : qsTr("本批同步结果")
        textTone: UiStyle.TextTone.Secondary
        wrapMode: Text.Wrap
    }

    GridLayout {
        Layout.fillWidth: true
        visible: root.selectingResources
        columns: root.width >= 720 ? 2 : 1
        columnSpacing: root.pageTheme.density.paneSpacing
        rowSpacing: root.pageTheme.density.paneSpacing

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 520
            Layout.minimumWidth: 0
            spacing: root.pageTheme.density.controlGap

            RowLayout {
                Layout.fillWidth: true
                Base.AppText {
                    Layout.fillWidth: true
                    text: qsTr("本地资源 · 已选 %1").arg(root.selectedResourceKeys.length)
                    styleRole: UiStyle.TypographyRole.BodyM
                }
                Base.AppCheckBox {
                    objectName: "resourceSyncSelectAllResources"
                    text: qsTr("全选资源")
                    enabled: root.selectableResourceKeys.length > 0
                    checkState: root.selectedResourceKeys.length === 0 ? Qt.Unchecked
                        : root.selectedResourceKeys.length === root.selectableResourceKeys.length
                            ? Qt.Checked : Qt.PartiallyChecked
                    nextCheckState: function() {
                        return checkState === Qt.Checked ? Qt.Unchecked : Qt.Checked
                    }
                    onClicked: root.selectedResourceKeys = checkState === Qt.Checked
                        ? root.selectableResourceKeys.slice(0) : []
                }
            }

            Base.AppSurface {
                Layout.fillWidth: true
                Layout.preferredHeight: root.listHeight
                sizeToContent: false
                surfaceTone: UiStyle.SurfaceTone.Section

                Base.AppScrollPane {
                    anchors.fill: parent
                    anchors.margins: root.pageTheme.density.controlGap
                    contentSpacing: root.pageTheme.density.controlGap

                    Base.AppText {
                        Layout.fillWidth: true
                        visible: root.resources.length === 0
                        text: qsTr("暂无本地资源，请将文件放入 D:/video/ 或 D:/audio/")
                        textTone: UiStyle.TextTone.Secondary
                        wrapMode: Text.Wrap
                    }
                    Repeater {
                        model: root.resources
                        delegate: ColumnLayout {
                            id: resourceRow
                            Layout.fillWidth: true
                            property var resource: modelData
                            spacing: root.pageTheme.density.controlGap

                            RowLayout {
                                Layout.fillWidth: true
                                visible: index === 0
                                    || root.resources[index - 1].category !== resourceRow.resource.category
                                Base.AppText {
                                    text: resourceRow.resource.category === "video" ? qsTr("视频 / 图片") : qsTr("音频")
                                    styleRole: UiStyle.TypographyRole.BodyS
                                }
                                Base.AppText {
                                    Layout.fillWidth: true
                                    text: resourceRow.resource.path.slice(0, resourceRow.resource.path.lastIndexOf("/") + 1)
                                    styleRole: UiStyle.TypographyRole.BodyS
                                    textTone: UiStyle.TextTone.Secondary
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideMiddle
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.minimumHeight: root.pageTheme.density.controlHeightLg
                                Base.AppCheckBox {
                                    objectName: "resourceSyncResource_" + index
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: resourceRow.resource.name
                                    enabled: resourceRow.resource.readable
                                    checked: root.selectedResourceKeys.indexOf(resourceRow.resource.key) >= 0
                                    Component.onCompleted: contentItem.elide = Text.ElideRight
                                    ToolTip.visible: hovered
                                    ToolTip.text: resourceRow.resource.path
                                    onClicked: {
                                        var keys = root.selectedResourceKeys.slice(0)
                                        if (checked)
                                            keys.push(resourceRow.resource.key)
                                        else
                                            keys.splice(keys.indexOf(resourceRow.resource.key), 1)
                                        root.selectedResourceKeys = keys
                                    }
                                }
                                Base.AppText {
                                    text: resourceRow.resource.readable
                                        ? root.formatBytes(resourceRow.resource.size) : qsTr("不可读取")
                                    styleRole: UiStyle.TypographyRole.BodyS
                                    textTone: resourceRow.resource.readable ? UiStyle.TextTone.Secondary : UiStyle.TextTone.Warning
                                }
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 380
            Layout.minimumWidth: 0
            spacing: root.pageTheme.density.controlGap

            RowLayout {
                Layout.fillWidth: true
                Base.AppText {
                    Layout.fillWidth: true
                    text: qsTr("目标 PC · 已选 %1").arg(root.selectedDeviceIds.length)
                    styleRole: UiStyle.TypographyRole.BodyM
                }
                Base.AppCheckBox {
                    objectName: "resourceSyncSelectAllDevices"
                    text: qsTr("全选在线")
                    enabled: root.selectableDeviceIds.length > 0
                    checkState: root.selectedDeviceIds.length === 0 ? Qt.Unchecked
                        : root.selectedDeviceIds.length === root.selectableDeviceIds.length
                            ? Qt.Checked : Qt.PartiallyChecked
                    nextCheckState: function() {
                        return checkState === Qt.Checked ? Qt.Unchecked : Qt.Checked
                    }
                    onClicked: root.selectedDeviceIds = checkState === Qt.Checked
                        ? root.selectableDeviceIds.slice(0) : []
                }
            }

            Base.AppSurface {
                Layout.fillWidth: true
                Layout.preferredHeight: root.listHeight
                sizeToContent: false
                surfaceTone: UiStyle.SurfaceTone.Section

                Base.AppScrollPane {
                    anchors.fill: parent
                    anchors.margins: root.pageTheme.density.controlGap
                    contentSpacing: root.pageTheme.density.controlGap

                    Base.AppText {
                        Layout.fillWidth: true
                        visible: root.pcDevices.length === 0
                        text: qsTr("暂无 PC 设备，请先在设备页添加电脑")
                        textTone: UiStyle.TextTone.Secondary
                        wrapMode: Text.Wrap
                    }
                    Repeater {
                        model: root.pcDevices
                        delegate: ColumnLayout {
                            id: deviceRow
                            Layout.fillWidth: true
                            property var device: modelData
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true
                                Base.AppCheckBox {
                                    objectName: "resourceSyncDevice_" + index
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: deviceRow.device.name
                                    enabled: root.selectableDeviceIds.indexOf(String(deviceRow.device.id)) >= 0
                                    checked: root.selectedDeviceIds.indexOf(String(deviceRow.device.id)) >= 0
                                    Component.onCompleted: contentItem.elide = Text.ElideRight
                                    ToolTip.visible: hovered
                                    ToolTip.text: deviceRow.device.name
                                    onClicked: {
                                        var ids = root.selectedDeviceIds.slice(0)
                                        if (checked)
                                            ids.push(String(deviceRow.device.id))
                                        else
                                            ids.splice(ids.indexOf(String(deviceRow.device.id)), 1)
                                        root.selectedDeviceIds = ids
                                    }
                                }
                                Base.AppText {
                                    text: deviceRow.device.online ? qsTr("在线") : qsTr("离线")
                                    styleRole: UiStyle.TypographyRole.BodyS
                                    textTone: deviceRow.device.online ? UiStyle.TextTone.Success : UiStyle.TextTone.Secondary
                                }
                            }
                            Base.AppText {
                                Layout.fillWidth: true
                                Layout.leftMargin: root.pageTheme.metrics.iconSizeLg + root.pageTheme.density.controlGap
                                text: String(deviceRow.device.configValues.ip || "").trim() || qsTr("未配置 IP")
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    Base.AppText {
        Layout.fillWidth: true
        visible: root.selectingResources
        text: qsTr("视频 / 图片上传到目标 PC 的 D:/video/，音频上传到 D:/audio/。同名文件将被覆盖。")
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Warning
        wrapMode: Text.Wrap
    }
    Base.AppText {
        objectName: "resourceSyncSummary"
        Layout.fillWidth: true
        visible: root.selectingResources
        text: qsTr("已选 %1 个资源 · %2 台 PC · 合计 %3")
            .arg(root.selectedResourceKeys.length).arg(root.selectedDeviceIds.length)
            .arg(root.formatBytes(root.selectedBytes))
        wrapMode: Text.Wrap
    }

    Base.AppScrollPane {
        objectName: "resourceSyncResults"
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(root.listHeight + 120, availableContentHeight)
        visible: !root.selectingResources
        contentSpacing: root.pageTheme.density.paneSpacing

        Repeater {
            model: root.targetResults
            delegate: ColumnLayout {
                id: targetRow
                Layout.fillWidth: true
                property var result: modelData
                spacing: root.pageTheme.density.controlGap

                RowLayout {
                    Layout.fillWidth: true
                    Base.AppText {
                        Layout.fillWidth: true
                        text: targetRow.result.name + " · " + targetRow.result.ip
                        elide: Text.ElideRight
                    }
                    Base.AppButton {
                        objectName: "resourceSyncDetails_" + index
                        text: root.expandedDeviceId === targetRow.result.deviceId ? qsTr("收起") : qsTr("查看文件")
                        size: UiStyle.ButtonSize.Small
                        onClicked: root.expandedDeviceId = root.expandedDeviceId === targetRow.result.deviceId
                            ? "" : targetRow.result.deviceId
                    }
                }
                Base.AppText {
                    Layout.fillWidth: true
                    text: targetRow.result.uploading
                        ? (targetRow.result.sentBytes === targetRow.result.totalBytes ? qsTr("等待服务器确认") : qsTr("正在上传"))
                        : targetRow.result.failed > 0 ? qsTr("成功 %1 个，失败 %2 个")
                            .arg(targetRow.result.succeeded).arg(targetRow.result.failed)
                        : targetRow.result.cancelled > 0 ? qsTr("已停止，成功 %1 个，取消 %2 个")
                            .arg(targetRow.result.succeeded).arg(targetRow.result.cancelled)
                        : targetRow.result.succeeded === targetRow.result.files.length ? qsTr("已完成") : qsTr("等待中")
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: targetRow.result.failed > 0 ? UiStyle.TextTone.Warning : UiStyle.TextTone.Secondary
                    wrapMode: Text.Wrap
                }
                Base.AppProgressBar {
                    Layout.fillWidth: true
                    value: targetRow.result.totalBytes > 0 ? targetRow.result.sentBytes / targetRow.result.totalBytes
                        : targetRow.result.succeeded === targetRow.result.files.length ? 1 : 0
                }
                Base.AppText {
                    Layout.fillWidth: true
                    text: qsTr("已发送 %1 / %2 · 成功 %3 / %4 个文件")
                        .arg(root.formatBytes(targetRow.result.sentBytes)).arg(root.formatBytes(targetRow.result.totalBytes))
                        .arg(targetRow.result.succeeded).arg(targetRow.result.files.length)
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    wrapMode: Text.Wrap
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.expandedDeviceId === targetRow.result.deviceId
                    Repeater {
                        model: targetRow.result.files
                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Base.AppText {
                                Layout.fillWidth: true
                                text: modelData.name + " · " + (modelData.state === "succeeded" ? qsTr("已完成")
                                    : modelData.state === "failed" ? qsTr("失败")
                                    : modelData.state === "cancelled" ? qsTr("已取消")
                                    : modelData.state === "uploading" ? qsTr("上传中") : qsTr("等待中"))
                                wrapMode: Text.WrapAnywhere
                            }
                            Base.AppText {
                                Layout.fillWidth: true
                                text: modelData.targetPath
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Secondary
                                wrapMode: Text.WrapAnywhere
                            }
                            Base.AppText {
                                Layout.fillWidth: true
                                visible: modelData.error.length > 0
                                text: modelData.error
                                styleRole: UiStyle.TypographyRole.BodyS
                                textTone: UiStyle.TextTone.Warning
                                wrapMode: Text.WrapAnywhere
                            }
                        }
                    }
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        visible: !root.selectingResources
        Base.AppButton {
            objectName: "resourceSyncChooseAgain"
            text: qsTr("重新选择")
            enabled: !root.syncBusy
            onClicked: {
                root.resourceSyncManager.refreshResources()
                root.selectingResources = true
            }
        }
        Base.AppButton {
            objectName: "resourceSyncRetry"
            text: qsTr("重试失败项")
            enabled: !root.syncBusy && root.failedCount > 0
            onClicked: root.resourceSyncManager.retryFailed()
        }
        Base.AppButton {
            objectName: "resourceSyncStop"
            text: qsTr("停止同步")
            visible: root.syncBusy
            onClicked: root.resourceSyncManager.stopSync()
        }
    }
    Base.AppText {
        Layout.fillWidth: true
        visible: !root.selectingResources && root.syncBusy
        text: qsTr("停止同步不会回滚目标 PC 上已经写入的文件。")
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Secondary
        wrapMode: Text.Wrap
    }
    Base.AppText {
        objectName: "resourceSyncError"
        Layout.fillWidth: true
        text: root.resourceSyncManager ? root.resourceSyncManager.errorMessage : ""
        visible: text.length > 0
        styleRole: UiStyle.TypographyRole.BodyS
        textTone: UiStyle.TextTone.Danger
        wrapMode: Text.WrapAnywhere
    }
}
