'use strict';
// The page only uses the message bridge. All REAPER APIs run in ReaWebAPI_Demo.lua.
const ui = Object.fromEntries([...document.querySelectorAll('[id]')].map(node => [node.id, node]));
const events = [], busy = new Set(), pending = new Map();
const session = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
let requestId = 0, backendState = null, connected = false, pageClosed = false, unsubscribe;
let observedTrack = null, colorDirty = false;
const sliders = Object.fromEntries(['volume', 'pan'].map(key => [key, {
  queued: null, flight: null, editing: false, pendingLog: null, logTimer: null,
}]));
let diagnosticRequest = 0;

function list(id, lines) {
  ui[id].replaceChildren(...lines.map(text => {
    const row = document.createElement('li'); row.textContent = text; return row;
  }));
}
function controls() {
  const track = connected && backendState?.track;
  for (const id of ['read-project', 'move-cursor', 'diagnostics', 'refresh-diagnostics'])
    ui[id].disabled = !connected || busy.has(id)
      || (id === 'refresh-diagnostics' && ui['diagnostic-panel'].hasAttribute('aria-busy'));
  for (const id of ['read-fx', 'reset-volume', 'center-pan']) ui[id].disabled = !track || busy.has(id);
  ui.volume.disabled = !track || busy.has('reset-volume');
  ui.pan.disabled = !track || busy.has('center-pan');
  for (const id of ['track-color', 'apply-color', 'reset-color'])
    ui[id].disabled = !track || busy.has('color');
  ui['cursor-target'].disabled = ui['log-reaper'].disabled = !connected;
  ui['copy-log'].disabled = !events.length || busy.has('copy-log');
}
function report(error) {
  if (pageClosed) return;
  ui.error.hidden = false;
  ui.error.textContent = `${error.code || 'ERROR'}: ${error.message}`;
  log(ui.error.textContent, 'error', 'ERROR');
}
async function action(id, fn) {
  if (pageClosed || busy.has(id)) return;
  busy.add(id); controls(); ui.error.hidden = true;
  try { await fn(); } catch (error) { report(error); }
  finally { busy.delete(id); controls(); }
}
function request(command, value = '', context = backendState) {
  if (pageClosed || (!connected && command !== 'ready')) return Promise.reject(new Error('Lua backend is not connected.'));
  const id = ++requestId;
  // Fixed headers and a free-text final field keep Lua independent of a JSON decoder.
  const text = [session, id, command, context?.epoch ?? 0, context?.selection ?? 0, value].join('\t');
  return new Promise((resolve, reject) => {
    const fail = error => {
      const entry = pending.get(id);
      if (!entry) return;
      clearTimeout(entry.timer); pending.delete(id); reject(error);
    };
    const timer = setTimeout(() => fail(new Error(`Lua did not confirm "${command}". Check REAPER before trying again; the command may already have run.`)), 10000);
    pending.set(id, { resolve, reject, timer });
    try {
      // Acceptance only means queued. Resolve after Lua sends its response.
      Promise.resolve(window.reaper.host.send(text)).then(accepted => {
        if (!accepted) fail(new Error('The message bridge did not accept the command.'));
      }, fail);
    } catch (error) { fail(error); }
  });
}
function current(response, track = false) {
  return !pageClosed && response.state?.epoch === backendState?.epoch
    && (!track || response.state.selection === backendState.selection);
}
function log(message, level = 'info', category = 'INFO') {
  if (pageClosed) return;
  const now = new Date();
  const time = now.toLocaleTimeString([], { hour12: false }) + '.' + String(now.getMilliseconds()).padStart(3, '0');
  const line = `${time} [${category}] ${message}`;
  const follow = ui.activity.scrollHeight - ui.activity.scrollTop - ui.activity.clientHeight < 32;
  if (!events.length) ui['log-status'].textContent = 'Track changes and confirmed volume / pan values. Latest 200 entries.';
  events.push(line);
  if (events.length > 200) events.shift();
  const row = document.createElement('div'); row.className = `log-row log-${level}`; row.textContent = line;
  ui.activity.append(row);
  if (ui.activity.children.length > 200) ui.activity.firstElementChild.remove();
  if (follow) ui.activity.scrollTop = ui.activity.scrollHeight;
  ui['log-count'].textContent = `${events.length} / 200`;
  ui['copy-log'].disabled = busy.has('copy-log');
  console[level === 'info' ? 'log' : level]('[ReaWebAPI demo]', `[${category}] ${message}`);
  if (connected && ui['log-reaper'].checked) {
    void request('console', line).catch(error => {
      ui['log-reaper'].checked = false;
      log(`REAPER console output stopped: ${error.message}`, 'warn', 'LOG');
    });
  }
}
function formatPan(value) {
  return `${value > 0 ? '+' : ''}${value.toFixed(3)} (${value === 0 ? 'center' : `${(Math.abs(value) * 100).toFixed(1)}% ${value < 0 ? 'L' : 'R'}`})`;
}
function formatVolume(value) {
  if (value <= 0) return '−∞ dB';
  const db = 20 * Math.log10(value);
  const rounded = Math.abs(db) < 0.05 ? 0 : db;
  return `${rounded > 0 ? '+' : ''}${rounded.toFixed(1)} dB`;
}
function trackSummary(track) {
  return track ? `Track ${JSON.stringify(track.name)} · Volume ${formatVolume(track.volume)} · Pan ${formatPan(track.pan)}` : 'No track selected.';
}
function sliderValue(key) {
  const value = Number(ui[key].value);
  return key === 'volume' ? (value <= Number(ui.volume.min) ? 0 : 10 ** (value / 20)) : value;
}
function showSlider(key, value) {
  const text = key === 'volume' ? formatVolume(value) : value.toFixed(2);
  ui[key].value = key === 'volume' ? (value > 0 ? 20 * Math.log10(value) : ui.volume.min) : value;
  ui[`${key}-value`].textContent = text;
  ui[key].setAttribute('aria-valuetext', key === 'pan' ? formatPan(value) : text);
}
function flushSliderLog(key) {
  const slider = sliders[key];
  clearTimeout(slider.logTimer); slider.logTimer = null;
  const change = slider.pendingLog; slider.pendingLog = null;
  const format = key === 'volume' ? formatVolume : formatPan;
  if (change && change.before[key] !== change.after[key])
    log(`${JSON.stringify(change.after.name)}: ${format(change.before[key])} → ${format(change.after[key])} · Lua readback`, 'info', key.toUpperCase());
}
function flushTrackLogs() {
  for (const key of Object.keys(sliders)) flushSliderLog(key);
}
function observeTrack(state) {
  const track = state.track;
  const previous = observedTrack;
  observedTrack = { epoch: state.epoch, selection: state.selection, track };
  if (!previous || previous.epoch !== state.epoch || previous.selection !== state.selection) {
    flushTrackLogs(); log(trackSummary(track), 'info', 'SELECT'); return;
  }
  if (!track || !previous.track) return;
  if (previous.track.name !== track.name) {
    flushTrackLogs(); log(`${JSON.stringify(previous.track.name)} → ${JSON.stringify(track.name)}`, 'info', 'NAME');
  }
  for (const [key, slider] of Object.entries(sliders)) {
    if (Math.abs(previous.track[key] - track[key]) <= 0.000000001) continue;
    if (!slider.pendingLog) slider.pendingLog = { before: previous.track, after: track };
    else slider.pendingLog.after = track;
    if (slider.logTimer === null) slider.logTimer = setTimeout(() => flushSliderLog(key), 200);
  }
}
function invalidateProject() {
  ui['project-name'].textContent = 'Project changed. Read a new snapshot.';
  for (const id of ['cursor-position', 'play-state', 'tempo', 'beat-position']) ui[id].textContent = '—';
  ui['marker-count'].textContent = 'Markers and regions';
  list('marker-list', ['Read the project to refresh.']);
}
function renderState(state) {
  const previous = backendState;
  const selectionChanged = !previous || previous.epoch !== state.epoch || previous.selection !== state.selection;
  const projectChanged = previous && (previous.epoch !== state.epoch || previous.changeCount !== state.changeCount);
  backendState = state;
  if (selectionChanged) {
    for (const slider of Object.values(sliders)) { slider.queued = null; slider.editing = false; }
    colorDirty = false;
  }
  if (projectChanged) invalidateProject();
  if (projectChanged || selectionChanged) {
    list('fx-list', ['Inspect FX to refresh.']);
  }
  const track = state.track;
  ui['track-name'].textContent = track ? track.name : 'No track selected.';
  ui['track-count'].textContent = `${state.count} ${state.count === 1 ? 'track' : 'tracks'} in project`;
  for (const [key, slider] of Object.entries(sliders)) {
    if (selectionChanged || (!slider.editing && !slider.flight && !slider.queued)) showSlider(key, track ? track[key] : 0);
  }
  if (selectionChanged || (!colorDirty && !busy.has('color'))) ui['track-color'].value = track ? track.hex : '#b7f58a';
  ui['color-state'].textContent = !track ? 'No track selected' : track.color ? 'Custom track color' : 'Default track color';
  ui.version.textContent = `REAPER ${state.version} / Lua backend`;
  observeTrack(state); controls();
}
function receive(text) {
  if (pageClosed) return;
  try {
    const message = JSON.parse(text);
    if (message.session !== session) return;
    if (message.state) renderState(message.state);
    if (message.type !== 'response') return;
    const entry = pending.get(message.id);
    if (!entry) return;
    clearTimeout(entry.timer); pending.delete(message.id);
    if (message.ok) entry.resolve(message);
    else entry.reject(new Error(message.error || 'Lua command failed.'));
  } catch (error) { report(error); }
}

