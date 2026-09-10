const elements = Object.fromEntries([
    "plan-name", "clock", "connection", "playback-label", "playback-dot",
    "now-title", "now-summary", "master-time", "timeline-seek", "elapsed-time",
    "remaining-time", "stop-button", "primary-button", "primary-icon", "primary-label",
    "refresh-button", "selection-count", "apply-queue-button", "timeline-list",
    "empty-timelines", "queue-count", "queue-list", "empty-queue", "device-count",
    "device-list", "empty-devices", "device-selection", "reset-devices-button", "command-program", "command-count", "command-list",
    "empty-commands", "toast"
].map(id => [id, document.getElementById(id)]));

const state = {
    data: null,
    selectedIds: new Set(),
    selectionDirty: false,
    startTimelineId: null,
    startTimeMs: 0,
    busy: false,
    refreshing: false,
    connected: false,
    toastTimer: 0,
    renderSignatures: {}
};

function formatTime(milliseconds, showMilliseconds = false) {
    const totalSeconds = Math.max(0, Math.floor(Number(milliseconds || 0) / 1000));
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor(totalSeconds % 3600 / 60);
    const seconds = totalSeconds % 60;
    const time = [hours, minutes, seconds].map(value => String(value).padStart(2, "0")).join(":");
    return showMilliseconds ? time + "." + String(Math.max(0, Math.floor(milliseconds || 0)) % 1000).padStart(3, "0") : time;
}

function createElement(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text !== undefined) element.textContent = text;
    return element;
}

function stateLabel(value) {
    return ({
        stopped: "待播",
        waiting: "排队中",
        running: "播出中",
        paused: "已暂停",
        completed: "已完成"
    })[value] || "待播";
}

function commandStateLabel(value) {
    return ({
        idle: "待执行",
        running: "执行中",
        succeeded: "已成功",
        failed: "失败",
        skipped: "已跳过"
    })[value] || "待执行";
}

function executionParametersText(command) {
    const parameters = command.executionParameters || [];
    return parameters.length
        ? parameters.map(parameter => `${parameter.name}：${typeof parameter.value === "boolean"
            ? (parameter.value ? "是" : "否")
            : String(parameter.value)}`).join(" · ")
        : "无";
}

function showToast(message, error = false) {
    clearTimeout(state.toastTimer);
    elements.toast.textContent = message;
    elements.toast.className = `toast visible${error ? " error" : ""}`;
    state.toastTimer = setTimeout(() => elements.toast.className = "toast", 2600);
}

function requestHeaders() {
    const headers = { "Content-Type": "application/json" };
    const token = sessionStorage.getItem("timeline-control-token");
    if (token) headers.Authorization = `Bearer ${token}`;
    return headers;
}

async function api(path, options = {}) {
    const response = await fetch(path, { ...options, headers: requestHeaders() });
    if (response.status === 401) {
        const token = window.prompt("请输入播控访问令牌");
        if (token) {
            sessionStorage.setItem("timeline-control-token", token.trim());
            return api(path, options);
        }
    }
    const body = await response.json();
    if (!response.ok) throw new Error(body.error?.message || "请求失败");
    return body;
}

function currentTimeline(data) {
    if (data.playbackState === "stopped") {
        const firstId = state.selectedIds.values().next().value;
        const first = data.timelines.find(item => item.id === firstId);
        if (first) return first;
    }
    return (data.queueIndex >= 0
        ? data.timelines.find(item => item.queuePosition === data.queueIndex)
        : null)
        || data.timelines.find(item => item.state === "running")
        || data.timelines.find(item => item.id === data.currentTimelineId)
        || data.timelines.find(item => state.selectedIds.has(item.id))
        || data.timelines[0]
        || null;
}

