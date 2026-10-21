# UICore 组件使用指南

本文档用于选择公共组件和确认调用边界。属性的完整定义以源码和公共头文件为准，上层当前待同步变更见 [CHANGELIST.md](CHANGELIST.md)。

## 1. 使用前提

Qt Quick 应用链接 `UICore`，并在创建 `QQmlEngine` 前调用 `UICore::initialize()`。独立应用优先使用自带默认主题和 `AppShell` 的 `AppWindow`：

```qml
import "qrc:/UICore/qml" as Ui

Ui.AppWindow {
    visible: true
    shell.applicationTitle: qsTr("应用")
}
```

自定义应用窗口需要自行持有唯一主题：

```qml
import QtQuick.Controls 2.14
import "qrc:/UICore/qml/theme" as Theme

ApplicationWindow {
    property QtObject appTheme: Theme.AppTheme {}
}
```

直接读取背景颜色时使用 `appTheme.colors.background...` 家族：窗口、画布、容器、内部分区和输入控件分别对应 `backgroundWindow`、`backgroundCanvas`、`backgroundSurface`、`backgroundSection`、`backgroundControl`；轻量透明浮层使用 `backgroundSurfaceOverlay` 或 `backgroundSectionOverlay`，Popup 和 Dialog 外壳使用 `backgroundPopup`，Dialog 二级区域使用 `backgroundDialogSection`。

常用导入：

```qml
import UICore.Fields 1.0
import UICore.Forms 1.0
import UICore.Style 1.0

import "qrc:/UICore/qml" as Ui
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/components/field" as Field
import "qrc:/UICore/qml/components/form" as Form
import "qrc:/UICore/qml/components/shell" as Shell
import "qrc:/UICore/qml/components/task" as TaskView
import "qrc:/UICore/qml/menus" as Menus
```

调用方不得导入 `internal` 或 `foundation` 路径。它们不是公共接口。

## 2. 先选择层级

| 需求 | 使用 |
| --- | --- |
| 普通静态页面或少量控件 | Base 组件 |
| 带标签、说明和输入控件的手工字段行 | `AppFieldBlock` |
| 手工组织多个字段并共享布局 | `AppFieldForm` |
| 渲染单个 `AppField` | `AppFieldControl` |
| 渲染 `AppForm` / `AppFormSection` | `AppFormContent` |
| 标准应用窗口与壳层 | `AppWindow` |
| 标准导航、左右面板和画布壳层 | `AppShell` |
| 横向、纵向导航条的公共容器 | `AppNavigationBar` |
| 顶部或底部横向菜单栏 | `AppTopNavigationBar` / `AppBottomNavigationBar` |
| 可定制的通用侧边栏 | `AppSidebar` |
| 侧边栏相邻的通用展开面板 | `AppSidebarPane` |
| 表单式菜单面板 | `AppMenuPane` |
| Dialog 内的输入区、参数区或结果区 | `AppDialogSection` |
| 通用多级树状列表 | `AppTreeList` |
| 任务列表与进度 | `TaskManager` + `AppTaskPanel` |

没有字段 schema 的静态 UI 不创建 `AppField`。手工字段只使用 `AppFieldBlock` 和 `AppFieldForm`；需要标题、背景或折叠能力时，在外层组合 `AppSection` 或 `AppPanel`。Schema 驱动 UI 只使用 `AppFieldControl` 和 `AppFormContent`，不直接调用 `components/field/internal`，也不为这些入口新增 Pane 包装组件。渲染组件只呈现状态和发送用户意图，业务状态继续由调用方或 C++ controller 持有。

## 3. Base 组件

| 组件 | 用途 |
| --- | --- |
| `AppText` / `AppIcon` | 使用主题排版和图标语义显示内容 |
| `AppButton` | 普通、主操作、危险或图标按钮 |
| `AppCard` | 整体可点击或可选中的自定义内容卡片 |
| `AppCardSelectionTransition` | 为一组 `AppCard` 提供互斥选择和共享选中框转移动画 |
| `AppTextField` | 自由输入，或允许输入候选项之外的值 |
| `AppTextArea` | 多行自由文本输入 |
| `AppNumberField` | 统一编辑整数或浮点数，并约束范围和小数位 |
| `AppSelect` | 只能从候选项中选择的封闭选择 |
| `AppToggleControl` | 单个布尔开关 |
| `AppCheckBox` | 单个可勾选项，支持原生二态和三态 |
| `AppChoiceControl` | 少量互斥选项 |
| `AppSegmentedControl` | 少量并列模式切换 |
| `AppSliderControl` | 连续或步进数值 |
| `AppColorControl` | 颜色值选择，支持 Filled 和 Ghost 输入外观 |
| `AppProgressBar` | 确定进度或不确定进度 |
| `AppSurface` | 无标题的基础语义表面 |
| `AppBackdrop` | 页面或画布背景 |
| `AppPanel` | 带标题、操作和可折叠内容的面板 |
| `AppSection` | 页面内部较轻量的内容分组 |
| `AppScrollPane` | 统一滚动与边缘反馈 |
| `AppScrollEdgeHints` | 为外部 Flickable、ListView 或 GridView 提供顶部和底部滚动提示 |
| `AppTreeList` | 渲染任意层级的 `QAbstractItemModel`，并提供展开、选择和键盘导航 |
| `AppPopup` | 独立自定义弹层；下拉控件已经自行管理弹层 |
| `AppAlert` | 参与页面布局的持续状态提示 |
| `AppDialog` | 带标准标题、正文和操作区的模态对话框 |
| `AppDialogSection` | Dialog 内默认透明、仅保留描边的二级内容表面 |
| `AppToast` | 不阻塞页面的短时浮层反馈 |
| `AppToolTip` | 使用主题外观和统一延时的悬停提示 |
| `AppBadge` | 只读状态、数量或分类标签 |
| `AppFieldBlock` | 标签、说明和控件组成的字段行 |
| `AppAutoHideController` | 无外观的延迟展开与自动隐藏状态请求 |