ui['clear-log'].addEventListener('click', () => {
  for (const slider of Object.values(sliders)) {
    clearTimeout(slider.logTimer); slider.logTimer = null; slider.pendingLog = null;
  }
  events.length = 0; ui.activity.replaceChildren();
  ui['log-count'].textContent = '0 / 200'; ui['copy-log'].disabled = true; ui['log-status'].textContent = 'Log cleared.';
});
ui['copy-log'].addEventListener('click', () => action('copy-log', async () => {
  const text = events.join('\n');
  try {
    if (!navigator.clipboard?.writeText) throw new Error('Clipboard API unavailable');
    await navigator.clipboard.writeText(text);
  } catch {
    // A DOM fallback keeps clipboard work in the UI on WebViews without this API.
    const previous = document.activeElement;
    const textarea = document.createElement('textarea');
    textarea.className = 'clipboard-buffer'; textarea.value = text;
    textarea.setAttribute('readonly', ''); document.body.append(textarea); textarea.select();
    try {
      if (!document.execCommand('copy')) throw new Error('Clipboard unavailable. Select and copy the log manually.');
    } finally { textarea.remove(); previous?.focus(); }
  }
  ui['log-status'].textContent = 'Log copied to clipboard.';
}));
ui['log-reaper'].addEventListener('change', () => {
  log(ui['log-reaper'].checked ? 'REAPER console output enabled.' : 'REAPER console output disabled.', 'info', 'LOG');
});

