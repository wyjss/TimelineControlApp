# UICore 协作约束

本文件约束在 UICore 仓库中的代码与文档修改。详细编码规则以 [CONVENTIONS.md](CONVENTIONS.md) 为准，组件选择与调用方式以 [COMPONENT_GUIDE.md](COMPONENT_GUIDE.md) 为准。

## 修改原则

- 只修改当前任务直接相关的文件；需要扩大范围时先说明原因并征得确认。
- 保持已有编码、换行风格和有用注释；修改注释时保持原语言。
- 使用满足需求的最小实现，不为单次调用新增辅助函数。
- 存在更简单写法时采用更简单写法，不顺带重构、格式化或重命名无关代码。
- 性能修改遵循 `CONVENTIONS.md` 的“性能与资源”约定；没有同场景前后数据时不记录性能或内存收益。
- UICore 只承载跨项目通用能力，不引入业务名称、业务流程或业务数据。

## 代码边界

- C++17、Qt 5.14 和 `UICore` 根命名空间是兼容基线。
- 依赖方向保持为 `Fields/Style -> Forms -> Shell`；Task 不依赖 Forms 或 Shell。
- 公共 C++ 接口位于 `include/UICore`，实现位于 `src`。
- 上层应用不直接导入或调用任何 `internal` 路径。
- 颜色、尺寸、字体、圆角和动画读取主题 Token，不在组件内增加字面值回退。
- 静态 UI 使用 Base 组件；只有数据由字段 schema 驱动时才使用 `AppField`。

## 修改前后

1. 先读 [README.md](README.md)；代码修改再读 [CONVENTIONS.md](CONVENTIONS.md)，组件调用再读 [COMPONENT_GUIDE.md](COMPONENT_GUIDE.md)。
2. 新增公共文件时同步 CMake 或 `.qrc`；保持公共 include 路径和 QML alias 稳定。
3. 公共组件、属性、信号或推荐用法变化时同步 `COMPONENT_GUIDE.md`。
4. 上层应用必须调整调用方式时同步 [CHANGELIST.md](CHANGELIST.md)。
5. 代码修改至少完成 Release 构建；涉及 QML 时再执行针对性 `qmllint` 和启动检查。
6. 只在实际执行验证后记录通过结果。
