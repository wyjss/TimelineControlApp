# 网页节目播控

该目录包含一个基于 `cpp-httplib` 的本地 HTTP 服务和无外部依赖的响应式网页。服务复用现有 `TimelineRuntime`，所有运行时读取和播控操作都会切回 Qt 主线程执行。

## 功能

- 查看当前方案、播控状态、主时钟和节目进度
- 查看节目库、触发规则状态、指令数量、执行状态和节目时长
- 查看当前节目的指令时间、目标设备、执行参数、持续时间、状态和错误信息
- 选择播控设备并与 C++ `TimelineManager::playbackDevices` 双向同步
- 选中节目与加入队列分离，显式加入、移除、排序和清空队列；已入队节目显示角标
- 单节目与队列分别开始、暂停、继续和停止，队列为空时隐藏队列面板
- 停止时拖动进度条选择当前节目的起播时间，之前的指令跳过；播放队列从第一项的 0 开始
- 运行时显示实际主节目，切换所选节目不改变正在播放的节目；完成后可再次播放
- 播放队列及顺序随桌面方案保存，重新载入后保持停止；旧方案载入为空队列
- 手动触发等待中的节目
- 查看设备类型与设备上报状态
- 可选 Bearer 访问令牌；默认仅建议监听本机地址

## 使用

模块已接入应用入口和构建目标。启动桌面程序后访问：

`http://127.0.0.1:8080`

服务默认仅允许本机访问，并随桌面程序退出而停止。

局域网访问时可在 `App/main.cpp` 中改为监听 `0.0.0.0`，并建议在启动前设置访问令牌：

```cpp
webControlServer.setAccessToken(QStringLiteral("请替换为随机令牌"));
webControlServer.start(QStringLiteral("0.0.0.0"), 8080);
```

## HTTP API

- `GET /api/v1/status`：完整播控快照
- `POST /api/v1/queue`：请求体为 `{ "timelineIds": ["..."] }`
- `POST /api/v1/playback-devices`：请求体为 `{ "deviceIds": ["..."] }`
- `POST /api/v1/control`：支持下表中的 `action`

| action | 参数及行为 |
| --- | --- |
| `select` | `timelineId`：改变所选节目，不改变队列和正在播放的节目 |
| `start-current` | 可选 `timelineId` 和 `startTimeMs`（毫秒，默认 0）；播放当前节目，不修改队列 |
| `start-queue` | 始终播放已编排的队列，从第一项的 0 开始 |
| `pause` / `resume` / `stop` | 可选 `source` 为 `current` 或 `queue`；来源不匹配时拒绝操作，省略时控制全局播放 |
| `trigger` | `timelineId`：手动触发等待中的节目 |
| `start` | 兼容原有队列启动接口；可传 `timelineIds` 和 `startTimeMs`，不传队列时使用已编排队列 |

启动仅允许停止或完成状态，编排队列仅允许停止状态。快照中的 `currentTimelineId` 表示所选节目，`playbackTimelineId` 表示实际主节目，`queuePlayback` 表示当前会话是否来自队列。队列播完但触发节目仍在运行时，主节目为空、`queuePlayback` 保持 `true`。

方案格式升级为版本 6，时间线管理器格式为版本 3。继续兼容之前支持的方案版本 2、3、5 和管理器版本 1、2；旧版程序不能读取新格式方案。

启用令牌后，请求需带 `Authorization: Bearer <token>` 或 `X-Control-Token: <token>`。