function pumpSlider(key) {
  const slider = sliders[key];
  if (slider.flight || !slider.queued) return;
  const next = slider.queued; slider.queued = null;
  slider.flight = (async () => {
    try { await request(key, next.value, next.context); }
    catch (error) {
      // A stale request must not discard a new gesture on another track.
      if (next.context.epoch === backendState?.epoch && next.context.selection === backendState?.selection) {
        slider.queued = null; slider.editing = false;
      }
      report(error);
    } finally {
      slider.flight = null;
      if (slider.queued) pumpSlider(key);
      else if (!slider.editing && !pageClosed) showSlider(key, backendState?.track?.[key] ?? 0);
    }
  })();
}
async function drainSlider(key) {
  const slider = sliders[key];
  while (slider.flight || slider.queued) { pumpSlider(key); await slider.flight; }
  flushSliderLog(key);
}
for (const [key, slider] of Object.entries(sliders)) {
  ui[key].addEventListener('input', () => {
    if (!connected || !backendState?.track || ui[key].disabled) return;
    slider.editing = true;
    const value = sliderValue(key);
    showSlider(key, value);
    // Each control keeps one request in flight and only its latest queued value.
    slider.queued = { value, context: backendState };
    pumpSlider(key);
  });
  ui[key].addEventListener('change', () => {
    slider.editing = false;
    void drainSlider(key).then(() => {
      if (!pageClosed && !slider.editing) showSlider(key, backendState?.track?.[key] ?? 0);
    }).catch(report);
  });
  ui[key].addEventListener('blur', () => {
    slider.editing = false;
    if (!slider.flight && !slider.queued) showSlider(key, backendState?.track?.[key] ?? 0);
  });
}
for (const [id, key, label] of [['reset-volume', 'volume', 'Volume reset to 0 dB'], ['center-pan', 'pan', 'Center Pan applied']]) {
  ui[id].addEventListener('click', () => action(id, async () => {
    const context = backendState;
    await drainSlider(key);
    const response = await request(id, '', context);
    if (!current(response, true)) return;
    showSlider(key, response.data[key]); flushSliderLog(key);
    log(`${JSON.stringify(response.state.track.name)} · ${label} · Undo available`, 'info', 'WRITE');
  }));
}
ui['track-color'].addEventListener('input', () => { colorDirty = true; });
async function applyColor(reset) {
  const color = ui['track-color'].value;
  const response = await request(reset ? 'reset-color' : 'color', reset ? '' : color);
  if (!current(response, true)) return;
  colorDirty = false; ui['track-color'].value = response.state.track.hex;
  log(`${JSON.stringify(response.state.track.name)} · ${reset ? 'Default color' : color} · native ${response.data.color} · Undo available`, 'info', 'COLOR');
}
ui['apply-color'].addEventListener('click', () => action('color', () => applyColor(false)));
ui['reset-color'].addEventListener('click', () => action('color', () => applyColor(true)));