`AppButton.variant` 使用 `Primary`、`Secondary`、`Tonal`、`Subtle`、`Ghost`、`Nav` 和 `Danger`。`Subtle` 使用半透明中性背景且不显示描边，用于需要轻微面积感的低强调操作；`Danger` 仅用于删除、停止且无法恢复等破坏性操作，普通取消、关闭或次要操作继续使用 `Secondary` 或 `Ghost`。

`AppButton.raised` 是独立于 `variant` 的微浮开关，默认 `false`。开启时用一个圆角矩形绘制上沿高光、背景明暗和下沿暗部，并添加低对比度闭合细边框，使底部和两侧与背景保持分离。标准主题使用冷蓝灰高光和 1px 弱边框，轻微提亮下半部并弱化底沿暗线；边框随微浮状态一起增强或减弱。键盘聚焦时隐藏弱边框，只保留清晰的外层焦点描边。效果不使用模糊阴影、ShaderEffect 或离屏图层，不改变布局尺寸和点击区域；悬停时增强，按下或选中时减弱，保留原有按下缩放。`Ghost`、`Nav` 仅在交互或选中时显示微浮；禁用或关闭微浮时卸载效果对象，关闭开关不播放退出动画。关闭时仍保留一个 Loader 及其组件定义，不能视为零内存开销。

```qml
Base.AppButton {
    text: qsTr("返回列表")
    variant: UiStyle.ButtonVariant.Secondary
    raised: true
}
```

使用标准 `AppTheme` 无需额外配置。自定义主题仅在启用微浮时需要提供 `colors.buttonRaisedTop`、`buttonRaisedBottom`、`buttonRaisedTopEdge`、`buttonRaisedBottomEdge`、`buttonRaisedBorder`，`shape.buttonRaisedEdgeWidth`（同时控制细边框宽度），以及 `controlStyles.buttonRaisedIdleOpacity`、`buttonRaisedHoverOpacity`、`buttonRaisedPressedOpacity`；沿用现有 `controlRadius` 和 motion Token。

容器留白按用途选择 Token，不按嵌套层级命名：Pane 边缘到主体内容使用 `panePadding`；窄侧栏内嵌的 Section 或 Card 需要提高信息密度时使用 `panePaddingCompact`，普通页面和宽弹窗中的容器仍使用 `panePadding`；标题、工具区和 Section 等主要区块之间使用 `paneSpacing`；连续卡片、字段或按钮之间使用 `controlGap`。不要为调用位置增加 `level1Padding`、`level2Padding`、`outerPadding` 或 `innerPadding`。

`AppScrollPane.contentPadding` 只缩进滚动内容，不缩进 viewport、滚动条和上下边缘提示。滚动区位于带内边距的 Surface 中时，优先让 `AppScrollPane` 填满 Surface，并用 `contentPadding` 保留内容边距；需要单独控制右侧内容边距时使用 `contentRightPadding`，滚动条仍保持在 viewport 边缘。滚动区随宿主内容缩进、但垂直滚动条需要贴住宿主外边缘时，设置 `verticalScrollBarParent`，将滚动条交给覆盖目标边缘的 overlay 父项承载；`AppScrollPane` 会负责纵向坐标映射和镜像布局，overlay 父项应覆盖滚动条的绘制与点击区域。

外部 `ListView`、`GridView` 或 `Flickable` 需要相同的边缘提示时，将 `AppScrollEdgeHints` 作为滚动组件的同级覆盖层，并通过 `target` 绑定滚动目标：

```qml
Item {
    HoverHandler {
        id: edgeHintsHover
    }

    ListView {
        id: listView
        anchors.fill: parent
    }

    Base.AppScrollEdgeHints {
        anchors.fill: listView
        target: listView
        hovered: edgeHintsHover.hovered
    }
}
```

`AppScrollEdgeHints` 只负责绘制，不接收鼠标输入，避免覆盖层阻断下方控件的 Hover；通过 `hovered` 接收外部视口的悬停状态。组件默认在首次发现溢出内容、`hovered` 变为 `true` 和目标滚动期间显示，并在停止滚动后自动隐藏；显示和隐藏使用主题 `motion.durationFast` 进行透明度过渡，`autoHideDelay` 默认读取 `motion.scrollEdgeHintHideDelay`。需要持续显示时设置 `autoHide: false`。

层级 `QAbstractItemModel` 使用 `AppTreeList`。组件封装 Qt 5.14 的 `QtQuick.Controls 1.4 TreeView` 和完整 `TreeViewStyle`，内部视图及其原生代理不向调用方暴露；`selectionMode` 沿用 Qt 的 `SelectionMode` 枚举。模型通过 `rowCount(parent)`、`index()` 和 `parent()` 表达任意层级。树形引导线从展开节点的箭头下方延伸到子节点，在末个子节点处收尾，并为更深层的后续兄弟项保留竖线；根节点之间不连线，横线避开箭头和图标。分支使用无背景的轻量箭头表达收起和展开。默认文本 Role 为 `display`，可选主题图标 Role 为 `iconName`，分别通过 `textRole` 和 `iconRole` 调整。默认内容保留统一图标占位，无图标节点留空，保证同级文字对齐；图标由模型显式提供，可使用 `folder`、`file`，组件不根据有无子节点推断节点类型。自定义 `contentDelegate` 混用有图标和无图标节点时，也应保留图标占位。

