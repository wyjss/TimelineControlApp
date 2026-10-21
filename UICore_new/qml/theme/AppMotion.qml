import QtQuick 2.14

QtObject {
    readonly property int durationFast: 100
    readonly property int durationStandard: 160
    readonly property int durationSlow: 220
    readonly property int paneRevealDuration: 260
    readonly property int contentSwapDuration: 140
    readonly property int cardSelectionTransitionDuration: 500
    readonly property int toastDismissDuration: 1200
    readonly property int scrollEdgeHintHideDelay: 800
    readonly property int shellPanelRevealDelay: 140
    readonly property int shellPanelHideDelay: 280
    readonly property int progressIndeterminateDuration: 900
    readonly property int tooltipDelay: 450
    readonly property int tooltipTimeout: 5000

    readonly property int easingStandard: Easing.OutCubic
    readonly property int easingEmphasized: Easing.OutQuint

    readonly property int transitionOffset: 10
}
