const elements = Object.fromEntries([
    "plan-name", "clock", "connection", "playback-label", "playback-dot",
    "now-title", "now-summary", "master-time", "active-timelines", "hero-progress", "timeline-seek", "elapsed-time",
    "remaining-time", "stop-button", "primary-button", "primary-icon", "primary-label",
    "refresh-button", "selection-count", "timeline-search", "timeline-list",
    "empty-timelines", "queue-panel", "queue-count", "queue-list", "queue-status",
    "queue-play-button", "queue-stop-button", "clear-queue-button", "device-count",
    "device-list", "empty-devices", "device-selection", "reset-devices-button", "command-program", "command-count", "command-list",
    "empty-commands", "toast", "show-filtered-out", "execution-filter",
    "confirm-dialog", "confirm-form", "confirm-title", "confirm-message", "confirm-password-field",
    "confirm-password", "confirm-cancel", "confirm-accept"
].map(id => [id, document.getElementById(id)]));

const state = {
    data: null,
    startTimelineId: null,
    startTimeMs: 0,
    busy: false,
    updateVersion: 0,
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
        waiting: "待触发",
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

function confirmAction(message, action = "", title = "操作确认") {
    const dialog = elements["confirm-dialog"];
    const requiresPassword = action !== "";
    dialog.classList.toggle("warning", requiresPassword);
    dialog.classList.toggle("pause", action === "pause");
    dialog.classList.toggle("trigger", action === "trigger");
    elements["confirm-title"].textContent = title;
    elements["confirm-message"].textContent = message;
    elements["confirm-accept"].textContent = action === "pause" ? "确认暂停"
        : action === "stop" ? "确认停止" : action === "trigger" ? "确认触发" : "确认";
    elements["confirm-password-field"].hidden = !requiresPassword;
    elements["confirm-password"].value = "";
    elements["confirm-password"].disabled = !requiresPassword;
    elements["confirm-accept"].disabled = requiresPassword;
    dialog.returnValue = "cancel";
    return new Promise(resolve => {
        dialog.addEventListener("close", () => {
            elements["confirm-password"].value = "";
            resolve(dialog.returnValue === "confirm");
        }, { once: true });
        dialog.showModal();
        if (requiresPassword) elements["confirm-password"].focus();
    });
}

function requestHeaders() {
    const headers = { "Content-Type": "application/json" };
    const token = sessionStorage.getItem("timeline-control-token");
    if (token) headers.Authorization = `Bearer ${token}`;
    return headers;
}

async function api(path, options = {}, promptForToken = true) {
    const response = await fetch(path, { ...options, headers: requestHeaders() });
    if (response.status === 401 && promptForToken) {
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
    const active = data.playbackState === "running" || data.playbackState === "paused";
    const id = active ? data.playbackTimelineId : data.currentTimelineId;
    return data.timelines.find(item => item.id === id) || null;
}

function renderTimelineList(data) {
    const query = elements["timeline-search"].value.trim().toLowerCase();
    const timelines = data.timelines.filter(timeline => timeline.name.toLowerCase().includes(query));
    const editable = data.playbackState === "stopped";
    const deviceNames = new Map(data.devices.map(device => [device.id, device.name || device.id]));
    const timelineNames = new Map(data.timelines.map(timeline => [timeline.id, timeline.name || timeline.id]));
    const signature = JSON.stringify([
        query,
        data.playbackState,
        state.busy,
        data.currentTimelineId,
        data.playQueue,
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
    elements["selection-count"].textContent = query ? `匹配 ${timelines.length} / 共 ${data.timelines.length}` : `${data.timelines.length} 个节目`;
    elements["empty-timelines"].hidden = timelines.length > 0;
    elements["empty-timelines"].textContent = data.timelines.length ? "没有匹配的时间轴" : "当前方案中还没有节目";

    for (const timeline of timelines) {
        const selected = data.currentTimelineId === timeline.id;
        const queued = data.playQueue.includes(timeline.id);
        const entry = createElement("div", "timeline-entry");
        const card = createElement("button", `timeline-card${selected ? " selected" : ""}${queued ? " queued" : ""}${timeline.state === "running" ? " active" : ""}`);
        card.type = "button";
        card.disabled = state.busy;
        card.setAttribute("aria-pressed", String(selected));
        card.addEventListener("click", () => post("/api/v1/control",
            { action: "select", timelineId: timeline.id }, `已选择 ${timeline.name}`));

        card.append(createElement("span", "selection-mark", "✓"));
        if (queued) card.append(createElement("span", "queue-corner", "☷ 队列"));
        const copy = createElement("span", "timeline-copy");
        const main = createElement("span", "timeline-main");
        main.append(createElement("span", "timeline-name", timeline.name));
        main.append(createElement("span", `state-chip ${timeline.state}`, stateLabel(timeline.state)));
        const meta = createElement("span", "timeline-meta");
        if (timeline.state === "running")
            meta.append(createElement("span", "", `当前时间 ${formatTime(timeline.currentTimeMs)}`));
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
        if (editable && selected && queued) {
            const queueButton = createElement("button", "text-button queue-toggle", "移除队列");
            queueButton.type = "button";
            queueButton.disabled = state.busy;
            queueButton.addEventListener("click", () => post("/api/v1/queue", {
                timelineIds: data.playQueue.filter(id => id !== timeline.id)
            }, "已移出队列"));
            entry.append(queueButton);
        }
        if (timeline.state !== "running") {
            const triggerButton = createElement("button", "manual-trigger", "⚡ 触发");
            triggerButton.type = "button";
            triggerButton.disabled = state.busy;
            triggerButton.title = `手动触发 ${timeline.name}`;
            triggerButton.addEventListener("click", async () => {
                if (!await confirmAction(
                    "将立即启动该时间线，并按编排向相关设备下发指令。",
                    "trigger", `触发时间线「${timeline.name}」？`
                )) return;
                post(
                    "/api/v1/control",
                    { action: "trigger", timelineId: timeline.id },
                    `已触发 ${timeline.name}`
                );
            });
            entry.append(triggerButton);
        } else {
            const stopButton = createElement("button", "manual-trigger timeline-stop", "■ 停止");
            stopButton.type = "button";
            stopButton.disabled = state.busy;
            stopButton.title = `仅停止 ${timeline.name} 的后续指令下发`;
            stopButton.setAttribute("aria-label", `停止时间线 ${timeline.name}`);
            stopButton.addEventListener("click", async () => {
                if (!await confirmAction(
                    "仅停止该时间线后续指令下发，不发送设备停止指令。",
                    "stop", `停止时间线「${timeline.name}」？`
                )) return;
                post(
                    "/api/v1/control",
                    { action: "stop-timeline", timelineId: timeline.id },
                    `已停止时间线 ${timeline.name}`
                );
            });
            entry.append(stopButton);
        }
        elements["timeline-list"].append(entry);
    }
}

function renderQueue(data) {
    const queue = data.playQueue
        .map(id => data.timelines.find(timeline => timeline.id === id))
        .filter(Boolean);
    const stopped = data.playbackState === "stopped";
    const running = data.queuePlayback && data.playbackState === "running";
    const paused = data.queuePlayback && data.playbackState === "paused";
    elements["queue-panel"].hidden = queue.length === 0;
    elements["queue-status"].textContent = data.queuePlayback
        ? (data.queueIndex < 0 && running ? "队列已播完，等待触发节目结束" : stateLabel(data.playbackState))
        : "待播放";
    elements["queue-play-button"].textContent = running ? "暂停" : paused ? "继续播放" : "播放队列";
    elements["queue-play-button"].disabled = state.busy || !queue.length
        || (!data.queuePlayback && !stopped && data.playbackState !== "completed");
    elements["queue-stop-button"].disabled = state.busy || !data.queuePlayback || stopped;
    elements["clear-queue-button"].disabled = state.busy || !stopped;
    const signature = JSON.stringify([
        data.queueIndex,
        data.playbackState,
        data.queuePlayback,
        state.busy,
        queue.map(timeline => [timeline.id, timeline.name, timeline.durationMs])
    ]);
    if (state.renderSignatures.queue === signature) return;
    state.renderSignatures.queue = signature;
    elements["queue-list"].replaceChildren();
    elements["queue-count"].textContent = String(queue.length);

    queue.forEach((timeline, index) => {
        const active = data.queuePlayback && data.queueIndex === index && !stopped;
        const row = createElement("li", `queue-row${active ? " active" : ""}`);
        row.append(createElement("span", "queue-index", String(index + 1).padStart(2, "0")));
        row.append(createElement("span", "queue-name", timeline.name));
        row.append(createElement("span", "queue-state", active ? stateLabel(data.playbackState) : formatTime(timeline.durationMs)));
        if (stopped) {
            const actions = createElement("div", "queue-row-actions");
            for (const offset of [-1, 1]) {
                const move = createElement("button", "text-button", offset < 0 ? "↑" : "↓");
                move.type = "button";
                move.setAttribute("aria-label", `${offset < 0 ? "上移" : "下移"} ${timeline.name}`);
                move.disabled = state.busy || index + offset < 0 || index + offset >= queue.length;
                move.addEventListener("click", () => {
                    const ids = data.playQueue.slice();
                    [ids[index], ids[index + offset]] = [ids[index + offset], ids[index]];
                    post("/api/v1/queue", { timelineIds: ids }, "队列顺序已更新");
                });
                actions.append(move);
            }
            const remove = createElement("button", "text-button", "移除");
            remove.type = "button";
            remove.setAttribute("aria-label", `移除 ${timeline.name}`);
            remove.disabled = state.busy;
            remove.addEventListener("click", () => post("/api/v1/queue",
                { timelineIds: data.playQueue.filter(id => id !== timeline.id) }, "已移出队列"));
            actions.append(remove);
            row.append(actions);
        }
        elements["queue-list"].append(row);
    });
}

function renderDevices(data) {
    const selectedIds = data.filterDeviceIds;
    const selectedGroups = data.filterGroupNames.concat(data.filterDeviceTypes.map(type => `${type}（类型分组）`));
    const locked = data.executionFilterEnabled && data.playbackState !== "stopped";
    const signature = JSON.stringify(data.devices.map(device => [
        device.id,
        device.name,
        device.type,
        device.online,
        selectedIds.includes(device.id),
        device.matchesFilter
    ]).concat([[data.playbackState, state.busy, selectedIds, selectedGroups, data.executionFilterEnabled, data.showFilteredOut]]));
    if (state.renderSignatures.devices === signature) return;
    state.renderSignatures.devices = signature;
    elements["device-list"].replaceChildren();
    elements["device-count"].textContent = String(data.devices.length);
    elements["empty-devices"].hidden = data.devices.length > 0;
    elements["reset-devices-button"].disabled = state.busy
        || locked
        || (selectedIds.length === 0 && selectedGroups.length === 0);
    elements["show-filtered-out"].checked = data.showFilteredOut;
    elements["show-filtered-out"].disabled = state.busy;
    elements["execution-filter"].checked = data.executionFilterEnabled;
    elements["execution-filter"].disabled = state.busy || data.playbackState !== "stopped";
    const selectedNames = selectedIds.map(id => data.devices.find(device => device.id === id)?.name || id);
    elements["device-selection"].textContent = selectedIds.length || selectedGroups.length
        ? `设备：${selectedNames.join("、") || "未指定"}；分组：${selectedGroups.join("、") || "未指定"}`
        : "当前：全部设备";

    for (const device of data.devices) {
        const selected = selectedIds.includes(device.id);
        const status = device.online ? "在线" : "离线";
        const row = createElement("button", `device-row${selected ? " selected" : !device.matchesFilter ? " filtered" : ""}`);
        row.type = "button";
        row.disabled = state.busy || locked;
        row.setAttribute("aria-pressed", String(selected));
        row.addEventListener("click", () => post(
            "/api/v1/device-filter",
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
    const commands = timeline ? timeline.commands.filter(command => data.showFilteredOut || command.matchesFilter)
        .sort((left, right) => left.startTimeMs - right.startTimeMs) : [];
    const devices = new Map(data.devices.map(device => [device.id, device.name || device.id]));
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
            command.executionParameters,
            command.state,
            command.error,
            command.matchesFilter
        ]),
        [...devices]
    ]);
    if (state.renderSignatures.commands === signature) return;
    state.renderSignatures.commands = signature;
    elements["command-program"].textContent = timeline?.name || "等待选择节目";
    elements["command-count"].textContent = String(commands.length);
    elements["command-list"].replaceChildren();
    elements["empty-commands"].hidden = commands.length > 0;
    elements["empty-commands"].textContent = timeline
        ? (timeline.commands.length ? "当前范围内没有指令" : "该节目没有指令")
        : "选择节目后查看指令";

    for (const command of commands) {
        const filtered = !command.matchesFilter;
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
        row.append(createElement("span", `command-status ${command.state}`, commandStateLabel(command.state)));
        row.title = `时间：${formatTime(command.startTimeMs)}\n设备：${devices.get(command.deviceId) || command.deviceId || "未指定设备"}\n名称：${command.name || "未命名指令"}\n执行参数：${parameters}\n状态：${commandStateLabel(command.state)}${command.error ? `\n错误：${command.error}` : ""}`;
        elements["command-list"].append(row);
    }
}

function render(data) {
    state.data = data;

    const timeline = currentTimeline(data);
    const playback = data.playbackState;
    const stopped = playback === "stopped";
    const duration = timeline?.durationMs || 0;
    if (state.startTimelineId !== timeline?.id || !stopped) state.startTimeMs = 0;
    state.startTimelineId = timeline?.id;
    state.startTimeMs = Math.min(state.startTimeMs, duration);
    const currentTime = stopped ? state.startTimeMs : timeline?.currentTimeMs || 0;
    const active = playback === "running" || playback === "paused";
    const runningTimelines = data.timelines.filter(item => item.state === "running")
        .sort((left, right) => Number(right.id === data.playbackTimelineId) - Number(left.id === data.playbackTimelineId));

    elements["plan-name"].textContent = data.planName || "未命名方案";
    elements["playback-label"].textContent = stateLabel(playback);
    elements["playback-dot"].style.color = playback === "running" ? "var(--green)" : playback === "paused" ? "var(--amber)" : "var(--muted)";
    elements["now-title"].textContent = active
        ? `${playback === "paused" ? "已暂停" : "正在播放"} · ${runningTimelines.length} 条时间线`
        : timeline?.name || "等待选择节目";
    elements["now-summary"].textContent = active ? "当前所有运行中的时间线"
        : timeline ? `当前节目 · ${timeline.commands.length} 条设备指令` : "从节目库中选择节目查看指令";
    elements["active-timelines"].hidden = !active;
    elements["active-timelines"].classList.toggle("paused", playback === "paused");
    elements["active-timelines"].replaceChildren();
    for (const item of runningTimelines) {
        const main = item.id === data.playbackTimelineId;
        const card = createElement("article", `active-timeline${main ? " main" : ""}`);
        const heading = createElement("div", "active-timeline-heading");
        const name = createElement("h2", "", item.name);
        name.title = item.name;
        heading.append(name, createElement("span", "active-timeline-role", main ? "主节目" : "触发节目"));
        const status = createElement("p", "active-timeline-status", stateLabel(playback));
        const time = createElement("div", "active-timeline-time");
        time.append(createElement("strong", "", formatTime(item.currentTimeMs)),
            createElement("span", "", `/ ${formatTime(item.durationMs)}`));
        const progressValue = item.durationMs ? Math.min(100, item.currentTimeMs / item.durationMs * 100) : 0;
        const progress = createElement("div", "active-timeline-progress");
        progress.setAttribute("role", "progressbar");
        progress.setAttribute("aria-label", `${item.name} 播放进度`);
        progress.setAttribute("aria-valuemin", "0");
        progress.setAttribute("aria-valuemax", "100");
        progress.setAttribute("aria-valuenow", String(progressValue));
        const fill = createElement("span", "");
        fill.style.width = `${progressValue}%`;
        progress.append(fill);
        card.append(heading, status, time, progress,
            createElement("p", "active-timeline-remaining", `剩余 ${formatTime(Math.max(0, item.durationMs - item.currentTimeMs))}`));
        elements["active-timelines"].append(card);
    }
    elements["hero-progress"].hidden = active;
    elements["master-time"].textContent = formatTime(data.currentTimeMs);
    elements["timeline-seek"].max = duration;
    elements["timeline-seek"].value = currentTime;
    elements["timeline-seek"].disabled = state.busy || !stopped || !duration || !timeline;
    elements["timeline-seek"].setAttribute("aria-valuetext", formatTime(currentTime, true));
    elements["elapsed-time"].textContent = formatTime(currentTime, true);
    elements["remaining-time"].textContent = `剩余 ${formatTime(Math.max(0, duration - currentTime))}`;

    const running = !data.queuePlayback && playback === "running";
    const paused = !data.queuePlayback && playback === "paused";
    elements["primary-icon"].textContent = running ? "Ⅱ" : "▶";
    elements["primary-label"].textContent = running ? "暂停" : paused ? "继续播放" : "播放当前节目";
    elements["primary-button"].disabled = state.busy || !data.currentTimelineId || (!running && !paused);
    elements["primary-button"].title = data.queuePlayback && active ? "请使用播放队列中的控制按钮" : "";
    elements["stop-button"].disabled = state.busy || stopped;
    elements["refresh-button"].disabled = state.busy;

    renderTimelineList(data);
    renderQueue(data);
    renderDevices(data);
    renderCommands(data, data.timelines.find(item => item.id === data.currentTimelineId));
}

async function refresh(showError = false) {
    if (state.busy || state.refreshing) return;
    state.refreshing = true;
    const version = state.updateVersion;
    try {
        const data = await api("/api/v1/status", {}, showError);
        if (version !== state.updateVersion) return;
        state.connected = true;
        elements.connection.className = "connection";
        elements.connection.lastChild.textContent = "控制端在线";
        render(data);
    } catch (error) {
        if (version !== state.updateVersion) return;
        state.connected = false;
        elements.connection.className = "connection disconnected";
        elements.connection.lastChild.textContent = "连接中断";
        if (showError) showToast(error.message, true);
    } finally {
        state.refreshing = false;
    }
}

async function post(path, body, successMessage) {
    if (state.busy) return;
    state.busy = true;
    ++state.updateVersion;
    if (state.data) render(state.data);
    try {
        const data = await api(path, { method: "POST", body: JSON.stringify(body) });
        render(data);
        showToast(successMessage);
    } catch (error) {
        showToast(error.message, true);
    } finally {
        state.busy = false;
        if (state.data) render(state.data);
    }
}

elements["confirm-password"].addEventListener("input", () => {
    elements["confirm-accept"].disabled = elements["confirm-password"].value !== "111111";
});

elements["confirm-form"].addEventListener("submit", event => {
    if (!elements["confirm-password-field"].hidden && elements["confirm-password"].value !== "111111")
        event.preventDefault();
});

elements["confirm-cancel"].addEventListener("click", () => elements["confirm-dialog"].close("cancel"));

elements["timeline-search"].addEventListener("input", () => {
    if (state.data) renderTimelineList(state.data);
    elements["timeline-list"].scrollTop = 0;
});

elements["timeline-seek"].addEventListener("input", () => {
    if (state.busy || state.data?.playbackState !== "stopped") return;
    state.startTimeMs = Number(elements["timeline-seek"].value);
    render(state.data);
});

elements["clear-queue-button"].addEventListener("click", () =>
    post("/api/v1/queue", { timelineIds: [] }, "播放队列已清空"));

elements["primary-button"].addEventListener("click", async () => {
    const playback = state.data?.playbackState;
    const action = playback === "paused" ? "resume" : playback === "running" ? "pause" : "start-current";
    if (action === "pause" && !await confirmAction(
        "将暂停所有时间线并向相关设备发送暂停指令，之后可继续播放。",
        "pause", "暂停播放？"
    )) return;
    const body = { action, source: "current" };
    if (action === "start-current") {
        body.timelineId = state.data.currentTimelineId;
        body.startTimeMs = state.startTimeMs;
    }
    post("/api/v1/control", body, action === "pause" ? "播放已暂停" : "播控状态已更新");
});

elements["queue-play-button"].addEventListener("click", async () => {
    const playback = state.data?.playbackState;
    const action = state.data?.queuePlayback && playback === "paused" ? "resume"
        : state.data?.queuePlayback && playback === "running" ? "pause" : "start-queue";
    if (action === "pause" && !await confirmAction(
        "将暂停所有时间线并向相关设备发送暂停指令，之后可继续播放。",
        "pause", "暂停播放？"
    )) return;
    post("/api/v1/control", { action, source: "queue" }, "队列播控状态已更新");
});
elements["queue-stop-button"].addEventListener("click", async () => {
    if (!await confirmAction(
        "将停止所有时间线并向相关设备发送停止指令，播放进度将重置，播放队列保留。",
        "stop", "停止全部播放？"
    )) return;
    post("/api/v1/control", { action: "stop", source: "queue" }, "队列播放已停止");
});
elements["stop-button"].addEventListener("click", async () => {
    if (!await confirmAction(
        "将停止所有时间线并向相关设备发送停止指令，播放进度将重置，播放队列保留。",
        "stop", "停止全部播放？"
    )) return;
    post("/api/v1/control", { action: "stop" }, "播放已停止");
});
elements["reset-devices-button"].addEventListener("click", () =>
    post("/api/v1/device-filter", { deviceIds: [], groupNames: [], deviceTypes: [] }, "已重置为全部设备"));
elements["show-filtered-out"].addEventListener("change", event =>
    post("/api/v1/device-filter", { showFilteredOut: event.target.checked }, "显示方式已更新"));
elements["execution-filter"].addEventListener("change", event =>
    post("/api/v1/device-filter", { executionFilterEnabled: event.target.checked }, "播放设备范围已更新"));
elements["refresh-button"].addEventListener("click", () => refresh(true));

setInterval(() => {
    elements.clock.textContent = new Intl.DateTimeFormat("zh-CN", {
        hour12: false, hour: "2-digit", minute: "2-digit", second: "2-digit"
    }).format(new Date());
}, 1000);
setInterval(() => refresh(false), 800);
refresh(true);
