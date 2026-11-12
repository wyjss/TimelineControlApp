# BlueprintFramework

BlueprintFramework 为宿主项目提供通用图编辑与图形化编程能力。TimelineControlApp 是接入方之一。Core 提供共享类型注册、受校验的图文档、JSON 读写、启动快照、按端口求值和异步执行；Quick 提供可嵌入的 QML 编辑器。Core 与 Quick 不依赖 Timeline 或 UICore，Demo 使用仓库内的 UICore 主题和控件。

详细契约见[数据结构与变更通知](docs/data-model.md)和[总体设计](../docs/blueprint-framework-design.md)。当前不提供旧接口适配或文件迁移，图文件只接受现行的 `version: 1` 格式。

## 构建和验证

使用 C++17、Qt 5.14 或以上的 Qt 5，以及与 Qt 匹配的编译器。以下命令从仓库根目录执行，Qt 路径替换为本机安装位置：

```powershell
$qtPrefix = 'C:/Qt/5.15.2--/msvc2019_64'
cmake -S BlueprintFramework -B build/blueprint -G 'Visual Studio 16 2019' -A x64 "-DCMAKE_PREFIX_PATH=$qtPrefix" -DBLUEPRINT_BUILD_TESTS=ON -DBLUEPRINT_BUILD_DEMO=ON
cmake --build build/blueprint --config Release
$env:PATH = "$qtPrefix/bin;" + $env:PATH
ctest --test-dir build/blueprint -C Release --output-on-failure
.\build\blueprint\Release\BlueprintExample.exe
.\build\blueprint\demo\Release\BlueprintFramework-demo.exe
```

构建选项如下（源码接入同样生效，命令行示例仅独立构建时生成）：

| 选项 | 默认值 | 用途 |
| --- | --- | --- |
| `BLUEPRINT_BUILD_QUICK` | `ON` | 构建 Quick 编辑器，需要 Qt Quick 和 QuickControls2。 |
| `BLUEPRINT_BUILD_DEMO` | `OFF` | 构建示例宿主，需要 Quick、Qt Widgets 和相邻的 `UICore_new`。 |
| `BLUEPRINT_BUILD_EXAMPLE` | `ON` | 构建无界面的 Core 命令行示例。 |
| `BLUEPRINT_BUILD_TESTS` | `OFF` | 构建文档投影与运行契约测试；当前测试集需要 Quick 和 Qt Test。 |

仅使用 Core 时设置 `-DBLUEPRINT_BUILD_QUICK=OFF`。仓库主工程已经加入 Core、Quick 和 Demo。Core 保留实际构建目标 `BlueprintFramework`，源码链接可使用 `BlueprintCore` 或 `Blueprint::Core`；可直接将 `BlueprintFramework-demo` 设为 Visual Studio 启动项目。

## 第三方接入

源码接入使用同一入口；只使用 Core 时配置 `BLUEPRINT_BUILD_QUICK=OFF`：

```cmake
add_subdirectory(path/to/BlueprintFramework blueprint)
target_link_libraries(MyCoreApp PRIVATE Blueprint::Core)

# BLUEPRINT_BUILD_QUICK=ON 时同一入口也提供编辑器。
target_link_libraries(MyQuickApp PRIVATE Blueprint::Quick)
```

也可独立构建、安装后通过 CMake 包接入：

```powershell
cmake --install build/blueprint --config Release --prefix C:/Libraries/BlueprintFramework
```

```cmake
find_package(BlueprintFramework REQUIRED)
target_link_libraries(MyApp PRIVATE Blueprint::Core)
# 安装时构建了 Quick 的包也提供 Blueprint::Quick。
```

配置使用方时，将安装前缀和 Qt 前缀加入 `CMAKE_PREFIX_PATH`。导出包包含公共头文件及静态库，不包含 Demo 或宿主业务服务；当前按源码和匹配工具链分发，不承诺跨编译器的二进制 ABI。

