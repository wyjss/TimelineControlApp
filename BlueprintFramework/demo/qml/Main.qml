import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtQuick.Dialogs 1.3 as Dialogs
import UICore.Style 1.0
import "qrc:/BlueprintQuick" as Quick
import "qrc:/UICore/qml/theme" as Theme
import "qrc:/UICore/qml/components/base" as Base

ApplicationWindow {
    id: window

    width: 1280
    height: 730
    minimumWidth: 940
    minimumHeight: 550
    visible: true
    title: qsTr("蓝图编辑器") + " — BlueprintFramework-demo"
    color: appTheme.colors.backgroundWindow
    property QtObject appTheme: Theme.AppTheme {}
    property string notice
    readonly property string graphError: demoGraph.error || demoGraph.session.error
    readonly property var boolOptions: [{label: qsTr("真"), value: true}, {label: qsTr("假"), value: false}]

    function requestOpen() {
        if (demoGraph.session.modified) {
            discardDialog.open()
        } else {
            openDialog.open()
        }
    }

    Connections {
        target: demoGraph.session
        function onHistoryChanged() { window.notice = "" }
    }

    Shortcut { sequence: StandardKey.Open; onActivated: window.requestOpen() }
    Shortcut { sequence: StandardKey.Save; onActivated: saveDialog.open() }

    Dialog {
        id: discardDialog
        modal: true
        anchors.centerIn: parent
        implicitWidth: 340
        title: qsTr("有未保存的修改")
        standardButtons: Dialog.Discard | Dialog.Cancel
        onDiscarded: {
            close()
            openDialog.open()
        }
        contentItem: Item {
            implicitWidth: 298
            implicitHeight: 54
            Text {
                anchors.centerIn: parent
                text: qsTr("继续将丢弃当前未保存的修改。")
                color: window.appTheme.colors.text
            }
        }
        background: Rectangle {
            radius: 9
            color: window.appTheme.colors.backgroundSurface
            border.color: window.appTheme.colors.border
        }
        palette.windowText: window.appTheme.colors.text
        palette.buttonText: window.appTheme.colors.text
        palette.button: window.appTheme.colors.backgroundSection
    }

    Dialogs.FileDialog {
        id: openDialog
        title: qsTr("打开蓝图")
        nameFilters: [qsTr("蓝图文件 (*.blueprint.json)"), qsTr("JSON 文件 (*.json)")]
        onAccepted: {
            if (demoGraph.open(fileUrl)) {
                window.notice = qsTr("已打开")
                Qt.callLater(editor.fit)
            }
        }
    }

    Dialogs.FileDialog {
        id: saveDialog
        title: qsTr("保存蓝图")
        selectExisting: false
        nameFilters: [qsTr("蓝图文件 (*.blueprint.json)")]
        defaultSuffix: "blueprint.json"
        onAccepted: if (demoGraph.save(fileUrl)) window.notice = qsTr("已保存")
    }


    Component {
        id: calculationBody

        Rectangle {
            id: body
            property var node: null
            property bool expanded: false
            property bool editing: false
            readonly property bool expandable: !!node && node.typeId === "demo.add"
            readonly property bool editable: !!node && node.parameters.value !== undefined
            readonly property bool isBoolConstant: !!node && node.typeId === "demo.boolConstant"
            readonly property bool choosingOption: !!node && (node.typeId === "demo.optionConstant" || isBoolConstant)
            readonly property string displayValue: node ? demoGraph.previewValues[node.id] || "—" : "—"
            objectName: "calculationBody"
            implicitHeight: expanded ? 56 : 31
            radius: 5
            color: window.appTheme.colors.backgroundWindow

            Text {
                x: 9
                y: 7
                visible: !body.editing
                text: body.expandable ? (body.expanded ? qsTr("▾ 数值") : qsTr("▸ 数值")) : qsTr("值")
                color: window.appTheme.colors.subtleText
                font.pixelSize: 12
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 9
                y: 6
                visible: !body.editing
                width: parent.width - 65
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                text: body.displayValue
                color: body.node && body.node.typeId === "demo.result"
                       ? window.appTheme.colors.successText : window.appTheme.colors.highlightText
                font.pixelSize: 14
                font.bold: true
            }
            Text {
                x: 9
                y: 33
                visible: body.expanded
                text: qsTr("将 A 和 B 相加")
                color: window.appTheme.colors.subtleText
                font.pixelSize: 12
            }
            MouseArea {
                objectName: "toggle-node-details"
                anchors.fill: parent
                enabled: body.expandable || (body.editable && !editor.connecting)
                propagateComposedEvents: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (body.expandable)
                        body.expanded = !body.expanded
                    mouse.accepted = false
                }
                onDoubleClicked: {
                    if (body.editable)
                        body.editing = true
                    else
                        mouse.accepted = false
                }
            }

            Loader {
                anchors.fill: parent
                active: body.editing
                sourceComponent: body.choosingOption ? optionEditor : textEditor
                onLoaded: {
                    item.forceActiveFocus()
                    if (body.choosingOption)
                        item.popup.open()
                    else
                        item.selectAll()
                }
            }

            Component {
                id: textEditor

                Base.AppTextField {
                    objectName: "inlineConstantValue"
                    text: body.node ? String(body.node.parameters.value) : ""
                    onAccepted: {
                        if (body.node && demoGraph.setConstantInput(body.node.id, text))
                            body.editing = false
                    }
                    Keys.onEscapePressed: body.editing = false
                    onActiveFocusChanged: {
                        if (!activeFocus)
                            body.editing = false
                    }
                }
            }

            Component {
                id: optionEditor

                Base.AppSelect {
                    id: inlineSelect
                    objectName: "inlineConstantOptions"
                    options: body.isBoolConstant ? window.boolOptions : demoGraph.constantOptions
                    value: body.node ? body.node.parameters.value : undefined
                    onValueSelected: {
                        if (!body.node)
                            return
                        if (body.isBoolConstant)
                            demoGraph.session.setParameter(body.node.id, "value", nextValue)
                        else
                            demoGraph.setConstantInput(body.node.id, nextValue)
                    }

                    Connections {
                        target: inlineSelect.popup
                        function onClosed() { body.editing = false }
                    }
                }
            }
        }
    }
    Component {
        id: comparisonBody

        Rectangle {
            id: comparison
            property var node: null
            implicitHeight: comparisonOperator.implicitHeight + 38
            radius: 5
            color: window.appTheme.colors.backgroundWindow

            Base.AppSelect {
                id: comparisonOperator
                objectName: "comparisonOperator"
                width: parent.width
                options: [
                    {label: ">", value: "gt"},
                    {label: "≥", value: "ge"},
                    {label: "<", value: "lt"},
                    {label: "≤", value: "le"},
                    {label: "==", value: "eq"},
                    {label: "!=", value: "ne"}
                ]
                value: comparison.node ? comparison.node.parameters.operator : undefined
                onValueSelected: if (comparison.node)
                    demoGraph.session.setParameter(comparison.node.id, "operator", nextValue)
            }
            Text {
                x: 9
                anchors.top: comparisonOperator.bottom
                anchors.topMargin: 7
                text: qsTr("值")
                color: window.appTheme.colors.subtleText
                font.pixelSize: 12
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 9
                anchors.top: comparisonOperator.bottom
                anchors.topMargin: 6
                width: parent.width - 65
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                text: comparison.node ? demoGraph.previewValues[comparison.node.id] || "—" : "—"
                color: window.appTheme.colors.highlightText
                font.pixelSize: 14
                font.bold: true
            }
        }
    }
    Component {
        id: speakerBody

        Rectangle {
            id: speaker

            property var node: null
            property var liveState: ({})
            readonly property bool existing: node && node.typeId === "demo.speakerReference"
            readonly property string targetId: node ? (existing ? node.parameters.objectId : "node:" + node.typeId + ":" + node.id) : ""
            readonly property bool available: liveState.playing !== undefined
            readonly property bool playing: liveState.playing === true
            property point durationDrop
            property string writableMember
            property string writableLabel
            objectName: "speakerBody"
            implicitHeight: speakerControls.implicitHeight + 16
            radius: 5
            color: playing ? window.appTheme.colors.successSoft : window.appTheme.colors.backgroundWindow
            onTargetIdChanged: liveState = targetId ? demoGraph.speakerState(targetId) : ({})

            function createOperation(typeId, member, position) {
                if (available) {
                    var id = demoGraph.addOperation(typeId, targetId, member, position)
                    if (id)
                        editor.selectedNodeId = id
                }
            }

            Connections {
                target: demoGraph

                function onSpeakerStateChanged(targetId) {
                    if (speaker.targetId === targetId)
                        speaker.liveState = demoGraph.speakerState(targetId)
                }

                function onSpeakerNodesChanged() {
                    speaker.liveState = speaker.targetId ? demoGraph.speakerState(speaker.targetId) : ({})
                }
            }

            ColumnLayout {
                id: speakerControls

                anchors.fill: parent
                anchors.margins: 8
                spacing: 7

                Text {
                    Layout.fillWidth: true
                    text: {
                        if (!speaker.targetId)
                            return ""
                        if (!speaker.existing)
                            return qsTr("音箱 · %1").arg(speaker.node.id.slice(0, 8))
                        var option = demoGraph.existingSpeakerOptions.find(
                            function(item) { return item.value === speaker.targetId })
                        return option ? option.label : qsTr("对象已失效")
                    }
                    color: window.appTheme.colors.subtleText
                    font.pixelSize: 11
                }

                Repeater {
                    model: demoGraph.objectMembers(speaker.targetId)

                    delegate: Text {
                        Layout.fillWidth: true
                        text: (modelData.key === "playing" ? (!speaker.available ? "—" : speaker.playing ? qsTr("播放中") : qsTr("空闲"))
                               : modelData.key === "testDurationMs" ? qsTr("时长 %1 ms").arg(speaker.liveState.testDurationMs || "—")
                               : modelData.label) + (modelData.type === "demo.readProperty" && !modelData.writable ? qsTr("（只读）") : "") + "  ↗"
                        color: memberDrag.pressed || memberDrag.containsMouse ? window.appTheme.colors.highlightText
                               : modelData.key === "playing" && speaker.playing ? window.appTheme.colors.successText
                               : window.appTheme.colors.subtleText
                        font.pixelSize: 12

                        Quick.NodeDragSource {
                            id: memberDrag
                            objectName: "drag-" + modelData.key
                            anchors.fill: parent
                            enabled: speaker.available
                            graphEditor: editor
                            title: modelData.writable ? qsTr("选择属性操作")
                                   : modelData.type === "demo.call" ? qsTr("调用接口") : qsTr("读取属性")
                            dropText: modelData.writable ? qsTr("释放选择操作") : qsTr("释放创建节点")
                            ToolTip.visible: containsMouse && !pressed
                            ToolTip.delay: 350
                            ToolTip.text: qsTr("拖到画布空白处创建节点")
                            onDropped: {
                                if (modelData.writable) {
                                    speaker.durationDrop = position
                                    speaker.writableMember = modelData.key
                                    speaker.writableLabel = modelData.label
                                    var release = mapToItem(editor, mouseX, mouseY)
                                    durationMenu.popup(release.x, release.y)
                                } else {
                                    speaker.createOperation(modelData.type, modelData.key, position)
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Base.AppButton {
                        objectName: "play-speaker"
                        Layout.fillWidth: true
                        size: UiStyle.ButtonSize.Small
                        text: qsTr("测试音")
                        enabled: speaker.available && !speaker.playing
                        onClicked: demoGraph.invokeSpeaker(speaker.targetId, "playTest")
                    }
                    Base.AppButton {
                        objectName: "stop-speaker"
                        size: UiStyle.ButtonSize.Small
                        text: qsTr("停止")
                        enabled: !!speaker.node && speaker.playing
                        onClicked: demoGraph.invokeSpeaker(speaker.targetId, "stop")
                    }
                }
            }

            Menu {
                id: durationMenu
                objectName: "durationDropMenu"
                parent: editor

                MenuItem {
                    text: qsTr("读取%1").arg(speaker.writableLabel)
                    onTriggered: speaker.createOperation("demo.readProperty", speaker.writableMember, speaker.durationDrop)
                }
                MenuItem {
                    objectName: "create-duration-setter"
                    text: qsTr("设置%1").arg(speaker.writableLabel)
                    onTriggered: speaker.createOperation("demo.setProperty", speaker.writableMember, speaker.durationDrop)
                }
            }
        }
    }

    Component {
        id: triggerBody

        Base.AppButton {
            property var node: null
            objectName: "run-flow"
            text: qsTr("运行")
            size: UiStyle.ButtonSize.Small
            enabled: !!node
            onClicked: demoGraph.run(node.id)
        }
    }

    Component {
        id: operationBody

        ColumnLayout {
            id: operation
            property var node: null
            readonly property bool reading: !!node && node.typeId === "demo.readProperty"
            readonly property string targetId: node ? node.parameters.target : ""
            readonly property var targets: reading ? demoGraph.readTargetOptions : demoGraph.speakerOptions
            readonly property var target: targets.find(function(item) { return item.value === operation.targetId })
            readonly property var members: reading ? (target ? demoGraph.readMembers(targetId) : [])
                                                  : node ? demoGraph.operationMembers(node.typeId, targetId) : []
            readonly property var member: node ? members.find(
                function(item) { return item.value === operation.node.parameters.member }) : undefined
            spacing: 3

            Text {
                Layout.fillWidth: true
                text: operation.target ? operation.target.label : operation.targetId ? qsTr("目标失效") : qsTr("选择目标对象")
                color: operation.target ? window.appTheme.colors.subtleText : window.appTheme.colors.dangerText
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: {
                    if (!operation.node)
                        return ""
                    if (!operation.member)
                        return operation.target && operation.reading ? qsTr("选择属性") : ""
                    var value = demoGraph.previewValues[operation.node.id]
                    return value === undefined ? operation.member.label : qsTr("%1 · %2").arg(operation.member.label).arg(value)
                }
                color: window.appTheme.colors.text
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 72
            color: window.appTheme.colors.backgroundSurface

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 19
                anchors.rightMargin: 16
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    color: window.appTheme.colors.highlightSoft
                    radius: 8
                    Text {
                        anchors.centerIn: parent
                        text: "◇"
                        font.pixelSize: 23
                        color: window.appTheme.colors.highlightText
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 5
                    spacing: 4
                    Text {
                        text: qsTr("蓝图编辑器")
                        font.pixelSize: 17
                        font.bold: true
                        color: window.appTheme.colors.text
                    }
                    Text {
                        Layout.fillWidth: true
                        text: (demoGraph.fileName || qsTr("未命名蓝图")) + (demoGraph.session.modified ? "  •" : "")
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        color: window.appTheme.colors.subtleText
                    }
                }

                Base.AppButton { text: qsTr("撤销"); enabled: demoGraph.session.canUndo; onClicked: demoGraph.session.undo() }
                Base.AppButton { text: qsTr("重做"); enabled: demoGraph.session.canRedo; onClicked: demoGraph.session.redo() }
                Base.AppButton { text: qsTr("适合画布"); onClicked: editor.fit() }
                Base.AppButton { text: qsTr("打开"); onClicked: window.requestOpen() }
                Base.AppButton {
                    text: qsTr("保存")
                    variant: UiStyle.ButtonVariant.Primary
                    onClicked: saveDialog.open()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: window.appTheme.colors.border }

        Quick.GraphEditor {
            id: editor
            objectName: "graphEditor"
            Layout.fillWidth: true
            Layout.fillHeight: true
            session: demoGraph.session
            colors: window.appTheme.colors
            nodeContents: ({
                "demo.constant": calculationBody,
                "demo.stringConstant": calculationBody,
                "demo.optionConstant": calculationBody,
                "demo.boolConstant": calculationBody,
                "demo.add": calculationBody,
                "demo.greater": calculationBody,
                "demo.less": calculationBody,
                "demo.equal": calculationBody,
                "demo.compare": comparisonBody,
                "demo.and": calculationBody,
                "demo.or": calculationBody,
                "demo.not": calculationBody,
                "demo.result": calculationBody,
                "demo.textResult": calculationBody,
                "demo.boolResult": calculationBody,
                "demo.speaker": speakerBody,
                "demo.speakerReference": speakerBody,
                "demo.trigger": triggerBody,
                "demo.readProperty": operationBody,
                "demo.setProperty": operationBody,
                "demo.call": operationBody
            })

            palettePanel: Component {
                ScrollView {
                    id: paletteView
                    objectName: "nodePalette"
                    implicitWidth: 174
                    clip: true
                    contentWidth: availableWidth
                    contentHeight: paletteColumn.implicitHeight + 30
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    background: Rectangle {
                        color: window.appTheme.colors.backgroundSurface
                        border.color: window.appTheme.colors.border
                    }

                    ColumnLayout {
                        id: paletteColumn
                        x: 15
                        y: 15
                        width: paletteView.availableWidth - 30
                        spacing: 8

                        Text {
                            Layout.bottomMargin: 4
                            text: qsTr("节点库")
                            font.pixelSize: 15
                            font.bold: true
                            color: window.appTheme.colors.text
                        }

                        Repeater {
                            model: demoGraph.palette
                            delegate: ColumnLayout {
                                id: categoryGroup
                                readonly property var category: modelData
                                property bool expanded: true
                                Layout.fillWidth: true
                                spacing: 6
                                objectName: "category-" + category.id

                                Text {
                                    Layout.fillWidth: true
                                    Layout.topMargin: index === 0 ? 0 : 8
                                    text: (categoryGroup.expanded ? "▾ " : "▸ ") + categoryGroup.category.title
                                    topPadding: 4
                                    bottomPadding: 4
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: window.appTheme.colors.subtleText

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: categoryGroup.expanded = !categoryGroup.expanded
                                    }
                                }

                                Repeater {
                                    model: categoryGroup.category.nodes
                                    delegate: Rectangle {
                                        id: paletteEntry
                                        readonly property bool placed: !!modelData.parameters
                                                                       && demoGraph.placedObjectIds.indexOf(modelData.parameters.objectId) !== -1
                                        visible: categoryGroup.expanded
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 52
                                        color: addArea.containsMouse ? window.appTheme.colors.highlightSoft
                                               : placed ? window.appTheme.colors.successSoft : window.appTheme.colors.backgroundSection
                                        border.color: addArea.containsMouse ? window.appTheme.colors.highlightText
                                                      : placed ? window.appTheme.colors.successText : window.appTheme.colors.border
                                        radius: 7

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 9
                                            spacing: 8
                                            Text {
                                                Layout.preferredWidth: 17
                                                text: paletteEntry.placed ? "✓" : modelData.symbol
                                                color: paletteEntry.placed ? window.appTheme.colors.successText : window.appTheme.colors.highlightText
                                                font.pixelSize: 17
                                                font.bold: true
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 3
                                                Text {
                                                    text: modelData.title
                                                    color: window.appTheme.colors.text
                                                    font.pixelSize: 13
                                                    font.bold: true
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: paletteEntry.placed ? qsTr("已放置 · 拖拽定位") : modelData.description
                                                    elide: Text.ElideRight
                                                    color: paletteEntry.placed ? window.appTheme.colors.successText : window.appTheme.colors.subtleText
                                                    font.pixelSize: 11
                                                }
                                            }
                                        }
                                        Quick.NodeDragSource {
                                            id: addArea
                                            objectName: "add-" + (modelData.parameters ? modelData.parameters.objectId : modelData.type)
                                            anchors.fill: parent
                                            graphEditor: editor
                                            title: modelData.title
                                            dropText: paletteEntry.placed ? qsTr("释放定位已有节点") : qsTr("释放创建节点")
                                            ToolTip.visible: containsMouse && !pressed
                                            ToolTip.delay: 350
                                            ToolTip.text: paletteEntry.placed ? qsTr("已放置，拖到画布空白处定位已有节点")
                                                                             : qsTr("拖到画布空白处创建节点")
                                            onDropped: editor.addNode(modelData.type, modelData.parameters, position)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            inspectorPanel: Component {
                Rectangle {
                    id: inspector
                    readonly property string selectedType: editor.selectedNode ? editor.selectedNode.typeId : ""
                    readonly property bool reading: !!editor.selectedNode && editor.selectedNode.typeId === "demo.readProperty"
                    readonly property var targets: reading ? demoGraph.readTargetOptions : demoGraph.speakerOptions
                    readonly property string targetId: editor.selectedNode ? editor.selectedNode.parameters.target || "" : ""
                    readonly property bool targetAvailable: targets.some(function(item) { return item.value === inspector.targetId })
                    readonly property var members: reading
                        ? (targetAvailable ? demoGraph.readMembers(targetId) : [])
                        : demoGraph.operationMembers(selectedType, targetId)
                    readonly property bool propertyWritable: selectedType === "demo.setProperty" && targetAvailable
                        && members.some(function(item) { return editor.selectedNode && item.value === editor.selectedNode.parameters.member })
                    implicitWidth: 226
                    color: window.appTheme.colors.backgroundSurface
                    border.color: window.appTheme.colors.border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 11

                        Text {
                            text: qsTr("节点属性")
                            color: window.appTheme.colors.text
                            font.pixelSize: 15
                            font.bold: true
                        }
                        Text {
                            visible: !editor.selectedNode
                            text: qsTr("选择节点查看属性")
                            color: window.appTheme.colors.subtleText
                            font.pixelSize: 13
                        }
                        Rectangle {
                            visible: !!editor.selectedNode
                            Layout.fillWidth: true
                            Layout.preferredHeight: 77
                            radius: 7
                            color: window.appTheme.colors.backgroundSection

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 11
                                spacing: 3
                                Text {
                                    text: editor.selectedNode ? editor.selectedNode.title : ""
                                    color: window.appTheme.colors.text
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Text {
                                    objectName: "selectedPreview"
                                    text: editor.selectedNode ? demoGraph.previewValues[editor.selectedNode.id] || "—" : ""
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    color: window.appTheme.colors.highlightText
                                    font.pixelSize: 22
                                }
                            }
                        }

                        ColumnLayout {
                            visible: inspector.selectedType === "demo.constant" || inspector.selectedType === "demo.stringConstant"
                            Layout.fillWidth: true
                            spacing: 7
                            Text {
                                text: qsTr("常量值")
                                color: window.appTheme.colors.subtleText
                                font.pixelSize: 12
                            }
                            Base.AppTextField {
                                id: constantField
                                objectName: "constantValue"
                                Layout.fillWidth: true
                                text: editor.selectedNode && editor.selectedNode.parameters.value !== undefined
                                      ? String(editor.selectedNode.parameters.value) : ""
                                onAccepted: if (editor.selectedNode) demoGraph.setConstantInput(editor.selectedNode.id, text)
                            }
                            Base.AppButton {
                                text: qsTr("应用")
                                Layout.fillWidth: true
                                onClicked: if (editor.selectedNode) demoGraph.setConstantInput(editor.selectedNode.id, constantField.text)
                            }
                        }

                        ColumnLayout {
                            visible: inspector.selectedType === "demo.optionConstant" || inspector.selectedType === "demo.boolConstant"
                            Layout.fillWidth: true
                            spacing: 7

                            Text {
                                text: qsTr("常量值")
                                color: window.appTheme.colors.subtleText
                                font.pixelSize: 12
                            }
                            Base.AppSelect {
                                objectName: "constantOptions"
                                Layout.fillWidth: true
                                options: inspector.selectedType === "demo.boolConstant" ? window.boolOptions : demoGraph.constantOptions
                                value: parent.visible && editor.selectedNode ? editor.selectedNode.parameters.value : undefined
                                onValueSelected: {
                                    if (!editor.selectedNode)
                                        return
                                    if (inspector.selectedType === "demo.boolConstant")
                                        demoGraph.session.setParameter(editor.selectedNode.id, "value", nextValue)
                                    else
                                        demoGraph.setConstantInput(editor.selectedNode.id, nextValue)
                                }
                            }
                        }

                        Base.AppSelect {
                            objectName: "objectCardTarget"
                            visible: inspector.selectedType === "demo.speakerReference"
                            Layout.fillWidth: true
                            placeholderText: qsTr("选择对象")
                            options: demoGraph.existingSpeakerOptions
                            value: visible ? editor.selectedNode.parameters.objectId : undefined
                            onValueSelected: if (editor.selectedNodeId)
                                demoGraph.session.setParameter(editor.selectedNodeId, "objectId", nextValue)
                        }

                        ColumnLayout {
                            visible: inspector.reading || inspector.selectedType === "demo.setProperty" || inspector.selectedType === "demo.call"
                            Layout.fillWidth: true
                            spacing: 7

                            Base.AppSelect {
                                objectName: "operationTarget"
                                Layout.fillWidth: true
                                placeholderText: qsTr("选择目标对象")
                                options: inspector.targets
                                value: inspector.targetId
                                onValueSelected: {
                                    if (!editor.selectedNode)
                                        return
                                    if (inspector.reading) {
                                        var current = editor.selectedNode.parameters.member
                                        var sameMember = demoGraph.readMembers(nextValue).some(
                                            function(item) { return item.value === current })
                                        demoGraph.bindRead(editor.selectedNodeId, nextValue, sameMember ? current : "")
                                    } else {
                                        demoGraph.session.setParameter(editor.selectedNodeId, "target", nextValue)
                                    }
                                }
                            }
                            Base.AppSelect {
                                objectName: "operationMember"
                                Layout.fillWidth: true
                                placeholderText: qsTr("选择属性或接口")
                                options: inspector.members
                                enabled: inspector.targetAvailable && inspector.members.length > 0
                                value: editor.selectedNode ? editor.selectedNode.parameters.member : undefined
                                onValueSelected: {
                                    if (!editor.selectedNode)
                                        return
                                    if (inspector.reading)
                                        demoGraph.bindRead(editor.selectedNodeId, inspector.targetId, nextValue)
                                    else
                                        demoGraph.session.setParameter(editor.selectedNodeId, "member", nextValue)
                                }
                            }
                            Text {
                                visible: inspector.selectedType === "demo.setProperty"
                                text: inspector.propertyWritable ? qsTr("未连线时使用此值（毫秒）") : qsTr("请选择可写属性后设置")
                                color: window.appTheme.colors.subtleText
                                font.pixelSize: 12
                            }
                            Base.AppTextField {
                                id: durationField
                                objectName: "operationDuration"
                                visible: inspector.selectedType === "demo.setProperty"
                                enabled: inspector.propertyWritable
                                Layout.fillWidth: true
                                text: visible && editor.selectedNode ? String(editor.selectedNode.parameters.value) : ""
                                onAccepted: if (editor.selectedNodeId)
                                    demoGraph.setDurationInput(editor.selectedNodeId, text)
                            }
                            Base.AppButton {
                                visible: inspector.selectedType === "demo.setProperty"
                                enabled: inspector.propertyWritable
                                Layout.fillWidth: true
                                text: qsTr("应用输入值")
                                onClicked: if (editor.selectedNodeId)
                                    demoGraph.setDurationInput(editor.selectedNodeId, durationField.text)
                            }
                        }

                        Base.AppButton {
                            visible: !!editor.selectedNode
                            Layout.fillWidth: true
                            text: qsTr("删除节点")
                            variant: UiStyle.ButtonVariant.Danger
                            onClicked: if (editor.selectedNodeId) demoGraph.session.removeNode(editor.selectedNodeId)
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: window.appTheme.colors.border }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            color: window.appTheme.colors.backgroundSurface

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                spacing: 16
                Text {
                    text: qsTr("%1 个节点   %2 条连线").arg(editor.nodeCount).arg(editor.connectionCount)
                    color: window.appTheme.colors.subtleText
                    font.pixelSize: 12
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: window.graphError || window.notice || (editor.connecting
                          ? qsTr("选择输入端口连接，按 Esc 取消")
                          : editor.selectedConnectionId ? qsTr("已选中连线，按 Delete 删除")
                          : qsTr("双击常量值编辑 · 拖动标题移动节点 · 滚轮缩放 · 右键连线或已连接的输入端口可删除"))
                    color: window.graphError ? window.appTheme.colors.dangerText : window.appTheme.colors.subtleText
                    font.pixelSize: 12
                }
                Text {
                    text: Math.round(editor.zoom * 100) + "%"
                    color: window.appTheme.colors.subtleText
                    font.pixelSize: 12
                }
            }
        }
    }
}