默认行高读取 `controlHeightSm`，层级缩进读取 `controlPaddingXSm * 2`（标准主题分别为 32 和 20）；可通过 `rowHeight` 和 `indentWidth` 调整。行背景保留主题圆角和整行选中态，左右各留 `controlGap / 2` 的外侧空间。

```qml
Base.AppTreeList {
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    model: treeModel
    onActivated: controller.openNode(index)

    Component.onCompleted: {
        expand(model.index(0, 0, rootIndex))
    }
}
```

节点内容需要自定义时设置 `contentDelegate`；层级线、缩进、行状态和分支箭头仍由 `AppTreeList` 管理。代理根对象必须声明 `property QtObject treeItem`，可读取 `index`、`roles`、`value`、`iconName`、`row`、`depth`、`selected`、`pressed`、`hasActiveFocus`、`hasChildren` 和 `expanded`。所有节点使用 `rowHeight` 指定的统一行高：

```qml
Base.AppTreeList {
    model: treeModel

    contentDelegate: Component {
        Base.AppText {
            property QtObject treeItem

            text: treeItem ? String(treeItem.value) : ""
        }
    }
}
```

`currentIndex`、`rootIndex` 和 `selection` 使用原生 `QModelIndex` / `ItemSelectionModel`；交互信号为 `clicked(index)`、`doubleClicked(index)`、`activated(index)`、`expanded(index)`、`collapsed(index)`。程序通过 `expand(index)`、`collapse(index)` 和 `isExpanded(index)` 控制分支。方向上/下移动当前行，方向右/左展开或收起当前分支，回车触发当前节点。部署应用时需要同时携带 Qt 的 `qml/QtQuick/Controls` 模块。

`activateItemOnSingleClick` 默认 `true`，保持单击触发 `activated`；设为 `false` 后，`activated` 由双击或回车触发。`doubleClicked` 始终转发原生双击，与激活方式无关。`expandsOnDoubleClick` 默认 `false`；开启后双击节点内容会展开／收起模型 `hasChildren(index)` 为真的分支，分支箭头仍使用原生点击行为。

外部需要双击打开文件时，由外部 Controller 判断节点类型及是否允许打开；不能用有无子节点区分文件和文件夹。下面的 `canOpenFile` 和 `openFile` 是外部接口示意：

```qml
Base.AppTreeList {
    model: treeModel
    activateItemOnSingleClick: false
    expandsOnDoubleClick: true
    onDoubleClicked: {
        if (controller.canOpenFile(index))
            controller.openFile(index)
    }
}
```

若打开动作同时支持回车，把上述处理放到 `onActivated`；不要在两个信号中重复执行同一个打开动作。

只读 `contentY` 表示距内容顶部的实际滚动偏移，顶部为 `0`，支持 `onContentYChanged`。组件已扣除底层 ListView 的 `originY`，避免插删行造成的内容原点变化影响保存值。通过 `scrollToContentY(y)` 显式恢复位置：立即停止惯性滚动、刷新当前布局，并将有限数值限制到当前可滚动范围；忽略 `NaN` 和无穷值。外部负责保存偏移，并在模型、展开状态及视图尺寸就绪后调用；组件不缓存待恢复位置。原先直接写 `contentY = y` 的调用需改为 `scrollToContentY(y)`。

只读 `visibleRowCount` 表示当前 `rootIndex` 下按展开状态排列的总行数，包含视口外的行，不包含 `rootIndex` 本身及折叠后隐藏的子节点；随模型、根索引及展开状态变化自动更新，支持 `onVisibleRowCountChanged`。它可用于计算树区域高度；等于 `0` 只表示当前没有展示行，加载和错误状态仍由外部区分。例如：

```qml
Base.AppTreeList {
    id: tree
    model: treeModel
    height: rowHeight * Math.min(visibleRowCount, maximumVisibleRows)
}
```

像素位置恢复要求前后行排列和行高一致；节点位置变化后的逻辑定位仍由外部决定。

多选必须提供 `ItemSelectionModel`，它与 `AppTreeList.model` 必须使用同一个模型；使用代理模型时两者都指向该代理。选择模型也可以由 C++ 创建并传入。视图直接修改这一个选择模型，不另存选中集合：

```qml
import QtQuick.Controls 1.4 as Controls1
import QtQml.Models 2.14
import "qrc:/UICore/qml/components/base" as Base

Base.AppTreeList {
    model: treeModel
    selectionMode: Controls1.SelectionMode.ExtendedSelection
    selection: ItemSelectionModel {
        model: treeModel
    }
}
```

| `selectionMode` | 行为 |
| --- | --- |
| `SingleSelection`（默认） | 单选；未提供选择模型时只保留视图当前行 |
| `MultiSelection` | 点击切换该项是否选中 |
| `ExtendedSelection` | 普通点击单选，Ctrl 增减选择，Shift 范围选择 |
| `NoSelection` | 不显示选中态 |

选择结果读取 `selection.selectedIndexes`，不能把 `currentIndex` 当作已选结果：当前行用于导航，可以未被选中。选中显示与结果集合都要求模型 flags 同时包含 `Qt::ItemIsSelectable` 和 `Qt::ItemIsEnabled`；外部模型改变 flags 后应发送对应的 `dataChanged`。提供选择模型时，`clearSelection()` 会清除选中显示；切换 `selectionMode` 沿用 Qt 行为，清空选择模型。

外部通过 `selection.setCurrentIndex(index, command)` 设置当前项后，视图同步键盘当前行和范围选择起点；使用 `ItemSelectionModel.ClearAndSelect` 同时选中该项，使用 `NoUpdate` 只移动当前项。当前项位于折叠分支或 `rootIndex` 范围之外时，视图当前行为空，不自动展开分支；该项重新可见后恢复。插入、移除、折叠或重置等结构变化后的同步在事件循环中完成。

