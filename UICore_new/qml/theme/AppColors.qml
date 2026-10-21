import QtQuick 2.14

QtObject {
    readonly property color backgroundBase: "#15191d"
    readonly property real backgroundHue: backgroundBase.hslHue
    readonly property real backgroundSaturation: backgroundBase.hslSaturation

    readonly property color backgroundWindow: Qt.hsla(backgroundHue, backgroundSaturation, 0.084, 1)
    readonly property color backgroundWindowVariant: backgroundBase
    readonly property color backgroundSurface: Qt.hsla(backgroundHue, backgroundSaturation, 0.131, 1)
    readonly property color backgroundSurfaceOverlay: Qt.rgba(backgroundSurface.r, backgroundSurface.g, backgroundSurface.b, 238 / 255)
    readonly property color backgroundPopup: Qt.hsla(backgroundHue, backgroundSaturation * 0.89, 0.220, 1)
    readonly property color backgroundDialogSection: "transparent"
    readonly property color backgroundSection: Qt.hsla(backgroundHue, backgroundSaturation * 0.93, 0.171, 1)
    readonly property color backgroundControl: backgroundSection
    readonly property color backgroundSectionOverlay: Qt.rgba(backgroundSection.r, backgroundSection.g, backgroundSection.b, backgroundSurfaceOverlay.a * 0.75)
    readonly property color backgroundCanvas: backgroundBase
    readonly property color borderPane: Qt.rgba(1, 1, 1, 20 / 255)
    readonly property color border: Qt.hsla(backgroundHue, backgroundSaturation * 0.75, 0.231, 1)
    readonly property color borderHeaderDivider: Qt.hsla(backgroundHue, backgroundSaturation * 0.75, 0.475, 1)
    readonly property color borderOverlay: Qt.rgba(1, 1, 1, 15 / 255)
    readonly property color borderPopup: Qt.hsla(backgroundHue, backgroundSaturation * 0.90, 0.380, 1)
    readonly property color borderDialogSection: Qt.rgba(1, 1, 1, 24 / 255)
    readonly property color controlBorder: Qt.hsla(backgroundHue, backgroundSaturation * 0.76, 0.322, 1)
    readonly property color buttonRaisedTop: Qt.rgba(0.55, 0.70, 1, 0.20)
    readonly property color buttonRaisedBottom: Qt.rgba(0.40, 0.55, 0.85, 0.08)
    readonly property color buttonRaisedTopEdge: Qt.rgba(0.62, 0.74, 1, 0.25)
    readonly property color buttonRaisedBottomEdge: Qt.rgba(0, 0, 0, 0.10)
    readonly property color buttonRaisedBorder: Qt.rgba(0.62, 0.74, 1, 0.18)
    readonly property color text: "#edf2f7"
    readonly property color subtleText: "#94a3b8"
    readonly property color disabledFill: "#111820"
    readonly property color disabledBorder: "#2b3948"
    readonly property color disabledText: "#7b899d"
    readonly property color inverseText: "#f8fafc"
    readonly property color highlightSoft: "#162d4a"
    readonly property color highlightText: "#78afff"
    readonly property color highlightFill: "#2f6feb"
    readonly property color successSoft: "#14271f"
    readonly property color successBorder: "#2f8a67"
    readonly property color successText: "#7ee2b7"
    readonly property color successFill: "#3fb950"
    readonly property color warningSoft: "#312813"
    readonly property color warningBorder: "#8a6a1f"
    readonly property color warningText: "#d29922"
    readonly property color warningFill: "#b7791f"
    readonly property color infoSoft: "#102c35"
    readonly property color infoBorder: "#2d91a8"
    readonly property color infoText: "#86d3e3"
    readonly property color neutralSoft: "#202b36"
    readonly property color neutralBorder: "#45576b"
    readonly property color neutralText: "#cbd5e1"
    readonly property color dangerSoft: "#2b1a21"
    readonly property color dangerBorder: "#b46076"
    readonly property color dangerText: "#ff9eb2"
    readonly property color dangerFill: "#f85149"
    readonly property color scrim: "#000000"
    readonly property color glow: "#0d1a27"
    readonly property color secondaryGlow: "#0b1118"
}
