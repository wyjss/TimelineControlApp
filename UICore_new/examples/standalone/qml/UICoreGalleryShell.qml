import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import UICore.Style 1.0
import "qrc:/UICore/qml/components/base" as Base

Base.AppScrollPane {
    id: root

    property Item gallery

    contentSpacing: gallery.density.sectionSpacing
    Base.AppSection {
        Layout.fillWidth: true
        title: qsTr("AppSidebar 可选属性")
        subtitle: qsTr("直接控制窗口左侧真实侧栏的默认菜单、自定义内容、空白主体、可选插槽和自动隐藏")
        showHeaderDivider: true
        clearFocusOnTap: true
        padding: 0
        contentSpacing: gallery.density.paneContentSpacing

        UICoreSidebarDemo {
            Layout.fillWidth: true
            onEventTriggered: gallery.lastEvent = message
        }
    }
}