节点类型、哪些节点可选、父子勾选级联及半选状态由外部模型决定。复选框行可用 `contentDelegate` 组合 `AppCheckBox`，并显式把编辑写回模型；行选择与复选框勾选各自独立。

`AppPopup.revealDuration` 和 `dismissDuration` 分别控制内容显现和消失动画，默认读取主题的标准、快速时长；派生反馈组件可以按自身语义覆盖。

`AppPopup` 未设置显式高度时只适合内容隐式高度不反向依赖弹层尺寸的场景。固定弹层宽度并同时使用 `Layout.fillWidth`、文本换行时，由调用方从可见标题、正文、操作等直接内容项的 `implicitHeight`、间距和上下内边距单向计算 `height`；不要把 `height` 或 `contentHeight` 绑定到 `contentItem.implicitHeight` 或承载内容的 `ColumnLayout` / `RowLayout.implicitHeight`。`AppToast` 已在内部处理该尺寸关系，调用方只设置位置和宽度。

`AppPopup` 在创建、关闭动画和 Loader 卸载期间继续使用所属窗口主题，调用方不需要手动传递主题。若打开 Popup 时才向 Repeater、Loader 或动态表单注入模型，先调用 `open()`，再通过 `Qt.callLater()` 注入数据，确保动态子控件创建时已经归属窗口。

`AppPopup`、`AppDialog` 及其非状态型派生弹出窗口统一使用以下规范配色：

- 弹出窗口外壳使用默认 `SurfaceTone.Popup`，由 `backgroundPopup` 和 `borderPopup` 提供独立浮空表面。
- 输入区、参数区、结果区等同级内容块使用 `AppDialogSection`；它复用 `AppPanel`，默认背景透明并保留 1px 描边，通过 `SurfaceTone.DialogSection`、`backgroundDialogSection` 和 `borderDialogSection` 提供可独立调整的二级表面。
- TextField、Select 等输入控件保持默认 `SurfaceTone.Control`，不为单个输入控件覆盖背景 tone。
- Alert、Toast 和局部状态块使用 Success、Warning、Info、Danger 等状态 tone；下拉选项等没有内容分区的轻量浮层使用 `SurfaceTone.SurfaceOverlay`。

`AppSurface`、`AppPanel`、`AppSection` 和 `AppPopup` 使用 `surfaceOpacityScale` 缩放自身背景及边框的透明度，不影响文字、图标和内容；默认值为 `1.0`。复合组件只向自己管理的容器背景传导该属性，`AppMenuPane` 会同步内置区块和表单分隔线，但不会修改字段控件或自定义 delegate 的透明度。菜单区块使用 `SectionOverlay` 保持层级，调用方只需设置菜单自身的透明度：

```qml
Menus.AppMenuPane {
    paneController: controller.activePaneController
    surfaceOpacityScale: 0.7
}
```

整张卡片只对应一个操作时使用 `AppCard`。它使用 `AbstractButton` 的鼠标、触摸、键盘、焦点和无障碍状态机，并统一把 `hovered`、`down`、`visualFocus` 和 `checked` 映射到 Section 表面；卡片内容不要再嵌套按钮或其它独立交互控件：

```qml
Base.AppCard {
    Layout.fillWidth: true
    text: qsTr("项目卡片")
    onClicked: controller.openItem()

    Base.AppText {
        Layout.fillWidth: true
        text: qsTr("项目名称")
        styleRole: UiStyle.TypographyRole.SectionTitle
    }

    Base.AppText {
        Layout.fillWidth: true
        text: qsTr("项目说明")
        textTone: UiStyle.TextTone.Secondary
        wrapMode: Text.WordWrap
    }
}
```

选择型卡片设置 `checkable: true` 并使用原生 `checked`、`toggled()`；不可点击的内容卡片继续使用 `AppSurface`。列表项需要更明确的持续选中反馈时设置 `emphasizedSelection: true`，选中态会使用高亮实底、描边、柔和外框和与边框一体的左侧指示条；密集列表可以关闭按下缩放。直接使用 `ButtonGroup` 时，每张卡片独立显示选中效果：

```qml
ButtonGroup {
    id: cardGroup
}

Base.AppCard {
    checkable: true
    checked: true
    emphasizedSelection: true
    animateScale: false
    ButtonGroup.group: cardGroup
}
```

需要让高亮边框和指示条在互斥卡片之间整体转移时，把卡片和 `AppCardSelectionTransition` 放在同一个视觉宿主中，并为每张卡片设置 `selectionTransition`。Transition 提供实际的 `ButtonGroup`，不要再为这些卡片设置 `ButtonGroup.group`；选中填充仍由各卡片过渡，共享边框负责位置和尺寸动画，时长读取 `motion.cardSelectionTransitionDuration`。Repeater 或 Loader 动态创建的卡片不需要额外调用刷新函数：

```qml
Item {
    implicitHeight: cardLayout.implicitHeight

    ColumnLayout {
        id: cardLayout
        anchors.fill: parent

        Base.AppCard {
            checkable: true
            checked: true
            emphasizedSelection: true
            selectionTransition: cardTransition
            animateScale: false
        }

        Base.AppCard {
            checkable: true
            emphasizedSelection: true
            selectionTransition: cardTransition
            animateScale: false
        }
    }

    Base.AppCardSelectionTransition {
        id: cardTransition
        anchors.fill: parent
    }
}
```

封闭选择：

```qml
property string region: "east"

Base.AppSelect {
    options: [
        { "label": "东区", "value": "east" },
        { "label": "西区", "value": "west" }
    ]
    value: region
    onValueSelected: region = nextValue
}
```

