# UICore

UICore 是面向多个 Qt Quick 项目的通用 UI 基础模块。

代码风格、主题和接入约定见 [CONVENTIONS.md](CONVENTIONS.md)。
组件选择、数据流和最小用法见 [COMPONENT_GUIDE.md](COMPONENT_GUIDE.md)。
仓库级协作约束见 [AGENTS.md](AGENTS.md)。
当前实现事项、保留决策和验证基线见 [IMPLEMENTATION_ISSUES.md](IMPLEMENTATION_ISSUES.md)。
上层应用当前仍需同步的公共用法变化见 [CHANGELIST.md](CHANGELIST.md)。

## 编译库

UICore 只生成一个 `UICore` 静态库，包含全部公共 C++ 类型、QML、主题、图标和资源初始化，不拆分 Core 与 Quick 编译目标。

## Standalone 组件陈列

UICore 作为顶层项目编译时默认生成 `UICoreStandalone`。示例按 Shell、基础控件、输入、容器、反馈和 Field/Form 分类加载，避免同时创建全部演示组件：

```powershell
cmake -S . -B build
cmake --build build --config Release

# Visual Studio 等多配置生成器
.\build\Release\UICoreStandalone.exe

# Ninja 等单配置生成器
.\build\UICoreStandalone.exe
```

单配置生成器需要在配置时追加 `-DCMAKE_BUILD_TYPE=Release`。

作为其它项目的子目录时，standalone 默认不参与构建；也可以通过 `-DUICORE_BUILD_STANDALONE=OFF` 显式关闭。

Release 构建和启动日志使用统一脚本验证：

```powershell
.\tools\verify-standalone.ps1 -BuildDirectory build -Configuration Release
```

脚本会记录 Qt 版本、生成器、Git 状态和程序日志到 `build/verification`。Standalone 在 `--smoke-test` 模式下运行 5 秒后自行退出；发现 QML 错误、binding loop 或递归布局警告时脚本返回失败。

## 自动化测试

UICore 作为顶层项目时默认启用 `UICORE_BUILD_TESTS`，作为子项目时默认关闭。测试包含一个 QtTest 契约可执行程序和一个调用 `UICore::initialize()` 的 QuickTest runner：

```powershell
cmake -S . -B build -DUICORE_BUILD_TESTS=ON
cmake --build build --config Release
ctest --test-dir build -C Release --output-on-failure
```

需要在上层工程显式验证 UICore 时可打开该选项；默认接入不会引入 QtTest 或 QuickTest 依赖。

Windows 下的组件内存验证会分别测量首实例占用和后续单实例增量，并按 `all` 页面实例数生成估算结果：

```powershell
.\verification\memory\verify-component-memory.ps1 -BuildDirectory build -Configuration Release
```

测试窗口固定显示在最左侧屏幕，结果写入 `build/verification/component-memory`。该测试不接入 CTest，避免把机器负载、显卡驱动和字体缓存导致的波动当作功能回归；详细指标定义见 [verification/memory/README.md](verification/memory/README.md)。

## 源码分层

- `Fields`：基础字段模型、通用 UI 字段 schema 和单字段渲染。
- `Style`：通用视觉、皮肤和布局语义。
- `Forms`：表单结构、布局和菜单模型。
- `Shell`：通用应用壳层、导航和 Pane。
- `Task`：独立任务模型及任务面板。

这些是源码逻辑层，不分别建立编译库。依赖方向为 `Fields/Style -> Forms -> Shell`，Task 不依赖 Forms 或 Shell；除 `AppIcon` 的内部绘制项外，C++ 层不依赖 QML 或 Qt Quick 类型。

## 目录

- `include/UICore`：对外公开头文件。
- `src`：按领域组织的 C++ 实现。
- `qml`：主题、基础组件及上层组件。
- `assets`：图标等静态资源。
- `resources`：Qt 资源清单。
- `verification`：QtTest、QuickTest 和 CTest 契约测试。

## 接入

```cmake
add_subdirectory(path/to/UICore)
target_link_libraries(MyApp PRIVATE UICore)
```

创建 `QQmlEngine` 前注册静态资源：

```cpp
#include <UICore/UICore.h>

UICore::initialize();
```

通用 Style 枚举以 `UiStyleEnums.h` 为唯一来源：

```cpp
#include <UICore/Style/UiStyleEnums.h>

auto mode = UICore::UiStyle::LayoutMode::Horizontal;
auto tone = UICore::UiStyle::SurfaceTone::Section;
```

```qml
import UICore.Style 1.0

property int layoutMode: UiStyle.LayoutMode.Horizontal
property int surfaceTone: UiStyle.SurfaceTone.Section
property int textTone: UiStyle.TextTone.Primary
property int styleRole: UiStyle.TypographyRole.BodyM
```

通用 UI 字段可在 C++ 或 QML 中创建，字段类型由 `AppField::Kind` 定义：

```cpp
#include <UICore/Fields/AppField.h>

auto kind = UICore::AppField::Kind::TextField;
```

```qml
import UICore.Fields 1.0
import "qrc:/UICore/qml/components/field" as Field

AppField {
    id: nameField
    kind: AppField.Kind.TextField
    label: "名称"
}

Field.AppFieldControl {
    fieldData: nameField
}
```

`AppField` 默认使用内部 `BaseField` 保存字段数据，也可以通过 `sourceField` 直接代理已有的 `BaseField`；代理模式不复制字段值。

Text、Int 和 Double 字段可以把 `options` 作为可编辑候选值：

```cpp
auto *field = new UICore::BaseField(parent);
field->setValueType(UICore::BaseField::IntType);
field->setEditorHint(UICore::BaseField::SelectEditor);
field->setOptions({30, 60, 90});
field->setAllowCustomValue(true);
```

`allowCustomValue` 默认为 `false`。`EnumType` 和封闭选择使用 `AppSelect`；允许自定义值时，Text 字段使用带候选下拉的 `AppTextField`，Int/Double 字段使用 `AppNumberField`。

当前 QML 资源路径保持兼容：

```qml
import "qrc:/UICore/qml/components/base" as Base
import "qrc:/UICore/qml/components/field" as Field
import "qrc:/UICore/qml/theme" as Theme
import "qrc:/UICore/qml" as Ui
```

独立应用优先使用 `AppWindow` 作为标准宿主。它持有默认主题和一个填满窗口的 `AppShell`：

```qml
import "qrc:/UICore/qml" as Ui

Ui.AppWindow {
    visible: true
    shell.applicationTitle: qsTr("应用")
}
```

自定义宿主窗口仍须持有唯一且完整的主题上下文。当前 `Theme.AppTheme` 同时是标准主题和默认主题，UICore 组件会从所属窗口自动读取，不需要逐层传递：

```qml
ApplicationWindow {
    id: window

    property QtObject appTheme: Theme.AppTheme {}

    Ui.AppShell {
        anchors.fill: parent
    }
}
```

组件不会为缺失的颜色、尺寸、字体、圆角或动画 Token 提供本地回退值。未设置 `appTheme` 或主题 Token 不完整时会直接产生 QML 错误，便于在接入阶段发现问题。

`AppShell` 仅保留通用壳层能力。业务工具栏通过 `topNavigationBar.content`、`topNavigationBar.trailingContent` 注入，时间线、方案文件等业务内容不属于 UICore。
