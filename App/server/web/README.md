# 网页节目播控

该目录包含一个基于 `cpp-httplib` 的本地 HTTP 服务和无外部依赖的响应式网页。服务复用现有 `TimelineRuntime`，所有运行时读取和播控操作都会切回 Qt 主线程执行。

## 功能

- 查看当前方案、播控状态、主时钟和节目进度
- 查看节目库、触发规则状态、指令数量、执行状态和节目时长
- 查看当前选中节目的指令时间、目标设备、执行参数、状态和错误信息
- 选择设备范围并与桌面共用 `filterDeviceIds`、`filterGroupNames`、`filterDeviceTypes`；网页显示类型分组条件，点选设备时保留已有分组条件，重置时清空三者
- 独立控制范围外指令的灰显/隐藏与播放执行；开启执行过滤后，播放期间锁定范围，显示方式仍可调整
- 显示桌面端编排的队列，支持移除、排序和清空队列；已入队节目显示角标
- 单节目与队列分别开始、暂停、继续和停止，队列为空时隐藏队列面板
- 停止时拖动进度条选择当前节目的起播时间，之前的指令跳过；播放队列从第一项的 0 开始
- 顶部显示所有运行中的时间线，区分主节目与触发节目，分别展示进度、剩余时间及暂停状态；切换所选节目仅改变指令查看对象
- 播放队列及顺序随桌面方案保存，重新载入后保持停止；旧方案载入为空队列
- 手动触发未运行的节目，不受整体播放状态限制
- 运行中的节目显示“停止”按钮，仅停止该时间线后续指令下发并回到停止状态，不发送设备停止指令；整体暂停时也可操作
- 运行中的节目在操作区左侧显示“同步船上音频”，沿用操作密码确认，将船上音频同步到该时间线的当前播放位置；整体暂停时禁用
- 查看设备类型与设备上报状态
- 可选 Bearer 访问令牌；当前应用入口默认监听全部 IPv4 网卡，未配置令牌

## 使用与外部接入

模块已接入应用入口和构建目标，服务与桌面程序共用 `TimelineRuntime`，并随桌面程序退出而停止。

当前 `App/main.cpp` 调用无参 `webControlServer.start()`，实际使用头文件默认值 `0.0.0.0:8080`，监听全部 IPv4 网卡；入口未调用 `setAccessToken()`，因此当前默认不校验访问令牌。启动失败时只输出警告，不会阻止桌面程序启动。

- 本机访问：`http://127.0.0.1:8080`
- 其他机器访问：`http://<运行桌面程序的主机IP>:8080`，需网络可达且防火墙允许该端口
- `0.0.0.0` 是监听地址，调用方应使用实际主机 IP

对外接入时，可在 `App/main.cpp` 中启动服务之前设置令牌，并显式指定监听地址：

```cpp
webControlServer.setAccessToken(QStringLiteral("请替换为随机令牌"));
if (!webControlServer.start(QStringLiteral("0.0.0.0"), 8080))
    qWarning("Failed to start web control server");
```

仅本机调用时将监听地址设为 `127.0.0.1`。目前地址、端口和令牌由 C++ 入口设置，没有对应的命令行、环境变量或 HTTP 配置入口；服务运行期间调用 `setAccessToken()` 不会生效。

## HTTP API 总览

以下为当前代码已经注册的全部业务接口：

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| GET | `/api/v1/status` | 获取方案、节目、指令、设备、队列和筛选设置的完整快照 |
| POST | `/api/v1/queue` | 整体替换播放队列，可用于加入、移除、排序和清空 |
| POST | `/api/v1/device-filter` | 更新设备筛选条件、执行过滤开关和显示方式 |
| POST | `/api/v1/control` | 选择节目、播放、暂停、继续、停止、触发节目和同步船上音频 |

另有静态资源 `GET /`、`GET /index.html`、`GET /assets/app.css`、`GET /assets/app.js`，用于网页界面，不属于业务 API。

### 通用约定

- POST 请求体为 JSON 对象，调用方应发送 `Content-Type: application/json`；请求体大小上限为 64 KiB。
- JSON 响应使用 `application/json; charset=utf-8`，业务响应带 `Cache-Control: no-store`。
- 时间字段使用毫秒；ID 使用字符串，从状态快照获取，不使用节目或设备名称代替 ID。
- 四个业务接口都复用相同的可选鉴权。配置令牌后，发送 `Authorization: Bearer <token>` 或 `X-Control-Token: <token>` 任一请求头；未配置令牌时无需鉴权。静态资源不校验令牌。
- 成功返回 HTTP 200 和完整状态快照，包含 `ok: true`。三个写接口也返回快照，而非仅返回操作结果。
- HTTP 200 表示接口操作被接受，不代表后续设备指令已经成功；指令执行结果需继续查询快照中的 `commands[].state` 和 `error`。船上音频同步没有独立的执行结果查询接口。
- 网页、桌面和外部调用共享状态，队列、选中节目、播控和筛选设置的修改会相互可见。修改队列不会自动保存方案文件。

