import QtQuick 2.14
import QtQuick.Window 2.14
import QtQuick.Layouts 1.14
import QtQuick.Controls 2.14
import "internal" as Internal

Item {
    id: editor

    property var session: null
    property QtObject colors
    // 内容组件根项声明 node 属性并通过 implicitHeight 提供高度。
    property var nodeContents: ({})
    // 标题组件同样接收 node，拖动由节点外壳处理。
    property var nodeHeaders: ({})
    // 返回空字符串时使用端口的原名称。
    property var inputPortLabel: null
    property var nodeStates: ({})
    property Component palettePanel: defaultPalette
    property Component inspectorPanel: defaultInspector
    property alias nodeColors: canvas.nodeColors
    property alias selectedNodeId: canvas.selectedNodeId
    readonly property string selectedConnectionId: canvas.selectedConnectionId
    readonly property var selectedNode: canvas.selectedNode
    readonly property int nodeCount: canvas.nodeCount
    readonly property int connectionCount: canvas.links.length
    readonly property real zoom: canvas.zoom
    readonly property bool connecting: canvas.pendingNode !== ""

    // 取消当前手势，预览和拖动源在释放后不再提交。
    signal interactionCanceled()

    Connections {
        target: editor.Window.window
        function onActiveChanged() {
            if (!editor.Window.window.active)
                editor.interactionCanceled()
        }
    }

    // 参数和画布坐标可选，支持直接放置已绑定对象。
    function addNode(typeId, parameters, position) { canvas.addNode(typeId, parameters, position) }
    function fit() { canvas.fit() }
    // 扩展内容可将释放位置转换成画布坐标，只接受空白区域。
    function emptyDropPosition(source, x, y) { return canvas.emptyDropPosition(source, x, y) }

    Component {
        id: defaultPalette
        Rectangle {
            implicitWidth: 190
            color: editor.colors ? editor.colors.backgroundSurface : "transparent"
            ListView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                model: editor.session ? editor.session.nodeTypes : []
                delegate: Button {
                    id: paletteButton
                    readonly property var typeColors: editor.nodeColors ? editor.nodeColors[modelData.typeId] : null
                    width: ListView.view.width
                    leftPadding: typeColors ? 20 : padding
                    text: modelData.title
                    onClicked: editor.addNode(modelData.typeId)
                    ToolTip.visible: hovered && modelData.description !== ""
                    ToolTip.text: modelData.description

                    Rectangle {
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 14
                        radius: 2
                        visible: !!paletteButton.typeColors
                        color: paletteButton.typeColors ? paletteButton.typeColors.background : "transparent"
                        border.color: paletteButton.typeColors ? paletteButton.typeColors.accent : "transparent"
                    }
                }
            }
        }
    }

    Component {
        id: defaultInspector
        Rectangle {
            id: inspector
            implicitWidth: 230
            color: editor.colors ? editor.colors.backgroundSurface : "transparent"
            readonly property var node: editor.selectedNode
            readonly property string nodeId: node ? node.id : ""
            readonly property string error: editor.session ? editor.session.error : ""
            property string errorKey: ""
            onNodeIdChanged: errorKey = ""
            onErrorChanged: errorKey = ""
            readonly property var definition: {
                var types = editor.session ? editor.session.nodeTypes : []
                for (var i = 0; i < types.length; ++i) {
                    if (node && types[i].typeId === node.typeId)
                        return types[i]
                }
                return null
            }
            Flickable {
                anchors.fill: parent
                anchors.margins: 12
                clip: true
                contentHeight: fields.implicitHeight
                ColumnLayout {
                    id: fields
                    width: parent.width
                    spacing: 8
                    Label {
                        Layout.fillWidth: true
                        text: inspector.node ? inspector.node.title : qsTr("选择节点")
                        wrapMode: Text.Wrap
                        color: editor.colors ? editor.colors.text : "black"
                    }
                    Repeater {
                        model: inspector.definition ? inspector.definition.parameters : []
                        delegate: ColumnLayout {
                            id: field
                            Layout.fillWidth: true
                            property var parameter: modelData
                            readonly property var value: inspector.node
                                ? inspector.node.parameters[parameter.key] : undefined
                            function submitValue(value) {
                                if (editor.session.setParameter(inspector.nodeId, parameter.key, value))
                                    return true
                                inspector.errorKey = parameter.key
                                return false
                            }

                            Label {
                                text: field.parameter.title
                                color: editor.colors ? editor.colors.subtleText : "black"
                            }
                            Loader {
                                Layout.fillWidth: true
                                sourceComponent: field.parameter.valueTypeId === "bool" ? booleanField
                                    : field.parameter.allowedValues.length ? optionField : textField
                                Component {
                                    id: booleanField
                                    CheckBox {
                                        checked: !!field.value
                                        onClicked: {
                                            if (!field.submitValue(checked))
                                                checked = Qt.binding(function() { return !!field.value })
                                        }
                                    }
                                }
                                Component {
                                    id: optionField
                                    ComboBox {
                                        id: option
                                        model: field.parameter.allowedValues
                                        currentIndex: model.indexOf(field.value)
                                        onActivated: {
                                            if (!field.submitValue(model[index]))
                                                currentIndex = Qt.binding(function() { return option.model.indexOf(field.value) })
                                        }
                                    }
                                }
                                Component {
                                    id: textField
                                    TextField {
                                        readonly property string committedText: field.value === undefined || field.value === null
                                            ? "" : String(field.value)
                                        text: committedText
                                        selectByMouse: true
                                        property bool edited: false
                                        property string editedNodeId
                                        property string editedKey
                                        onTextEdited: {
                                            edited = true
                                            editedNodeId = inspector.node.id
                                            editedKey = field.parameter.key
                                        }
                                        onEditingFinished: {
                                            if (!edited)
                                                return
                                            edited = false
                                            if (!inspector.node || inspector.node.id !== editedNodeId || field.parameter.key !== editedKey)
                                                return
                                            var value = field.parameter.valueTypeId === "number"
                                                ? (text.trim() === "" ? NaN : Number(text)) : text
                                            if (!field.submitValue(value))
                                                text = Qt.binding(function() { return committedText })
                                        }
                                    }
                                }
                            }
                            Label {
                                Layout.fillWidth: true
                                text: field.parameter.key === inspector.errorKey ? inspector.error : ""
                                visible: text !== ""
                                wrapMode: Text.Wrap
                                color: editor.colors ? editor.colors.dangerText : palette.text
                            }
                            Button {
                                text: qsTr("恢复默认")
                                onClicked: {
                                    if (!editor.session.resetParameter(inspector.nodeId, field.parameter.key))
                                        inspector.errorKey = field.parameter.key
                                }
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: inspector.error
                        visible: text !== "" && !inspector.errorKey
                        wrapMode: Text.Wrap
                        color: editor.colors ? editor.colors.text : "black"
                    }
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Loader {
            sourceComponent: editor.palettePanel
            visible: !!sourceComponent
            Layout.fillHeight: true
            Layout.preferredWidth: item ? item.implicitWidth : 0
        }

        Internal.GraphCanvas {
            id: canvas
            objectName: "graphCanvas"
            Layout.fillWidth: true
            Layout.fillHeight: true
            interactionHost: editor
            session: editor.session
            colors: editor.colors
            nodeContents: editor.nodeContents
            nodeHeaders: editor.nodeHeaders
            nodeStates: editor.nodeStates
        }

        Loader {
            sourceComponent: editor.inspectorPanel
            visible: !!sourceComponent
            Layout.fillHeight: true
            Layout.preferredWidth: item ? item.implicitWidth : 0
        }
    }
}
