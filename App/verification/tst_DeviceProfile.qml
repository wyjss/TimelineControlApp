import QtQuick 2.14
import QtQuick.Controls 2.14
import QtTest 1.2
import "qrc:/UICore/qml/theme" as Theme
import "../pages" as Pages

TestCase {
    name: "DeviceProfile"
    when: windowShown && testWindow.visible

    ApplicationWindow {
        id: testWindow
        width: 1800
        height: 900
        visible: true
        property QtObject appTheme: Theme.AppTheme {}
    }

    Component {
        id: deviceComponent
        QtObject {
            property string id: "one"
            property string name: "Alpha"
            property string templateName: "PC"
            property string deviceType: "PC"
            property string description: "测试设备"
            property bool online: true
            property var supportedProtocols: ["pc", "http"]
            property var commands: []
            property var configValues: ({ "ip": "127.0.0.1" })
        }
    }

    Component {
        id: modelComponent
        QtObject {
            property var currentDevice: null
            property var devices: []
            property var deviceTypes: ["PC"]
            function selectDevice(id) {
                for (var index = 0; index < devices.length; ++index) {
                    if (devices[index].id === id)
                        currentDevice = devices[index]
                }
            }
        }
    }

    Component {
        id: pageComponent
        Pages.DevicesPage {
            height: 660
            deviceTemplateModel: ({ "templates": [{ "name": "PC", "deviceType": "PC" }] })
        }
    }

    function test_profileBindings_data() {
        return [{ tag: "narrow", pageWidth: 1180 }, { tag: "wide", pageWidth: 1700 }]
    }

    function test_profileBindings(data) {
        var first = createTemporaryObject(deviceComponent, testWindow)
        var second = createTemporaryObject(deviceComponent, testWindow, { id: "two", name: "Beta" })
        var model = createTemporaryObject(modelComponent, testWindow,
                                          { devices: [first, second], currentDevice: first })
        var page = createTemporaryObject(pageComponent, testWindow.contentItem,
                                         { width: data.pageWidth, deviceModel: model })
        verify(page)
        var profile = findChild(page, "deviceProfile")
        var nameField = findChild(page, "deviceProfileName")
        var statusField = findChild(page, "deviceProfileProtocolStatus")
        var descriptionField = findChild(page, "deviceProfileDescription")
        verify(profile && nameField && statusField && descriptionField)
        compare(nameField.valueText, "Alpha")
        compare(statusField.textValue("leftValue"), "pc, http")
        compare(statusField.textValue("rightValue"), "在线")
        compare(descriptionField.valueText, "测试设备")

        // 原对象的属性变化必须立即更新档案；颜色名称也应作为原文显示。
        first.name = "red"
        first.description = " \t "
        first.online = false
        first.supportedProtocols = ["udp"]
        compare(nameField.valueText, "red")
        compare(descriptionField.valueText, "空")
        compare(statusField.textValue("leftValue"), "udp")
        compare(statusField.textValue("rightValue"), "离线")

        page.deviceSearchText = "no-match"
        wait(30)
        compare(page.filteredDevices.length, 0)
        verify(!page.selectedDeviceInCurrentView)
        compare(nameField.valueText, "red")
        page.deviceSearchText = ""
        model.currentDevice = second
        compare(nameField.valueText, "Beta")

        // 模拟方案重载：ID 相同，但当前设备替换成新对象。
        var reloaded = createTemporaryObject(deviceComponent, testWindow, { id: "two", name: "重载设备" })
        model.devices = [reloaded]
        model.currentDevice = reloaded
        compare(nameField.valueText, "重载设备")
        reloaded.description = "设备描述较长时仍应在档案区域内显示，不挤出侧栏"
        wait(30)
        var position = profile.mapToItem(page, 0, 0)
        verify(profile.width > 0 && profile.height > 0)
        verify(position.x >= 0 && position.x + profile.width <= page.width + 1)
        verify(nameField.height > 0 && statusField.height > 0 && descriptionField.height > 0)
        verify(nameField.y + nameField.height <= statusField.y + 1)
        verify(statusField.y + statusField.height <= descriptionField.y + 1)
        verify(descriptionField.y + descriptionField.height <= profile.height + 1)

        model.devices = []
        model.currentDevice = null
        wait(30)
        compare(nameField.valueText, "空")
        compare(descriptionField.valueText, "空")
        compare(statusField.textValue("leftValue"), "")
        compare(statusField.textValue("rightValue"), "")
    }
}