`AppSelect.value` 由调用方持有。用户选择时组件只发送 `valueSelected(nextValue)`；调用方接受选择时应在处理器中提交新值，不提交时控件保持原值。

`AppChoiceControl` 和 `AppSegmentedControl` 使用相同的受控值协议，只表达单个互斥值。用户操作只发送 `valueSelected(nextValue)`，调用方接受后再写回 `value`。多个可独立选择的项目使用 `Column` 或 `Repeater` 组合 `AppCheckBox`，选中值集合由调用方持有；不要把数组传给 `AppChoiceControl`。

`AppColorControl.value` 同样由调用方持有。文本提交或颜色对话框确认时，组件只发送 `valueEdited(nextValue)`，随后从外部 `value` 恢复显示；调用方接受时应在处理器中写回新值，拒绝或异步处理时控件保持旧值，异步接受后再更新 `value`。

允许继续输入的候选值：

```qml
Base.AppTextField {
    text: "60"
    options: [30, 60, 90]
}
```

多行自由文本使用 `AppTextArea`。它保留原生 `text`、选择、换行和 `readOnly` 语义，最小高度读取主题 Token：

```qml
Base.AppTextArea {
    Layout.fillWidth: true
    text: controller.notes
    placeholderText: qsTr("请输入说明")
    onTextChanged: controller.notes = text
}
```

数值输入使用受控的 `value` 和 `valueEdited(nextValue)`；回车、失焦或候选值确认时提交：

```qml
property real threshold: 0.75

Base.AppNumberField {
    value: threshold
    minimum: 0
    maximum: 1
    decimals: 2
    onValueEdited: threshold = nextValue
}
```

布尔开关直接使用原生 `checked` 和 `toggled()`：

```qml
property bool featureEnabled: false

Base.AppToggleControl {
    checked: featureEnabled
    onToggled: featureEnabled = checked
}
```

单个确认项或多选列表项使用 `AppCheckBox`，并通过原生 `checked`、`checkState`、`tristate` 和 `toggled()` 交互：

```qml
Base.AppCheckBox {
    text: qsTr("同时导出元数据")
    checked: controller.exportMetadata
    onToggled: controller.exportMetadata = checked
}
```

对支持 `readOnly` 的输入控件（`AppTextField`、`AppTextArea`、`AppNumberField` 和 `AppSelect`），该属性表示内容可读但不可编辑；`enabled: false` 表示整个控件禁用。不要用禁用态替代只读态。

确定进度直接设置 `from`、`to` 和 `value`，无法量化的等待状态设置 `indeterminate: true`。需要业务状态色时使用 `fillOverride` 或 `trackOverride`，不在外部重画轨道：

```qml
Base.AppProgressBar {
    Layout.fillWidth: true
    from: 0
    to: 100
    value: controller.progress
    indeterminate: controller.progressUnknown
}
```

少量只读状态或数量使用 `AppBadge`；需要点击、删除或选择能力时改用 Button、Card 或 CheckBox，不把 Badge 当作交互 Chip：

```qml
Base.AppBadge {
    text: qsTr("运行中")
    surfaceTone: UiStyle.SurfaceTone.Info
    textTone: UiStyle.TextTone.Info
}
```

悬停说明使用 `AppToolTip`。它保留原生 ToolTip 的定位、显示和关闭机制，默认延时与超时读取主题：

```qml
Base.AppButton {
    id: refreshButton
    text: qsTr("刷新")

    Base.AppToolTip {
        parent: refreshButton
        visible: refreshButton.hovered
        text: qsTr("重新加载当前数据")
    }
}
```

页面内需要持续可见的反馈使用 `AppAlert`。它参与正常布局，关闭按钮只发送 `closeRequested()`，显示状态仍由调用方持有：

```qml
Base.AppAlert {
    Layout.fillWidth: true
    visible: controller.hasError
    surfaceTone: UiStyle.SurfaceTone.Danger
    title: qsTr("保存失败")
    message: controller.errorMessage
    closable: true
    onCloseRequested: controller.dismissError()
}
```

短时反馈使用 `AppToast`。调用方负责设置位置和宽度；`show()` 会打开 Toast，已打开时则重新开始自动关闭计时。鼠标悬停期间不会自动关闭，移出后重新计时；`timeout <= 0` 时不自动关闭。计时结束后使用主题的 `toastDismissDuration` 渐隐：

```qml
Base.AppToast {
    id: savedToast

    parent: page
    x: Math.max(0, (page.width - width) / 2)
    y: ApplicationWindow.window.appTheme.density.pageMargin
    width: Math.min(360, page.width)
    surfaceTone: UiStyle.SurfaceTone.Success
    message: qsTr("设置已保存")
}

Base.AppButton {
    text: qsTr("保存")
    onClicked: savedToast.show()
}
```

标准模态交互使用 `AppDialog`。`accepted()` 和 `rejected()` 只表达用户意图；默认在发出信号后关闭，对应的 `closeOnAccepted`、`closeOnRejected` 可关闭这一行为。关闭按钮、Escape 和没有既有操作结果的程序关闭按拒绝处理。业务对话框的正文作为默认内容直接注入。确认按钮通过 `acceptEnabled` 控制可用状态，通过 `acceptButtonVariant` 选择语义，通过 `acceptIconName` 设置主题图标；破坏性确认使用 `UiStyle.ButtonVariant.Danger`。

Dialog 默认把高度限制在父项高度减去两侧页面边距，超出的正文在标题和操作区之间滚动；设置 `maximumDialogHeight <= 0` 可取消限制。打开后优先聚焦 `initialFocusItem`，未提供有效目标时依次聚焦确认、取消或关闭按钮：

