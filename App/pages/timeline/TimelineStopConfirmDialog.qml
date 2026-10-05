import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base

Base.AppDialog {
    id: root
    objectName: "stopPlaybackConfirmDialog"

    property bool stopped: true

    signal stopRequested()

    width: Math.min(420, parent.width - resolvedTheme.density.pageMargin * 2)
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)
    title: qsTr("停止全部播放？")
    message: qsTr("将停止所有时间线并重置播放进度，播放队列保留。")
    initialFocusItem: cancelStopButton
    onStoppedChanged: {
        if (stopped)
            close()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: root.spacing

        Item {
            Layout.fillWidth: true
        }

        Base.AppButton {
            id: cancelStopButton
            objectName: "cancelStopPlaybackButton"
            text: qsTr("取消")
            variant: UiStyle.ButtonVariant.Secondary
            onClicked: root.close()
        }

        Base.AppButton {
            objectName: "confirmStopPlaybackButton"
            text: qsTr("停止播放")
            variant: UiStyle.ButtonVariant.Danger
            onClicked: {
                root.close()
                root.stopRequested()
            }
        }
    }
}
