import QtQuick 2.14
import QtQuick.Controls 2.14
import "qrc:/UICore/qml/theme" as Theme

ApplicationWindow {
    id: root

    property QtObject appTheme: Theme.AppTheme {}
    property var objects: []
    property var preloadedObject: null

    width: 1600
    height: 900
    visible: true

    function testProperties(index) {
        var properties = {
            "x": (index % 16) * 48,
            "y": Math.floor(index / 16) * 32,
            "width": 44,
            "height": 28
        }

        switch (componentTestProfile.length > 0
                ? componentTestProfile
                : componentTestName) {
        case "AppAlert":
            properties.title = "Title"
            properties.message = "Message"
            break
        case "AppBadge":
        case "AppCard":
        case "AppCheckBox":
        case "AppText":
        case "AppTextArea":
        case "AppTextField":
        case "AppToggleControl":
        case "AppToolTip":
            properties.text = "Test"
            break
        case "AppButton":
            properties.text = "Test"
            properties.iconName = "scene"
            break
        case "AppChoiceControl":
        case "AppSegmentedControl":
        case "AppSelect":
            properties.options = [
                { "label": "A", "value": "a" },
                { "label": "B", "value": "b" }
            ]
            properties.value = "a"
            break
        case "AppColorControl":
            properties.value = "#7cb4ff"
            break
        case "AppDialog":
        case "AppDialogSection":
        case "AppPanel":
        case "AppSection":
        case "AppToast":
            properties.title = "Title"
            break
        case "AppFieldBlock":
            properties.label = "Label"
            properties.subtitle = "Subtitle"
            break
        case "AppIcon":
            properties.name = "scene"
            properties.size = 16
            break
        case "AppNumberField":
        case "AppProgressBar":
        case "AppSliderControl":
            properties.value = 0.5
            break
        }
        return properties
    }

    function createTestObjects() {
        var component = Qt.createComponent(componentTestUrl)
        if (component.status !== Component.Ready) {
            console.error("COMPONENT_TEST_LOAD_ERROR", componentTestName,
                          component.errorString())
            return
        }

        var created = []
        for (var index = 0; index < componentTestCount; ++index) {
            var object = component.createObject(container, testProperties(index))
            if (!object) {
                console.error("COMPONENT_TEST_CREATE_ERROR", componentTestName,
                              index, component.errorString())
                break
            }
            created.push(object)
        }
        objects = created
    }

    function createPreloadedObject() {
        if (componentPreloadUrl.toString().length === 0)
            return

        var component = Qt.createComponent(componentPreloadUrl)
        if (component.status !== Component.Ready) {
            console.error("COMPONENT_PRELOAD_ERROR", component.errorString())
            return
        }

        preloadedObject = component.createObject(container)
        if (!preloadedObject)
            console.error("COMPONENT_PRELOAD_ERROR", component.errorString())
    }

    Component.onCompleted: createPreloadedObject()

    Item {
        id: container

        anchors.fill: parent
    }

    Timer {
        interval: 6000
        running: componentTestCount > 0
        onTriggered: root.createTestObjects()
    }
}
