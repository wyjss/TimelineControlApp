import QtQuick 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base

Item {
    id: root

    property var blockData: ({})
    property QtObject blockController: null
    property int selectedLayerIndex: 0
    property string selectedLayerName: qsTr("全球影像")
    property string selectedLayerType: qsTr("影像")
    property string selectedLayerLod: qsTr("渲染 0–18 · 数据 0–18")
    property string selectedLayerProfile: "WebMercator"
    property string selectedLayerStyle: ""

    readonly property string currentViewName: qsTr("三维视图")
    readonly property string currentMapName: qsTr("城市基础地图")
    readonly property var layerItems: [{
        "name": qsTr("全球影像"),
        "typeText": qsTr("影像"),
        "lodText": qsTr("渲染 0–18 · 数据 0–18"),
        "priority": 100,
        "profileName": "WebMercator"
    }, {
        "name": qsTr("全球地形"),
        "typeText": qsTr("高程"),
        "lodText": qsTr("渲染 0–16 · 数据 0–16"),
        "priority": 90,
        "profileName": "WebMercator"
    }, {
        "name": qsTr("行政区划"),
        "typeText": qsTr("矢量"),
        "lodText": qsTr("渲染 2–16 · 数据 2–16"),
        "priority": 80,
        "styleName": qsTr("行政区划样式")
    }, {
        "name": qsTr("城市模型"),
        "typeText": qsTr("模型"),
        "lodText": qsTr("渲染 12–20 · 数据 12–20"),
        "priority": 70
    }]

    signal actionTriggered(string actionId, var payload)

    function valueOf(source, key, fallback) {
        return source && source[key] !== undefined && source[key] !== null
            ? source[key]
            : fallback
    }

    function selectLayer(layer, layerIndex) {
        if (!layer)
            return

        selectedLayerIndex = layerIndex
        selectedLayerName = valueOf(layer, "name", "")
        selectedLayerType = valueOf(layer, "typeText", "")
        selectedLayerLod = valueOf(layer, "lodText", "")
        selectedLayerProfile = valueOf(layer, "profileName", "")
        selectedLayerStyle = valueOf(layer, "styleName", "")
    }

    implicitHeight: contentColumn.implicitHeight

    ColumnLayout {
        id: contentColumn

        width: parent && parent.width > 0 ? parent.width : implicitWidth
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Base.AppText {
                Layout.fillWidth: true
                styleRole: UiStyle.TypographyRole.SectionTitle
                text: qsTr("当前地图")
            }

            Base.AppText {
                Layout.fillWidth: true
                styleRole: UiStyle.TypographyRole.BodyS
                textTone: UiStyle.TextTone.Secondary
                text: qsTr("查看地图图层并进入对应配置。")
                wrapMode: Text.WordWrap
            }
        }

        Base.AppSurface {
            Layout.fillWidth: true
            surfaceTone: UiStyle.SurfaceTone.Section
            shapeRole: UiStyle.ShapeRole.Section
            padding: 12
            strokeWidth: 1
            borderOverride: themeReady ? resolvedTheme.colors.borderOverlay : "transparent"
            constrainContentWidth: true

            ColumnLayout {
                width: parent && parent.width > 0 ? parent.width : implicitWidth
                spacing: 8

                Base.AppText {
                    Layout.fillWidth: true
                    styleRole: UiStyle.TypographyRole.BodyL
                    text: root.currentMapName
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }

                Base.AppText {
                    Layout.fillWidth: true
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    text: qsTr("视图 %1 · %2 个图层")
                        .arg(root.currentViewName)
                        .arg(root.layerItems ? root.layerItems.length : 0)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Base.AppButton {
                        Layout.fillWidth: true
                        text: qsTr("重新加载")
                        variant: UiStyle.ButtonVariant.Tonal
                        onClicked: root.actionTriggered("layers.reloadMap", {})
                    }

                    Base.AppButton {
                        Layout.fillWidth: true
                        text: qsTr("编辑地图")
                        variant: UiStyle.ButtonVariant.Tonal
                        onClicked: root.actionTriggered("layerconfig.openMapDescCreator", {
                            "mode": "edit",
                            "name": root.currentMapName
                        })
                    }
                }
            }
        }

        Base.AppSurface {
            id: layerModule

            Layout.fillWidth: true
            surfaceTone: UiStyle.SurfaceTone.Section
            shapeRole: UiStyle.ShapeRole.Section
            padding: 4
            strokeWidth: 1
            borderOverride: themeReady ? resolvedTheme.colors.borderOverlay : "transparent"
            constrainContentWidth: true

            ColumnLayout {
                id: layerColumn

                width: parent && parent.width > 0 ? parent.width : implicitWidth
                spacing: 0

                Repeater {
                    model: root.layerItems

                    delegate: ColumnLayout {
                        id: layerRow

                        readonly property var rowData: modelData
                        readonly property string layerName: String(root.valueOf(rowData, "name", ""))
                        readonly property int rowIndex: index

                        Layout.fillWidth: true
                        spacing: 0

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: layerCard.implicitHeight

                            Rectangle {
                                anchors.fill: parent
                                radius: layerModule.themeReady
                                    ? layerModule.resolvedTheme.shape.controlRadius
                                    : 0
                                color: layerModule.themeReady
                                    ? layerModule.resolvedTheme.colors.inverseText
                                    : "transparent"
                                opacity: layerCard.checked ? 0.05 : 0
                            }

                            Base.AppCard {
                                id: layerCard

                                anchors.fill: parent
                                checkable: true
                                checked: layerRow.rowIndex === root.selectedLayerIndex
                                surfaceTone: UiStyle.SurfaceTone.Ghost
                                emphasizedSelection: false
                                animateScale: false
                                compact: true
                                shapeRole: UiStyle.ShapeRole.Control
                                onClicked: root.selectLayer(layerRow.rowData, layerRow.rowIndex)

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: 3
                                        Layout.preferredHeight: 28
                                        radius: width / 2
                                        color: layerModule.themeReady
                                            ? layerModule.resolvedTheme.colors.highlightText
                                            : "transparent"
                                        opacity: layerCard.checked ? 1 : 0
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Base.AppText {
                                            Layout.fillWidth: true
                                            styleRole: UiStyle.TypographyRole.BodyM
                                            textTone: UiStyle.TextTone.Primary
                                            text: layerRow.layerName
                                            elide: Text.ElideRight
                                        }

                                        Base.AppText {
                                            Layout.fillWidth: true
                                            styleRole: UiStyle.TypographyRole.BodyS
                                            textTone: UiStyle.TextTone.Secondary
                                            text: root.valueOf(layerRow.rowData, "typeText", "")
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Base.AppText {
                                        styleRole: UiStyle.TypographyRole.BodyS
                                        textTone: UiStyle.TextTone.Secondary
                                        text: qsTr("P%1")
                                            .arg(root.valueOf(layerRow.rowData, "priority", ""))
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            Layout.preferredHeight: visible ? 1 : 0
                            visible: layerRow.rowIndex < root.layerItems.length - 1
                            color: layerModule.themeReady
                                ? layerModule.resolvedTheme.colors.borderOverlay
                                : "transparent"
                        }
                    }
                }
            }
        }

        Base.AppSurface {
            Layout.fillWidth: true
            surfaceTone: UiStyle.SurfaceTone.Section
            shapeRole: UiStyle.ShapeRole.Section
            padding: 12
            strokeWidth: 1
            borderOverride: themeReady ? resolvedTheme.colors.borderOverlay : "transparent"
            constrainContentWidth: true

            ColumnLayout {
                width: parent && parent.width > 0 ? parent.width : implicitWidth
                spacing: 8

                Base.AppText {
                    Layout.fillWidth: true
                    styleRole: UiStyle.TypographyRole.BodyL
                    text: root.selectedLayerName
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }

                Base.AppText {
                    Layout.fillWidth: true
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    text: root.selectedLayerType
                }

                Base.AppText {
                    Layout.fillWidth: true
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    text: root.selectedLayerLod
                }

                Base.AppText {
                    Layout.fillWidth: true
                    visible: root.selectedLayerProfile.length > 0
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    text: qsTr("Profile：%1").arg(root.selectedLayerProfile)
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }

                Base.AppText {
                    Layout.fillWidth: true
                    visible: root.selectedLayerStyle.length > 0
                    styleRole: UiStyle.TypographyRole.BodyS
                    textTone: UiStyle.TextTone.Secondary
                    text: qsTr("样式：%1").arg(root.selectedLayerStyle)
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Base.AppButton {
                        Layout.fillWidth: true
                        text: qsTr("编辑图层")
                        variant: UiStyle.ButtonVariant.Tonal
                        onClicked: root.actionTriggered("layerconfig.openLayerDescCreator", {
                            "mode": "edit",
                            "name": root.selectedLayerName
                        })
                    }

                    Base.AppButton {
                        Layout.fillWidth: true
                        enabled: root.selectedLayerStyle.length > 0
                        text: qsTr("编辑样式")
                        variant: UiStyle.ButtonVariant.Tonal
                        onClicked: root.actionTriggered("layerconfig.openFeatureStyleEditor", {
                            "mode": "edit",
                            "name": root.selectedLayerStyle
                        })
                    }
                }

                Base.AppButton {
                    Layout.fillWidth: true
                    text: qsTr("打开瓦片导出器")
                    variant: UiStyle.ButtonVariant.Tonal
                    onClicked: root.actionTriggered("layers.openTileExporter", {
                        "mapName": root.currentMapName,
                        "layerName": root.selectedLayerName
                    })
                }
            }
        }
    }
}
