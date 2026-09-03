import QtQuick 2.14
import UICore.Style 1.0
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/theme" as Theme

Base.AppSurface {
    id: root

    property QtObject pageTheme: ApplicationWindow.window && ApplicationWindow.window.appTheme
        ? ApplicationWindow.window.appTheme
        : fallbackTheme
    property var appRuntime: typeof app !== "undefined" ? app : null
    readonly property var settings: appRuntime && appRuntime.settings ? appRuntime.settings : null

    sizeToContent: false
    surfaceTone: UiStyle.SurfaceTone.Surface
    surfaceOpacityScale: 0.85
    shapeRole: UiStyle.ShapeRole.Panel
    strokeWidth: 0

    Theme.AppTheme {
        id: fallbackTheme
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pageTheme.density.panePaddingCompact
        spacing: root.pageTheme.density.paneContentSpacing

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("系统设置")
            styleRole: UiStyle.TypographyRole.SectionTitle
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.pageTheme.density.dividerThickness
            color: root.pageTheme.colors.border
        }

        Base.AppText {
            Layout.fillWidth: true
            text: root.settings ? root.settings.applicationName : qsTr("时间线控制应用")
            styleRole: UiStyle.TypographyRole.BodyM
        }

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("语言：%1").arg(root.settings && root.settings.locale === "zh_CN"
                                      ? qsTr("简体中文")
                                      : String(root.settings ? root.settings.locale : ""))
            styleRole: UiStyle.TypographyRole.BodyS
            textTone: UiStyle.TextTone.Secondary
        }

        Base.AppText {
            Layout.fillWidth: true
            text: qsTr("主题：%1").arg(root.settings && root.settings.themeMode === "dark"
                                      ? qsTr("深色")
                                      : String(root.settings ? root.settings.themeMode : ""))
            styleRole: UiStyle.TypographyRole.BodyS
            textTone: UiStyle.TextTone.Secondary
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