宿主在项目作用域持有 `NodeRegistry`，文档借用同一服务。注册表必须早于文档创建、晚于文档销毁；可在文档打开后追加新类型，重复类型 ID 被拒绝，已注册定义保持不变。类型追加会更新编辑器节点库，不修改图数据或撤销历史。

需要编辑器时，为一份 `GraphDocument` 创建一个 `GraphEditSession`，让多个 `GraphEditor` 共享会话。在加载 QML 前创建会话；会话初始化静态库中的 QML 资源，并应在文档销毁前结束。QML 使用：

```qml
import "qrc:/BlueprintQuick" as Blueprint

Blueprint.GraphEditor {
    session: graphSession
    colors: hostColors
}
```

默认节点库和属性面板使用正式类型元数据生成；宿主可传入 `palettePanel`、`inspectorPanel` 和按 `typeId` 索引的 `nodeContents`。参数、属性和接口声明复用值类型及约束，宿主负责对象查找、实际属性读写和接口实现。

运行时接收 `document.snapshot()` 与按类型提供的 `RuntimeImplementations`。纯计算返回按输出端口键组织的数据；动作通过完成回调返回执行出口、输出和诊断。图配置在下次启动时生效，宿主实时状态通过读取节点或宿主通知更新。需要同时预览和执行时使用不同的运行实例。详见[运行契约](docs/data-model.md#运行契约)。

## Demo 操作

打开 Demo 会看到 `12 + 30 → 42`。将左侧节点库条目拖到画布空白处创建，拖放时显示与落点对齐的标题预览；分类可收起、展开。拖动标题调整位置。从输出端口拖到输入端口，也可以依次点击两个端口。拖动已连接的输入时，会从原输出端口拉出连线，放到另一输入后改接到该输入；输出拖到已占用输入时替换该输入的来源。执行输出已有连线时，拖到新输入可更换目标；数据输出继续支持添加分支。重连失败、释放到空白处或按 Esc 会保留原连线；重连成功可一次撤销。连线悬停时高亮，点击选中后按 Delete 删除。右键连线或已连接的输入端口可删除连线。拖线优先吸附合法输入，非法目标显示原因。画布支持 Ctrl+Z/Ctrl+Y，文本控件保留自己的编辑快捷键；Esc 或窗口失活取消当前手势，节点移动和平移恢复原位置。工具栏提供撤销、重做、打开和保存。

通用比较节点支持 `>`、`≥`、`<`、`≤`、`==`、`!=`。数值支持全部运算；同类型字符串和布尔值支持等于与不等于，其余运算和异类比较返回否。缺少输入时保持未求值。

节点库提供数值、字符串和选项常量。选中节点后在右侧编辑；选项保存稳定值 `auto` 或 `manual`。缺少输入或未配置属性时显示 `—`；实际求值失败显示诊断文本。

画布右侧的模拟音箱由 Demo 宿主管理。点击「手动触发」后，流程沿执行线设置测试时长，再调用测试播放；播放通过定时器异步完成。「读取属性」将宿主的实时播放状态传给「状态结果」，状态变化时更新预览。

左侧「已有对象」中的音箱 A 和音箱 B 可拖到画布空白处，列表标记已放置对象。重复放置会定位已有卡片；操作节点可直接引用音箱，移除卡片只删除图中的表示。对象的配置和播放状态继续归宿主管理。

「读取属性」在右侧选择目标和属性，属性声明决定端口类型。可把音箱成员拖到空白处生成绑定节点；可写属性提供读取和设置两项。设置节点未连线时使用配置派生的输入默认值。绑定、位置、连线和节点配置随图保存，实时状态不写回图文件。

点击加法节点内的数值区域可展开说明，端口布局变化时连线同步。自定义内容的接入约定见[从文档通知到 QML](docs/data-model.md#从文档通知到-qml)。

Demo 保留调试阶段直接关闭窗口的行为；打开另一张图时仍确认丢弃未保存修改。合并记录和原有渲染测量见[工作记录](docs/work-log.md)。