function renderTimelineList(data) {
    const editable = data.playbackState === "stopped";
    const deviceNames = new Map(data.devices.map(device => [device.id, device.name || device.id]));
    const timelineNames = new Map(data.timelines.map(timeline => [timeline.id, timeline.name || timeline.id]));
    const signature = JSON.stringify([
        editable,
        state.busy,
        [...state.selectedIds],
        data.timelines.map(timeline => [
            timeline.id,
            timeline.name,
            timeline.state,
            timeline.currentTimeMs,
            timeline.durationMs,
            timeline.commands.map(command => command.state),
            timeline.triggers
        ])
    ]);
    if (state.renderSignatures.timelines === signature) return;
    state.renderSignatures.timelines = signature;
    elements["timeline-list"].replaceChildren();
    elements["empty-timelines"].hidden = data.timelines.length > 0;

    for (const timeline of data.timelines) {
        const selected = state.selectedIds.has(timeline.id);
        const entry = createElement("div", "timeline-entry");
        const card = createElement("button", `timeline-card${selected ? " selected" : ""}${timeline.state === "running" ? " active" : ""}`);
        card.type = "button";
        card.disabled = !editable || state.busy;
        card.setAttribute("aria-pressed", String(selected));
        card.addEventListener("click", () => {
            if (selected) state.selectedIds.delete(timeline.id);
            else state.selectedIds.add(timeline.id);
            state.selectionDirty = true;
            render(state.data);
        });

        card.append(createElement("span", "queue-check", "✓"));
        const copy = createElement("span", "timeline-copy");
        const main = createElement("span", "timeline-main");
        main.append(createElement("span", "timeline-name", timeline.name));
        main.append(createElement("span", `state-chip ${timeline.state}`, stateLabel(timeline.state)));
        const meta = createElement("span", "timeline-meta");
        meta.append(createElement("span", "", `${timeline.commands.length} 条指令`));
        const failedCount = timeline.commands.filter(command => command.state === "failed").length;
        meta.append(createElement("span", "", failedCount ? `${failedCount} 条异常` : "指令正常"));
        const triggers = timeline.triggers || [];
        if (triggers.length) {
            const touchedCount = triggers.filter(trigger => trigger.touched).length;
            meta.append(createElement("span", "", touchedCount
                ? `${touchedCount}/${triggers.length} 已触发`
                : `${triggers.length} 条触发`));
            card.title = triggers.map(trigger => {
                const status = trigger.touched ? "已触发" : trigger.active
                    ? "待触发" : trigger.enabled ? "未激活" : "已停用";
                return `${deviceNames.get(trigger.locatorId) || trigger.locatorId} · ${trigger.fenceId} · ${Number(trigger.heading).toFixed(1)}° → ${timelineNames.get(trigger.targetTimelineId) || trigger.targetTimelineId}（${status}）`;
            }).join("\n");
        }
        copy.append(main, meta);
        card.append(copy, createElement("span", "duration", formatTime(timeline.durationMs)));
        const progress = createElement("span", "timeline-progress");
        const progressFill = createElement("span", "timeline-progress-fill");
        const progressValue = timeline.state === "completed" ? 100 : timeline.durationMs
            ? Math.min(100, timeline.currentTimeMs / timeline.durationMs * 100)
            : 0;
        progressFill.style.width = `${progressValue}%`;
        progress.append(progressFill);
        card.append(progress);
        entry.append(card);
        if (timeline.state === "waiting") {
            const triggerButton = createElement("button", "manual-trigger", "⚡ 触发");
            triggerButton.type = "button";
            triggerButton.disabled = state.busy || data.playbackState !== "running";
            triggerButton.title = data.playbackState === "running"
                ? `手动触发 ${timeline.name}`
                : "继续播放后可手动触发";
            triggerButton.addEventListener("click", () => post(
                "/api/v1/control",
                { action: "trigger", timelineId: timeline.id },
                `已触发 ${timeline.name}`
            ));
            entry.append(triggerButton);
        }
        elements["timeline-list"].append(entry);
    }
}

function renderQueue(data) {
    const queue = [...state.selectedIds]
        .map(id => data.timelines.find(timeline => timeline.id === id))
        .filter(Boolean);
    const signature = JSON.stringify([
        data.queueIndex,
        data.playbackState,
        queue.map(timeline => [timeline.id, timeline.name, timeline.durationMs])
    ]);
    if (state.renderSignatures.queue === signature) return;
    state.renderSignatures.queue = signature;
    elements["queue-list"].replaceChildren();
    elements["queue-count"].textContent = String(queue.length);
    elements["empty-queue"].hidden = queue.length > 0;

    queue.forEach((timeline, index) => {
        const active = data.queueIndex === index && data.playbackState !== "stopped";
        const row = createElement("li", `queue-row${active ? " active" : ""}`);
        row.append(createElement("span", "queue-index", String(index + 1).padStart(2, "0")));
        row.append(createElement("span", "queue-name", timeline.name));
        row.append(createElement("span", "queue-state", active ? "NOW" : formatTime(timeline.durationMs)));
        elements["queue-list"].append(row);
    });
}

