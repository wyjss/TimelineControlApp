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
.\build\blueprint\Release\BlueprintAsyncExample.exe
.\build\blueprint\demo\Release\BlueprintFramework-demo.exe

```

`BlueprintAsyncExample` 只需 Core。入口为内置加法节点提供两个输入（60 和 40），并触发等待时长节点。等待沿数据线读取加法结果作为时长。两个节点都通过执行器回调报告完成。

构建选项如下（源码接入同样生效，命令行示例仅独立构建时生成）：

| 选项 | 默认值 | 用途 |
| --- | --- | --- |
| `BLUEPRINT_BUILD_QUICK` | `ON` | 构建 Quick 编辑器，需要 Qt Quick 和 QuickControls2。 |
| `BLUEPRINT_BUILD_DEMO` | `OFF` | 构建示例宿主，需要 Quick、Qt Widgets 和相邻的 `UICore_new`。 |
| `BLUEPRINT_BUILD_EXAMPLE` | `ON` | 构建无界面的 Core 命令行示例。 |
| `BLUEPRINT_BUILD_TESTS` | `OFF` | 构建运行契约测试，需要 Qt Test。启用 Quick 时同时构建编辑器和撤销测试。 |

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

需要基础节点时，在宿主初始化时包含 `<Blueprint/BasicNodes.h>` 并调用 `Blueprint::registerBasicNodes(registry, implementations)`，将节点定义和运行实现加入现有注册表与实现表。它包含数值、字符串、选项、布尔常量，加法、比较、布尔运算和条件分支。类型 ID 沿用原 Demo 图中的 `demo.*`，原有端口和参数可直接读取。基础节点、对象操作和等待都通过按类型注册的 `Executor` 运行。宿主可以继续注册业务节点，并将合并后的实现表交给 `GraphRuntime::start`。

需要对象操作时，先注册可绑定对象的类型和成员，再调用 `registerObjectNodes`。宿主提供按引用解析稳定类型的函数，并用 `addObjectImplementations` 注入实时读写、接口调用和可选取消。框架由属性及接口声明派生端口，校验输入输出。接口参数的本地覆盖键由 `objectCallPortKey` 生成，和图中端口共用同一键。后置添加的接口可用连线及签名默认值，若需要本地编辑其覆盖值，应在注册对象节点前注册这些接口声明。

使用等待节点时，初始化调用 `registerWaitNodes`，启动执行时用 `addWaitImplementations` 注入计时器所属对象和可选的单调时钟。全局等待使用这次执行的时钟零点，相对等待从动作到达时计时。宿主可以为不同入口指定不同的时钟策略。

需要编辑器时，为一份 `GraphDocument` 创建一个 `GraphEditSession`，让多个 `GraphEditor` 共享会话。在加载 QML 前创建会话；会话初始化静态库中的 QML 资源，并应在文档销毁前结束。QML 使用：

```qml
import "qrc:/BlueprintQuick" as Blueprint

