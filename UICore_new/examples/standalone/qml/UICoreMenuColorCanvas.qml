import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base

Base.AppSurface {
    id: root

    readonly property QtObject colors: ApplicationWindow.window.appTheme.colors
    readonly property QtObject density: ApplicationWindow.window.appTheme.density

    sizeToContent: false
    surfaceTone: UiStyle.SurfaceTone.Ghost
    shapeRole: UiStyle.ShapeRole.None
    fillOverride: ApplicationWindow.window.menuColorCanvasTone === "white"
        ? "#ffffff"
        : "#000000"

    Base.AppSurface {
        id: wd

        anchors.fill: parent
        anchors.margins: root.density.pageMargin
        sizeToContent: false
        surfaceTone: UiStyle.SurfaceTone.Window

        Base.AppSurface {
            id: windowVariant

            anchors.left: parent.left
            anchors.top: parent.top
            width: parent.width / 2
            height: root.density.controlHeightLg + root.density.panePadding
            sizeToContent: false
            surfaceTone: UiStyle.SurfaceTone.Window
            fillOverride: root.colors.backgroundWindowVariant

            Base.AppText {
                anchors.left: parent.left
                anchors.leftMargin: root.density.panePadding
                anchors.verticalCenter: parent.verticalCenter
                text: "backgroundWindowVariant"
                styleRole: UiStyle.TypographyRole.Label
            }
        }

        Base.AppText {
            anchors.right: parent.right
            anchors.rightMargin: root.density.panePadding
            anchors.verticalCenter: windowVariant.verticalCenter
            text: "backgroundWindow"
            styleRole: UiStyle.TypographyRole.BodyS
            textTone: UiStyle.TextTone.Secondary
        }

        Base.AppSurface {
            id: lbar

            anchors.left: parent.left
            anchors.top: windowVariant.bottom
            anchors.bottom: parent.bottom
            anchors.margins: root.density.panePadding
            width: wd.width / 5
            sizeToContent: false
            surfaceTone: UiStyle.SurfaceTone.Surface

            Base.AppText {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: root.density.panePaddingCompact
                text: "backgroundSurface"
                styleRole: UiStyle.TypographyRole.Label
            }

            Base.AppSurface {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: root.density.panePaddingCompact
                height: parent.height / 3
                sizeToContent: false
                surfaceTone: UiStyle.SurfaceTone.SurfaceOverlay

                Base.AppText {
                    anchors.centerIn: parent
                    text: "backgroundSurfaceOverlay"
                    styleRole: UiStyle.TypographyRole.BodyS
                    wrapMode: Text.Wrap
                }
            }
        }

        Base.AppSurface {
            id: mainLevel1

            anchors.left: lbar.right
            anchors.right: parent.right
            anchors.top: windowVariant.bottom
            anchors.bottom: parent.bottom
            anchors.margins: root.density.panePadding
            anchors.leftMargin: 0
            sizeToContent: false
            surfaceTone: UiStyle.SurfaceTone.Canvas

            Base.AppText {
                id: canvasLabel

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: root.density.panePadding
                text: "backgroundCanvas"
                styleRole: UiStyle.TypographyRole.Label
            }

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: canvasLabel.bottom
                anchors.bottom: parent.bottom
                anchors.margins: root.density.panePadding
                spacing: root.density.paneSpacing

                Base.AppSurface {
                    id: mainLevel2

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 2
                    sizeToContent: false
                    surfaceTone: UiStyle.SurfaceTone.Surface

                    Base.AppText {
                        id: surfaceLabel

                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: root.density.panePaddingCompact
                        text: "backgroundSurface"
                        styleRole: UiStyle.TypographyRole.Label
                    }

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: surfaceLabel.bottom
                        anchors.bottom: parent.bottom
                        anchors.margins: root.density.panePaddingCompact
                        spacing: root.density.paneSpacing

                        Repeater {
                            model: [{
                                "label": "backgroundSection",
                                "tone": UiStyle.SurfaceTone.Section
                            }, {
                                "label": "backgroundControl",
                                "tone": UiStyle.SurfaceTone.Control
                            }, {
                                "label": "backgroundSectionOverlay",
                                "tone": UiStyle.SurfaceTone.SectionOverlay
                            }]

                            Base.AppSurface {
                                id: mainLevel3

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredHeight: 1
                                sizeToContent: false
                                surfaceTone: modelData.tone

                                Base.AppText {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    styleRole: UiStyle.TypographyRole.BodyS
                                }
                            }
                        }
                    }
                }

                Base.AppSurface {
                    id: dialogLevel1

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    sizeToContent: false
                    surfaceTone: UiStyle.SurfaceTone.Popup

                    Base.AppText {
                        id: popupLabel

                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: root.density.panePaddingCompact
                        text: "backgroundPopup"
                        styleRole: UiStyle.TypographyRole.Label
                    }

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: popupLabel.bottom
                        anchors.bottom: parent.bottom
                        anchors.margins: root.density.panePaddingCompact
                        spacing: root.density.paneSpacing

                        Repeater {
                            model: [qsTr("参数区"), qsTr("结果区")]

                            Base.AppSurface {
                                id: dialogLevel2

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredHeight: 1
                                sizeToContent: false
                                surfaceTone: UiStyle.SurfaceTone.DialogSection

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: root.density.panePaddingCompact
                                    spacing: root.density.controlGap

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: modelData + " · DialogSection"
                                        styleRole: UiStyle.TypographyRole.BodyS
                                        wrapMode: Text.Wrap
                                    }

                                    Base.AppTextField {
                                        Layout.fillWidth: true
                                        placeholderText: qsTr("三级输入控件 · Control + controlBorder")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
