import QtQuick 2.14

QtObject {
    readonly property int durationFast: 100
    readonly property int durationStandard: 160
    readonly property int durationSlow: 220
    readonly property int contentSwapDuration: 140
    readonly property int shellPanelRevealDelay: 140
    readonly property int shellPanelHideDelay: 280

    readonly property int easingStandard: Easing.OutCubic
    readonly property int easingEmphasized: Easing.OutQuint

    readonly property int transitionOffset: 10
}