function renderProject(response) {
  if (!current(response) || response.state.changeCount !== backendState.changeCount) return;
  const data = response.data;
  ui['project-name'].textContent = data.name || 'Untitled project';
  ui['cursor-position'].textContent = `${data.cursor.toFixed(3)} s`;
  const status = data.playState & 4 ? 'Recording' : data.playState & 2 ? 'Paused' : data.playState & 1 ? 'Playing' : 'Stopped';
  ui['play-state'].textContent = `${status} · ${data.position.toFixed(2)} s`;
  ui.tempo.textContent = `${data.tempo.toFixed(2)} BPM`;
  ui['beat-position'].textContent = `${data.bar + 1} / ${(data.beat + 1).toFixed(2)} (${data.beatsPerBar}/${data.denominator})`;
  ui['marker-count'].textContent = `${data.markers} markers · ${data.regions} regions`;
  const labels = data.rows.map(row => `${row.region ? 'Region' : 'Marker'} ${row.number}: ${row.name || '(unnamed)'} · ${row.start.toFixed(3)} s${row.region ? ` to ${row.finish.toFixed(3)} s` : ''}`);
  if (data.total > 12) labels.push(`Showing the first 12 of ${data.total} markers and regions.`);
  list('marker-list', labels.length ? labels : ['No markers or regions in this project.']);
  log(`${JSON.stringify(data.name || 'Untitled project')} · Cursor ${data.cursor.toFixed(3)} s · ${status} · ${data.tempo.toFixed(2)} BPM · ${data.markers} markers / ${data.regions} regions`, 'info', 'PROJECT');
}
ui['read-project'].addEventListener('click', () => action('read-project', async () => renderProject(await request('project'))));
ui['move-cursor'].addEventListener('click', () => action('move-cursor', async () => {
  const text = ui['cursor-target'].value.trim(), time = Number(text);
  if (!text || !Number.isFinite(time)) throw new Error('Enter a finite time in seconds.');
  const response = await request('cursor', time);
  renderProject(response);
  if (current(response)) log(`Edit cursor → ${response.data.cursor.toFixed(3)} s`, 'info', 'CURSOR');
}));
ui['read-fx'].addEventListener('click', () => action('read-fx', async () => {
  const response = await request('fx');
  if (!current(response, true) || response.state.changeCount !== backendState.changeCount) return;
  const { rows, count, name } = response.data;
  const lines = rows.map((row, index) => `${index + 1}. ${row.name} · ${row.params} parameters${row.params ? ` · first: ${row.value.toFixed(3)} [${row.min.toFixed(3)}, ${row.max.toFixed(3)}]` : ''}`);
  if (count > 16) lines.push(`Showing the first 16 of ${count} FX.`);
  list('fx-list', lines.length ? lines : ['No FX on the selected track.']);
  log(`${JSON.stringify(name)} · ${count} FX`, 'info', 'FX');
}));