Blueprint.GraphEditor {
    session: graphSession
    colors: hostColors
}
```

默认节点库和属性面板使用正式类型元数据生成；宿主可传入 `palettePanel`、`inspectorPanel`，以及按 `typeId` 索引的 `nodeContents` 和 `nodeHeaders`。自定义标题与内容都接收 `node`，以 `implicitHeight` 提供高度，拖动仍由节点外壳处理。参数、属性和接口声明复用值类型及约束，宿主负责对象查找、实际属性读写和接口实现。

运行时接收 `document.snapshot()` 与按类型提供的 `RuntimeImplementations`。纯计算返回按输出端口键组织的数据；动作通过完成回调返回单个执行出口或要同时触发的多个出口，以及数据输出和诊断。图配置在下次启动时生效，宿主实时状态通过读取节点或宿主通知更新。需要同时预览和执行时使用不同的运行实例。详见[运行契约](docs/data-model.md#运行契约)。

## Demo 操作

打开 Demo 会看到 `12 + 30 → 42`。将左侧节点库条目拖到画布空白处创建，拖放时显示与落点对齐的标题预览；分类可收起、展开。拖动标题调整位置。从输出端口拖到输入端口，也可以依次点击两个端口。输入只有一条连线时，从该输入拖线可把原连线改接到另一输入。执行输入有多条连线时，先选中要改接的线，再从输入拖线。输出拖到已连接的数据输入会替换来源，拖到执行输入会添加连线。重连失败、释放到空白处或按 Esc 会保留原连线；重连成功可一次撤销。连线悬停时高亮，点击选中后按 Delete 删除。右键连线可删除该条连线，只有一条连线的输入也可以右键删除。拖线优先吸附合法输入，非法目标显示原因。画布支持 Ctrl+Z/Ctrl+Y，文本控件保留自己的编辑快捷键；Esc 或窗口失活取消当前手势，节点移动和平移恢复原位置。工具栏提供撤销、重做、打开和保存。

通用比较节点支持 `>`、`≥`、`<`、`≤`、`==`、`!=`。数值支持全部运算；同类型字符串和布尔值支持等于与不等于，其余运算和异类比较返回否。缺少输入时保持未求值。

在「流程控制」中拖入「条件分支」。把「比较」的输出接到「条件」，把「开始（手动）」或上一步的执行输出接到「执行」，再把「成立」接到「调用接口」的「执行」。运行时读取比较结果并沿对应出口继续；若「不成立」留空，该分支到此结束。

在「入口与事件」中拖入「开始（自动）」，每张图最多放置一个。将它的「继续」接到流程首个动作。工具栏「触发蓝图」调用 Demo 宿主的 `DemoGraph::trigger()`，从该入口启动。重复触发会重新开始自动流程并重置本次计时。

「入口与事件」还提供「开始（手动）」和「属性变化」。在右侧为「属性变化」选择模拟音箱和属性。属性的实际值改变后，通过「变化后的值」复合出口提供本次通知的数据，并启动一次独立执行，已有流程继续运行。监听「播放中」时，可以从该出口分别连到「条件分支」的「执行」和「条件」，再从「成立」接后续动作。编辑图中的属性配置不会触发事件。

从「流程控制」拖入「等待时长」，串接在两个执行节点之间。流程到达该节点时开始计时，默认 1000 毫秒。可在右侧填写整数毫秒，也可接入上游数据，接线时使用上游值。输入 0 立即继续。点击工具栏「停止」可结束当前图中已经启动的所有执行，并取消其中的等待。

「等待全局时间」使用本次自动入口的启动时刻作为零点。例如，目标为 5000 毫秒，执行在启动后第 3 秒到达时等待约 2 秒，到达时已满 5 秒则直接继续。目标可以在右侧填写或从数据线传入。来自手动或属性事件入口的流程使用「等待时长」。

要并发触发多个动作，可把同一个「继续」分别连接到它们的「执行」。各分支都收到执行信号，可同时等待异步结果。本次执行在所有分支完成后结束。分支可以读取前一步已产出的数据。某个动作需要另一动作的结果时，把两者沿执行线串接。旧图中已有的「同时触发」节点仍可执行。

多个执行输出也可以接到同一个「执行」输入，例如把「成立」和「不成立」都接到同一个清理动作。每收到一路信号，就触发一次。在同一次流程中，如果动作还在执行，后到的信号按到达顺序等待，每一路都执行一次。

节点库提供数值、字符串和选项常量。选中节点后在右侧编辑；选项保存稳定值 `auto` 或 `manual`。缺少输入或未配置属性时显示 `—`；实际求值失败显示诊断文本。

画布右侧的模拟音箱由 Demo 宿主管理。点击「开始（手动）」后，流程沿执行线设置测试时长，再调用测试播放；播放通过定时器异步完成。「读取属性」将宿主的实时播放状态传给「状态结果」，状态变化时更新预览。

左侧「已有对象」中的音箱 A 和音箱 B 可拖到画布空白处，列表标记已放置对象。重复放置会定位已有卡片；操作节点可直接引用音箱，移除卡片只删除图中的表示。对象的配置和播放状态继续归宿主管理。

「读取属性」在右侧选择目标和属性，属性声明决定端口类型。可把音箱成员拖到空白处生成绑定节点；可写属性提供读取和设置两项。设置节点未连线时使用配置派生的输入默认值。绑定、位置、连线和节点配置随图保存，实时状态不写回图文件。

「调用接口」选定目标和接口后，按签名显示数据端口。可从音箱成员直接拖出「按指定时长播放」，也可在右侧选择。「时长」接线时由上游提供，未接线时使用右侧填写的毫秒数或接口默认值，清空输入恢复默认。只有一个返回值的接口将结果口显示为复合出口，例如「按指定时长播放」结束后，从「播放时长」分别连接另一台音箱「设置属性」的执行输入和值输入。无返回值或多个返回值的接口保留独立的「继续」出口。这次播放的时长不修改源音箱的测试时长配置。切换同一接口的目标保留连线，换接口前须断开会消失的端口连线，包括独立的「继续」出口。

节点标题与节点库中的名称一致，沿用普通节点的单行标题高度；已有音箱使用对应节点库条目的「音箱 A／B」。对象及成员操作节点在正文顶部显示设备图标（若有）和设备名称，短标识放在下一行。设备信息块按完整对象引用固定生成标识色，选中边框独立表示当前节点。读取、设置、调用和监听的具体成员显示在设备信息下方。点击加法节点内的数值区域可展开说明，端口布局变化时连线同步。自定义内容的接入约定见[从文档通知到 QML](docs/data-model.md#从文档通知到-qml)。

复合输出口可分别连接数据输入与执行输入，线型由目标输入决定；读取数据或刷新预览不会触发执行。属性变化和单返回值接口已使用复合出口，原有「继续」连线需重新连接，不提供旧图迁移。执行中的动作和等待节点显示对应状态，错误节点显示失败提示；这些提示及实时状态均不保存到图文件。

Demo 保留调试阶段直接关闭窗口的行为；打开另一张图时仍确认丢弃未保存修改。合并记录和原有渲染测量见[工作记录](docs/work-log.md)。
