import QtQuick 2.14

Item {
    id: root

    // 控制器只发送状态请求；opened 的最终状态仍由调用方持有。
    property bool suspended: false
    property bool opened: false

    // 调用方负责合并悬停、焦点、桥接区等条件；控制器不处理方向和鼠标事件。
    property bool triggerActive: false

    // 延迟由调用方绑定主题 Token，控制器不提供本地回退值。
    property int revealDelay
    property int hideDelay

    signal openRequested(bool opened)

    width: 0
    height: 0
    visible: false
    enabled: false

    function sync() {
        revealTimer.stop()
        hideTimer.stop()

        if (!enabled || suspended)
            return

        if (triggerActive) {
            if (!opened)
                revealTimer.restart()
        } else if (opened) {
            hideTimer.restart()
        }
    }

    onEnabledChanged: sync()
    onSuspendedChanged: sync()
    onOpenedChanged: sync()
    onTriggerActiveChanged: sync()
    onRevealDelayChanged: sync()
    onHideDelayChanged: sync()
    Component.onCompleted: sync()

    Timer {
        id: revealTimer

        interval: root.revealDelay
        repeat: false
        onTriggered: root.openRequested(true)
    }

    Timer {
        id: hideTimer

        interval: root.hideDelay
        repeat: false
        onTriggered: root.openRequested(false)
    }
}