### 1. 查询状态：GET /api/v1/status

无请求参数，返回全部节目及设备，没有分页或按 ID 单独查询的接口。

| 顶层字段 | 类型 | 含义 |
| --- | --- | --- |
| `ok` | boolean | 成功时为 `true` |
| `planName` | string | 当前方案名称 |
| `playbackState` | string | 全局播放状态：`stopped`、`running`、`paused`、`completed` |
| `currentTimeMs` | number | 全局主时钟时间 |
| `currentTimelineId` | string | 当前选中、用于查看的节目 ID；无选中项时为空字符串 |
| `playbackTimelineId` | string | 实际主节目 ID；无主节目时为空字符串 |
| `queuePlayback` | boolean | 当前会话是否来自队列 |
| `queueIndex` | number | 当前播放的队列索引，从 0 开始；无有效当前项时为 -1 |
| `playQueue` | string[] | 按播放顺序排列的节目 ID |
| `filterDeviceIds` | string[] | 当前设备 ID 筛选条件 |
| `filterGroupNames` | string[] | 当前自定义设备组筛选条件 |
| `filterDeviceTypes` | string[] | 当前设备类型筛选条件 |
| `executionFilterEnabled` | boolean | 是否只执行筛选范围内的播放指令 |
| `showFilteredOut` | boolean | 界面是否显示范围外的设备和指令 |
| `timelines` | object[] | 全部节目，结构见下表 |
| `devices` | object[] | 全部设备，结构见下表 |

`timelines[]`：

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `id` / `name` | string | 节目 ID / 名称 |
| `state` | string | `stopped`、`waiting`、`running`、`completed` |
| `currentTimeMs` | number | 节目内播放位置 |
| `durationMs` | number | 节目时长，取最后一条指令的触发时刻 |
| `queuePosition` | number | 在编排队列中的位置，从 0 开始；未入队为 -1 |
| `commands` | object[] | 该节目的指令 |
| `triggers` | object[] | 该节目的过点触发规则 |

`timelines[].commands[]`：

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `id` / `name` | string | 时间线指令 ID / 指令名称 |
| `deviceId` | string | 目标设备 ID |
| `matchesFilter` | boolean | 目标设备是否符合当前筛选条件 |
| `startTimeMs` | number | 指令在节目内的触发时间 |
| `executionParameters` | object[] | 非空执行参数的展示值，每项为 `{ "name": "参数名称", "value": "参数值" }`，`value` 保留 JSON 数据类型；不包含参数键、完整定义或空值 |
| `state` | string | `idle`、`running`、`succeeded`、`failed`、`skipped` |
| `error` | string | 指令错误信息，无错误时通常为空字符串 |

`timelines[].triggers[]` 包含字符串 `id`、`locatorId`、`fenceId`、`targetTimelineId`，数字 `heading`（航向角，度），布尔值 `enabled`（规则是否启用）、`active`（当前是否激活）、`touched`（当前激活周期是否已触发）。

`devices[]` 包含字符串 `id`、`name`、`type`，布尔值 `online`（设备上报状态）、`matchesFilter`（是否匹配当前筛选）。当前快照不包含设备的组名列表、连接地址或设备指令定义，也没有单独的组列表接口。

全局暂停时，时间线自身的 `state` 仍可为 `running`，应结合顶层 `playbackState` 判断。`currentTimelineId` 和 `playbackTimelineId` 可不同；切换选中项不会切换实际主节目。队列播完但触发节目仍在运行时，主节目为空，`queuePlayback` 仍为 `true`，`queueIndex` 为 -1。

### 2. 编排队列：POST /api/v1/queue

```json
{
  "timelineIds": ["timeline-a", "timeline-b"]
}
```

- `timelineIds` 按数组顺序整体替换原队列；只保留传入的节目，传空数组可清空队列。
- ID 去除首尾空格后必须非空、互不重复，并且全部已经存在。
- 仅全局 `stopped` 状态允许修改；`running`、`paused`、`completed` 均拒绝。完成后需要先调用 `stop`，才能修改队列。
- 非空或重复 ID 的校验失败返回 400 `invalid_queue`；节目不存在或状态不允许返回 409 `queue_rejected`。
- 当前实现对 `timelineIds` 缺失或非数组的情况会转换为空数组，停止状态下可能清空队列；调用方应始终明确传入字符串数组。

