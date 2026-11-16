// Run against the patched noVNC tree, with no npm dependencies:
// NOVNC_DIR=/path/to/novnc node --experimental-vm-modules --test clipboard.test.mjs
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';
import vm from 'node:vm';

const root = process.env.NOVNC_DIR;
assert.ok(root, 'Set NOVNC_DIR to the patched noVNC source directory');

async function load(relative, globals = {}, dependencies = {}) {
    const source = await readFile(path.join(root, relative), 'utf8');
    const context = vm.createContext({ console, setTimeout, clearTimeout, ...globals });
    const module = new vm.SourceTextModule(source, { context });
    await module.link(async specifier => {
        const exports = dependencies[specifier];
        assert.ok(exports, `Missing test dependency: ${specifier}`);
        return new vm.SyntheticModule(Object.keys(exports), function () {
            for (const [name, value] of Object.entries(exports)) this.setExport(name, value);
        }, { context });
    });
    await module.evaluate();
    return module.namespace.default;
}

async function clipboard(clipboardApi, permission = 'granted') {
    const target = new EventTarget();
    const window = new EventTarget();
    const document = new EventTarget();
    document.activeElement = target;
    const Clipboard = await load('core/clipboard.js', {
        navigator: { clipboard: clipboardApi, permissions: { query: async () => {
            if (permission === 'unsupported') throw new TypeError('Unsupported permission');
            return { state: permission };
        } } }, document, window,
    });
    return { clipboard: new Clipboard(target), target, window, document };
}

function paste(text) {
    const event = new Event('paste', { cancelable: true });
    event.clipboardData = { types: ['text/plain'], getData: () => text };
    return event;
}

test('native paste works without async clipboard access, including Unicode and newlines', async () => {
    const { clipboard: c, document } = await clipboard(undefined);
    const received = [];
    c.onnativepaste = text => received.push(text);
    c.grab();
    const event = paste('écho robot\nsecond line');
    document.dispatchEvent(event);
    assert.equal(event.defaultPrevented, true);
    assert.deepEqual(received, ['écho robot\nsecond line']);
    c.ungrab();
    document.dispatchEvent(paste('must not arrive'));
    assert.equal(received.length, 1);
});

test('window refocus and clicks refresh the clipboard even when the canvas stays focused', async () => {
    let reads = 0;
    const { clipboard: c, target, window, document } = await clipboard({ readText: async () => String(++reads) });
    const received = [];
    c.onpaste = text => received.push(text);
    c.grab();
    window.dispatchEvent(new Event('focus'));
    await new Promise(setImmediate);
    target.dispatchEvent(new Event('mousedown'));
    await new Promise(setImmediate);
    assert.deepEqual(received, ['1', '2']);
    document.activeElement = {};
    window.dispatchEvent(new Event('focus'));
    assert.equal(reads, 2, 'do not read when another page control has focus');
    c.ungrab();
    document.activeElement = target;
    window.dispatchEvent(new Event('focus'));
    assert.equal(reads, 2);
});

test('a delayed clipboard read cannot overwrite newer native paste data', async () => {
    let finishRead;
    const { clipboard: c } = await clipboard({ readText: () => new Promise(resolve => { finishRead = resolve; }) });
    const received = [];
    c.onpaste = text => received.push(text);
    c.onnativepaste = text => received.push(text);
    const pending = c._handleFocus();
    await new Promise(setImmediate);
    c._handlePaste(paste('new clipboard'));
    finishRead('stale clipboard');
    await pending;
    assert.deepEqual(received, ['new clipboard']);
});

test('remote-to-host copying still writes the clipboard', async () => {
    const written = [];
    const { clipboard: c } = await clipboard({ writeText: async text => written.push(text) });
    await c._handleCopy(paste('remote text'));
    assert.deepEqual(written, ['remote text']);
});

