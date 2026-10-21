# 组件内存验证

该验证在独立进程中分别创建 1 个和多个同类组件，统计 Windows Private Working Set：

- `FirstInstanceMB`：创建首个实例前后的增量，包含该组件及其内部 QML 类型的首次加载成本。
- `IncrementPerInstanceKB`：从 1 个扩展到 `ManyCount` 个后的平均后续单实例增量。
- `EstimatedAllPageMB`：按 `FirstInstanceMB + (AllPageCount - 1) * IncrementPerInstanceKB` 估算 `all` 页面中该类组件的占用。
- `EstimatedAllPageProcessMB`：空场景与所有 `EstimatedAllPageMB` 的合计，记录在 `metadata.txt`。

`components.csv` 中可通过 `Profile` 为同一组件选择测试属性，通过 `PreloadUrl` 在正式测量前创建依赖。`probe` 行用于定位 Qt Controls 的共享首次成本，不计入 `all` 页面估算；其中 `AppSelectAfterQtComboBox` 记录预热原生 ComboBox 后 AppSelect 的剩余成本。

Release 构建并运行全部组件：

```powershell
.\verification\memory\verify-component-memory.ps1 `
    -BuildDirectory build `
    -Configuration Release
```

只验证指定组件：

```powershell
.\verification\memory\verify-component-memory.ps1 `
    -BuildDirectory build `
    -Configuration Release `
    -Component AppIcon,AppText
```

脚本只支持 Windows。测试窗口固定显示在最左侧屏幕，子进程不创建控制台。结果保存到 `build/verification/component-memory/<时间戳>/`。

脚本在正式测量前逐组件运行一次预热进程，确保首实例和多实例进程使用相同的 QML 磁盘缓存条件。

内存结果受 Qt 版本、显卡驱动、DPI、字体缓存和系统负载影响，只能比较同一环境、同一配置下的结果。`all` 页面估算会把各类型的首次加载成本相加，其中可能重复包含共享初始化；该结果用于解释综合压力场景，不代替实际页面工作集测量。