### 3. 设备筛选：POST /api/v1/device-filter

```json
{
  "deviceIds": ["device-a"],
  "groupNames": [],
  "deviceTypes": [],
  "executionFilterEnabled": true,
  "showFilteredOut": true
}
```

| 可选字段 | 类型 | 含义 |
| --- | --- | --- |
| `deviceIds` | string[] | 选择指定设备，ID 必须存在 |
| `groupNames` | string[] | 按自定义设备组选择，精确匹配组名 |
| `deviceTypes` | string[] | 按设备类型选择，精确匹配快照中的 `devices[].type` |
| `executionFilterEnabled` | boolean | `true` 时仅执行范围内的播放指令，范围外指令记为 `skipped` |
| `showFilteredOut` | boolean | `true` 时界面显示范围外项目，`false` 时隐藏 |

- 仅修改请求中出现的字段；某一条件传空数组表示清空该条件，省略字段则保留原值。三个条件必须全部为空才表示不限制设备。
- 设备 ID、自定义组、设备类型之间按并集匹配，满足任一条件即可通过；同名自定义组和设备类型是独立条件。
- 数组元素必须是非空字符串，单个数组内不能重复；类型或开关不合法返回 400 `invalid_filter`。设备 ID 不存在返回 400 `invalid_devices`；组名和类型不会检查是否存在。
- 全局非 `stopped` 状态下，传入 `executionFilterEnabled` 会被拒绝，即使传入值与当前值相同；当前已开启执行过滤时，传入任一范围条件也会被拒绝。返回 409 `devices_locked`，`completed` 状态同样受限。
- 未开启执行过滤时，播放期间仍可修改筛选条件；`showFilteredOut` 始终可改。
- 此接口不会裁剪状态接口返回的数组；外部界面需自行使用 `matchesFilter` 和 `showFilteredOut` 决定如何展示。

只清空全部范围条件、保留两个开关时，请求体为：

```json
{ "deviceIds": [], "groupNames": [], "deviceTypes": [] }
```

### 4. 播控操作：POST /api/v1/control

请求体必须包含 `action`；根据操作附加对应参数：

| action | 参数 | 行为与限制 |
| --- | --- | --- |
| `select` | `timelineId` 必传 | 选择已存在的节目供查看，任何全局状态均可；不改变队列或实际主节目 |
| `start-current` | `timelineId`、`startTimeMs` 可选 | 只播放指定或当前选中的节目，不修改编排队列；传入 ID 时也会改变选中项；仅全局 `stopped` 或 `completed` 可启动 |
| `start-queue` | 无 | 播放已编排的非空队列，从第一项的 0 毫秒开始；仅全局 `stopped` 或 `completed` 可启动；不使用 `startTimeMs` |
| `start` | `timelineIds`、`startTimeMs` 可选 | 原有队列启动方式；非空 ID 数组会替换编排队列并播放，省略或空数组使用现有队列；从第一项指定时间开始，后续项从 0 开始；仅全局 `stopped` 或 `completed` 可启动 |
| `pause` | `source` 可选 | 仅全局 `running` 可暂停 |
| `resume` | `source` 可选 | 仅全局 `paused` 可继续 |
| `stop` | `source` 可选 | 仅全局非 `stopped` 时接受；停止全部时间线，保留编排队列，按已有设备配置下发系统停止指令 |
| `trigger` | `timelineId` 必传 | 从 0 手动触发指定节目；节目必须存在且自身不处于 `running`，不限制全局状态；不将其设为主节目，不修改编排队列 |
| `stop-timeline` | `timelineId` 必传 | 仅停止指定 `running` 时间线的调度，整体暂停时也可操作；不发送设备停止指令，其他时间线继续；停止队列当前项会结束本轮队列推进并保留队列列表 |
| `sync-ship-audio` | `timelineId` 必传 | 将船上音频同步至指定节目的当前位置；要求该时间线与全局状态均为 `running`；没有匹配的船上音频指令时也可返回成功 |

参数及副作用：

- `startTimeMs` 为节目内起播时间，单位毫秒，省略时为 0。调用方应传非负整数，并控制在节目时长以内；早于起播时间的指令跳过。
- `source` 只对 `pause`、`resume`、`stop` 生效：`queue` 要求 `queuePlayback == true`，`current` 要求 `queuePlayback == false`；省略或空字符串不检查来源，其他值会被拒绝。
- `source` 仅校验当前会话来源；暂停、继续、整体停止均控制全局时钟或全部时间线，也影响并行触发的节目。若只需停止某一条时间线，使用 `stop-timeline`。
- `trigger` 会在主时钟未运行时启动它；整体暂停期间调用，可能同时恢复其他时间线的调度。调用方应在确认此行为符合预期后使用。
- 暂停、继续会按已有设备配置下发相应系统指令。`sync-ship-audio` 处理指定时间线 0 毫秒处、目标设备属于“游客船”组的相关音频及融合器指令；它没有独立的设备同步回执字段。
- 未知或缺失的 `action`、不存在的节目、状态或来源不匹配，统一返回 409 `control_rejected`，当前没有按原因细分错误码。

