# BlueprintFramework

BlueprintFramework 是 TimelineControlApp 的 CMake 子项目，可单独配置和构建。`BlueprintCore` 提供节点类型注册和可编辑的图文档。每次有效编辑提交后，文档通过 `changed` 发送一次变更通知。QML 视图与运行时的接入设计见[数据结构与变更通知](docs/data-model.md)。

主工程生成的 Visual Studio 解决方案中，`BlueprintFramework` 项目构建 `BlueprintCore` 静态库，其他目标可链接 `BlueprintCore`。

使用 Qt 5.14 或以上的 Qt 5 和与其匹配的编译器。以 Windows 上的 Visual Studio 2019 和 Qt 5.14 为例，在工程目录运行：

```powershell
cmake -S . -B build -G 'Visual Studio 16 2019' -A x64 '-DQt5_DIR=C:/Qt/Qt5.14.0/5.14.0/msvc2017_64/lib/cmake/Qt5'
cmake --build build --config Release
$env:PATH = 'C:\Qt\Qt5.14.0\5.14.0\msvc2017_64\bin;' + $env:PATH
.\build\Release\BlueprintExample.exe
```

示例注册 `Constant` 和 `Display`，验证参数编辑、拒绝类型不匹配的连接，以及删除节点和关联线时只发布一批变更。其他 CMake 工程可通过 `add_subdirectory` 引入本项目并链接 `BlueprintCore`。
