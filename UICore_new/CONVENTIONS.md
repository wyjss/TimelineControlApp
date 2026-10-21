# UICore 代码与使用约定

本文档是 UICore 的代码风格和接入约定。组件选择和调用方式见 [COMPONENT_GUIDE.md](COMPONENT_GUIDE.md)。目录、公共 API、主题机制或构建方式变化时，必须在同一次修改中更新本文档。

## 1. 边界与目录

- UICore 只包含跨项目通用能力，不包含具体业务名称、流程和数据。
- 公共头文件放在 `include/UICore/<领域>`，实现放在 `src/<领域>`。
- QML 放在 `qml`，图标放在 `assets`，资源清单放在 `resources`。
- 只建立一个 `UICore` 编译库，包含公共 C++ 类型、QML、主题、图标和资源初始化；Fields、Style、Forms、Shell、Task 只保留源码逻辑层，不分别建立 target。
- 源码依赖方向保持为 `Fields/Style -> Forms -> Shell`，Task 不依赖 Forms 或 Shell；除 `AppIcon` 的内部绘制项外，C++ 层不依赖 QML 文件或 Qt Quick 类型。

## 2. C++

- 使用 C++17、Qt 5.14 和一个根命名空间 `UICore`；CMake target 名称不形成 C++ 子命名空间。
- 类型使用 `PascalCase`，函数和变量使用 `camelCase`，私有成员使用 `m_` 前缀。
- 指针和引用写作 `Type *value`、`const Type &value`。
- `.cpp` 首先包含自己的公共头文件，随后按 Qt、标准库分组。
- UICore 的 `.cpp` 在所有 include 后统一使用 `using namespace UICore;`，不使用文件级 `namespace UICore { ... }` 包裹；命名空间自由函数在定义处保留 `UICore::` 限定。
- 对外头文件统一使用安装式路径，例如：

```cpp
#include <UICore/Forms/AppForm.h>
```

- 类和函数的大括号独占一行；短小的单语句判断可以省略大括号。
- setter 先比较新旧值，无变化立即返回；变化后只发送必要的 `...Changed` 信号。
- 暴露给 QML 的稳定属性使用 `Q_PROPERTY`，按语义选择 `FINAL`、`CONSTANT` 和 `NOTIFY`。
- 通用视觉、皮肤和布局枚举统一定义在 `UICore::UiStyle`，使用 `enum class` 和显式数值。
- 表面语义、文本语义和排版角色是封闭的公共集合，分别使用 `UiStyle::SurfaceTone`、`UiStyle::TextTone` 和 `UiStyle::TypographyRole`。
- 字段渲染类型定义为 `AppField::Kind`；Form 结构枚举定义在 `UICore::UiForm`，不放入 `UiStyle`。
- `BaseField` 是字段数据和约束的唯一来源；`AppField` 只保存 UI 描述，并通过内部或外部 `BaseField` 代理公共字段属性，不复制两份状态。
- `BaseField.required` 只表达必填标记；校验规则和时机由调用方持有，错误通过 `errorText` 输入，`valid` 只表示 `errorText` 是否为空。Section 和 Form 只聚合该状态，不生成错误文案。
- `valueType` 决定字段写回类型，`editorHint` 决定推荐编辑器，`options` 提供候选值，`allowCustomValue` 决定候选值之外的内容是否可输入。
- 枚举默认行为在实际消费位置通过 `switch/default` 表达，不为单次使用增加归一化辅助函数。
- QObject 所有权优先使用 parent；观察外部 QObject 时使用 `QPointer`。
- 实现保持最小，不为单次调用增加辅助函数，不做与当前修改无关的格式化。
- `.h`、`.cpp` 使用 UTF-8；修改已有注释时保持原注释语言。

## 3. QML