播放指定节目示例：

```json
{ "action": "start-current", "timelineId": "timeline-a", "startTimeMs": 5000 }
```

其他常用请求体：

```json
{ "action": "start-queue" }
```

```json
{ "action": "pause", "source": "queue" }
```

```json
{ "action": "resume", "source": "queue" }
```

```json
{ "action": "stop" }
```

```json
{ "action": "trigger", "timelineId": "timeline-b" }
```

### 错误响应

```json
{
  "ok": false,
  "error": {
    "code": "control_rejected",
    "message": "当前状态或播放来源不支持该操作"
  }
}
```

| HTTP 状态 | error.code | 含义 |
| --- | --- | --- |
| 400 | `invalid_json` | 三个 POST 接口的请求体不是有效 JSON 对象 |
| 400 | `invalid_queue` | 队列存在无效或重复 ID |
| 400 | `invalid_filter` | 筛选数组、元素或布尔开关不合法 |
| 400 | `invalid_devices` | 筛选中的设备 ID 不存在 |
| 401 | `unauthorized` | 已配置令牌，但请求未提供有效令牌；同时返回 `WWW-Authenticate: Bearer` |
| 404 | `not_found` | 未注册的资源或路由 |
| 404 | `asset_not_found` | 网页静态资源文件缺失 |
| 409 | `queue_rejected` | 当前状态不能编排队列，或队列中的节目不存在 |
| 409 | `devices_locked` | 当前状态不能修改执行开关或执行范围 |
| 409 | `control_rejected` | 播控操作、参数、状态或来源不满足要求 |
| 413 | `http_error` | HTTP 层拒绝超过请求体上限的数据 |
| 503 | `runtime_unavailable` | 播控运行时不可用 |
| 其他 | `http_error` | HTTP 层错误且没有已有响应体时的通用错误 |

调用方应同时检查 HTTP 状态和 `ok`，使用 `error.code` 分支处理，`message` 用于展示。

### 外部调用示例（PowerShell）

先只读查询快照，取得实际 ID：

```powershell
$baseUrl = 'http://192.168.1.100:8080' # 替换为运行桌面程序的主机地址
$headers = @{ Authorization = 'Bearer 请替换为已配置的令牌' }
# 服务未设置令牌时，可使用 $headers = @{}
$snapshot = Invoke-RestMethod -Method Get -Uri "$baseUrl/api/v1/status" -Headers $headers
$snapshot.timelines | Select-Object id, name, state
$snapshot.devices | Select-Object id, name, type, online
```

启动指定节目会实际下发设备指令，以下 ID 需替换为快照中的节目 ID；三个写接口可采用相同的 JSON 调用方式：

```powershell
$body = @{ action = 'start-current'; timelineId = 'timeline-a'; startTimeMs = 0 } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$baseUrl/api/v1/control" -Headers $headers `
    -ContentType 'application/json; charset=utf-8' -Body $body
```

## 当前对外能力边界

- 当前为 HTTP 服务，没有内置 HTTPS；需要加密接入时可由反向代理提供 HTTPS。
- 当前没有 CORS 响应头或 OPTIONS 预检处理。其他服务器、桌面客户端可直接按 HTTP 调用；其他域名或端口下的浏览器页面，需要同源代理或另行配置跨域支持。
- 配置的单一令牌同时拥有查询和播控权限，没有用户、角色或只读令牌区分。网页操作密码仅在前端确认弹窗中校验，HTTP 服务端不校验该密码，不能用其代替访问令牌。
- 状态获取使用轮询，没有 WebSocket 或 SSE 推送；现有网页每 800 毫秒查询一次完整快照。
- 尚未开放方案创建、加载和保存，节目及指令的增删改，设备配置和直接发送设备指令，触发规则修改，以及播放中的跳转定位接口。桌面运行时存在某些能力，并不代表它们已注册为 HTTP API。
- 当前参数校验并不统一，例如队列字段可被转换为空数组，控制字段也有默认值与类型转换；外部调用方应严格按本文约定构造参数。

## 方案格式兼容

方案格式升级为版本 6，时间线管理器格式为版本 3。继续兼容之前支持的方案版本 2、3、5 和管理器版本 1、2；旧版程序不能读取新格式方案。