for (const permission of ['prompt', 'denied', 'unsupported']) {
    test(`automatic sync does not trigger a browser paste prompt when permission is ${permission}`, async () => {
        let reads = 0;
        const { clipboard: c } = await clipboard({ readText: async () => { reads++; } }, permission);
        await c._handleFocus();
        assert.equal(reads, 0);
    });
}

test('pasting into another page control does not send text to VNC', async () => {
    const { clipboard: c, document } = await clipboard(undefined);
    let called = false;
    c.onnativepaste = () => { called = true; };
    c.grab();
    document.activeElement = {};
    const event = paste('sidebar text');
    document.dispatchEvent(event);
    assert.equal(called, false);
    assert.equal(event.defaultPrevented, false);
    c.ungrab();
});

async function keyboard(isApple) {
    const events = [];
    const Keyboard = await load('core/input/keyboard.js', { window: new EventTarget() }, {
        '../util/logging.js': { Debug: () => {} },
        '../util/events.js': { stopEvent: event => event.preventDefault() },
        './util.js': { getKeycode: event => event.code, getKeysym: () => 118 },
        './keysym.js': { default: {} },
        '../util/browser.js': { isMac: () => isApple, isIOS: () => false, isWindows: () => false },
    });
    const result = new Keyboard();
    result.onkeyevent = (...event) => events.push(event);
    return { keyboard: result, events };
}

for (const isApple of [true, false]) {
    test(`native ${isApple ? 'Cmd+V' : 'Ctrl+Shift+V'} reaches the browser and releases remote modifiers`, async () => {
        const { keyboard: k, events } = await keyboard(isApple);
        k._keyDownList[isApple ? 'MetaLeft' : 'ControlLeft'] = 65513;
        let prevented = false;
        k._handleKeyDown({ code: 'KeyV', metaKey: isApple, ctrlKey: !isApple, shiftKey: !isApple, preventDefault: () => { prevented = true; } });
        assert.equal(prevented, false);
        assert.equal(events.length, 1);
        assert.equal(events[0][2], false, 'release the modifier before pasting');
        assert.equal(Object.keys(k._keyDownList).length, 0);
    });
}

test('ordinary typing is still handled by VNC', async () => {
    const { keyboard: k, events } = await keyboard(false);
    let prevented = false;
    k._handleKeyDown({ code: 'KeyV', preventDefault: () => { prevented = true; } });
    assert.equal(prevented, true);
    assert.equal(events.length, 1);
    assert.equal(events[0][2], true);
});

test('RFB sends clipboard data before paste keys, and respects view-only mode', async () => {
    const source = await readFile(path.join(root, 'core/rfb.js'), 'utf8');
    const dependencies = {};
    for (const match of source.matchAll(/^import\s+(.+?)\s+from\s+["'](.+?)["'];/gm)) {
        const [_, imported, specifier] = match;
        dependencies[specifier] = imported.startsWith('{')
            ? Object.fromEntries(imported.slice(1, -1).split(',').map(name => [name.trim(), () => {}]))
            : imported.startsWith('*') ? { Debug: () => {} } : { default: class {} };
    }
    const RFB = await load('core/rfb.js', {}, dependencies);
    const events = [];
    const rfb = {
        _rfbConnectionState: 'connected', _viewOnly: false,
        _keyboard: { _allKeysUp: () => events.push('release') },
        clipboardPasteFrom: text => events.push(['clipboard', text]),
        sendKey: (...key) => events.push(key),
    };
    RFB.prototype._handleNativePaste.call(rfb, 'robot command');
    assert.deepEqual(events, ['release', ['clipboard', 'robot command'],
        [0xffe1, 'ShiftLeft', true], [0xff63, 'Insert', true],
        [0xff63, 'Insert', false], [0xffe1, 'ShiftLeft', false]]);
    events.length = 0;
    rfb._viewOnly = true;
    RFB.prototype._handleNativePaste.call(rfb, 'must not arrive');
    assert.equal(events.length, 0);
});
