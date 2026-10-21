# UICore 上层同步变更清单

本文档只记录当前仍需要上层应用同步的公共用法变化。已完成迁移的历史记录由 Git 保存；当前正式用法以 [README.md](README.md)、[CONVENTIONS.md](CONVENTIONS.md) 和 [COMPONENT_GUIDE.md](COMPONENT_GUIDE.md) 为准。

截至 2026-09-08，资源页树列表滚动调用、Shell 受控导航变更和启用微浮的自定义主题仍需由上层应用同步。

## 记录规则

- 只有删除、重命名或改变公共 C++/QML 接口、资源路径、默认行为且需要上层改代码时才新增记录。
- 每条记录必须说明受影响接口、当前替代用法、上层修改动作和最低验证要求。
- 最新变更放在最前；所有已维护项目完成同步后，删除对应迁移记录，并把稳定用法收口到组件指南或约定。
- 纯内部实现、行为等价修复和不要求调用方修改的优化不进入本文件。

## 当前待同步变更

### 资源页树列表通过显式方法恢复滚动

仍在写入 `AppTreeList.contentY` 的资源页需改用 `scrollToContentY(savedY)`；读取 `contentY` 及监听 `onContentYChanged` 可继续用于保存位置。该只读属性以内容顶部为零，组件内部处理底层 ListView 的 `originY`；不要再访问内部视图读写滚动位置。外部应在模型、展开状态和视图尺寸就绪后恢复，组件不会保存提前提交的恢复请求。

树区域高度和无展示行判断可使用只读 `visibleRowCount`，它统计当前根索引下展开后的全部行，包含视口外的行。此次补充接口不要求已正常使用现有公共接口的页面调整代码。

最低验证要求：资源页加载无缺失属性或只读属性写入错误；滚动后离开并重建页面可恢复位置；覆盖插删行、展开／收起、切换根索引和空模型时的高度与空状态。

### 微浮按钮的自定义主题增加边框颜色

启用 `AppButton.raised` 的自定义主题需补充 `colors.buttonRaisedBorder`，标准值为 `Qt.rgba(0.62, 0.74, 1, 0.18)`；细边框宽度复用已有的 `shape.buttonRaisedEdgeWidth`。使用标准 `AppTheme` 或未启用微浮的应用无需调整。

最低验证要求：补充 Token 后启动应用，确认微浮按钮无缺失颜色错误，并检查普通、悬停、按下和键盘聚焦状态的边框。

### AppShell 改为受控导航宿主

`AppShell.navigationRoutingEnabled`、`NavigationDestination` 和 `NavigationActivation` 已删除。导航项不再通过 `source`、`destination` 和 `activation` 让 Shell 自动改写 `activeNavigationKey`、`leftPaneSource` 或 `canvasDelegateSource`；点击只发送 `navigationRequested(key)`，应用接受后把状态提交给 `AppShellController`，再按应用语义控制 Pane 或画布。

`AppSidebar.itemActivated(key, itemData)` 继续保留给自定义宿主读取完整导航项，但 `AppShell` 不再消费该信号。`AppShell.leftPaneSource` 和 `canvasDelegateSource` 也继续保留；删除的是由导航项 `source` 自动写入它们的路由行为。

EarthUI 的 `app/shared/qml/AppShellHost.qml` 后续同步时：

- 删除 `routedNavigationItems`，直接设置 `navigationItems: root.navigationItems`。
- 删除 `navigationRoutingEnabled: true`，不再给导航项补 `destination` 和 `activation`。
- 在 `onNavigationRequested` 中处理 Pane Toggle：当前项且 Pane 已打开时先调用 `shell.hideLeftPane()`，再清空 Controller 的 `activeNavigationKey`；其它情况先提交新 key，再调用 `shell.showLeftPane()`。
- 同一批同步其内嵌 UiCore 副本中的 `qml/AppShell.qml`、Standalone 示例和组件指南，避免新 Shell 与仍在设置已删除属性的旧宿主同时运行。

`AppShellHost.qml` 的导航绑定和处理器改为：

```qml
navigationItems: root.navigationItems
activeNavigationKey: root.activeNavigationKey

onNavigationRequested: function(key) {
    if (!root.resolvedShellController)
        return

    if (root.activeNavigationKey === key && shell.leftPaneOpen) {
        shell.hideLeftPane()
        root.resolvedShellController.activeNavigationKey = ""
        return
    }

    root.resolvedShellController.activeNavigationKey = key
    shell.showLeftPane()
}
```

TimelineControlApp 当前已经在 `onNavigationRequested` 中提交 `TimelineShellController.activeNavigationKey`，且 `canvasDelegateSource` 由 Controller 状态派生，不使用自动路由接口，无需修改代码。

最低验证要求：同步 UiCore 副本后完成 Release 构建；对 `AppShell.qml` 和应用 Shell 宿主执行 `qmllint`；启动后覆盖切换到其它导航项、再次点击当前项关闭 Pane、Pane 隐藏后重新打开，以及 Controller 观察者收到最终导航状态。