- 文件名和公共组件名使用 `App` 前缀及 `PascalCase`，根对象统一使用 `id: root`。
- 使用 4 空格缩进；属性、只读派生属性、信号、函数、视觉子项依次组织。
- 可派生状态使用 `readonly property`，避免保存可由其他状态计算出的重复数据。
- 通用交互事件使用明确语义，如 `...Requested`、`...Edited`、`...Triggered`。
- 受控状态组件只发送编辑意图，不直接写入调用方提供的 `value`、`activeNavigationKey` 等状态；调用方接受后负责回写。
- `AppTreeList.selection` 使用原生 `ItemSelectionModel` 的共享可写协议；视图直接更新选择，外部与视图使用同一个模型，不额外复制选中集合。
- `AppTreeList` 的交互信号传递模型索引；可选的双击分支展开由组件处理，节点类型和打开动作由外部决定。
- `AppTreeList.contentY` 和 `visibleRowCount` 是只读视图状态；滚动偏移以内容顶部为零，通过 `scrollToContentY(y)` 显式恢复，保存值和恢复时机由外部持有。
- 通用 Style 枚举通过 `import UICore.Style 1.0` 使用，例如 `UiStyle.LayoutMode.Horizontal`；QML 不重复定义。
- 通用字段通过 `import UICore.Fields 1.0` 创建，字段类型使用 `AppField.Kind.TextField`。
- `AppField.sourceField` 绑定外部 `BaseField` 后直接读写该对象；不在 QML 或 C++ 中增加额外同步层。
- `AppSelect` 只负责封闭选择；允许自定义值的候选输入由 `AppTextField` 提供。
- 手工字段使用 `AppFieldBlock` 表达单个字段行，使用 `AppFieldForm` 组织多个字段；需要表面、标题或折叠能力时由 `AppSection` 或 `AppPanel` 承载，不新增字段 Pane 包装组件。
- `AppFieldControl` 只负责渲染单个 `AppField`；`AppFormContent` 负责 Form/Section 组织并复用 `AppFieldControl`。
- 没有字段 schema 的静态 UI 直接使用 Base 控件，不为其额外创建 `AppField`。
- 纯 QML 的通用 Style 枚举属性使用 `int` 保存，默认值和赋值均使用对应的 `UiStyle` 枚举常量。
- 皮肤只替换固定视觉角色对应的主题 Token 值；颜色、尺寸等内部 Token 名称继续使用字符串。
- 尺寸、颜色、字体、圆角和动画必须读取主题 Token，组件内部不得为缺失主题或缺失 Token 提供字面值回退。
- QML 资源路径是公共接口，修改 `.qrc` alias 前必须确认兼容性。

### 性能与资源

- 重型可选内容使用 `Loader`，小型固定视觉对象直接创建；Loader 不持有业务状态，并明确创建、卸载和关闭动画期间的保留条件。
- UICore 内部已确定尺寸、无内容承载且不处理交互或焦点的背景使用 `AppSurfaceChrome`；需要内容测量、交互、焦点处理或缩放能力时继续使用 `AppSurface`。`AppSurfaceChrome` 属于 `internal`，不作为公共组件提供。
- 大型或无界数据使用 `ListView`，需要同时显示的少量项目保留 `Repeater`；静态类型分支优先使用可由 `qmllint` 检查的 `Component`。
- 尺寸依赖保持单向；`anchors.fill` 或 Layout 已确定尺寸时关闭 `sizeToContent`，同一属性不同时参与 Layout、内容尺寸和动画反馈；`GridLayout` 的 `columns`、`rows` 不直接读取自身正在由 Layout 分配的尺寸，需要响应尺寸时从外层尺寸派生并延迟提交结构变化。
- Animation、Behavior 和 Timer 只用于实际变化且具有明确结束条件的状态；mipmap、离屏染色和视觉特效按实际需要开启。
- 性能修改使用相同场景比较对象或 delegate 数量、布局警告、帧时间和内存；不只依据进程工作集，Standalone Gallery 仅作为综合压力场景。

### 主题

