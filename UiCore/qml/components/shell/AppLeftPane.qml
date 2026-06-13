import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtQml 2.14
import "../../foundation"
import "../base" as Base
import "../base/internal" as Internal

Base.AppPanel {
    id: root

    property var paneData: ({})
    property real contentOpacity: 1

    readonly property var resolvedItems: paneData && paneData.items !== undefined ? paneData.items : []
    readonly property var primaryAction: paneData && paneData.primaryAction !== undefined ? paneData.primaryAction : null
    readonly property string resolvedTitle: paneData && paneData.title !== undefined ? String(paneData.title) : ""
    readonly property string resolvedSubtitle: paneData && paneData.subtitle !== undefined ? String(paneData.subtitle) : ""
    readonly property string filterPlaceholder: paneData && paneData.filterPlaceholder !== undefined
        ? String(paneData.filterPlaceholder)
        : ""
    readonly property string filterText: paneData && paneData.filterText !== undefined && paneData.filterText !== null
        ? String(paneData.filterText)
        : ""
    signal filterEdited(string text)
    signal actionTriggered(string actionId, var payload)

    function rowValue(rowData, key, fallback) {
        if (rowData !== undefined && rowData !== null && rowData[key] !== undefined)
            return rowData[key]

        return fallback
    }

    function rowActionPayload(rowData) {
        return {
            "rowId": rowValue(rowData, "id", rowValue(rowData, "label", "")),
            "rowData": rowData
        }
    }

    compact: true
    surfaceTone: "surfaceOverlay"
    contentSpacing: 0
    title: resolvedTitle
    subtitle: resolvedSubtitle

    Base.AppScrollPane {
        id: leftPanelScroll

        Layout.fillWidth: true
        Layout.fillHeight: true
        opacity: root.contentOpacity
        theme: root.theme
        contentSpacing: 8

        Base.AppTextField {
            id: filterField
            objectName: "filterField"
            property bool syncingFilterText: false

            function syncFilterText() {
                if (!filterField.activeFocus && filterField.text !== root.filterText) {
                    syncingFilterText = true
                    filterField.text = root.filterText
                    syncingFilterText = false
                }
            }

            Layout.fillWidth: true
            visible: root.filterPlaceholder.length > 0 || root.filterText.length > 0
            theme: root.theme
            surfaceTone: "section"
            placeholderText: root.filterPlaceholder
            onTextChanged: {
                if (!filterField.syncingFilterText)
                    root.filterEdited(text)
            }
            onActiveFocusChanged: {
                if (!filterField.activeFocus)
                    syncFilterText()
            }
            Component.onCompleted: syncFilterText()
            Connections {
                target: root

                function onFilterTextChanged() {
                    filterField.syncFilterText()
                }
            }
        }

        Repeater {
            model: root.resolvedItems

            delegate: Item {
                id: rowItem

                readonly property var rowData: modelData
                readonly property var rowDataRef: modelData
                readonly property bool selected: !!root.rowValue(rowData, "selected", false)

                Layout.fillWidth: true
                implicitHeight: 44

                Base.AppSurface {
                    anchors.fill: parent
                    sizeToContent: false
                    theme: root.theme
                    surfaceTone: rowItem.selected ? "highlight" : "section"
                    shapeRole: AppUiEnums.ShapeRole.Control
                    active: rowItem.selected
                    hoveredState: rowTap.hovered
                    interactive: true
                    strokeWidth: rowItem.selected ? 2 : 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 6
                            Layout.preferredHeight: 6
                            radius: 3
                            color: rowItem.selected
                                ? root.colorValue("highlightText", "#7cb4ff")
                                : root.colorValue("subtleText", "#97a3b6")
                            opacity: rowItem.selected ? 1 : 0.45
                        }

                        Base.AppText {
                            Layout.fillWidth: true
                            text: String(root.rowValue(rowDataRef, "label", ""))
                            theme: root.theme
                            styleRole: "bodyM"
                            textTone: rowItem.selected ? "accent" : "primary"
                        }

                        Base.AppText {
                            visible: String(root.rowValue(rowDataRef, "meta", "")).length > 0
                            text: String(root.rowValue(rowDataRef, "meta", ""))
                            theme: root.theme
                            styleRole: "bodyS"
                            textTone: "secondary"
                        }
                    }
                }

                Internal.AppTapRegion {
                    id: rowTap

                    anchors.fill: parent
                    enabled: root.enabled
                    onTapped: root.actionTriggered("leftPane.rowTriggered", root.rowActionPayload(rowItem.rowDataRef))
                }
            }
        }

        Base.AppButton {
            objectName: "primaryActionButton"
            Layout.fillWidth: true
            visible: root.primaryAction !== null
            theme: root.theme
            variant: root.primaryAction && root.primaryAction.variant !== undefined
                ? root.primaryAction.variant
                : AppUiEnums.ButtonVariant.Secondary
            text: root.primaryAction && root.primaryAction.text !== undefined
                ? String(root.primaryAction.text)
                : ""
            onClicked: root.actionTriggered(
                root.primaryAction && root.primaryAction.actionId !== undefined
                    ? String(root.primaryAction.actionId)
                    : "",
                root.primaryAction && root.primaryAction.payload !== undefined
                    ? root.primaryAction.payload
                    : ({})
            )
        }
    }
}

