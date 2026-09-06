# 页面回归检查

复用 UICore 的 QuickTest runner，页面直接加载当前源码，不需要启动设备后端：

```powershell
cmake -S UICore_new -B build/uicore-ui-review -DCMAKE_PREFIX_PATH=C:/Qt/5.15.2/msvc2019_64
cmake --build build/uicore-ui-review --config Release
$env:PATH = 'C:/Qt/5.15.2/msvc2019_64/bin;' + $env:PATH
$env:QT_QPA_PLATFORM = 'offscreen'
$env:QT_QUICK_BACKEND = 'software'
$env:QT_QPA_FONTDIR = 'C:/Windows/Fonts'
& build/uicore-ui-review/verification/Release/UICoreQmlTests.exe -input App/verification -o build/ui-pages-tests.txt,txt
ctest --test-dir build/uicore-ui-review -C Release --output-on-failure
```

Qt 路径按本机安装位置调整。测试覆盖名称与地址搜索、在线筛选、无结果时的选中状态、紧凑模式、分类切换，以及 1180 / 1700 宽度下编辑区的边界和返回概览。另覆盖 296 / 740 宽度下的指令名称显示、毫秒时间格式，以及 680 宽度下触发规则展开、收起和操作入口的边界。680 / 1100 宽度下检查点击规则文字、空白和启停开关均不打开编辑窗口，只有菜单中的“编辑”打开对应规则。密集事件检查覆盖标签分层、点击区域不重叠、溢出合并，以及移除重叠事件后恢复紧凑行高。指令集检查覆盖最窄编辑区右侧面板的默认 6 条指令、无参数直接添加、有参数先配置、添加时间和目标设备、播放期间禁用，切换至无指令设备、点击设备轨道保留当前面板、点击已有指令切换至时间轴指令面板，以及长列表选中定位。1180 / 1700 宽度下使用真实鼠标点击指令分段切换器的中央和边缘，检查双向切换、指令列表显示、条目选择及左右方向键切换。编辑状态下左右空间由轨道与指令面板使用，返回概览后恢复时间轴列表。测试不执行设备指令，也不写入方案。

该 runner 未注册 App 的 `deviceicon` 图片提供器，因此设备用例会出现 `Invalid image provider` 提示；图标需要在完整应用中检查。完整应用在首次显示前定位最左侧屏幕。

2026-09-06：Qt 5.15.2 / MSVC 2019 Release 下页面测试 15 项（含初始化与清理）通过，UICore 的 3 项 CTest 通过。相同环境的 UICore Standalone 在修改前后均有 28 条既有绑定循环，0 条递归布局、0 条 QML 加载或类型错误；不将该启动检查记录为通过。