主题由应用窗口持有一次。独立应用优先使用已经持有默认主题的 `AppWindow`：

```qml
import "qrc:/UICore/qml" as Ui

Ui.AppWindow {
}
```

自定义宿主窗口使用当前标准主题：

```qml
ApplicationWindow {
    property QtObject appTheme: Theme.AppTheme {}
}
```

- `AppWindow` 默认持有 `Theme.AppTheme`；UICore 组件从所属 `ApplicationWindow` 自动读取 `appTheme`。
- 不在组件上声明 `theme` 属性，不编写 `theme: root.theme`，不向 Loader 项手动注入主题。
- `appTheme` 是必需依赖，且必须完整提供 `colors`、`density`、`metrics`、`shell`、`shape`、`motion`、`typography`、`controlStyles`、`icons` 和 `z`。
- 背景颜色 Token 统一使用 `background...` 前缀：`backgroundWindow`、`backgroundCanvas`、`backgroundSurface`、`backgroundSection`、`backgroundControl` 及对应 Overlay 变体。
- 按钮微浮是可选装饰，`AppButton.raised` 默认关闭。开启时由主题的 `buttonRaised...` Token 控制渐变、边缘和状态强度；关闭时不读取这些新增 Token，自定义主题未启用微浮时无需补充它们。
- 具有正文结构的非状态型弹出窗口外壳使用 `SurfaceTone.Popup`；Dialog 的同级输入区、参数区和结果区使用 `AppDialogSection`（`SurfaceTone.DialogSection`），输入控件保持默认 `SurfaceTone.Control`。同一 Dialog 中的同级内容块不混用其它背景 tone。
- Alert、Toast 和局部状态块使用 Success、Warning、Info、Danger 等状态 tone；下拉选项等不包含内容分区的轻量浮层可使用 `SurfaceTone.SurfaceOverlay`。
- 自定义组件需要直接读取 Token 时使用窗口主题，不提供本地回退值；缺少主题或 Token 时应直接暴露 QML 错误。
- 组件尚未归属窗口时只使用不可见的中性初始化值，不读取主题 Token；归属窗口后仍缺少 `appTheme` 时必须明确报错，中性值不构成运行期主题回退。
- 主题组件会保留最后一次取得的有效窗口主题，避免 `AppPopup` 关闭时视觉项暂时脱离窗口而丢失主题；业务组件不需要手动传递主题。
- Qt Quick Controls Style 由宿主程序选择；UICore 不在库内部强制设置。示例程序使用 `Basic`。

## 4. 接入

```cmake
add_subdirectory(path/to/UICore)
target_link_libraries(MyApp PRIVATE UICore)
```

创建 `QQmlEngine` 前初始化静态资源：

```cpp
#include <UICore/UICore.h>

UICore::initialize();
```

常用 QML 导入：

```qml
import UICore.Forms 1.0
import UICore.Fields 1.0
import UICore.Style 1.0

import "qrc:/UICore/qml" as Ui
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/components/field" as Field
import "qrc:/UICore/qml/theme" as Theme
```

## 5. 修改检查

- 新文件是否位于正确领域，是否引入了业务耦合。
- 新公共 C++ 文件、QML 注册或资源初始化实现是否加入 `UICore`。
- 新 QML、JS 或图标是否加入对应 `.qrc`。
- 是否保持公共 include 路径和 QML alias 稳定。
- 是否误加了逐层主题传递或重复状态。
- 约定发生变化时是否同步更新本文档。
- 公共组件、属性、信号或推荐用法变化时是否同步更新 `COMPONENT_GUIDE.md`。
- 公共 QML/C++ 用法发生变化时是否同步更新 `CHANGELIST.md`。
- 顶层测试默认开启、作为子项目默认关闭；新增契约接入现有 QtTest 或 QuickTest runner，不依赖 Gallery 目测。
- 至少完成 Release 构建和完整 CTest；涉及 QML 时再完成针对性 `qmllint` 与启动检查。
