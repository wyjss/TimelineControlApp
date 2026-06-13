import QtQuick 2.14
import QtQuick.Layouts 1.14
import "../../foundation"
import "internal" as Internal

Internal.AppControlBase {
    id: root

    default property alias fieldContent: fieldStack.data

    property bool inheritFormDefaults: true
    property string label: ""
    property string subtitle: ""
    property bool showLabel: true
    property bool showSubtitle: true
    property var layoutMode: inheritedFieldFormContext
        && inheritedFieldFormContext.fieldLayoutMode !== undefined
        ? inheritedFieldFormContext.fieldLayoutMode
        : AppUiEnums.LayoutMode.Vertical
    property var fieldControl: null
    property int labelWidth: inheritedFieldFormContext
        && inheritedFieldFormContext.fieldLabelWidth !== undefined
        ? Number(inheritedFieldFormContext.fieldLabelWidth)
        : 120
    property int fieldSpacing: inheritedFieldFormContext
        && inheritedFieldFormContext.fieldFieldSpacing !== undefined
        ? Number(inheritedFieldFormContext.fieldFieldSpacing)
        : densityValue("controlGap", 8)
    property int copySpacing: 2
    property int minFieldWidth: 0
    property string labelStyleRole: "bodyS"
    property string subtitleStyleRole: "bodyS"
    property string labelTone: "primary"
    property string subtitleTone: "secondary"
    property string labelTextTone: ""
    property string subtitleTextTone: ""
    property bool showDivider: inheritedFieldFormContext
        && inheritedFieldFormContext.fieldShowDivider !== undefined
        ? !!inheritedFieldFormContext.fieldShowDivider
        : false
    property var fieldContentFillWidth: undefined
    property string fieldContentAlignment: ""
    property bool showUnderline: inheritedFieldFormContext
        && inheritedFieldFormContext.fieldShowUnderline !== undefined
        ? (!!fieldControl && !!inheritedFieldFormContext.fieldShowUnderline)
        : false
    property int dividerThickness: densityValue("dividerThickness", 1)
    property int dividerTopMargin: densityValue("controlGap", 8)
    property int dividerBottomMargin: densityValue("controlGap", 8)
    property int dividerInsetStart: 0
    property int dividerInsetEnd: 0
    property color dividerColor: colorValue("border", "#334155")
    property real dividerOpacity: 0.52
    property int underlineThickness: densityValue("dividerThickness", 1)
    property int underlineTopMargin: densityValue("controlGap", 8)
    property int underlineBottomMargin: densityValue("controlGap", 8)
    property string underlineScope: inheritedFieldFormContext
        && inheritedFieldFormContext.fieldUnderlineScope !== undefined
        ? String(inheritedFieldFormContext.fieldUnderlineScope)
        : "field"
    property int underlineInsetStart: underlineScope === "row" ? 0 : (horizontalMode ? horizontalFieldX : 0)
    property int underlineInsetEnd: 0
    property real underlineIdleOpacity: 0.72
    property real underlineHoverOpacity: 0.90
    property real underlineDisabledOpacity: 0.34

    function fieldFormContextFor(item) {
        var current = item

        while (current) {
            if (current.fieldFormContext !== undefined && current.fieldFormContext)
                return current

            current = current.parent
        }

        return null
    }

    function inferFieldContentFillWidth(item) {
        return !!(item && item.Layout && item.Layout.fillWidth)
    }

    readonly property var inheritedFieldFormContext: inheritFormDefaults
        ? fieldFormContextFor(parent)
        : null
    readonly property int resolvedLayoutMode: AppUiEnums.normalizeLayoutMode(layoutMode)
    readonly property string resolvedLayoutModeName: resolvedLayoutMode === AppUiEnums.LayoutMode.Horizontal
        ? "horizontal"
        : "vertical"
    readonly property bool horizontalMode: resolvedLayoutMode === AppUiEnums.LayoutMode.Horizontal
    readonly property bool hasExplicitFieldContentFillWidth: fieldContentFillWidth !== undefined
        && fieldContentFillWidth !== null
    readonly property string resolvedLabelTextTone: labelTextTone.length > 0 ? labelTextTone : labelTone
    readonly property string resolvedSubtitleTextTone: subtitleTextTone.length > 0 ? subtitleTextTone : subtitleTone
    readonly property bool resolvedFieldContentFillWidth: !horizontalMode
        || (hasExplicitFieldContentFillWidth
            ? !!fieldContentFillWidth
            : inferFieldContentFillWidth(fieldControl))
    readonly property string resolvedFieldContentAlignment: fieldContentAlignment.length > 0
        ? fieldContentAlignment
        : (resolvedFieldContentFillWidth ? "fill" : "end")
    readonly property bool fieldContentAlignedStart: !resolvedFieldContentFillWidth
        && resolvedFieldContentAlignment === "start"
    readonly property bool fieldContentAlignedCenter: !resolvedFieldContentFillWidth
        && resolvedFieldContentAlignment === "center"
    readonly property bool fieldContentAlignedEnd: !resolvedFieldContentFillWidth
        && !fieldContentAlignedStart
        && !fieldContentAlignedCenter
    readonly property bool hasLabelCopy: showLabel && label.length > 0
    readonly property bool hasSubtitleCopy: showSubtitle && subtitle.length > 0
    readonly property bool hasCopy: hasLabelCopy || hasSubtitleCopy
    readonly property real resolvedLabelWidth: horizontalMode && hasCopy
        ? Math.max(labelWidth, copyColumn.implicitWidth)
        : 0
    readonly property real verticalCopyHeight: hasCopy ? copyColumn.implicitHeight : 0
    readonly property real horizontalFieldX: hasCopy ? resolvedLabelWidth + fieldSpacing : 0
    readonly property real verticalFieldY: hasCopy ? verticalCopyHeight + fieldSpacing : 0
    readonly property real fieldContentImplicitWidth: Math.max(minFieldWidth, fieldStack.implicitWidth)
    readonly property real fieldContentImplicitHeight: fieldStack.implicitHeight
    readonly property bool underlineHovered: fieldControl
        && fieldControl.interactionHovered !== undefined
        && fieldControl.interactionHovered
    readonly property bool underlineActive: fieldControl
        && fieldControl.interactionActive !== undefined
        && fieldControl.interactionActive
    readonly property bool underlineEnabled: fieldControl && fieldControl.enabled !== undefined
        ? fieldControl.enabled
        : root.enabled
    readonly property color underlineColor: underlineActive
        ? colorValue("highlightText", "#7cb4ff")
        : colorValue("border", "#334155")
    readonly property real underlineOpacity: !underlineEnabled
        ? underlineDisabledOpacity
        : (underlineActive ? 1 : (underlineHovered ? underlineHoverOpacity : underlineIdleOpacity))
    readonly property bool hasLine: showDivider || showUnderline
    readonly property int resolvedLineThickness: Math.max(
        showDivider ? dividerThickness : 0,
        showUnderline ? underlineThickness : 0
    )
    readonly property int resolvedLineTopMargin: Math.max(
        showDivider ? dividerTopMargin : 0,
        showUnderline ? underlineTopMargin : 0
    )
    readonly property int resolvedLineBottomMargin: Math.max(
        showDivider ? dividerBottomMargin : 0,
        showUnderline ? underlineBottomMargin : 0
    )
    readonly property real contentImplicitHeight: horizontalMode
        ? Math.max(copyColumn.implicitHeight, fieldContentImplicitHeight)
        : verticalCopyHeight
            + (hasCopy && fieldContentImplicitHeight > 0 ? fieldSpacing : 0)
            + fieldContentImplicitHeight

    padding: 0
    background: null
    implicitWidth: layoutRoot.implicitWidth
    implicitHeight: layoutRoot.implicitHeight

    contentItem: Item {
        id: layoutRoot

        implicitWidth: root.horizontalMode
            ? root.resolvedLabelWidth
                + (root.hasCopy && root.fieldContentImplicitWidth > 0 ? root.fieldSpacing : 0)
                + root.fieldContentImplicitWidth
            : Math.max(
                root.hasCopy ? copyColumn.implicitWidth : 0,
                root.fieldContentImplicitWidth
            )
        implicitHeight: root.contentImplicitHeight
            + (root.hasLine
                ? root.resolvedLineTopMargin + root.resolvedLineThickness + root.resolvedLineBottomMargin
                : 0)

        Column {
            id: copyColumn

            width: root.horizontalMode
                ? root.resolvedLabelWidth
                : (root.hasCopy ? layoutRoot.width : 0)
            spacing: root.copySpacing
            visible: root.hasCopy

            AppText {
                visible: root.hasLabelCopy
                width: parent.width
                text: root.label
                theme: root.resolvedTheme
                styleRole: root.labelStyleRole
                textTone: root.resolvedLabelTextTone
                wrapMode: Text.WordWrap
            }

            AppText {
                visible: root.hasSubtitleCopy
                width: parent.width
                text: root.subtitle
                theme: root.resolvedTheme
                styleRole: root.subtitleStyleRole
                textTone: root.resolvedSubtitleTextTone
                wrapMode: Text.WordWrap
            }
        }

        Item {
            id: fieldSlot

            x: root.horizontalMode ? root.horizontalFieldX : 0
            y: root.horizontalMode ? 0 : root.verticalFieldY
            width: root.horizontalMode
                ? Math.max(0, layoutRoot.width - x)
                : layoutRoot.width
            implicitHeight: fieldStack.implicitHeight

            ColumnLayout {
                id: fieldStack

                width: root.resolvedFieldContentFillWidth ? parent.width : implicitWidth
                anchors.left: root.resolvedFieldContentFillWidth || root.fieldContentAlignedStart
                    ? parent.left
                    : undefined
                anchors.right: root.resolvedFieldContentFillWidth || root.fieldContentAlignedEnd
                    ? parent.right
                    : undefined
                anchors.horizontalCenter: root.fieldContentAlignedCenter
                    ? parent.horizontalCenter
                    : undefined
                spacing: root.fieldSpacing
            }
        }

        Rectangle {
            visible: root.showDivider
            x: Math.max(0, root.dividerInsetStart)
            y: root.contentImplicitHeight + root.resolvedLineTopMargin
            width: Math.max(0, layoutRoot.width - x - root.dividerInsetEnd)
            height: root.dividerThickness
            color: root.dividerColor
            opacity: root.dividerOpacity
        }

        Rectangle {
            visible: root.showUnderline
            x: Math.max(0, root.underlineInsetStart)
            y: root.contentImplicitHeight + root.resolvedLineTopMargin
            width: Math.max(0, layoutRoot.width - x - root.underlineInsetEnd)
            height: root.underlineThickness
            color: root.underlineColor
            opacity: root.underlineOpacity

            Behavior on color {
                ColorAnimation {
                    duration: root.resolvedTheme ? root.resolvedTheme.motion.durationStandard : 180
                    easing.type: root.resolvedTheme ? root.resolvedTheme.motion.easingStandard : Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: root.resolvedTheme ? root.resolvedTheme.motion.durationFast : 120
                    easing.type: root.resolvedTheme ? root.resolvedTheme.motion.easingStandard : Easing.OutCubic
                }
            }
        }
    }

}
