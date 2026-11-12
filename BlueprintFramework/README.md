# BlueprintFramework

BlueprintFramework 是 TimelineControlApp 的 CMake 子项目，可单独配置和构建。`BlueprintCore` 提供节点类型注册、图文档编辑和 JSON 保存加载。每次有效编辑提交后，文档通过 `changed` 发送一次变更通知。架构见[数据结构与变更通知](docs/data-model.md)。

在主工程生成的 Visual Studio 解决方案中，将 `BlueprintFramework-demo` 设为启动项目并运行。`BlueprintFramework` 项目构建可供其他目标链接的 `BlueprintCore` 静态库。

`BlueprintQuick` 提供可嵌入的 QML 编辑器和按文档共享的编辑会话。宿主链接 `BlueprintQuick`，为一份 `GraphDocument` 创建一个 `GraphEditSession`，然后让各个 `GraphEditor` 使用同一个会话。QML 使用 `import "qrc:/BlueprintQuick" as Blueprint`，宿主提供主题颜色、节点库和属性面板。会话应先于编辑器创建，并在文档销毁前结束。

使用 Qt 5.14 或以上的 Qt 5 和与其匹配的编译器。以 Windows 上的 Visual Studio 2019 和 Qt 5.14 为例，在工程目录运行：

```powershell
cmake -S . -B build -G 'Visual Studio 16 2019' -A x64 '-DQt5_DIR=C:/Qt/Qt5.14.0/5.14.0/msvc2017_64/lib/cmake/Qt5'
cmake --build build --config Release --target BlueprintFramework-demo
$env:PATH = 'C:\Qt\Qt5.14.0\5.14.0\msvc2017_64\bin;' + $env:PATH
.\build\demo\Release\BlueprintFramework-demo.exe
```

打开 Demo 会看到 `12 + 30 → 42`。点击左侧节点库添加节点，拖动标题调整位置。可从输出端口拖到输入端口，也可以依次点击两个端口。连线悬停时会高亮，点击选中后按 Delete 删除。右键连线或已连接的输入端口会打开菜单，选择「删除连线」后断开。选中常量后，在右侧输入数值并按回车或点击应用。工具栏提供撤销、重做、打开和保存。

左侧节点库还提供「字符串常量」和「选项常量」。添加后在右侧输入文本，或从「自动 / 手动」中选择。两种常量都可接到「文本结果」。选项输出并保存稳定值 `auto` 或 `manual`。缺少输入或存在循环时，该节点显示 `—`。独立构建仍可运行 `BlueprintExample` 命令行示例检查核心编辑与通知。

初始画布右侧有两个「模拟音箱」。点击下方「手动触发」的运行按钮，流程沿绿色执行线设置目标音箱的测试时长，再调用测试播放。「读取属性」沿数据线把播放状态传给「状态结果」，定时结束时结果自动更新。测试播放由定时器模拟。

左侧「已有对象」提供宿主管理的音箱 A 和音箱 B。点击或拖到画布空白处放置卡片，重复放置会定位已有卡片。选中卡片后可在右侧更换绑定，若目标已有卡片则保留原绑定。操作节点可直接绑定这两台音箱，移除卡片后仍能调用音箱。

从左侧节点库添加「读取属性」后，在右侧选择目标对象，再选择该对象公开的属性。属性决定输出类型；切换到不同类型前需要断开输出连线。也可以把音箱上带箭头的成员拖到画布空白处，直接生成绑定好的节点。拖动时长会弹出读取和设置两项。设置节点的数值输入未连线时使用右侧的输入值。对象绑定、连线和输入值随图保存，播放状态和运行时写入的时长在当前运行实例中生效。

点击加法节点内的数值区域可展开说明，端口随布局移动，连线端点会同步更新。节点自定义内容的接入约定见[数据结构与变更通知](docs/data-model.md#从文档通知到-qml)。
