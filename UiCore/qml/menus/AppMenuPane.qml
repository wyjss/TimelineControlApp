import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import "../foundation"
import "../foundation/AppBridgeUtils.js" as BridgeUtils
import "../components/base" as Base
import "../components/form" as Form

Base.AppPanel {
    id: root

    property var drawerData: ({})
    property var paneData: ({})
    property QtObject paneController: null
    property string filterText: ""
    property real contentOpacity: 1

    readonly property string resolvedTitle: paneController && paneController.title !== undefined
        ? String(paneController.title)
        : (paneData && paneData.title !== undefined ? String(paneData.title) : "")
    readonly property string resolvedSubtitle: paneController && paneController.subtitle !== undefined
        ? String(paneController.subtitle)
        : (paneData && paneData.subtitle !== undefined ? String(paneData.subtitle) : "")
    readonly property var fixedTopBlocks: paneController && paneController.fixedTopBlocks !== undefined
        ? paneController.fixedTopBlocks
        : (paneData && paneData.fixedTopBlocks !== undefined ? paneData.fixedTopBlocks : [])
    readonly property var blocks: paneController && paneController.blocks !== undefined
        ? paneController.blocks
        : (paneData && paneData.blocks !== undefined ? paneData.blocks : [])
    readonly property bool hasFixedTopBlocks: fixedTopBlocks.length > 0
    signal actionTriggered(string actionId, var payload)

    function valueOf(source, key, fallback) {
        return BridgeUtils.valueOf(source, key, fallback)
    }

    function isDefined(value) {
        return BridgeUtils.isDefined(value)
    }

    function normalizedValue(value) {
        return BridgeUtils.normalizedValue(value)
    }

    function menuBlockKind(source) {
        try {
            if (isDefined(source) && source.menuBlockKind !== undefined)
                return AppUiEnums.normalizeMenuBlockKind(source.menuBlockKind)
        } catch (error) {
        }

        try {
            if (isDefined(source) && source.sections !== undefined)
                return AppUiEnums.MenuBlockKind.Form
        } catch (error) {
        }

        try {
            if (isDefined(source)
                    && source.delegateSource !== undefined
                    && String(source.delegateSource).length > 0) {
                return AppUiEnums.MenuBlockKind.Custom
            }
        } catch (error) {
        }

        return -1
    }

    function objectPayload(payload) {
        return BridgeUtils.objectPayload(payload)
    }

    function handleFieldEdited(fieldKey, value) {
        var normalizedFieldKey = fieldKey !== undefined && fieldKey !== null ? String(fieldKey) : ""
        var resolvedValue = normalizedValue(value)
        var menuKey = ""
        var payload = ({})

        try {
            if (drawerData !== undefined && drawerData !== null && drawerData.key !== undefined && drawerData.key !== null)
                menuKey = String(drawerData.key)
        } catch (error) {
        }

        payload.menuKey = menuKey
        payload.fieldKey = normalizedFieldKey
        payload.value = resolvedValue

        if (paneController && paneController.handleFieldEdited !== undefined)
            paneController.handleFieldEdited(normalizedFieldKey, resolvedValue)

        actionTriggered("menu.fieldEdited", payload)
    }

    function dispatchAction(actionId, payload) {
        var resolvedPayload = objectPayload(payload)

        if (paneController)
            paneController.handleAction(actionId, resolvedPayload)

        actionTriggered(actionId, resolvedPayload)
    }

    function commitExpanded(target, nextExpanded) {
        return BridgeUtils.commitExpanded(target, nextExpanded)
    }

    function blockExpansionPayload(blockData, blockIndex, nextExpanded) {
        return {
            "blockIndex": Number(blockIndex),
            "blockKey": String(root.valueOf(blockData, "key", "")),
            "blockTitle": String(root.valueOf(blockData, "title", "")),
            "expanded": !!nextExpanded
        }
    }

    compact: true
    surfaceTone: "surfaceOverlay"
    contentSpacing: 0
    title: resolvedTitle
    subtitle: resolvedSubtitle
    opacity: contentOpacity

    ColumnLayout {
        id: fixedTopBlocksHost

        Layout.fillWidth: true
        objectName: "fixedTopBlocksHost"
        visible: root.hasFixedTopBlocks
        spacing: 10

        Repeater {
            model: root.fixedTopBlocks

            delegate: blockLoaderComponent
        }
    }

    Item {
        id: fixedTopBlocksSeparator

        readonly property bool separatorEnabled: root.hasFixedTopBlocks
        readonly property int separatorExtent: separatorEnabled ? 12 : 0

        Layout.fillWidth: true
        Layout.preferredHeight: separatorExtent
        objectName: "fixedTopBlocksSeparator"
        visible: separatorEnabled

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: root.colorValue("borderOverlay", "#99334155")
            opacity: 0.72
        }
    }

    Base.AppScrollPane {
        id: menuScroll

        Layout.fillWidth: true
        Layout.fillHeight: true
        objectName: "menuScroll"
        theme: root.theme
        contentSpacing: 10

        Repeater {
            model: root.blocks

            delegate: blockLoaderComponent
        }
    }

    Component {
        id: blockLoaderComponent

        Loader {
            id: blockLoader

            Layout.fillWidth: true
            Layout.preferredHeight: item ? item.implicitHeight : 0
            width: parent ? parent.width : 0
            height: Layout.preferredHeight

            readonly property var blockData: modelData
            readonly property int blockIndex: index
            readonly property int blockKind: root.menuBlockKind(blockData)
            readonly property bool isFormBlock: blockKind === AppUiEnums.MenuBlockKind.Form
            readonly property bool isCustomBlock: blockKind === AppUiEnums.MenuBlockKind.Custom

            sourceComponent: isFormBlock ? formBlockComponent : (isCustomBlock ? customBlockComponent : null)

            Binding {
                when: !!blockLoader.item && blockLoader.item.width !== undefined
                target: blockLoader.item
                property: "width"
                value: blockLoader.width
            }
        }
    }

    Component {
        id: formBlockComponent

        Base.AppSection {
            id: formBlockSection

            readonly property string blockKey: String(root.valueOf(blockData, "key", blockIndex))
            readonly property int formSurfaceMode: AppUiEnums.normalizeSurfaceMode(
                root.valueOf(blockData, "surfaceMode", AppUiEnums.SurfaceMode.Section)
            )
            readonly property bool flatMode: formSurfaceMode === AppUiEnums.SurfaceMode.Flat
            readonly property bool bareMode: formSurfaceMode === AppUiEnums.SurfaceMode.Bare
            readonly property bool chromelessMode: flatMode || bareMode
            readonly property string formSubtitle: String(root.valueOf(blockData, "subtitle", ""))
            readonly property bool formCollapsible: !!root.valueOf(blockData, "collapsible", false)
            readonly property bool formExpanded: !!root.valueOf(blockData, "expanded", true)
            readonly property bool showFieldDividers: !!root.valueOf(blockData, "showFieldDividers", false)
            readonly property bool hasExplicitHeaderDivider: !!root.valueOf(blockData, "hasExplicitHeaderDivider", false)
            readonly property bool collapsedMode: !blockExpandedState
            readonly property bool resolvedHeaderDivider: hasExplicitHeaderDivider
                ? !!root.valueOf(blockData, "showHeaderDivider", false)
                : (chromelessMode && showFieldDividers)
            property bool blockExpandedState: formExpanded

            Layout.fillWidth: true
            objectName: "block:" + blockKey
            theme: root.theme
            title: String(root.valueOf(blockData, "title", ""))
            subtitle: formSubtitle
            surfaced: !chromelessMode
            surfaceTone: chromelessMode ? "ghost" : "sectionOverlay"
            compact: chromelessMode || collapsedMode
            padding: bareMode
                ? 0
                : (compact ? densityValue("panePaddingCompact", 14) : densityValue("panePadding", 18))
            spacing: bareMode ? 0 : densityValue("paneSpacing", 12)
            showSubtitle: formSubtitle.length > 0 && !collapsedMode
            collapsible: formCollapsible
            showHeaderDivider: resolvedHeaderDivider && !collapsedMode
            onToggled: {
                blockExpandedState = expanded
                root.commitExpanded(blockData, expanded)
                root.dispatchAction(
                    "menu.blockExpandedChanged",
                    root.blockExpansionPayload(blockData, blockIndex, expanded)
                )
            }

            onFormExpandedChanged: {
                if (blockExpandedState !== formExpanded)
                    blockExpandedState = formExpanded
            }

            Binding {
                target: formBlockSection
                property: "expanded"
                value: formBlockSection.blockExpandedState
            }

            Loader {
                id: formContentLoader

                Layout.fillWidth: true
                Layout.preferredHeight: item ? item.implicitHeight : 0
                active: formBlockSection.expanded
                sourceComponent: formContentComponent
            }

            Component {
                id: formContentComponent

                Form.AppFormContent {
                    width: formContentLoader.width
                    theme: root.theme
                    formData: blockData
                    onFieldEdited: function(fieldKey, value) {
                        root.handleFieldEdited(fieldKey, root.normalizedValue(value))
                    }
                    onActionTriggered: function(actionId, payload) {
                        root.dispatchAction(actionId, payload)
                    }
                }
            }
        }
    }

    Component {
        id: customBlockComponent

        Base.AppSection {
            readonly property string blockKey: String(root.valueOf(blockData, "key", blockIndex))
            readonly property string customTitle: String(root.valueOf(blockData, "title", ""))
            readonly property string customSubtitle: String(root.valueOf(blockData, "subtitle", ""))
            readonly property bool flatCustomBlock: customTitle.length === 0 && customSubtitle.length === 0

            Layout.fillWidth: true
            objectName: "block:" + blockKey
            theme: root.theme
            title: customTitle
            subtitle: customSubtitle
            surfaced: !flatCustomBlock
            surfaceTone: flatCustomBlock ? "ghost" : "sectionOverlay"
            compact: flatCustomBlock
            padding: flatCustomBlock ? 0 : densityValue("panePadding", 18)
            spacing: flatCustomBlock ? 0 : densityValue("paneSpacing", 12)

            Item {
                id: customBlockHost

                Layout.fillWidth: true
                implicitHeight: Math.max(0, customBlockLoader.item ? customBlockLoader.item.implicitHeight : 0)

                Loader {
                    id: customBlockLoader

                    anchors.fill: parent
                    source: String(root.valueOf(blockData, "delegateSource", ""))
                }

                Binding {
                    when: !!customBlockLoader.item && customBlockLoader.item.theme !== undefined
                    target: customBlockLoader.item
                    property: "theme"
                    value: root.theme
                }

                Binding {
                    when: !!customBlockLoader.item && customBlockLoader.item.blockData !== undefined
                    target: customBlockLoader.item
                    property: "blockData"
                    value: root.valueOf(blockData, "blockData", ({}))
                }

                Binding {
                    when: !!customBlockLoader.item && customBlockLoader.item.blockController !== undefined
                    target: customBlockLoader.item
                    property: "blockController"
                    value: root.valueOf(
                        blockData,
                        "controller",
                        root.paneController
                    )
                }

                Connections {
                    target: customBlockLoader.item
                    ignoreUnknownSignals: true

                    function onFieldEdited(fieldKey, value) {
                        root.handleFieldEdited(fieldKey, root.normalizedValue(value))
                    }

                    function onActionTriggered(actionId, payload) {
                        root.dispatchAction(actionId, payload)
                    }
                }
            }
        }
    }
}

