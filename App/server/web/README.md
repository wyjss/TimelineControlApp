# 网页节目播控

该目录包含一个基于 `cpp-httplib` 的本地 HTTP 服务和无外部依赖的响应式网页。服务复用现有 `TimelineRuntime`，所有运行时读取和播控操作都会切回 Qt 主线程执行。

## 功能

- 查看当前方案、播控状态、主时钟和节目进度
- 查看节目库、触发规则状态、指令数量、执行状态和节目时长
- 查看当前节目的指令时间、目标设备、执行参数、持续时间、状态和错误信息
- 选择播控设备并与 C++ `TimelineManager::playbackDevices` 双向同步
- 编排并应用播放队列
- 开始、暂停、继续、停止播放，并手动触发等待中的节目
- 停止时拖动进度条选择队列第一条节目的起播时间，之前的指令跳过，后续节目从 0 开始
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
- `POST /api/v1/control`：`action` 为 `start`、`pause`、`resume`、`stop` 或 `trigger`；手动触发时同时传入 `timelineId`；`start` 可传入 `startTimeMs`（毫秒，默认 0）和 `timelineIds`

启用令牌后，请求需带 `Authorization: Bearer <token>` 或 `X-Control-Token: <token>`。
