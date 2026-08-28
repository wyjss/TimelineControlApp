const elements = Object.fromEntries([
    "plan-name", "clock", "connection", "playback-label", "playback-dot",
    "now-title", "now-summary", "master-time", "progress-fill", "elapsed-time",
    "remaining-time", "stop-button", "primary-button", "primary-icon", "primary-label",
    "refresh-button", "selection-count", "apply-queue-button", "timeline-list",
    "empty-timelines", "queue-count", "queue-list", "empty-queue", "device-count",
    "device-list", "empty-devices", "toast"
].map(id => [id, document.getElementById(id)]));

const state = {
    data: null,
    selectedIds: new Set(),
    selectionDirty: false,
    busy: false,
    refreshing: false,
    connected: false,
    toastTimer: 0
};

function formatTime(milliseconds) {
    const totalSeconds = Math.max(0, Math.floor(Number(milliseconds || 0) / 1000));
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor(totalSeconds % 3600 / 60);
    const seconds = totalSeconds % 60;
    return [hours, minutes, seconds].map(value => String(value).padStart(2, "0")).join(":");
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
    return data.timelines.find(item => item.queuePosition === data.queueIndex)
        || data.timelines.find(item => item.state === "running")
        || data.timelines.find(item => state.selectedIds.has(item.id))
        || null;
}

function renderTimelineList(data) {
    elements["timeline-list"].replaceChildren();
    elements["empty-timelines"].hidden = data.timelines.length > 0;
    const editable = data.playbackState === "stopped";

    for (const timeline of data.timelines) {
        const selected = state.selectedIds.has(timeline.id);
        const card = createElement("button", `timeline-card${selected ? " selected" : ""}${timeline.state === "running" ? " active" : ""}`);
        card.type = "button";
        card.disabled = !editable;
        card.setAttribute("aria-pressed", String(selected));
        card.addEventListener("click", () => {
            if (selected) state.selectedIds.delete(timeline.id);
            else state.selectedIds.add(timeline.id);
            state.selectionDirty = true;
            render(data);
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
        copy.append(main, meta);
        card.append(copy, createElement("span", "duration", formatTime(timeline.durationMs)));
        elements["timeline-list"].append(card);
    }
}

function renderQueue(data) {
    const queue = [...state.selectedIds]
        .map(id => data.timelines.find(timeline => timeline.id === id))
        .filter(Boolean);
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
    elements["device-list"].replaceChildren();
    elements["device-count"].textContent = String(data.devices.length);
    elements["empty-devices"].hidden = data.devices.length > 0;

    for (const device of data.devices) {
        const status = device.status?.trim() || "未报告";
        const normalized = status.toLowerCase();
        const problem = /离线|断开|失败|故障|异常|offline|error|failed/.test(normalized);
        const online = !problem && /在线|正常|就绪|已连接|online|ready|connected/.test(normalized);
        const row = createElement("div", "device-row");
        row.append(createElement("span", `device-dot${online ? " online" : ""}${problem ? " problem" : ""}`));
        const copy = createElement("span", "device-copy");
        copy.append(createElement("strong", "", device.name || device.id));
        copy.append(createElement("span", "", device.type || "未分类设备"));
        row.append(copy, createElement("span", "device-status", status));
        elements["device-list"].append(row);
    }
}

function render(data) {
    state.data = data;
    if (!state.selectionDirty && data.playbackState === "stopped")
        state.selectedIds = new Set(data.playQueue);

    const timeline = currentTimeline(data);
    const playback = data.playbackState;
    const currentTime = timeline?.currentTimeMs || 0;
    const duration = timeline?.durationMs || 0;
    const progress = duration ? Math.min(100, currentTime / duration * 100) : 0;

    elements["plan-name"].textContent = data.planName || "未命名方案";
    elements["playback-label"].textContent = stateLabel(playback);
    elements["playback-dot"].style.color = playback === "running" ? "var(--green)" : playback === "paused" ? "var(--amber)" : "var(--muted)";
    elements["now-title"].textContent = timeline?.name || "等待选择节目";
    elements["now-summary"].textContent = timeline
        ? `队列第 ${Math.max(0, timeline.queuePosition) + 1} 项 · ${timeline.commands.length} 条设备指令`
        : "从节目库中选择并编排播放队列";
    elements["master-time"].textContent = formatTime(data.currentTimeMs);
    elements["progress-fill"].style.width = `${progress}%`;
    elements["elapsed-time"].textContent = formatTime(currentTime);
    elements["remaining-time"].textContent = `剩余 ${formatTime(Math.max(0, duration - currentTime))}`;

    const paused = playback === "paused";
    const stopped = playback === "stopped";
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

async function post(path, body, successMessage) {
    if (state.busy) return;
    state.busy = true;
    if (state.data) render(state.data);
    try {
        const data = await api(path, { method: "POST", body: JSON.stringify(body) });
        state.selectionDirty = false;
        render(data);
        showToast(successMessage);
    } catch (error) {
        showToast(error.message, true);
    } finally {
        state.busy = false;
        if (state.data) render(state.data);
    }
}

elements["apply-queue-button"].addEventListener("click", () =>
    post("/api/v1/queue", { timelineIds: [...state.selectedIds] }, "播放队列已更新"));

elements["primary-button"].addEventListener("click", () => {
    const playback = state.data?.playbackState;
    const action = playback === "paused" ? "resume" : playback === "running" ? "pause" : "start";
    const body = { action };
    if (action === "start") body.timelineIds = [...state.selectedIds];
    post("/api/v1/control", body, action === "pause" ? "播放已暂停" : "播控状态已更新");
});

elements["stop-button"].addEventListener("click", () =>
    post("/api/v1/control", { action: "stop" }, "播放已停止"));
elements["refresh-button"].addEventListener("click", () => refresh(true));

setInterval(() => {
    elements.clock.textContent = new Intl.DateTimeFormat("zh-CN", {
        hour12: false, hour: "2-digit", minute: "2-digit", second: "2-digit"
    }).format(new Date());
}, 1000);
setInterval(() => refresh(false), 800);
refresh(true);
