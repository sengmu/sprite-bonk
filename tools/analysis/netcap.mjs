// Runtime network capture for pokebonk.com: attach to the CDP Chrome tab,
// reload, click through guest -> lobby -> run, record ALL requests and save
// every JSON response body under reference/data/ with a manifest.
import http from 'node:http';
import fs from 'node:fs';

const PORT = 9555;
const OUT = '/home/hatch/workspace/sprite-bonk-3d/reference/data';
fs.mkdirSync(OUT, { recursive: true });
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function getJson(path, method = 'GET') {
  return new Promise((res, rej) => {
    const req = http.request(`http://127.0.0.1:${PORT}${path}`, { method }, (r) => {
      let d = ''; r.on('data', (c) => (d += c)); r.on('end', () => { try { res(JSON.parse(d)); } catch { res(d); } });
    });
    req.on('error', rej); req.end();
  });
}

let tabs = await getJson('/json/list');
let tab = tabs.filter((t) => t.type === 'page').pop();
if (!tab) { log('no tab, creating'); tab = await getJson('/json/new?https://pokebonk.com/', 'PUT'); }
log('TAB', tab.id, tab.url);

const ws = new WebSocket(tab.webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0; const pending = new Map(); const listeners = [];
ws.onmessage = (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); return; }
  for (const fn of listeners) fn(m);
};
function send(method, params = {}) { return new Promise((res) => { const i = ++id; pending.set(i, res); ws.send(JSON.stringify({ id: i, method, params })); }); }
async function evalJs(expr) {
  const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true });
  if (r.result?.exceptionDetails) return 'EXC: ' + (r.result.exceptionDetails.exception?.description || '').slice(0, 200);
  return r.result?.result?.value ?? '';
}
async function shot(name) {
  const r = await send('Page.captureScreenshot', { format: 'png' });
  if (r.result?.data) { fs.writeFileSync(`${OUT}/${name}`, Buffer.from(r.result.data, 'base64')); log('SHOT', name); }
}
const pageText = () => evalJs(`document.body ? document.body.innerText.slice(0, 4000) : ''`);
async function clickTextJS(text) {
  const r = await evalJs(`(() => {
    const els = [...document.querySelectorAll('button, a, [role=button], div, span')];
    const el = els.filter(e => e.offsetParent !== null && e.textContent.trim() === ${JSON.stringify(text)})
      .sort((a, b) => (a.textContent.length - b.textContent.length))[0];
    if (!el) return false; el.click(); return true; })()`);
  log('clickText', JSON.stringify(text), '->', r);
  return r === true;
}
async function waitForText(text, timeoutMs) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeoutMs) {
    const t = await pageText();
    if (typeof t === 'string' && t.includes(text)) return true;
    await sleep(2500);
  }
  return false;
}
async function dismiss() { // GPU warning overlay
  const t = await pageText();
  if (typeof t === 'string' && t.includes('Got it')) await clickTextJS('Got it');
}

// ---- network recording -------------------------------------------------
const manifest = [];         // every finished request
const responses = new Map(); // requestId -> info
let savedCount = 0;
listeners.push(async (m) => {
  if (m.method === 'Network.responseReceived') {
    const r = m.params.response;
    responses.set(m.params.requestId, { url: r.url, status: r.status, mime: r.mimeType, type: m.params.type });
  }
  if (m.method === 'Network.loadingFinished') {
    const info = responses.get(m.params.requestId) || {};
    const entry = { url: info.url || '', status: info.status, mime: info.mime || '', type: info.type || '', bytes: m.params.encodedDataLength, file: null, error: null };
    manifest.push(entry);
    const isJson = (info.mime || '').includes('json') || /\.json(\?|$)/.test(info.url || '');
    if (isJson && info.url) {
      try {
        const body = await send('Network.getResponseBody', { requestId: m.params.requestId });
        if (body.result?.body != null) {
          let name = decodeURIComponent(new URL(info.url).pathname.split('/').pop() || 'data');
          if (!name || name === 'data') name = 'resp';
          if (!name.endsWith('.json')) name += '.json';
          let fname = name; let k = 1;
          while (fs.existsSync(`${OUT}/${fname}`)) fname = name.replace('.json', `_${k++}.json`);
          const raw = body.result.base64Encoded ? Buffer.from(body.result.body, 'base64').toString('utf8') : body.result.body;
          fs.writeFileSync(`${OUT}/${fname}`, raw);
          entry.file = fname; savedCount++;
          log('SAVED JSON', fname, raw.length, 'bytes <-', info.url);
        }
      } catch (e) { entry.error = String(e).slice(0, 120); }
    }
  }
});

await send('Network.enable', { maxTotalBufferSize: 200 * 1024 * 1024, maxResourceBufferSize: 100 * 1024 * 1024 });
await send('Page.enable'); await send('Runtime.enable');

// ---- drive the game ------------------------------------------------------
const cur = await evalJs('location.href');
log('current url:', cur);
if (!String(cur).includes('pokebonk')) {
  await send('Page.navigate', { url: 'https://pokebonk.com/' });
  await sleep(8000);
}
await send('Page.reload', {});
log('reloaded; waiting for load...');
await sleep(30000);
await dismiss();
await shot('cap_00_loaded.png');
log('text head:', String(await pageText()).slice(0, 300).replace(/\n/g, ' | '));

if (await waitForText('Play as a guest', 20000)) { await clickTextJS('Play as a guest'); await sleep(6000); await dismiss(); }
await shot('cap_01_after_guest.png');
log('text head:', String(await pageText()).slice(0, 300).replace(/\n/g, ' | '));

// Starter select (only if not yet chosen in this profile).
if (String(await pageText()).includes('choose')) {
  await clickTextJS('Bulbasaur');
  await sleep(1500);
  if (await waitForText('Yes, I choose', 8000)) { await clickTextJS('Yes, I choose'); await sleep(5000); await dismiss(); }
}
await shot('cap_02_lobby.png');
log('text head:', String(await pageText()).slice(0, 300).replace(/\n/g, ' | '));

if (String(await pageText()).includes('Skip')) { await clickTextJS('Skip'); await sleep(2500); }
await clickTextJS('Play'); await sleep(5000); await dismiss();
if (String(await pageText()).includes('I choose you')) { await clickTextJS('I choose you!'); await sleep(5000); }
await shot('cap_03_setup.png');
log('text head:', String(await pageText()).slice(0, 300).replace(/\n/g, ' | '));

if (String(await pageText()).includes('Start!')) { await clickTextJS('Start!'); await sleep(4000); await dismiss(); }
if (String(await pageText()).includes('Start now')) { await clickTextJS('Start now'); await sleep(6000); }
await shot('cap_04_run_start.png');
log('text head:', String(await pageText()).slice(0, 300).replace(/\n/g, ' | '));

// First minute+ of play: keep capturing; a few frames for state proof.
for (let i = 0; i < 3; i++) { await sleep(25000); await shot(`cap_05_play_${i}.png`); }

fs.writeFileSync(`${OUT}/manifest.json`, JSON.stringify({ captured_at: new Date().toISOString(), requests: manifest }, null, 1));
log('DONE. requests:', manifest.length, 'json saved:', savedCount);
console.log('JSON URLS:');
for (const e of manifest) if (e.file || (e.mime || '').includes('json')) console.log(' -', e.url, '->', e.file || e.error || '');
process.exit(0);