function renderDevices(data) {
    const selectedIds = data.playbackDevices || [];
    const signature = JSON.stringify(data.devices.map(device => [
        device.id,
        device.name,
        device.type,
        device.online,
        selectedIds.includes(device.id)
    ]).concat([[data.playbackState, state.busy]]));
    if (state.renderSignatures.devices === signature) return;
    state.renderSignatures.devices = signature;
    elements["device-list"].replaceChildren();
    elements["device-count"].textContent = String(data.devices.length);
    elements["empty-devices"].hidden = data.devices.length > 0;
    elements["reset-devices-button"].disabled = state.busy
        || data.playbackState !== "stopped"
        || selectedIds.length === 0;
    const selectedNames = data.devices
        .filter(device => selectedIds.includes(device.id))
        .map(device => device.name || device.id);
    elements["device-selection"].textContent = selectedNames.length
        ? `当前：${selectedNames.join("、")}`
        : "当前：全部设备";

    for (const device of data.devices) {
        const selected = selectedIds.includes(device.id);
        const status = device.online ? "在线" : "离线";
        const row = createElement("button", `device-row${selected ? " selected" : selectedIds.length ? " filtered" : ""}`);
        row.type = "button";
        row.disabled = state.busy || data.playbackState !== "stopped";
        row.setAttribute("aria-pressed", String(selected));
        row.addEventListener("click", () => post(
            "/api/v1/playback-devices",
            { deviceIds: selected
                ? selectedIds.filter(id => id !== device.id)
                : [...selectedIds, device.id] },
            selected ? `已取消 ${device.name || device.id}` : `已选择 ${device.name || device.id}`
        ));
        row.append(createElement("span", `device-dot${device.online ? " online" : " problem"}`));
        const copy = createElement("span", "device-copy");
        copy.append(createElement("strong", "", device.name || device.id));
        copy.append(createElement("span", "", device.type || "未分类设备"));
        row.append(copy, createElement("span", "device-status", status));
        row.append(createElement("span", "device-selected", selected ? "✓" : ""));
        elements["device-list"].append(row);
    }
}

function renderCommands(data, timeline) {
    const commands = timeline ? [...timeline.commands].sort((left, right) => left.startTimeMs - right.startTimeMs) : [];
    const devices = new Map(data.devices.map(device => [device.id, device.name || device.id]));
    const selectedIds = data.playbackDevices || [];
    const nextCommand = commands.find(command => command.state === "idle"
        && command.startTimeMs >= (data.playbackState === "stopped" ? state.startTimeMs : timeline?.currentTimeMs || 0));
    const signature = JSON.stringify([
        timeline?.id,
        timeline?.name,
        nextCommand?.id,
        commands.map(command => [
            command.id,
            command.name,
            command.deviceId,
            command.startTimeMs,
            command.durationMs,
            command.executionParameters,
            command.state,
            command.error
        ]),
        [...devices],
        selectedIds
    ]);
    if (state.renderSignatures.commands === signature) return;
    state.renderSignatures.commands = signature;
    elements["command-program"].textContent = timeline?.name || "等待选择节目";
    elements["command-count"].textContent = String(commands.length);
    elements["command-list"].replaceChildren();
    elements["empty-commands"].hidden = commands.length > 0;
    elements["empty-commands"].textContent = timeline ? "该节目没有指令" : "选择节目后查看指令";

    for (const command of commands) {
        const filtered = selectedIds.length > 0 && !selectedIds.includes(command.deviceId);
        const row = createElement("div", `command-grid command-row ${command.state}${command === nextCommand ? " next" : ""}${filtered ? " filtered" : ""}`);
        row.append(createElement("span", "command-time", formatTime(command.startTimeMs)));
        const copy = createElement("span", "command-copy");
        copy.append(createElement("strong", "", command.name || "未命名指令"));
        const parameters = executionParametersText(command);
        if (parameters !== "无")
            copy.append(createElement("small", "command-parameters", `参数：${parameters}`));
        if (command.error) copy.append(createElement("small", "command-error", command.error));
        row.append(copy);
        row.append(createElement("span", "command-device", devices.get(command.deviceId) || command.deviceId || "未指定设备"));
        row.append(createElement("span", "command-duration", command.durationMs ? formatTime(command.durationMs) : "瞬时"));
        row.append(createElement("span", `command-status ${command.state}`, commandStateLabel(command.state)));
        row.title = `时间：${formatTime(command.startTimeMs)}\n设备：${devices.get(command.deviceId) || command.deviceId || "未指定设备"}\n名称：${command.name || "未命名指令"}\n执行参数：${parameters}\n持续时间：${command.durationMs ? formatTime(command.durationMs) : "瞬时"}\n状态：${commandStateLabel(command.state)}${command.error ? `\n错误：${command.error}` : ""}`;
        elements["command-list"].append(row);
    }
}

