const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

class Element {
    constructor() {
        this.children = [];
        this.style = {};
        this.attributes = {};
        this.events = {};
        this.lastChild = {};
    }
    append(...children) { this.children.push(...children); }
    replaceChildren(...children) { this.children = children; }
    setAttribute(key, value) { this.attributes[key] = value; }
    addEventListener(event, handler) { this.events[event] = handler; }
}

const elements = new Map();
const requests = [];
const context = vm.createContext({
    document: {
        getElementById(id) {
            if (!elements.has(id)) elements.set(id, new Element());
            return elements.get(id);
        },
        createElement: () => new Element()
    },
    sessionStorage: { getItem: () => null },
    setInterval: () => 0,
    setTimeout: () => 0,
    clearTimeout: () => {},
    fetch: (url, options) => new Promise(resolve => requests.push({ url, options, resolve }))
});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../server/web/assets/app.js'), 'utf8'), context);
const data = {
    planName: 'Test', playbackState: 'stopped', currentTimeMs: 0,
    currentTimelineId: 'a', playbackTimelineId: '', queuePlayback: false, queueIndex: -1,
    playQueue: ['b'], playbackDevices: [], devices: [],
    timelines: ['a', 'b'].map(id => ({
        id, name: id.toUpperCase(), state: 'stopped', currentTimeMs: 0,
        durationMs: 60000, commands: [], triggers: []
    }))
};
data.timelines[0].commands.push({
    id: 'event', name: 'Set light', deviceId: 'light', startTimeMs: 5000,
    executionParameters: [{ name: 'Brightness', value: 50 }], state: 'idle', error: ''
});
const render = () => {
    context.fixture = structuredClone(data);
    vm.runInContext('render(fixture)', context);
};
const respond = async (request, snapshot) => {
    request.resolve({ ok: true, status: 200, json: async () => structuredClone(snapshot) });
    await new Promise(setImmediate);
};

(async () => {
    await respond(requests.shift(), data);
    assert.equal(elements.get('now-title').textContent, 'A');
    assert.equal(elements.get('primary-label').textContent, '播放当前节目');
    assert.equal(elements.get('queue-panel').hidden, false);
    const commandRow = elements.get('command-list').children[0];
    assert.deepEqual(commandRow.children.map(child => child.className), [
        'command-time', 'command-copy', 'command-device', 'command-status idle'
    ]);
    assert.equal(commandRow.children[0].textContent, '00:00:05');
    assert.equal(commandRow.children[1].children[1].textContent, '参数：Brightness：50');
    assert.ok(!commandRow.title.includes('持续时间'));
    data.timelines[0].commands[0].executionParameters[0].value = 75;
    render();
    assert.equal(elements.get('command-list').children[0].children[1].children[1].textContent,
        '参数：Brightness：75');

    elements.get('timeline-list').children[1].children[0].events.click();
    let request = requests.shift();
    assert.deepEqual(JSON.parse(request.options.body), { action: 'select', timelineId: 'b' });
    data.currentTimelineId = 'b';
    await respond(request, data);
    assert.equal(elements.get('now-title').textContent, 'B');
    assert.equal(elements.get('timeline-list').children[1].children[1].textContent, '移除队列');

    data.playbackState = 'running';
    data.playbackTimelineId = 'a';
    render();
    assert.equal(elements.get('now-title').textContent, 'A');
    assert.equal(elements.get('primary-label').textContent, '暂停');
    assert.equal(elements.get('queue-status').textContent, '待播放');
    assert.equal(elements.get('queue-play-button').disabled, true);
    assert.equal(elements.get('queue-stop-button').disabled, true);
    elements.get('primary-button').events.click();
    request = requests.shift();
    assert.deepEqual(JSON.parse(request.options.body), { action: 'pause', source: 'current' });
    data.playbackState = 'paused';
    await respond(request, data);
    assert.equal(elements.get('primary-label').textContent, '继续播放');

    data.playbackState = 'completed';
    render();
    assert.equal(elements.get('primary-label').textContent, '播放当前节目');
    assert.equal(elements.get('primary-button').disabled, false);
    assert.equal(elements.get('queue-play-button').disabled, false);
    elements.get('primary-button').events.click();
    request = requests.shift();
    assert.deepEqual(JSON.parse(request.options.body), {
        action: 'start-current', source: 'current', timelineId: 'b', startTimeMs: 0
    });
    await respond(request, data);
    elements.get('queue-play-button').events.click();
    request = requests.shift();
    assert.deepEqual(JSON.parse(request.options.body), { action: 'start-queue', source: 'queue' });
    data.playbackState = 'running';
    data.queuePlayback = true;
    data.queueIndex = 0;
    data.playbackTimelineId = 'b';
    await respond(request, data);
    assert.equal(elements.get('primary-button').disabled, true);
    assert.equal(elements.get('queue-play-button').textContent, '暂停');
    data.playbackState = 'paused';
    render();
    assert.equal(elements.get('queue-play-button').textContent, '继续播放');
    data.playbackState = 'completed';
    render();
    assert.equal(elements.get('queue-play-button').textContent, '播放队列');
    assert.equal(elements.get('queue-play-button').disabled, false);

    data.playbackState = 'stopped';
    data.queuePlayback = false;
    data.playbackTimelineId = '';
    data.queueIndex = -1;
    render();
    vm.runInContext('refresh()', context);
    const oldPoll = requests.shift();
    const oldData = structuredClone(data);
    elements.get('clear-queue-button').events.click();
    request = requests.shift();
    assert.deepEqual(JSON.parse(request.options.body), { timelineIds: [] });
    data.playQueue = [];
    await respond(request, data);
    assert.equal(elements.get('queue-panel').hidden, true);
    await respond(oldPoll, oldData);
    assert.equal(elements.get('queue-panel').hidden, true);
    assert.equal(requests.length, 0);
    console.log('PASS: selected vs playing program, separate controls, completed replay, request payloads, empty queue, stale poll protection and event parameter refresh');
})().catch(error => { console.error(error); process.exitCode = 1; });
