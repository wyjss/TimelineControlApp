# UICore 当前实现事项与决策

本文档只保留尚未完成的实现事项、需要长期遵守的保留决策和当前验证基线。已解决问题及过程数据由 Git 保存，不在当前文档重复维护。

## 1. 当前基线

- 兼容基线为 C++17、Qt 5.14 和 `UICore` 根命名空间。
- 静态界面使用 Base 组件；只有数据由字段 schema 驱动时才使用 `AppField`、Field 和 Form 组件。
- 依赖方向保持为 `Fields/Style -> Forms -> Shell`；Task 不依赖 Forms 或 Shell。
- 2026-08-15 使用 Qt 5.14.2 完成 Release 全量构建和三项 CTest，全部通过。
- 同次 Standalone 检查结果为 0 条 binding loop、0 条递归布局警告和 0 条 QML 加载错误。
- 性能修改只有在相同场景取得对象数、帧时间、CPU/GPU 或内存对照后才记录收益。

## 2. 当前执行队列

| 编号 | 事项 | 优先级 | 当前下一步 |
| --- | --- | --- | --- |
| IMPL-QML-001 / IMPL-PERF-001 | 收口尺寸依赖 | P1 | 将 `sizeToContent` 收敛为单一独立内容根，迁移后删除 `AppControlBase` 剩余子项扫描和 `contentRevision`；继续验证 Field、PaneHeader、PaneBase |
| IMPL-THEME-001 | 清理组件样式字面值 | P2 | 区分主题值、数据值、比例和 Canvas 计算常量，为静态检查建立明确白名单 |
| IMPL-RUNTIME-001 | 补齐 `BaseRuntime` Shell 销毁通知 | P1 | 覆盖设置、替换、置空和外部销毁，确保必要的 `shellChanged()` 只发送一次 |
| IMPL-TASK-003 | 避免活动 Task 与历史对象重复保留 | P2 | 在不改变历史顺序和数量上限的前提下调整归档时机，并记录对象数和内存对照 |
| IMPL-TASK-004 | 清理 `AppTaskPanel` 失效展开状态 | P2 | 任务移除后只保留现存 taskId，覆盖持续添加、展开和移除场景 |
| IMPL-FORM-001 | 收口 Form 标题分隔线默认语义 | P2 | 统一 QObject/Map 在 Section、Flat、Bare 模式下的默认值和显式覆盖语义 |
| IMPL-PERF-005 | 复核 `AppField` 内部回退字段成本 | 暂缓 | 只有取得对象、绑定和内存对照，并保持 `sourceField` 销毁后的安全回退时才实施 |
| IMPL-PERF-006 | 复核剩余无效动画对象 | P2 | 只处理有对象数、帧时间或 CPU 数据证明收益的分支 |
| IMPL-BUILD-001 | 精简无效 CMake 自动化和依赖查找 | P2 | 验证 standalone 开关 ON/OFF 后删除无输入的 AUTOUIC/AUTORCC，并按目标查找依赖 |
| IMPL-STYLE-001 | 收口 Task 状态样式契约 | P1 | 建立 C++ Task 枚举到 QML 呈现的稳定映射，删除裸数字和重复状态字符串 |
| IMPL-QML-008 | 收口剩余无行为可写属性 | P2 | 确认无外部写入后，将 TaskPanel 计数改为只读派生属性 |

### 尺寸事项的当前状态

- 历史 `AppControlBase` binding loop 和 Gallery 的 Toast、Popup、响应式 Grid 警告已经归零。
- `sizeToContent: true` 只适用于直接内容根的隐式尺寸不依赖宿主尺寸的场景。
- `AppFieldControl`、`AppPaneHeader` 和 `AppPaneBase` 仍需分别覆盖填充宽度、文字换行、窗口缩放和展开折叠。
- `AppScrollPane.availableContentHeight` 由 `AppDialog` 消费，不属于无行为属性。

## 3. 保留决策

以下实现经过兼容性或运行成本复核，没有新的证据和完整验收前不再作为普通“简化”项处理。

| 范围 | 当前决策 |
| --- | --- |
| Base 与 Field 边界 | Base 组件保持静态、通用且不依赖 `AppField`；Field/Form 只承载 schema 驱动的数据渲染 |
| IMPL-MODEL-001 / QObject 与 Map | `AppFormContent`、`AppMenuPane` 等正式路径优先 QObject；Map 兼容读取集中在边界适配，不向 Base 扩散 |
| IMPL-SHELL-004 / `AppRailButton` | 与 `AppButton` 的布局和状态语义不同，保留独立实现 |
| IMPL-SHELL-005 / Shell 状态分层 | 保留 `AppShellController`、可选 `AppShellRouteState` 和 `BaseRuntime`；`AppShell` 只作为受控视觉宿主，不恢复自动路由或第二份导航状态 |
| IMPL-FIELD-001 / renderer | `AppFieldControl` 保留静态 `Component` 分支，使 QML 可由 `qmllint` 检查；不改成字符串 URL 动态加载 |
| IMPL-RENDER-001 / 图标与 Canvas | Qt 5.14 下保留 `ColorOverlay` 动态主题染色和小型 Canvas glyph；只有 profiler 确认为热点后才替换 |
| IMPL-PERF-002 / 数据列表 | 大型或无界数据使用 `ListView`，同时显示的少量项目保留 `Repeater`，不为小数据额外增加虚拟化状态机 |
| IMPL-KEEP-001 / `ThreadRunnable` | Qt 5.14 没有 `QRunnable::create()`，保留当前实现 |
| IMPL-KEEP-001 / `AppPopup` | 保留 reveal 状态和 `_retainedTheme`，用于显现动画与关闭期间的主题连续性 |
| IMPL-PERF-005 / `AppField.sourceField` | 直接代理 `BaseField` 是字段状态来源；内部回退字段负责 source 销毁后的安全状态 |
| `AppTextField` 候选弹层 | 首次使用后保留轻量弹层骨架，关闭时清空 ListView 模型并释放选项 delegate；只有实测保留成本高于重复创建成本时才改为关闭后卸载 |

## 4. 统一验收

- 代码修改至少完成 Qt 5.14 Release 构建。
- 涉及 QML 时执行针对性 `qmllint`、相关 QuickTest 和 Standalone 启动检查。
- 启动日志不得新增 QML error、binding loop 或递归 Layout。
- 尺寸修改覆盖窗口缩放、文字换行、可见项变化和展开折叠。
- 交互修改覆盖鼠标、触摸、键盘、焦点、无障碍、只读和禁用状态。
- 弹层修改覆盖点击外部、Escape、焦点转移、关闭动画和 Loader 卸载。
- 受控组件覆盖调用方接受与拒绝用户意图两条路径。
- 公共推荐用法变化同步 `COMPONENT_GUIDE.md`；上层必须改代码时同步 `CHANGELIST.md`。

## 5. 维护规则

- 本文件不是轮次日志，只记录当前事实。
- 新事项沿用现有 `IMPL-*` 编号体系，并进入当前执行队列。
- 事项完成且当前契约已写入 README、约定或组件指南后，从本文件删除。
- 暂缓或保留项必须写明继续实施所需的证据或前置条件。
