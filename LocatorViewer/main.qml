import QtQuick 2.14
import QtQuick.Window 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtGraphicalEffects 1.14

import ragis.quick 1.0
//import ribbon 1.0
import Ribbon 1.0
//import "qrc:/qml"
RibbonWindow {
    id: root
    width: 1140
    height: 800
    visible: true
    title: qsTr("Hello World")

    footer: RowLayout{
        height: 30
        RowLayout{
            Text {
                text: qsTr("vp center")
            }
            Text {
                text: "[" + app.vpCenterStr + "]"
            }

            Text {
                text: qsTr("vp hpd")
            }

            Text {
                text: "[" + app.vpHpdStr + "]"
            }

            Text{
                text: "\t视点定位：" + app.currentLocation
            }
        }
    }

    RowLayout{
        id: main_layout
        anchors.fill: parent
        // TimeEdit {

        // }

        //RAGisQuickTextureItem{
        RAGisQuickFrameBufferObject{
            id: view_3d
            Layout.fillWidth: true
            Layout.fillHeight: true
            //anchors.margins: 20
            clip: true
            viewName: "default3D"
            focus: true
            onFocusChanged: {
                console.log("ragis focus changed ", focus)
            }
            // MouseArea{
            //     anchors.fill: parent
            //     onClicked: {
            //         parent.focus = true
            //     }
            // }


        }


         RAGisQuickTextureItem{
             Layout.fillWidth: true
             Layout.fillHeight: true
             viewName: "default2D"
             focus: true
         }
    }
    Pane{
        z: 1
        anchors.bottom:  main_layout.bottom
        anchors.horizontalCenter: main_layout.horizontalCenter
        //anchors.right: root.right
        width: 200
        height: 90
        visible: geo_view.model.length

        ListView{
            id: geo_view
            anchors.fill: parent
            highlightFollowsCurrentItem: true
            highlight: Rectangle { color: "lightsteelblue"; radius: 5 }
            model: app.pickedPropKeys
            delegate: RowLayout{
                id: item_layout
                height: vt.height
                Text{
                    text: app.pickedPropKeys[index] + ": "
                    MouseArea{
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: geo_view.currentIndex = index

                    }
                }
                Text{
                    id: vt
                    text: app.pickedPropValues[index]
                    wrapMode: Text.WordWrap
                    MouseArea{
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: geo_view.currentIndex = index

                    }
                }


            }
        }

    }

    // RAGisQuickFrameBufferObject{
    //     viewName: "default3D"
    //     anchors.fill: parent
    //    // anchors.top: header.bottom
    //    // y: header.height
    //    // anchors.bottom: parent.bottom
    //     //width: parent.width
    //     //anchors.fill: parent
    //     focus: true
    //     // MouseArea{
    //     //     anchors.fill: parent
    //     // }
    // }

    // Rectangle{
    //     anchors.fill: parent
    //     color:"red"
    // }

}