普通 Dialog 可以直接承载输入控件；具有输入区、参数区、结果区等多个稳定工作区域时，使用同级 `AppDialogSection` 划分区域，这些区域不互相嵌套。

```qml
Base.AppDialog {
    id: confirmDialog

    parent: page
    width: Math.min(420, page.width
                    - ApplicationWindow.window.appTheme.density.pageMargin * 2)
    title: qsTr("删除项目")
    message: qsTr("此操作无法撤销。")
    rejectText: qsTr("取消")
    acceptText: qsTr("删除")
    acceptEnabled: nameInput.text.trim() === controller.currentProjectName
    acceptButtonVariant: UiStyle.ButtonVariant.Danger
    initialFocusItem: nameInput
    onAccepted: controller.removeCurrentItem()

    Base.AppTextField {
        id: nameInput
        Layout.fillWidth: true
        placeholderText: qsTr("输入项目名称以确认")
    }
}
```

## 4. Field 与 Form

`BaseField` 保存值和约束，`AppField` 增加 UI 描述。`AppField.sourceField` 绑定外部 `BaseField` 后直接代理它，不复制状态。

`required` 只显示必填标记，不会自动判空或生成错误。校验规则和时机由调用方持有，并把结果写入 `errorText`；只读 `valid` 等于 `errorText` 为空。`AppField` 直接代理这三个属性，`AppFormSection.valid` 和 `AppForm.valid` 分别聚合全部子字段和子 Section。`AppFieldBlock` 负责显示 Danger 错误文本及无障碍说明，但不执行校验。

`AppField.Kind.Button` 默认使用无描边、浅色中性背景的 `UiStyle.ButtonVariant.Subtle`；需要标准描边按钮时显式设置 `variant: UiStyle.ButtonVariant.Secondary`。

单字段：

```qml
AppField {
    id: nameField
    key: "name"
    kind: AppField.Kind.TextField
    label: "名称"
}

Field.AppFieldControl {
    fieldData: nameField
    onValueEdited: nameField.value = value
}
```

完整表单：

```qml
Form.AppFormContent {
    formData: appForm
    onFieldEdited: appForm.setFieldValue(fieldKey, value)
}
```

选择 renderer 的规则：

- `MultilineTextEditor` 使用 `AppTextArea`；`CheckBoxEditor` 使用 `AppCheckBox`。
- `BoolType + AutoEditor` 使用 `AppToggleControl`，显式 `CheckBoxEditor` 使用 `AppCheckBox`。
- `EnumType` 或 `allowCustomValue == false` 的 `SelectEditor` 使用 `AppSelect`。
- `IntType` 和 `DoubleType` 的 TextField 使用 `AppNumberField`；范围和后缀由字段 schema 提供，浮点精度至少保留两位，并可由 `stepSize` 提高。
- Text 且 `allowCustomValue == true` 时使用带候选项的 `AppTextField`；数值字段允许自定义候选值时由 `AppNumberField` 复用相同候选交互。
- 不直接调用 `components/field/internal` 中的 renderer。

## 5. Shell、菜单与任务

独立窗口优先使用 `AppWindow`，通过 `shell` 配置其中的 `AppShell`；已有宿主窗口或需要嵌入时直接使用 `AppShell`。`AppNavigationBar` 是横向、纵向导航条的公共底层；`AppTopNavigationBar`、`AppBottomNavigationBar` 是横向实现，`AppSidebar` 是纵向 Rail 实现，`AppSidebarPane` 是承载相邻展开内容的通用面板；`AppRailButton` 是更细的壳层组成件，只在自定义壳层时单独使用。

`AppShellController` 持有 `activeNavigationKey` 和画布交互状态等可跨组件观察的壳层状态。`AppShell` 是受控视觉宿主：应用提供 `navigationItems`、`activeNavigationKey`、Pane 内容和画布内容，Shell 点击导航时只发送 `navigationRequested(key)`，不回写这些外部状态。点击后应打开 Pane、切换画布还是执行命令由应用决定。右侧内容由应用自行组合 `AppSidebarPane` 与所需内容组件。

Shell 相关对象按状态生命周期分工，不互相替代：

| 对象 | 职责 | 不承担 |
| --- | --- | --- |
| `AppShellController` | 保存可由 QML、C++ 服务共同观察的导航键和画布交互状态 | Pane 动画、Loader 和局部显示状态 |
| `AppShellRouteState` | 可选地保存对话框等全局壳层工作流目标及参数 | 普通导航选择和 Pane 展开状态 |
| `AppShell` | 呈现外部导航状态，管理 Pane 显隐、焦点、动画和内容宿主 | 持久化导航或业务路由状态 |
| `BaseRuntime` | 提供应用设置并向 QML 暴露 Shell Controller 引用 | 再保存一份导航状态 |

`AppNavigationBar` 提供 `orientation`、`leadingContent`、`content`、`trailingContent` 和 `itemDelegate`。设置 `content` 时使用调用方内容；未设置时由组件按 `orientation` 排列 `menuItems`，并使用派生组件提供的 `itemDelegate` 创建按钮；没有 delegate 时主体保持空白。`activeItemKey` 和 `itemTriggered(key)` 定义统一的受控菜单契约，具体按钮外观由派生组件实现。

`AppTopNavigationBar` 默认显示 `title` 和横向菜单，`AppBottomNavigationBar` 默认显示横向菜单，两者使用一致的边缘选中指示。`AppShell` 通过 `topNavigationBar` 和 `bottomNavigationBar` 暴露实际组件；应用直接配置对应导航栏的 `leadingContent`、`content`、`trailingContent`、`menuItems` 和 `activeItemKey`，并监听 `itemTriggered(key)`。底部栏在具有菜单、内容或操作时默认显示。

