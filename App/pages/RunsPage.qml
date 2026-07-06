import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UiCore/qml/components/base" as Base
import "qrc:/UiCore/qml/theme" as Theme

Item {
    id: root

    focus: true
    Theme.AppTheme {
        id: fallbackTheme
    }

    property QtObject pageTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : fallbackTheme
    readonly property int pageMargin: pageTheme && pageTheme.density ? pageTheme.density.pageMargin : 20

    readonly property var runRows: [
        { "name": "当前运行", "time": "00:14.000", "state": "已就绪" },
        { "name": "彩排 A", "time": "02:18.420", "state": "已完成" },
        { "name": "设备同步", "time": "00:31.120", "state": "已完成" },
        { "name": "试运行", "time": "01:02.000", "state": "已取消" }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: root.pageMargin
        anchors.rightMargin: root.pageMargin
        anchors.topMargin: root.pageMargin
        anchors.bottomMargin: root.pageMargin
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Base.AppText {
                text: qsTr("运行记录")
                theme: root.pageTheme
                styleRole: "titleL"
            }

            Item {
                Layout.fillWidth: true
            }

            Base.AppButton {
                text: qsTr("导出")
                theme: root.pageTheme
                iconName: "background-task"
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            columnSpacing: 14
            rowSpacing: 14

            Base.AppSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 520
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Base.AppText {
                        text: qsTr("执行历史")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    Repeater {
                        model: root.runRows

                        delegate: Base.AppSurface {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            sizeToContent: false
                            theme: root.pageTheme
                            surfaceTone: index === 0 ? "highlight" : "surface"
                            strokeWidth: index === 0 ? 0 : 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        theme: root.pageTheme
                                        styleRole: "bodyM"
                                        elide: Text.ElideRight
                                    }

                                    Base.AppText {
                                        Layout.fillWidth: true
                                        text: modelData.time
                                        theme: root.pageTheme
                                        styleRole: "bodyS"
                                        textTone: "secondary"
                                    }
                                }

                                Base.AppText {
                                    Layout.preferredWidth: 78
                                    text: modelData.state
                                    theme: root.pageTheme
                                    styleRole: "bodyS"
                                    textTone: index === 0 ? "accent" : "secondary"
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }

            Base.AppSurface {
                Layout.preferredWidth: 340
                Layout.fillHeight: true
                sizeToContent: false
                theme: root.pageTheme
                surfaceTone: "section"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    Base.AppText {
                        text: qsTr("实时状态")
                        theme: root.pageTheme
                        styleRole: "sectionTitle"
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 76
                        sizeToContent: false
                        theme: root.pageTheme
                        surfaceTone: "surface"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            Base.AppText {
                                text: qsTr("时钟")
                                theme: root.pageTheme
                                styleRole: "bodyS"
                                textTone: "secondary"
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: qsTr("00:14.000")
                                theme: root.pageTheme
                                styleRole: "titleM"
                                textTone: "accent"
                            }
                        }
                    }

                    Base.AppSurface {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        sizeToContent: false
                        theme: root.pageTheme
                        surfaceTone: "surface"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            Base.AppText {
                                text: qsTr("下一条指令")
                                theme: root.pageTheme
                                styleRole: "bodyS"
                                textTone: "secondary"
                            }

                            Base.AppText {
                                Layout.fillWidth: true
                                text: qsTr("音频指令")
                                theme: root.pageTheme
                                styleRole: "bodyM"
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
        }
    }
}
