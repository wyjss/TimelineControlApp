import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UiCore/qml/components/base" as Base
import "qrc:/UiCore/qml/theme" as Theme

Item {
    id: root

    focus: true

    property string initialPcId: ""
    property string selectedPcId: ""
    property int selectedScreenIndex: 0
    property int keystoneRevision: 0
    property string statusText: ""

    Theme.AppTheme {
        id: fallbackTheme
    }

    property QtObject pageTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : fallbackTheme
    property var appRuntime: typeof app !== "undefined" ? app : null
    property var deviceManager: appRuntime && appRuntime.deviceManager ? appRuntime.deviceManager : null
    property var deviceModel: appRuntime && appRuntime.deviceModel ? appRuntime.deviceModel : null
    readonly property var devices: deviceModel ? deviceModel.devices : []
    readonly property var pcDevices: buildPcDevices()
    readonly property var selectedPc: selectedPcForId(selectedPcId)
    readonly property size selectedResolution: sizeFromValue(configValue(selectedPc, "screenSize", undefined), Qt.size(1920, 1080))
    readonly property size selectedLayout: sizeFromValue(configValue(selectedPc, "screenLayout", undefined), Qt.size(1, 1))
    readonly property int screenColumns: Math.max(1, Math.round(selectedLayout.width))
    readonly property int screenRows: Math.max(1, Math.round(selectedLayout.height))
    readonly property int screenCount: screenColumns * screenRows
    readonly property int selectedScreenWidth: Math.max(1, Math.round(selectedResolution.width))
    readonly property int selectedScreenHeight: Math.max(1, Math.round(selectedResolution.height))
    readonly property int totalScreenWidth: selectedScreenWidth * screenColumns
    readonly property int totalScreenHeight: selectedScreenHeight * screenRows

    signal backRequested()

    onPcDevicesChanged: ensureSelectedPc()
    onInitialPcIdChanged: ensureSelectedPc()
    onSelectedPcIdChanged: keystoneRevision += 1
    onScreenCountChanged: selectedScreenIndex = Math.max(0, Math.min(selectedScreenIndex, screenCount - 1))

    Component.onCompleted: ensureSelectedPc()

    Connections {
        target: root.selectedPc
        ignoreUnknownSignals: true
        function onConfigValuesChanged() { root.keystoneRevision += 1 }
    }

    function colorValue(name, fallback) {
        if (pageTheme && pageTheme.colors && pageTheme.colors[name] !== undefined)
            return pageTheme.colors[name]

        return fallback
    }

    function leavePage() {
        if (root.appRuntime && root.appRuntime.shell) {
            root.appRuntime.shell.selectDrawer("projection")
            return
        }

        root.backRequested()
    }

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value))
    }

    function buildPcDevices() {
        var result = []
        for (var index = 0; index < devices.length; ++index) {
            var device = devices[index]
            var deviceType = String(device.deviceType || "")
            var templateName = String(device.templateName || "")
            var protocol = String(device.protocol || "").toLowerCase()
            if (deviceType === "电脑" || templateName === "电脑" || protocol === "pc")
                result.push(device)
        }

        return result
    }

    function selectedPcForId(deviceId) {
        var normalizedId = String(deviceId || "")
        for (var index = 0; index < pcDevices.length; ++index) {
            if (String(pcDevices[index].id || "") === normalizedId)
                return pcDevices[index]
        }

        return pcDevices.length > 0 ? pcDevices[0] : null
    }

    function ensureSelectedPc() {
        if (pcDevices.length === 0) {
            selectedPcId = ""
            selectedScreenIndex = 0
            return
        }

        var preferred = initialPcId.length > 0 ? initialPcId : selectedPcId
        selectedPcId = String(selectedPcForId(preferred).id || "")
        selectedScreenIndex = Math.max(0, Math.min(selectedScreenIndex, screenCount - 1))
    }

    function selectPc(deviceId) {
        selectedPcId = String(deviceId || "")
        selectedScreenIndex = 0
        statusText = ""
    }

    function configValue(device, key, fallback) {
        if (!device || !device.configValues)
            return fallback

        var values = device.configValues
        return values[key] !== undefined && values[key] !== null ? values[key] : fallback
    }

    function sizeFromValue(value, fallback) {
        if (value && value.width !== undefined && value.height !== undefined) {
            var widthValue = Math.round(Number(value.width))
            var heightValue = Math.round(Number(value.height))
            if (widthValue > 0 && heightValue > 0)
                return Qt.size(widthValue, heightValue)
        }

        var match = String(value || "").trim().match(/(\d+)\D+(\d+)/)
        if (match) {
            var parsedWidth = Math.round(Number(match[1]))
            var parsedHeight = Math.round(Number(match[2]))
            if (parsedWidth > 0 && parsedHeight > 0)
                return Qt.size(parsedWidth, parsedHeight)
        }

        return fallback
    }

    function sizeText(sizeValue) {
        return String(Math.round(sizeValue.width)) + "x" + String(Math.round(sizeValue.height))
    }

    function pcName(device) {
        if (!device)
            return qsTr("未选择 PC")

        var name = String(device.name || "").trim()
        return name.length > 0 ? name : String(device.id || qsTr("PC"))
    }

    function pcAddress(device) {
        if (!device)
            return qsTr("无设备")

        var address = String(device.address || "").trim()
        return address.length > 0 ? address : qsTr("未分配")
    }

    function defaultCorners() {
        return [
            { "x": 0.0, "y": 0.0 },
            { "x": root.selectedScreenWidth, "y": 0.0 },
            { "x": root.selectedScreenWidth, "y": root.selectedScreenHeight },
            { "x": 0.0, "y": root.selectedScreenHeight }
        ]
    }

    function pointFromValue(value, fallback) {
        if (!value)
            return { "x": Number(fallback.x), "y": Number(fallback.y) }

        var x = Number(value.x)
        var y = Number(value.y)
        return {
            "x": isNaN(x) ? Number(fallback.x) : x,
            "y": isNaN(y) ? Number(fallback.y) : y
        }
    }

    function cloneCorners(corners) {
        var result = []
        for (var index = 0; index < corners.length; ++index)
            result.push({ "x": Number(corners[index].x), "y": Number(corners[index].y) })
        return result
    }

    function keystoneItems() {
        var value = configValue(root.selectedPc, "keystoneCorrection", [])
        var result = []
        if (!value || value.length === undefined)
            return result

        for (var index = 0; index < value.length; ++index)
            result.push(value[index])
        return result
    }

    function keystoneItemForScreen(screenIndex) {
        var items = keystoneItems()
        for (var index = 0; index < items.length; ++index) {
            var item = items[index]
            if (Math.round(Number(item.screenIndex)) === screenIndex)
                return item
        }

        return null
    }

    function cornersForScreen(screenIndex) {
        root.keystoneRevision

        var defaults = defaultCorners()
        var item = keystoneItemForScreen(screenIndex)
        if (!item)
            return defaults

        return [
            pointFromValue(item.topLeft, defaults[0]),
            pointFromValue(item.topRight, defaults[1]),
            pointFromValue(item.bottomRight, defaults[2]),
            pointFromValue(item.bottomLeft, defaults[3])
        ]
    }

    function normalizedCornersForScreen(screenIndex) {
        var corners = cornersForScreen(screenIndex)
        var result = []
        for (var index = 0; index < corners.length; ++index) {
            result.push({
                "x": Number(corners[index].x) / root.selectedScreenWidth,
                "y": Number(corners[index].y) / root.selectedScreenHeight
            })
        }
        return result
    }

    function itemFromCorners(screenIndex, corners) {
        return {
            "screenIndex": screenIndex,
            "topLeft": { "x": Number(corners[0].x), "y": Number(corners[0].y) },
            "topRight": { "x": Number(corners[1].x), "y": Number(corners[1].y) },
            "bottomRight": { "x": Number(corners[2].x), "y": Number(corners[2].y) },
            "bottomLeft": { "x": Number(corners[3].x), "y": Number(corners[3].y) }
        }
    }

    function writeKeystoneItems(items) {
        if (!root.selectedPc)
            return

        var values = {}
        var currentValues = root.selectedPc.configValues || {}
        for (var key in currentValues)
            values[key] = currentValues[key]

        values["keystoneCorrection"] = items
        root.selectedPc.configValues = values
        root.keystoneRevision += 1
    }

    function setCornersForScreen(screenIndex, corners) {
        var next = []
        var items = keystoneItems()
        for (var index = 0; index < items.length; ++index) {
            var item = items[index]
            if (Math.round(Number(item.screenIndex)) !== screenIndex)
                next.push(item)
        }

        next.push(itemFromCorners(screenIndex, cloneCorners(corners)))
        writeKeystoneItems(next)
        statusText = ""
    }

    function setCorner(screenIndex, cornerIndex, pixelX, pixelY) {
        var corners = cornersForScreen(screenIndex)
        corners[cornerIndex] = {
            "x": clamp(pixelX, -0.24 * root.selectedScreenWidth, 1.24 * root.selectedScreenWidth),
            "y": clamp(pixelY, -0.24 * root.selectedScreenHeight, 1.24 * root.selectedScreenHeight)
        }
        setCornersForScreen(screenIndex, corners)
    }

    function resetScreen(screenIndex) {
        var next = []
        var items = keystoneItems()
        for (var index = 0; index < items.length; ++index) {
            var item = items[index]
            if (Math.round(Number(item.screenIndex)) !== screenIndex)
                next.push(item)
        }

        writeKeystoneItems(next)
        statusText = qsTr("已重置当前屏幕")
    }

    function resetPc() {
        writeKeystoneItems([])
        statusText = qsTr("已重置当前 PC")
    }

    function simulatedSave() {
        statusText = qsTr("校正数据已写入当前 PC 设备")
    }

    function cornerLabel(index) {
        if (index === 0)
            return qsTr("左上")
        if (index === 1)
            return qsTr("右上")
        if (index === 2)
            return qsTr("右下")
        return qsTr("左下")
    }

    function screenTitle(screenIndex) {
        var column = screenIndex % screenColumns
        var row = Math.floor(screenIndex / screenColumns)
        return qsTr("屏幕 %1 (%2,%3)").arg(screenIndex + 1).arg(column + 1).arg(row + 1)
    }

    Rectangle {
        anchors.fill: parent
        color: root.colorValue("window", "#0f172a")
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 32
        anchors.rightMargin: 32
        anchors.topMargin: 64
        anchors.bottomMargin: 44
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Base.AppButton {
                text: qsTr("返回")
                theme: root.pageTheme
                iconName: "undo"
                onClicked: root.leavePage()
            }

            Base.AppText {
                Layout.fillWidth: true
                text: qsTr("PC 梯形校正")
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
                    text: root.selectedPc
                        ? root.sizeText(Qt.size(root.totalScreenWidth, root.totalScreenHeight)) + " / " + root.screenColumns + "x" + root.screenRows
                        : qsTr("未选择 PC")
                    theme: root.pageTheme
                    styleRole: "bodyS"
                    textTone: "secondary"
                }
            }

            Base.AppButton {
                text: qsTr("保存")
                theme: root.pageTheme
                iconName: "resources"
                enabled: !!root.selectedPc
                onClicked: root.simulatedSave()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            Base.AppSurface {
                Layout.preferredWidth: 248
                Layout.minimumWidth: 220
                Layout.fillHeight: true
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Base.AppText {
                        Layout.fillWidth: true
                        text: qsTr("PC 设备")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        text: qsTr("%1 台可用").arg(root.pcDevices.length)
                        theme: root.pageTheme
                        styleRole: "bodyS"
                        textTone: "secondary"
                        elide: Text.ElideRight
                    }

                    Base.AppScrollPane {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        theme: root.pageTheme
                        contentSpacing: 8

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.pcDevices.length === 0 ? 76 : 0
                            visible: root.pcDevices.length === 0

                            Base.AppText {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("暂无 PC 设备")
                                theme: root.pageTheme
                                styleRole: "bodyM"
                                textTone: "secondary"
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }
                        }

                        Repeater {
                            model: root.pcDevices

                            delegate: Item {
                                id: pcRow

                                readonly property var pcDevice: modelData
                                readonly property bool selected: String(pcDevice.id || "") === root.selectedPcId
                                readonly property size resolution: root.sizeFromValue(root.configValue(pcDevice, "screenSize", undefined), Qt.size(1920, 1080))
                                readonly property size layoutSize: root.sizeFromValue(root.configValue(pcDevice, "screenLayout", undefined), Qt.size(1, 1))

                                Layout.fillWidth: true
                                Layout.preferredHeight: 86

                                Base.AppSurface {
                                    anchors.fill: parent
                                    theme: root.pageTheme
                                    surfaceTone: pcRow.selected ? "highlight" : "surface"
                                    active: pcRow.selected
                                    hoveredState: pcTap.containsMouse
                                    interactive: true
                                    strokeWidth: pcRow.selected || pcTap.containsMouse ? 1 : 0
                                    borderOverride: pcRow.selected
                                        ? root.colorValue("highlightText", "#7cb4ff")
                                        : root.colorValue("border", "#334155")
                                    hoverOverlayOpacity: 0.08
                                }

                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Base.AppText {
                                        width: parent.width
                                        text: root.pcName(pcDevice)
                                        theme: root.pageTheme
                                        styleRole: "bodyM"
                                        textTone: pcRow.selected ? "accent" : "primary"
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        width: parent.width
                                        text: root.pcAddress(pcDevice)
                                        theme: root.pageTheme
                                        styleRole: "bodyS"
                                        textTone: "secondary"
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        width: parent.width
                                        text: root.sizeText(resolution) + " / " + Math.round(layoutSize.width) + "x" + Math.round(layoutSize.height)
                                        theme: root.pageTheme
                                        styleRole: "bodyS"
                                        textTone: "secondary"
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: pcTap

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.selectPc(pcDevice.id)
                                }
                            }
                        }
                    }
                }
            }

            Base.AppSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 520
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Base.AppText {
                            Layout.fillWidth: true
                            text: root.selectedPc ? root.pcName(root.selectedPc) : qsTr("校正画布")
                            theme: root.pageTheme
                            styleRole: "sectionTitle"
                        }

                        Base.AppText {
                            text: root.screenTitle(root.selectedScreenIndex)
                            theme: root.pageTheme
                            styleRole: "bodyS"
                            textTone: "secondary"
                            visible: !!root.selectedPc
                        }
                    }

                    Item {
                        id: canvasHost

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 340
                        clip: true

                        Rectangle {
                            id: screenCanvas

                            readonly property real aspect: Math.max(0.2, root.totalScreenWidth / Math.max(1, root.totalScreenHeight))

                            width: Math.min(parent.width, parent.height * aspect)
                            height: width / aspect
                            anchors.centerIn: parent
                            radius: 6
                            color: root.colorValue("canvas", "#0b1020")
                            border.color: root.colorValue("border", "#334155")
                            border.width: 1
                            visible: !!root.selectedPc

                            Repeater {
                                model: root.screenCount

                                delegate: Item {
                                    id: tile

                                    readonly property int screenIndex: index
                                    readonly property int column: index % root.screenColumns
                                    readonly property int row: Math.floor(index / root.screenColumns)
                                    readonly property bool selected: index === root.selectedScreenIndex
                                    readonly property var normalizedCorners: root.normalizedCornersForScreen(index)

                                    x: column * screenCanvas.width / root.screenColumns
                                    y: row * screenCanvas.height / root.screenRows
                                    width: screenCanvas.width / root.screenColumns
                                    height: screenCanvas.height / root.screenRows
                                    z: selected ? 5 : 1

                                    Canvas {
                                        id: tileCanvas

                                        anchors.fill: parent
                                        contextType: "2d"

                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()
                                        Connections {
                                            target: root
                                            function onKeystoneRevisionChanged() { tileCanvas.requestPaint() }
                                            function onSelectedScreenIndexChanged() { tileCanvas.requestPaint() }
                                        }

                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            var c = tile.normalizedCorners
                                            ctx.save()
                                            ctx.beginPath()
                                            ctx.moveTo(c[0].x * width, c[0].y * height)
                                            ctx.lineTo(c[1].x * width, c[1].y * height)
                                            ctx.lineTo(c[2].x * width, c[2].y * height)
                                            ctx.lineTo(c[3].x * width, c[3].y * height)
                                            ctx.closePath()
                                            ctx.fillStyle = tile.selected ? "rgba(124,180,255,0.20)" : "rgba(22,34,52,0.76)"
                                            ctx.fill()
                                            ctx.clip()

                                            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.24)
                                            ctx.lineWidth = 1
                                            var stepX = Math.max(18, width / 8)
                                            var stepY = Math.max(18, height / 6)
                                            ctx.beginPath()
                                            for (var gx = stepX; gx < width; gx += stepX) {
                                                ctx.moveTo(gx, 0)
                                                ctx.lineTo(gx, height)
                                            }
                                            for (var gy = stepY; gy < height; gy += stepY) {
                                                ctx.moveTo(0, gy)
                                                ctx.lineTo(width, gy)
                                            }
                                            ctx.stroke()
                                            ctx.restore()

                                            ctx.strokeStyle = tile.selected
                                                ? root.colorValue("highlightText", "#7cb4ff")
                                                : root.colorValue("border", "#334155")
                                            ctx.lineWidth = tile.selected ? 2 : 1
                                            ctx.beginPath()
                                            ctx.moveTo(c[0].x * width, c[0].y * height)
                                            ctx.lineTo(c[1].x * width, c[1].y * height)
                                            ctx.lineTo(c[2].x * width, c[2].y * height)
                                            ctx.lineTo(c[3].x * width, c[3].y * height)
                                            ctx.closePath()
                                            ctx.stroke()
                                        }
                                    }

                                    Base.AppText {
                                        anchors.centerIn: parent
                                        text: String(index + 1)
                                        theme: root.pageTheme
                                        styleRole: "titleL"
                                        textTone: "secondary"
                                        opacity: tile.selected ? 0.82 : 0.42
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton
                                        onClicked: root.selectedScreenIndex = tile.screenIndex
                                    }

                                    Repeater {
                                        model: [0, 1, 2, 3]

                                        delegate: Rectangle {
                                            id: cornerHandle

                                            readonly property var corner: tile.normalizedCorners[modelData]

                                            width: tile.selected ? 16 : 10
                                            height: width
                                            radius: width / 2
                                            x: corner.x * tile.width - width / 2
                                            y: corner.y * tile.height - height / 2
                                            visible: tile.selected
                                            color: root.colorValue("window", "#0f172a")
                                            border.color: root.colorValue("highlightText", "#7cb4ff")
                                            border.width: 2
                                            z: 10

                                            MouseArea {
                                                anchors.fill: parent
                                                acceptedButtons: Qt.LeftButton
                                                cursorShape: Qt.SizeAllCursor
                                                preventStealing: true
                                                onPressed: root.selectedScreenIndex = tile.screenIndex
                                                onPositionChanged: {
                                                    if (!pressed || tile.width <= 0 || tile.height <= 0)
                                                        return

                                                    var point = tile.mapFromItem(cornerHandle, mouse.x, mouse.y)
                                                    root.setCorner(tile.screenIndex,
                                                                   modelData,
                                                                   point.x / tile.width * root.selectedScreenWidth,
                                                                   point.y / tile.height * root.selectedScreenHeight)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Base.AppText {
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 40, 360)
                            text: qsTr("暂无 PC 设备")
                            theme: root.pageTheme
                            styleRole: "bodyM"
                            textTone: "secondary"
                            horizontalAlignment: Text.AlignHCenter
                            visible: !root.selectedPc
                        }
                    }
                }
            }

            Base.AppSurface {
                Layout.preferredWidth: 286
                Layout.minimumWidth: 252
                Layout.fillHeight: true
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Base.AppText {
                        Layout.fillWidth: true
                        text: qsTr("校正参数")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        text: root.selectedPc
                            ? root.screenTitle(root.selectedScreenIndex)
                            : qsTr("未选择屏幕")
                        theme: root.pageTheme
                        styleRole: "bodyS"
                        textTone: "secondary"
                        elide: Text.ElideRight
                    }

                    Base.AppScrollPane {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        theme: root.pageTheme
                        contentSpacing: 8

                        Repeater {
                            model: root.selectedPc ? [0, 1, 2, 3] : []

                            delegate: Base.AppSurface {
                                id: cornerRow

                                readonly property var corner: root.cornersForScreen(root.selectedScreenIndex)[modelData]

                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                theme: root.pageTheme
                                surfaceTone: "surface"
                                sizeToContent: false

                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Base.AppText {
                                        width: parent.width
                                        text: root.cornerLabel(modelData)
                                        theme: root.pageTheme
                                        styleRole: "bodyM"
                                        textTone: "primary"
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        width: parent.width
                                        text: "x:" + Number(corner.x).toFixed(1) + " y:" + Number(corner.y).toFixed(1)
                                        theme: root.pageTheme
                                        styleRole: "bodyS"
                                        textTone: "secondary"
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    Base.AppButton {
                        Layout.fillWidth: true
                        text: qsTr("重置当前屏幕")
                        theme: root.pageTheme
                        iconName: "undo"
                        enabled: !!root.selectedPc
                        onClicked: root.resetScreen(root.selectedScreenIndex)
                    }

                    Base.AppButton {
                        Layout.fillWidth: true
                        text: qsTr("重置当前 PC")
                        theme: root.pageTheme
                        iconName: "layer-config"
                        enabled: !!root.selectedPc
                        onClicked: root.resetPc()
                    }

                    Base.AppText {
                        Layout.fillWidth: true
                        text: root.statusText
                        theme: root.pageTheme
                        styleRole: "bodyS"
                        textTone: "accent"
                        elide: Text.ElideRight
                        visible: root.statusText.length > 0
                    }
                }
            }
        }
    }
}
