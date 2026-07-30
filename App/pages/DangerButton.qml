import QtQuick 2.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base

Base.AppButton {
    function variantSpec() {
        return {
            "idleFill": "dangerSoft",
            "activeFill": "dangerSoft",
            "disabledFill": "backgroundSection",
            "idleBorder": "dangerBorder",
            "emphasisBorder": "dangerBorder",
            "textTone": UiStyle.TextTone.Danger,
            "emphasisTextTone": UiStyle.TextTone.Danger,
            "idleIconColor": "dangerText",
            "emphasisIconColor": "dangerText",
            "hoverOverlayColor": "dangerText",
            "activeOverlayColor": "dangerBorder",
            "hoverOpacity": 0.08,
            "activeOpacity": 0.12,
            "idleStrokeWidth": 1,
            "emphasisStrokeWidth": 1,
            "disabledStrokeWidth": 1
        }
    }
}