```qml
shell.topNavigationBar.menuItems: [
    { "key": "overview", "label": qsTr("概览"), "iconName": "scene" }
]
shell.topNavigationBar.activeItemKey: controller.topKey
shell.bottomNavigationBar.menuItems: [
    { "key": "tasks", "label": qsTr("任务"), "iconName": "background-task" }
]
shell.bottomNavigationBar.activeItemKey: controller.bottomKey

Connections {
    target: shell.topNavigationBar

    function onItemTriggered(key) {
        controller.handleTopItem(key)
    }
}
```

`AppSidebar` 将 `headerContent`、`footerContent` 分别映射到公共的 leading、trailing 插槽，并提供基于 `AppRailButton` 的纵向默认菜单和自身右侧分隔线。设置 `content` 时完全使用调用方内容；未设置时由 `menuItems` 生成默认菜单。默认在图标下方显示居中的单行省略文字，设置 `showItemLabels: false` 可切换为纯图标 Rail；两种模式下 Sidebar 宽度保持不变。默认菜单通过 `activeItemKey` 表达可选的互斥状态，通过 `itemTriggered(key)` 统一发送单击意图，因此也可用于不保持选中状态的动作项。

```qml
Shell.AppSidebar {
    menuItems: [
        { "key": "layers", "label": qsTr("图层"), "iconName": "layers" },
        { "key": "resources", "label": qsTr("资源"), "iconName": "resources" }
    ]
    activeItemKey: controller.activeKey
    onItemTriggered: function(key) {
        controller.triggerSidebarItem(key)
    }
}
```

`AppSidebar` 不绑定或创建展开面板。点击侧栏项目后是打开面板、切换画布还是执行一次命令，由 `itemTriggered(key)` 的处理方决定；`itemActivated(key, itemData)` 额外携带完整项目数据，供自定义宿主处理。Sidebar 自身通过 `opened`、`autoHideEnabled`、`autoHideSuspended`、`autoHideTriggerActive`、`revealDelay` 和 `hideDelay` 独立控制显隐；状态仍由调用方持有，组件通过 `openRequested(bool)` 发送变更请求。`occupiedWidth` 表示 Sidebar 当前应占用的布局宽度，自动隐藏模式下即使已经展开也为 `0`。

`AppSidebarPane` 通过 `content` 承载任意面板内容，也可通过 `source` 加载 QML URL，并负责相邻面板的位置、显隐动画、悬停桥接和可选自动隐藏；`source` 非空时优先，空值时使用 `content`。它不限定内容外观，`AppMenuPane` 只是可装入其中的一种内容。`displayMode` 使用 `Hidden`、`Pinned`、`AutoHide` 统一表达固定隐藏、固定显示和自动显隐；`opened` 是组件计算后的只读状态。内容默认在首次打开时创建，并在关闭后保留；设置 `retainContent: false` 可在关闭动画结束后卸载，设置 `loadOnDemand: false` 会在关闭状态下立即创建内容。内容尚未创建或已经卸载时，`paneItem` 为 `null`：

```qml
Shell.AppSidebarPane {
    anchors.fill: parent
    anchorItem: sidebar
    displayMode: Shell.AppSidebarPane.AutoHide
    retainContent: true
    triggerActive: sidebar.effectiveHovered
    content: Component {
        Menus.AppMenuPane {
            paneController: controller.activePaneController
        }
    }
}
```

`anchorItem` 与 `AppSidebarPane` 应处于同一个父级坐标系；面板通过 `gap` 始终贴近该锚点的内侧边缘。`gap` 和上下 `inset` 默认读取 `shell.shellOverlayMargin`；Pane 最外层使用 `colors.borderPane` 绘制 1px 低对比轮廓。`triggerActive` 只在 `AutoHide` 模式下用于接入 Sidebar 或其它宿主触发区；面板自身和间隔桥接区的鼠标状态由 `AppSidebarPane` 自动合并，延迟判断交给 `AppAutoHideController`。需要临时保持显示或隐藏时，直接把 `displayMode` 切换为 `Pinned` 或 `Hidden`；返回 `AutoHide` 后自动显隐恢复。`reveal()`、`dismiss()` 只在 `AutoHide` 模式下立即改变临时状态。方向通过 `edge` 设置，当前支持左、右侧。

`AppShell.sidebar` 暴露窗口左侧实际使用的 `AppSidebar`，`sidebarOpen` 持有其显隐状态，`sidebarOpenRequested(bool)` 回传自动显隐请求。应用通过 `shell.sidebar.autoHideEnabled` 独立启用 Sidebar 自动隐藏；`AppShell.leftContentInset` 只读取 `sidebar.occupiedWidth`，不受 Pane 自动隐藏影响。`sidebarAutoHideTriggerActive` 用于扩展 Sidebar 的触发范围，`sidebarAutoHideSuspended` 用于暂停 Sidebar 自动隐藏；Shell 已提供窗口左边缘鼠标触发区。

`AppShell.sidebarPane` 暴露相邻的 `AppSidebarPane`。应用通过 `leftPaneDisplayMode` 选择 Pane 的 `Hidden`、`Pinned` 或 `AutoHide`，通过只读 `leftPaneOpen` 观察实际状态。`showLeftPane(mode)`、`hideLeftPane()` 和 `toggleLeftPane(mode)` 是供自定义 Sidebar 直接调用的显隐命令；省略 `mode` 时显示或恢复为 `Pinned`。这些命令不修改导航键、Pane 内容或画布路由。画布交互期间，Shell 会把配置为 `AutoHide` 的 Pane 临时解释为 `Pinned`，交互结束后恢复自动显隐。该模式不改变 Sidebar 是否浮动或占用画布宽度；Sidebar 与 Pane 的显隐仍彼此独立。

