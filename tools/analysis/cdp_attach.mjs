// Attach to an existing pokebonk tab: node cdp_attach.mjs <script.json>
import http from 'node:http';
import fs from 'node:fs';
const spec = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const PORT = 9555;
function getJson(path) { return new Promise((res, rej) => { http.get(`http://127.0.0.1:${PORT}${path}`, (r) => { let d=''; r.on('data',c=>d+=c); r.on('end',()=>res(JSON.parse(d))); }).on('error', rej); }); }
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const tabs = await getJson('/json/list');
const tab = tabs.filter(t => t.type === 'page' && t.url.includes('pokebonk')).pop();
if (!tab) { console.log('NO TAB'); process.exit(1); }
console.log('TAB', tab.id, tab.url, tab.title);
const ws = new WebSocket(tab.webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0; const pending = new Map();
ws.onmessage = (ev) => { const m = JSON.parse(ev.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } };
function send(method, params = {}) { return new Promise((res) => { const i = ++id; pending.set(i, res); ws.send(JSON.stringify({ id: i, method, params })); }); }
await send('Page.enable'); await send('Runtime.enable');
async function shot(name) { const r = await send('Page.captureScreenshot', { format: 'png' }); if (r.result?.data) { fs.writeFileSync(name, Buffer.from(r.result.data, 'base64')); console.log('SHOT', name); } else console.log('SHOT FAILED', JSON.stringify(r).slice(0,200)); }
async function evalJs(expr) { const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true }); if (r.result?.exceptionDetails) return 'EXC: ' + (r.result.exceptionDetails.exception?.description || r.result.exceptionDetails.text || '').slice(0,300); return r.result?.result?.value ?? r.result?.result?.description ?? ''; }
async function clickXY(x, y, after=1000) { await send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 }); await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 }); await sleep(after); }
for (const st of spec.steps || []) {
  if (st.type === 'shot') await shot(st.name);
  else if (st.type === 'wait') await sleep(st.ms || 1000);
  else if (st.type === 'eval') console.log('EVAL>>', await evalJs(st.expr));
  else if (st.type === 'click') await clickXY(st.x, st.y, st.after || 1000);
  else if (st.type === 'clickEl') {
    const pt = await evalJs(`(() => { const el = document.querySelector(${JSON.stringify(st.sel)}); if (!el) return null; const r = el.getBoundingClientRect(); return {x: r.x + r.width/2, y: r.y + r.height/2, w: r.width, h: r.height}; })()`);
    console.log('CLICKEL', st.sel, '->', JSON.stringify(pt));
    if (pt) await clickXY(pt.x, pt.y, st.after || 1000);
  } else if (st.type === 'clickText') {
    const pt = await evalJs(`(() => { const els=[...document.querySelectorAll('button,a,[role=button],div,span')]; const el=els.filter(e=>e.offsetParent!==null).find(e=>e.textContent.trim()===${JSON.stringify(st.text)}); if(!el) return null; const r=el.getBoundingClientRect(); return {x:r.x+r.width/2, y:r.y+r.height/2, cls:el.className}; })()`);
    console.log('CLICKTEXT', st.text, '->', JSON.stringify(pt));
    if (pt) await clickXY(pt.x, pt.y, st.after || 1000);
  } else if (st.type === 'key') {
    await send('Input.dispatchKeyEvent', { type: 'keyDown', key: st.key, code: st.code || st.key, windowsVirtualKeyCode: st.vk || 0 });
    await sleep(st.hold || 60);
    await send('Input.dispatchKeyEvent', { type: 'keyUp', key: st.key, code: st.code || st.key, windowsVirtualKeyCode: st.vk || 0 });
    await sleep(st.after || 300);
  } else if (st.type === 'keys') {
    for (const k of st.keys) await send('Input.dispatchKeyEvent', { type: 'keyDown', key: k.key, code: k.code, windowsVirtualKeyCode: k.vk || 0 });
    await sleep(st.hold || 1000);
    for (const k of st.keys) await send('Input.dispatchKeyEvent', { type: 'keyUp', key: k.key, code: k.code, windowsVirtualKeyCode: k.vk || 0 });
    await sleep(st.after || 300);
  }
}
console.log('DONE');
process.exit(0);