function render(data) {
    state.data = data;
    if (!state.selectionDirty && data.playbackState === "stopped")
        state.selectedIds = new Set(data.playQueue);

    const timeline = currentTimeline(data);
    const playback = data.playbackState;
    const stopped = playback === "stopped";
    const duration = timeline?.durationMs || 0;
    if (state.startTimelineId !== timeline?.id || !stopped) state.startTimeMs = 0;
    state.startTimelineId = timeline?.id;
    state.startTimeMs = Math.min(state.startTimeMs, duration);
    const currentTime = stopped ? state.startTimeMs : timeline?.currentTimeMs || 0;
    const queuePosition = stopped ? [...state.selectedIds].indexOf(timeline?.id) : timeline?.queuePosition;

    elements["plan-name"].textContent = data.planName || "未命名方案";
    elements["playback-label"].textContent = stateLabel(playback);
    elements["playback-dot"].style.color = playback === "running" ? "var(--green)" : playback === "paused" ? "var(--amber)" : "var(--muted)";
    elements["now-title"].textContent = timeline?.name || "等待选择节目";
    elements["now-summary"].textContent = timeline
        ? `${queuePosition >= 0 ? `队列第 ${queuePosition + 1} 项` : "当前节目"} · ${timeline.commands.length} 条设备指令`
        : "从节目库中选择并编排播放队列";
    elements["master-time"].textContent = formatTime(data.currentTimeMs);
    elements["timeline-seek"].max = duration;
    elements["timeline-seek"].value = currentTime;
    elements["timeline-seek"].disabled = state.busy || !stopped || !duration || !state.selectedIds.size;
    elements["timeline-seek"].setAttribute("aria-valuetext", formatTime(currentTime, true));
    elements["elapsed-time"].textContent = formatTime(currentTime, true);
    elements["remaining-time"].textContent = `剩余 ${formatTime(Math.max(0, duration - currentTime))}`;

    const paused = playback === "paused";
    elements["primary-icon"].textContent = paused ? "▶" : stopped ? "▶" : "Ⅱ";
    elements["primary-label"].textContent = paused ? "继续播放" : stopped ? "开始播放" : "暂停播放";
    elements["primary-button"].disabled = state.busy || (stopped && state.selectedIds.size === 0);
    elements["stop-button"].disabled = state.busy || stopped;
    elements["refresh-button"].disabled = state.busy;
    elements["selection-count"].textContent = `已选 ${state.selectedIds.size} 个`;
    elements["apply-queue-button"].disabled = state.busy || !stopped || !state.selectionDirty;

    renderTimelineList(data);
    renderQueue(data);
    renderDevices(data);
    renderCommands(data, timeline);
}

async function refresh(showError = false) {
    if (state.busy || state.refreshing) return;
    state.refreshing = true;
    try {
        const data = await api("/api/v1/status");
        state.connected = true;
        elements.connection.className = "connection";
        elements.connection.lastChild.textContent = "控制端在线";
        render(data);
    } catch (error) {
        state.connected = false;
        elements.connection.className = "connection disconnected";
        elements.connection.lastChild.textContent = "连接中断";
        if (showError) showToast(error.message, true);
    } finally {
        state.refreshing = false;
    }
}

async function post(path, body, successMessage, syncQueue = false) {
    if (state.busy) return;
    state.busy = true;
    if (state.data) render(state.data);
    try {
        const data = await api(path, { method: "POST", body: JSON.stringify(body) });
        if (syncQueue) state.selectionDirty = false;
        render(data);
        showToast(successMessage);
    } catch (error) {
        showToast(error.message, true);
    } finally {
        state.busy = false;
        if (state.data) render(state.data);
    }
}

elements["timeline-seek"].addEventListener("input", () => {
    if (state.busy || state.data?.playbackState !== "stopped") return;
    state.startTimeMs = Number(elements["timeline-seek"].value);
    render(state.data);
});

elements["apply-queue-button"].addEventListener("click", () =>
    post("/api/v1/queue", { timelineIds: [...state.selectedIds] }, "播放队列已更新", true));

elements["primary-button"].addEventListener("click", () => {
    const playback = state.data?.playbackState;
    const action = playback === "paused" ? "resume" : playback === "running" ? "pause" : "start";
    const body = { action };
    if (action === "start") {
        body.timelineIds = [...state.selectedIds];
        body.startTimeMs = state.startTimeMs;
    }
    post("/api/v1/control", body, action === "pause" ? "播放已暂停" : "播控状态已更新", action === "start");
});

elements["stop-button"].addEventListener("click", () =>
    post("/api/v1/control", { action: "stop" }, "播放已停止"));
elements["reset-devices-button"].addEventListener("click", () =>
    post("/api/v1/playback-devices", { deviceIds: [] }, "已重置为全部设备"));
elements["refresh-button"].addEventListener("click", () => refresh(true));

setInterval(() => {
    elements.clock.textContent = new Intl.DateTimeFormat("zh-CN", {
        hour12: false, hour: "2-digit", minute: "2-digit", second: "2-digit"
    }).format(new Date());
}, 1000);
setInterval(() => refresh(false), 800);
refresh(true);