`AppShell.navigationItems` 只消费 `key`、`label`、`iconName` 等导航显示字段。`activeNavigationKey` 表达当前选中项，点击始终发送 `navigationRequested(key)`。应用通过 `leftPaneContent` 注入一个已经配置完整的 Pane `Component`，也可通过 `leftPaneSource` 加载 QML URL；`leftPanelWidth` 设置 Pane 宽度。

Pane 导航可在应用宿主中按受控协议处理；状态先提交给 Controller，Pane 显隐继续使用 Shell 命令：

```qml
shell.navigationItems: controller.navigationItems
shell.activeNavigationKey: controller.activeNavigationKey

Connections {
    target: shell

    function onNavigationRequested(key) {
        if (controller.activeNavigationKey === key && shell.leftPaneOpen) {
            controller.activeNavigationKey = ""
            shell.hideLeftPane()
            return
        }

        controller.activeNavigationKey = key
        shell.showLeftPane()
    }
}
```

画布导航同样由应用在 `navigationRequested(key)` 中提交 `activeNavigationKey`，并让 `canvasDelegateSource` 绑定 Controller 派生结果。切换 URL 后旧 Loader 内容会被释放，页面状态应由外部模型持有。`AutoHide` 临时收回 Pane 不改变选中项。

标准表单菜单使用 `AppMenuModel` + `AppMenuPane`。`AppMenuPane` 会把字段编辑交给 `paneController.handleFieldEdited()`，把操作交给 `paneController.handleAction()`；`menuKey` 只用于标识操作来源，调用方不要在 QML 中再建立一份同步状态。菜单区块默认使用局部 `paneSpacing + controlGap` 间距，不修改全局 `paneContentSpacing`。菜单总标题和 Form 标题默认显示使用 `borderHeaderDivider` 的实心分隔线；分隔线与标题使用 `headerSpacing`，正文仍使用标准 Pane 间距，Form 可显式设置 `showHeaderDivider: false` 关闭。`AppForm.surfaceMode` 默认使用移除背景、圆角、外框、额外内边距和区块尾部分隔线的 `Flat`，需要卡片容器时显式设置 `Section`。字段之间默认不显示分隔线，密集字段列表可在 Form 或 Section 上显式设置 `showFieldDividers: true` 开启。`AppFormSection` 会在任一字段值实际变化时发送 `fieldValueChanged(fieldKey, value)`，`AppForm` 会转发其所有 Section 的同名信号；该信号同时覆盖 `setFieldValue()` 和直接修改 `AppField` 的情况。

任务面板直接消费 `TaskManager`：

```qml
TaskView.AppTaskPanel {
    taskItems: taskManager.tasks
    activeTaskCount: taskManager.activeTaskCount
}
```

`TaskManager::registerTask()` 只接受在 Manager 线程创建的堆对象；注册成功即把所有权转交给 Manager。调用方不得在 `unregisterTask()` 或 `clearTasks()` 后自行 `delete` / `deleteLater()`：返回 `true` 只表示移除请求已接受，运行中的 WorkerThread Task 会先收到取消请求，并在 worker 返回后再从 Manager 移除和延迟删除。`WorkerThread` 的 `start()` 在 Manager 私有线程池执行，`cancel()` 在 Manager 所在线程执行，因此 Task 实现必须让取消操作保持非阻塞，并能与 `start()` 安全并发；取消标志必须保持 sticky，`start()` 不得清除已经到达的取消请求。

`AppTaskPanel` 根据 `taskItems` 展示任务状态、进度和详情，并通过 `activeTaskCount` 汇总活跃数量；任务对象和生命周期由 `TaskManager` 持有。

业务工具栏、时间线、地图、图层和业务对话框不放入 UICore；通过 `AppShell` 的内容插槽或上层应用组件注入。

## 6. 交互与兼容

- 交互信号使用 `...Requested`、`...Edited`、`...Triggered`；调用方负责把意图提交到状态所有者。
- `AppToggleControl` 直接使用 Qt `Switch` 的 `checked` 和无参数 `toggled()`；处理信号时读取 `checked`。
- `AppSelect` 使用 Qt `ComboBox` 原生键盘语义：弹层关闭时方向键和 `Home`/`End` 直接选择，空格开关弹层；弹层打开时方向键移动高亮，空格或回车确认，Escape 关闭。
- Segmented 和 Choice 支持方向键、`Home`、`End`、空格和回车。
- 弹层由所属控件负责打开、定位和收起，不在外部重复维护可见状态。
- 需要点击面板空白处清除焦点时，设置 `AppPanel.clearFocusOnBackgroundTap`。
- `AppSurface.sizeToContent: true` 只用于直接内容的隐式尺寸不依赖 Surface 的场景；内容使用 `anchors.fill`、水平双边锚定、居中锚定或外部已确定 Surface 尺寸时，设置 `sizeToContent: false`。
- 提供 `animated` 的组件在设为 `false` 时关闭自身管理的颜色、透明度、尺寸和位移动画；调用方注入的子组件仍由其自身动画属性控制。
- `AppIcon.mipmap` 默认关闭；图标持续缩放或旋转且实际显示质量需要时再显式开启。已经预着色或需要保留原色的图标设置 `tintSource: false`，其余图标保留默认主题着色。
- `AppIcon.animateColor` 和 `AppTextField.animateTextColor` 默认开启；颜色表达数据值时关闭对应动画。
- Style 属性使用 `UiStyle` 枚举，不传名称字符串或无语义裸数字。
- 公共 QML alias、C++ include 和枚举数值属于兼容接口；变更前先检查 `CHANGELIST.md`。
