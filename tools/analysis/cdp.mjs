// Minimal CDP driver: node cdp.mjs <script.json>
// script: {url, waitMs, steps:[{type:'click'|'key'|'type'|'shot'|'eval', ...}], outPrefix}
import http from 'node:http';
import fs from 'node:fs';

const spec = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const PORT = 9555;

function getJson(path) {
  return new Promise((res, rej) => {
    http.get(`http://127.0.0.1:${PORT}${path}`, (r) => {
      let d = ''; r.on('data', (c) => (d += c)); r.on('end', () => res(JSON.parse(d)));
    }).on('error', rej);
  });
}
function putJson(path) {
  return new Promise((res, rej) => {
    const req = http.request(`http://127.0.0.1:${PORT}${path}`, { method: 'PUT' }, (r) => {
      let d = ''; r.on('data', (c) => (d += c)); r.on('end', () => res(JSON.parse(d)));
    });
    req.on('error', rej); req.end();
  });
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const tab = await putJson(`/json/new?${encodeURIComponent(spec.url)}`);
const ws = new WebSocket(tab.webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0;
const pending = new Map();
ws.onmessage = (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
};
function send(method, params = {}) {
  return new Promise((res) => { const i = ++id; pending.set(i, res); ws.send(JSON.stringify({ id: i, method, params })); });
}
await send('Page.enable');
await send('Runtime.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
await sleep(spec.waitMs || 8000);

async function shot(name) {
  const r = await send('Page.captureScreenshot', { format: 'png' });
  if (r.result?.data) { fs.writeFileSync(name, Buffer.from(r.result.data, 'base64')); console.log('SHOT', name); }
  else console.log('SHOT FAILED', name, JSON.stringify(r).slice(0, 200));
}
async function evalJs(expr) {
  const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true });
  return r.result?.result?.value ?? r.result?.result?.description ?? JSON.stringify(r.result).slice(0, 300);
}

for (const st of spec.steps || []) {
  if (st.type === 'shot') await shot(st.name);
  else if (st.type === 'wait') await sleep(st.ms || 1000);
  else if (st.type === 'eval') console.log('EVAL>>', await evalJs(st.expr));
  else if (st.type === 'click') {
    await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: st.x, y: st.y, button: 'left', clickCount: 1 });
    await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: st.x, y: st.y, button: 'left', clickCount: 1 });
    await sleep(st.after || 800);
  } else if (st.type === 'clickText') {
    const pt = await evalJs(`(() => { const els=[...document.querySelectorAll('button,a,div,span')]; const el=els.find(e=>e.offsetParent!==null && e.textContent.trim().startsWith(${JSON.stringify(st.text)})); if(!el) return null; const r=el.getBoundingClientRect(); return {x:r.x+r.width/2, y:r.y+r.height/2, tag:el.tagName, cls:el.className}; })()`);
    console.log('CLICKTEXT', st.text, '->', JSON.stringify(pt));
    if (pt) { await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: pt.x, y: pt.y, button: 'left', clickCount: 1 }); await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: pt.x, y: pt.y, button: 'left', clickCount: 1 }); }
    await sleep(st.after || 1000);
  } else if (st.type === 'key') {
    await send('Input.dispatchKeyEvent', { type: 'keyDown', key: st.key, code: st.code || st.key, windowsVirtualKeyCode: st.vk || 0 });
    await sleep(st.hold || 60);
    await send('Input.dispatchKeyEvent', { type: 'keyUp', key: st.key, code: st.code || st.key, windowsVirtualKeyCode: st.vk || 0 });
    await sleep(st.after || 300);
  } else if (st.type === 'keys') {
    // hold several keys down for ms (movement)
    for (const k of st.keys) await send('Input.dispatchKeyEvent', { type: 'keyDown', key: k.key, code: k.code, windowsVirtualKeyCode: k.vk || 0 });
    await sleep(st.hold || 1000);
    for (const k of st.keys) await send('Input.dispatchKeyEvent', { type: 'keyUp', key: k.key, code: k.code, windowsVirtualKeyCode: k.vk || 0 });
    await sleep(st.after || 300);
  }
}
console.log('DONE');
process.exit(0);
