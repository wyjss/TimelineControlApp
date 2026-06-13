import QtQuick 2.14

QtObject {
    readonly property QtObject colors: AppColors {}
    readonly property QtObject density: AppDensity {}
    readonly property QtObject metrics: AppMetrics {}
    readonly property QtObject shell: AppShellLayout {}
    readonly property QtObject shape: AppShape {}
    readonly property QtObject motion: AppMotion {}
    readonly property QtObject typography: AppTypography {}
    readonly property QtObject controlStyles: AppControlStyles {}
    readonly property QtObject icons: AppIcons {}
    readonly property QtObject z: AppZ {}
    property var textToneColors: ({
        "primary": "text",
        "secondary": "subtleText",
        "accent": "highlightText",
        "success": "successText",
        "warning": "warningText",
        "info": "infoText",
        "neutral": "neutralText",
        "danger": "dangerText",
        "inverse": "inverseText"
    })
}