async function readDiagnostics() {
  const revision = ++diagnosticRequest;
  ui['refresh-diagnostics'].disabled = true;
  ui['diagnostic-panel'].setAttribute('aria-busy', 'true');
  ui['diagnostic-snapshot'].classList.remove('failed');
  ui['diagnostic-snapshot'].textContent = 'Reading Lua backend details…';
  try {
    const response = await request('diagnostics');
    if (revision !== diagnosticRequest || ui['diagnostic-panel'].hidden) return;
    const { runtime: text, ...backend } = response.data;
    const runtime = JSON.parse(text);
    ui['diagnostic-backend'].textContent = runtime.backend || '—';
    ui['diagnostic-stage'].textContent = `${runtime.stage || 'ready'} · Lua connected`;
    ui['diagnostic-api'].textContent = backend.backend;
    ui['diagnostic-queue'].textContent = `${backend.received} received · ${backend.sent} sent`;
    ui['diagnostic-output'].textContent = JSON.stringify({ backend, runtime }, null, 2);
    ui['diagnostic-details'].hidden = false;
    ui['diagnostic-snapshot'].textContent = `Snapshot updated at ${new Date().toLocaleTimeString()}. Refresh to read again.`;
  } catch (error) {
    if (revision !== diagnosticRequest || ui['diagnostic-panel'].hidden) return;
    ui['diagnostic-snapshot'].classList.add('failed');
    ui['diagnostic-snapshot'].textContent = `${error.message}. Try refreshing the snapshot.`;
  } finally {
    if (revision === diagnosticRequest) {
      ui['diagnostic-panel'].removeAttribute('aria-busy');
      ui['refresh-diagnostics'].disabled = !connected;
    }
  }
}
ui.diagnostics.addEventListener('click', () => {
  const open = ui['diagnostic-panel'].hidden;
  ui['diagnostic-panel'].hidden = !open; ui.diagnostics.setAttribute('aria-expanded', String(open));
  if (open) void readDiagnostics();
  else {
    ++diagnosticRequest; ui['diagnostic-panel'].removeAttribute('aria-busy');
    ui['refresh-diagnostics'].disabled = !connected; ui['diagnostic-details'].open = false;
  }
});
ui['refresh-diagnostics'].addEventListener('click', () => {
  if (!ui['diagnostic-panel'].hidden && !ui['refresh-diagnostics'].disabled) void readDiagnostics();
});
window.addEventListener('pagehide', () => {
  pageClosed = true; connected = false; ++diagnosticRequest;
  for (const slider of Object.values(sliders)) {
    slider.queued = null; slider.editing = false;
    clearTimeout(slider.logTimer); slider.logTimer = null; slider.pendingLog = null;
  }
  for (const entry of pending.values()) { clearTimeout(entry.timer); entry.reject(new Error('Page closed.')); }
  pending.clear();
  if (unsubscribe) void Promise.resolve(unsubscribe()).catch(() => {});
});

async function start() {
  controls();
  try {
    if (!window.reaper?.host?.send || !window.reaper?.events?.on)
      throw new Error('Load ReaWebAPI_Demo.lua from the REAPER Action List with a ReaWebAPI version that supports host messages.');
    unsubscribe = await window.reaper.events.on('message', receive);
    // Subscribe first. Each page reload gets its own session and fresh Lua snapshot.
    const response = await request('ready');
    if (pageClosed) return;
    connected = true; controls();
    ui.status.textContent = 'Lua connected'; ui.status.classList.add('connected');
    renderProject({ ...response, data: response.data.project });
    log('Connected to Lua. Selection and project changes update through the defer loop.');
  } catch (error) {
    if (pageClosed) return;
    connected = false; controls(); ui.status.textContent = 'Lua unavailable'; report(error);
  }
}
void start();
