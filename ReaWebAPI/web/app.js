'use strict';
const ui = Object.fromEntries(['status', 'track-count', 'track-name', 'read-track', 'devtools', 'activity', 'error', 'version', 'pan', 'pan-value', 'center-pan', 'diagnostics', 'diagnostic-output', 'track-color', 'apply-color', 'reset-color', 'color-state', 'read-project', 'project-name', 'cursor-position', 'play-state', 'tempo', 'beat-position', 'cursor-target', 'move-cursor', 'marker-count', 'marker-list', 'read-fx', 'fx-list', 'run-checks', 'api-coverage', 'check-results'].map(id => [id, document.getElementById(id)]));
const events = [], dispose = [];
for (const id of ['read-track-result', 'copy-log', 'clear-log', 'log-reaper', 'log-count', 'log-status']) ui[id] = document.getElementById(id);
for (const id of ['diagnostic-panel', 'refresh-diagnostics', 'diagnostic-backend', 'diagnostic-stage', 'diagnostic-api', 'diagnostic-queue', 'diagnostic-snapshot', 'diagnostic-details']) ui[id] = document.getElementById(id);
let selectedTrack = null, refreshWanted = false, refreshing = false;
let selectionRevision = 0, colorRevision = 0;
let pendingPan = Promise.resolve();
let projectEpoch = 0, colorBusy = false;
let observedTrack = null, readRequested = false, flushPanOnRead = false, panWriteRevision = 0;
let pendingPanLog = null, panLogTimer = null, pageClosed = false;
const busy = new Set();
function list(id, lines) {
  ui[id].replaceChildren(...lines.map(text => {
    const row = document.createElement('li'); row.textContent = text; return row;
  }));
}
function selectedControls() {
  for (const id of ['track-color', 'apply-color', 'reset-color']) ui[id].disabled = !selectedTrack || colorBusy;
  ui['read-fx'].disabled = !selectedTrack || busy.has('read-fx');
}
async function action(id, fn) {
  if (busy.has(id)) return;
  busy.add(id); ui[id].disabled = true;
  try { await run(fn); } finally { busy.delete(id); ui[id].disabled = false; selectedControls(); }
}
function log(message, level = 'info', category = 'INFO', detail) {
  if (pageClosed) return;
  const now = new Date();
  const time = now.toLocaleTimeString([], { hour12: false }) + '.' + String(now.getMilliseconds()).padStart(3, '0');
  const line = `${time} [${category}] ${message}`;
  const follow = ui.activity.scrollHeight - ui.activity.scrollTop - ui.activity.clientHeight < 32;
  if (!events.length) ui['log-status'].textContent = 'Track changes and confirmed Pan values. Latest 200 entries.';
  events.push(line);
  if (events.length > 200) events.shift();
  const row = document.createElement('div');
  row.className = `log-row log-${level}`; row.textContent = line;
  ui.activity.append(row);
  if (ui.activity.children.length > 200) ui.activity.firstElementChild.remove();
  if (follow) ui.activity.scrollTop = ui.activity.scrollHeight;
  ui['log-count'].textContent = `${events.length} / 200`;
  ui['copy-log'].disabled = busy.has('copy-log');
  console[level === 'info' ? 'log' : level]('[ReaWebAPI demo]', `[${category}] ${message}`, ...(detail ? [detail] : []));
  if (ui['log-reaper'].checked && window.reaper) {
    // Console mirroring is optional and never blocks state reads or UI updates.
    void reaper.debug[level === 'info' ? 'log' : level](line).catch(error => {
      ui['log-reaper'].checked = false;
      log(`REAPER console output stopped: ${error.message}`, 'warn', 'LOG');
    });
  }
}
function formatPan(value) {
  const n = Number(value);
  return `${n > 0 ? '+' : ''}${n.toFixed(3)} (${n === 0 ? 'center' : `${(Math.abs(n) * 100).toFixed(1)}% ${n < 0 ? 'L' : 'R'}`})`;
}
function trackSummary(snapshot) {
  return snapshot.id ? `Track ${JSON.stringify(snapshot.name)} · Pan ${formatPan(snapshot.pan)}` : 'No track selected.';
}
function flushPanLog() {
  clearTimeout(panLogTimer); panLogTimer = null;
  const change = pendingPanLog; pendingPanLog = null;
  if (change && change.before.pan !== change.after.pan)
    log(`${JSON.stringify(change.after.name)}: ${formatPan(change.before.pan)} → ${formatPan(change.after.pan)} · REAPER readback`, 'info', 'PAN');
}
function observeTrack(snapshot) {
  const previous = observedTrack;
  observedTrack = snapshot;
  if (!previous || previous.id !== snapshot.id || previous.epoch !== snapshot.epoch) {
    flushPanLog();
    log(trackSummary(snapshot), 'info', 'SELECT');
    return;
  }
  if (!snapshot.id) return;
  if (previous.name !== snapshot.name) {
    flushPanLog();
    log(`${JSON.stringify(previous.name)} → ${JSON.stringify(snapshot.name)}`, 'info', 'NAME');
  }
  if (Math.abs(previous.pan - snapshot.pan) > 0.000001) {
    if (!pendingPanLog) pendingPanLog = { before: previous, after: snapshot };
    else pendingPanLog.after = snapshot;
    // Coalesce continuous changes into at most five readback entries per second.
    if (panLogTimer === null) panLogTimer = setTimeout(flushPanLog, 200);
  }
}
function finishTrackRead(message) {
  readRequested = false;
  ui['read-track'].disabled = false;
  ui['read-track'].textContent = 'Log selected track';
  ui['read-track-result'].textContent = message;
}
ui['clear-log'].addEventListener('click', () => {
  clearTimeout(panLogTimer); panLogTimer = null; pendingPanLog = null;
  events.length = 0; ui.activity.replaceChildren();
  ui['log-count'].textContent = '0 / 200'; ui['copy-log'].disabled = true;
  ui['log-status'].textContent = 'Log cleared.';
});
ui['copy-log'].addEventListener('click', () => action('copy-log', async () => {
  await reaper.clipboard.writeText(events.join('\n'));
  ui['log-status'].textContent = 'Log copied to clipboard.';
}).finally(() => { ui['copy-log'].disabled = !events.length; }));
ui['log-reaper'].addEventListener('change', () => {
  log(ui['log-reaper'].checked ? 'REAPER console output enabled.' : 'REAPER console output disabled.', 'info', 'LOG');
});
function report(error) {
  ui.error.hidden = false;
  ui.error.textContent = `${error.code || 'ERROR'}: ${error.message}`;
  log(ui.error.textContent, 'error', 'ERROR', error);
}
async function run(action) {
  ui.error.hidden = true;
  try { await action(); } catch (error) { report(error); }
}
function showPan(value) {
  ui.pan.value = value;
  ui['pan-value'].textContent = Number(value).toFixed(2);
}
async function refresh(invalidate = false) {
  if (pageClosed) return;
  if (invalidate) {
    ++selectionRevision; ++colorRevision;
    selectedTrack = null;
    ui.pan.disabled = ui['center-pan'].disabled = true;
    selectedControls();
  }
  refreshWanted = true;
  if (refreshing) return;
  refreshing = true;
  try {
    do {
      refreshWanted = false;
      const revision = selectionRevision, requestedLog = readRequested, flushPan = flushPanOnRead;
      const track = await reaper.GetSelectedTrack(0, 0);
      if (revision !== selectionRevision) continue;
      const calls = [{ method: 'CountTracks', args: [0] }];
      if (track) calls.push({ method: 'GetTrackName', args: [track] },
        { method: 'GetMediaTrackInfo_Value', args: [track, 'D_PAN'] }, { method: 'GetTrackColor', args: [track] });
      const [count, name, pan, color = 0] = await reaper.transaction.batch(calls);
      if (revision !== selectionRevision) continue;
      const trackChanged = selectedTrack?.id !== track?.id;
      selectedTrack = track;
      ui['track-name'].textContent = name?.[1] ?? 'No track selected.';
      ui['track-count'].textContent = `${count} ${count === 1 ? 'track' : 'tracks'} in project`;
      ui.pan.disabled = ui['center-pan'].disabled = !track;
      selectedControls();
      ui['color-state'].textContent = !track ? 'No track selected' : color ? 'Custom track color' : 'Default track color';
      if (trackChanged || document.activeElement !== ui.pan) showPan(pan ?? 0);
      const snapshot = { id: track?.id ?? null, epoch: projectEpoch, name: name?.[1] ?? '(name unavailable)', pan: pan ?? 0 };
      observeTrack(snapshot);
      if (requestedLog) {
        flushPanLog();
        log(trackSummary(snapshot), 'info', 'READ');
        finishTrackRead(`Logged: ${trackSummary(snapshot)}`);
        ui.activity.scrollTop = ui.activity.scrollHeight;
      }
      if (flushPan) { flushPanOnRead = false; flushPanLog(); }
      // Render the name and controls first. Native color conversion must not
      // delay selection feedback or the next refresh, and late results expire.
      const colorRequest = ++colorRevision;
      if (!color && document.activeElement !== ui['track-color']) ui['track-color'].value = '#b7f58a';
      if (color) void reaper.ColorFromNative(color).then(rgb => {
        if (colorRequest === colorRevision && document.activeElement !== ui['track-color'])
          ui['track-color'].value = '#' + rgb.map(n => n.toString(16).padStart(2, '0')).join('');
      }).catch(error => { if (colorRequest === colorRevision) report(error); });
    } while (refreshWanted);
  } catch (error) {
    selectedTrack = null;
    ui.pan.disabled = ui['center-pan'].disabled = true;
    selectedControls();
    // Project/selection events schedule the next read. Writes are never retried.
    if (!['PROJECT_CHANGED', 'STALE_HANDLE', 'WINDOW_CLOSED'].includes(error.code)) report(error);
    if (readRequested) {
      log(`Track read interrupted: ${error.code || error.message}. Try again.`, 'warn', 'READ');
      finishTrackRead('Read interrupted. Try again.');
    }
  } finally {
    refreshing = false;
    if (refreshWanted) void refresh();
  }
}
ui['read-track'].addEventListener('click', () => {
  readRequested = true; ui['read-track'].disabled = true;
  ui['read-track'].textContent = 'Reading…'; ui['read-track-result'].textContent = 'Reading from REAPER…';
  ui.error.hidden = true;
  void refresh();
});
ui.devtools.addEventListener('click', () => run(async () => { await reaper.debug.openDevTools(); log('DevTools open requested.'); }));
async function applyColor(reset) {
  if (!selectedTrack || colorBusy) return;
  const track = selectedTrack, epoch = projectEpoch;
  colorBusy = true; selectedControls();
  try {
    const rgb = ui['track-color'].value.slice(1).match(/../g).map(n => parseInt(n, 16));
    const color = reset ? 0 : await reaper.ColorToNative(...rgb);
    if (projectEpoch !== epoch) throw new Error('Project changed. Select the track again.');
    // SetTrackColor(0) means black. Clearing a custom color uses I_CUSTOMCOLOR.
    const call = reset ? { method: 'SetMediaTrackInfo_Value', args: [track, 'I_CUSTOMCOLOR', 0] }
      : { method: 'SetTrackColor', args: [track, color] };
    await reaper.transaction.batch([call], { undoLabel: 'ReaWebAPI: track color' });
    const actual = await reaper.GetTrackColor(track);
    if (actual !== (reset ? 0 : color | 0x1000000)) throw new Error('Track color readback differs from the requested value.');
    const trackName = observedTrack?.id === track.id ? observedTrack.name : track.id;
    log(`${JSON.stringify(trackName)} · ${reset ? 'Default color' : ui['track-color'].value} · native ${actual} · Undo available`, 'info', 'COLOR');
    await refresh();
  } finally { colorBusy = false; selectedControls(); }
}
ui['apply-color'].addEventListener('click', () => run(() => applyColor(false)));
ui['reset-color'].addEventListener('click', () => run(() => applyColor(true)));

async function readProject() {
  const epoch = projectEpoch;
  const [name, cursor, position, state, tempo, counts] = await Promise.all([
    reaper.GetProjectName(0), reaper.GetCursorPosition(), reaper.GetPlayPosition(),
    reaper.GetPlayState(), reaper.Master_GetTempo(), reaper.CountProjectMarkers(0)
  ]);
  const beat = await reaper.TimeMap2_timeToBeats(0, cursor);
  const rows = await Promise.all(Array.from({ length: Math.min(counts[0], 12) }, (_, i) => reaper.EnumProjectMarkers3(0, i)));
  if (epoch !== projectEpoch) return;
  ui['project-name'].textContent = name || 'Untitled project';
  ui['cursor-position'].textContent = `${cursor.toFixed(3)} s`;
  const status = state & 4 ? 'Recording' : state & 2 ? 'Paused' : state & 1 ? 'Playing' : 'Stopped';
  ui['play-state'].textContent = `${status} · ${position.toFixed(2)} s`;
  ui.tempo.textContent = `${tempo.toFixed(2)} BPM`;
  ui['beat-position'].textContent = `${beat[1] + 1} / ${(beat[0] + 1).toFixed(2)} (${beat[2]}/${beat[4]})`;
  ui['marker-count'].textContent = `${counts[1]} markers · ${counts[2]} regions`;
  const labels = rows.filter(row => row[0] !== 0).map(([, region, start, end, label, number]) =>
    `${region ? 'Region' : 'Marker'} ${number}: ${label || '(unnamed)'} · ${start.toFixed(3)} s${region ? ` to ${end.toFixed(3)} s` : ''}`);
  if (counts[0] > 12) labels.push(`Showing the first 12 of ${counts[0]} markers and regions.`);
  list('marker-list', labels.length ? labels : ['No markers or regions in this project.']);
  log(`${JSON.stringify(name || 'Untitled project')} · Cursor ${cursor.toFixed(3)} s · ${status} · ${tempo.toFixed(2)} BPM · ${counts[1]} markers / ${counts[2]} regions`, 'info', 'PROJECT');
}
ui['read-project'].addEventListener('click', () => action('read-project', readProject));
ui['move-cursor'].addEventListener('click', () => action('move-cursor', async () => {
  const text = ui['cursor-target'].value.trim(), time = Number(text);
  if (!text || !Number.isFinite(time)) throw new Error('Enter a finite time in seconds.');
  const result = await reaper.SetEditCurPos(time, true, false);
  if (result !== undefined) throw new Error('Expected a void JavaScript return value.');
  await readProject(); log(`Edit cursor → ${time.toFixed(3)} s`, 'info', 'CURSOR');
}));
ui['read-fx'].addEventListener('click', () => action('read-fx', async () => {
  const track = selectedTrack, epoch = projectEpoch;
  if (!track) return;
  const count = await reaper.TrackFX_GetCount(track), lines = [];
  for (let fx = 0; fx < Math.min(count, 16); ++fx) {
    const [ok, name] = await reaper.TrackFX_GetFXName(track, fx);
    const params = await reaper.TrackFX_GetNumParams(track, fx);
    let value = '';
    if (params > 0) {
      const [current, min, max] = await reaper.TrackFX_GetParam(track, fx, 0);
      value = ` · first: ${current.toFixed(3)} [${min.toFixed(3)}, ${max.toFixed(3)}]`;
    }
    lines.push(`${fx + 1}. ${ok ? name : '(FX unavailable)'} · ${params} parameters${value}`);
  }
  if (epoch !== projectEpoch || selectedTrack?.id !== track.id) return;
  if (count > 16) lines.push(`Showing the first 16 of ${count} FX.`);
  list('fx-list', lines.length ? lines : ['No FX on the selected track.']);
  log(`${JSON.stringify(observedTrack?.name ?? track.id)} · ${count} FX`, 'info', 'FX');
}));
ui['run-checks'].addEventListener('click', () => action('run-checks', async () => {
  const epoch = projectEpoch, rows = [], finite = value => typeof value === 'number' && Number.isFinite(value);
  const check = async (label, fn) => {
    try {
      const result = await fn();
      if (projectEpoch !== epoch) throw new Error('Project changed during checks. Run again.');
      rows.push([result === null ? 'SKIP' : result ? 'PASS' : 'FAIL', label]);
    } catch (error) { rows.push(['FAIL', `${label}: ${error.code || error.message}`]); }
  };
  await check('Generated API definitions match the native host', async () => {
    const c = await reaper.system.getCapabilities();
    const names = Object.keys(c.api.bindings);
    return c.api.implemented === names.length && names.every(n => c.methods.includes(n) && typeof reaper[n] === 'function');
  });
  await check('Project name / version / change counter', async () =>
    typeof await reaper.GetProjectName(0) === 'string' && typeof await reaper.GetAppVersion() === 'string' && Number.isInteger(await reaper.GetProjectStateChangeCount(0)));
  await check('Cursor, playback state and tempo', async () => {
    const a = await Promise.all([reaper.GetCursorPosition(), reaper.GetPlayPosition(), reaper.GetPlayState(), reaper.Master_GetTempo()]);
    return a.every(finite) && Number.isInteger(a[2]) && a[3] > 0;
  });
  await check('TimeMap2_timeToBeats returns five ordered values', async () => {
    const values = await reaper.TimeMap2_timeToBeats(0, await reaper.GetCursorPosition());
    return values.length === 5 && values.every(finite) && values[2] > 0 && values[4] > 0;
  });
  await check('Marker count and enumeration tuples', async () => {
    const counts = await reaper.CountProjectMarkers(0);
    const marker = await reaper.EnumProjectMarkers3(0, 0);
    return counts.length === 3 && counts.every(n => Number.isInteger(n) && n >= 0) && counts[0] === counts[1] + counts[2]
      && marker.length === 7 && typeof marker[1] === 'boolean' && (marker[4] === null || typeof marker[4] === 'string') && (counts[0] === 0 ? marker[0] === 0 : marker[0] !== 0);
  });
  await check('RGB / native color round trip', async () => {
    const rgb = await reaper.ColorFromNative(await reaper.ColorToNative(37, 149, 211));
    return JSON.stringify(rgb) === '[37,149,211]';
  });
  await check('Track handle and FX queries (select a track to exercise)', async () => {
    const track = await reaper.GetSelectedTrack(0, 0);
    if (!track) return null;
    const count = await reaper.TrackFX_GetCount(track);
    if (!Number.isInteger(await reaper.GetTrackColor(track)) || !Number.isInteger(count) || count < 0) return false;
    if (count) {
      const [ok, name] = await reaper.TrackFX_GetFXName(track, 0);
      if (!ok || typeof name !== 'string') return false;
      if (await reaper.TrackFX_GetNumParams(track, 0) > 0) {
        const values = await reaper.TrackFX_GetParam(track, 0, 0);
        if (values.length !== 3 || !values.every(finite)) return false;
      }
    }
    return true;
  });
  await check('Project handles, GUID conversion and RECT output', async () => {
    const [project] = await reaper.EnumProjects(-1);
    if (!project || !(await reaper.ValidatePtr(project, 'ReaProject*'))) return false;
    if (await reaper.CountTracks(project) !== await reaper.CountTracks(0)) return false;
    const guid = await reaper.genGuid('');
    const converted = await reaper.stringToGuid(guid, '');
    const rectangle = await reaper.EnsureNotCompletelyOffscreen(20, 20, 420, 320);
    return /^\{[\dA-F-]{36}\}$/i.test(guid) && converted === guid && rectangle.length === 4 && rectangle.every(Number.isInteger);
  });
  await check('Media item / take / envelope handles and MIDI bytes', async () => {
    const track = await reaper.GetSelectedTrack(0, 0);
    if (!track) return null;
    const envelope = await reaper.GetTrackEnvelope(track, 0);
    if (envelope && !(await reaper.ValidatePtr2(0, envelope, 'TrackEnvelope*'))) return false;
    const item = await reaper.GetTrackMediaItem(track, 0);
    if (!item) return null;
    if (!(await reaper.ValidatePtr2(0, item, 'MediaItem*'))) return false;
    const take = await reaper.GetActiveTake(item);
    if (!take || !(await reaper.TakeIsMIDI(take))) return null;
    const [ok, bytes] = await reaper.MIDI_GetAllEvts(take);
    if (!ok || !(bytes instanceof Uint8Array)) return false;
    log(`Read ${bytes.byteLength} MIDI bytes without changing the take.`);
    return true;
  });
  await check('Audio accessor lifetime and Float64Array write-back', async () => {
    const track = await reaper.GetSelectedTrack(0, 0);
    if (!track) return null;
    const accessor = await reaper.CreateTrackAudioAccessor(track);
    if (!accessor) return false;
    try {
      const start = await reaper.GetAudioAccessorStartTime(accessor);
      const samples = new Float64Array(32);
      const status = await reaper.GetAudioAccessorSamples(accessor, 48000, 1, start, samples.length, samples);
      return Number.isInteger(status) && samples.every(Number.isFinite);
    } finally { await reaper.DestroyAudioAccessor(accessor); }
  });
  ui['check-results'].replaceChildren(...rows.map(([status, label]) => {
    const item = document.createElement('li'); item.className = status.toLowerCase(); item.textContent = `${status} · ${label}`; return item;
  }));
  log(`API checks: ${rows.filter(r => r[0] === 'PASS').length} passed, ${rows.filter(r => r[0] === 'FAIL').length} failed, ${rows.filter(r => r[0] === 'SKIP').length} skipped.`);
}));
ui.pan.addEventListener('input', () => {
  const track = selectedTrack, value = Number(ui.pan.value), revision = ++panWriteRevision, epoch = projectEpoch;
  ui['pan-value'].textContent = value.toFixed(2);
  if (track) pendingPan = reaper.audio.setTrackValueLatest(track, 'D_PAN', value).then(result => {
    if (!result.superseded && !result.applied) throw new Error('REAPER rejected the Pan update.');
    if (result.applied && revision === panWriteRevision && epoch === projectEpoch && selectedTrack?.id === track.id)
      void refresh();
  }).catch(report);
});
ui.pan.addEventListener('change', () => run(async () => {
  await pendingPan;
  flushPanOnRead = true;
  void refresh();
}));
ui['center-pan'].addEventListener('click', () => run(async () => {
  if (!selectedTrack) return;
  const track = selectedTrack, epoch = projectEpoch, revision = selectionRevision;
  const name = observedTrack?.id === track.id ? observedTrack.name : track.id;
  ui.pan.disabled = true;
  try {
    await pendingPan;
    const [applied] = await reaper.transaction.batch([{ method: 'SetMediaTrackInfo_Value', args: [track, 'D_PAN', 0] }], { undoLabel: 'ReaWebAPI: center track pan' });
    if (!applied) throw new Error('REAPER rejected the Center Pan command.');
    log(`${JSON.stringify(name)} · Center Pan applied · Undo available`, 'info', 'WRITE');
    if (epoch === projectEpoch && revision === selectionRevision && selectedTrack?.id === track.id) {
      showPan(0); flushPanOnRead = true; void refresh();
    }
  } finally { ui.pan.disabled = !selectedTrack; }
}));
let diagnosticRequest = 0;
async function readDiagnostics() {
  const request = ++diagnosticRequest;
  ui['refresh-diagnostics'].disabled = true;
  ui['diagnostic-panel'].setAttribute('aria-busy', 'true');
  ui['diagnostic-snapshot'].classList.remove('failed');
  ui['diagnostic-snapshot'].textContent = 'Reading runtime details…';
  try {
    const [runtime, capabilities] = await Promise.all([reaper.debug.getDiagnostics(), reaper.system.getCapabilities()]);
    if (request !== diagnosticRequest || ui['diagnostic-panel'].hidden) return;
    const { schemaVersion, reaperVersion, catalogueHash, official, implemented, compatible, partial, missing, available, unavailable } = capabilities.api;
    ui['diagnostic-backend'].textContent = runtime.backend;
    ui['diagnostic-stage'].textContent = runtime.stage;
    ui['diagnostic-api'].textContent = `${available} / ${implemented}`;
    ui['diagnostic-queue'].textContent = `${runtime.queuedCalls} queued · ${runtime.pendingCalls} pending`;
    // Keep useful diagnostics, without dumping all 730 binding signatures and method names.
    ui['diagnostic-output'].textContent = JSON.stringify({ runtime, api: { schemaVersion, reaperVersion, catalogueHash, official, implemented, compatible, partial, missing, available, unavailable } }, null, 2);
    ui['diagnostic-details'].hidden = false;
    ui['diagnostic-snapshot'].textContent = `Snapshot updated at ${new Date().toLocaleTimeString()}. Refresh to read again.`;
  } catch (error) {
    if (request !== diagnosticRequest || ui['diagnostic-panel'].hidden) return;
    ui['diagnostic-snapshot'].classList.add('failed');
    ui['diagnostic-snapshot'].textContent = `${error.code || 'ERROR'}: ${error.message}. Try refreshing the snapshot.`;
  } finally {
    if (request === diagnosticRequest) {
      ui['refresh-diagnostics'].disabled = false;
      ui['diagnostic-panel'].removeAttribute('aria-busy');
    }
  }
}
ui.diagnostics.addEventListener('click', () => {
  const open = ui['diagnostic-panel'].hidden;
  ui['diagnostic-panel'].hidden = !open;
  ui.diagnostics.setAttribute('aria-expanded', String(open));
  if (open) void readDiagnostics();
  else {
    // A late response must never reopen a panel the user has already closed.
    ++diagnosticRequest;
    ui['diagnostic-panel'].removeAttribute('aria-busy');
    ui['refresh-diagnostics'].disabled = false;
    ui['diagnostic-details'].open = false;
  }
});
ui['refresh-diagnostics'].addEventListener('click', () => {
  if (!ui['diagnostic-panel'].hidden && !ui['refresh-diagnostics'].disabled) void readDiagnostics();
});
window.addEventListener('pagehide', () => {
  pageClosed = true; ++selectionRevision; ++colorRevision; ++panWriteRevision;
  clearTimeout(panLogTimer); pendingPanLog = null;
  for (const off of dispose) void off();
});
run(async () => {
  if (!window.reaper) {
    ui.status.textContent = 'Outside REAPER';
    for (const control of ['read-track', 'devtools', 'diagnostics']) ui[control].disabled = true;
    throw new Error('Load ReaWebAPI_Demo.lua from the REAPER Action List to open this demo.');
  }
  const capabilities = await reaper.lifecycle.ready;
  if (capabilities.api?.implemented !== 730 || !capabilities.methods.includes('MIDI_GetAllEvts') || typeof reaper.window?.setIcon !== 'function') {
    ui.status.textContent = 'Extension update required';
    throw new Error('Install the matching ReaWebAPI extension and restart REAPER to use this demo.');
  }
  projectEpoch = capabilities.projectEpoch;
  ui.status.textContent = 'Runtime connected'; ui.status.classList.add('connected');
  // First track data is independent of the version label and window setup.
  void refresh();
  const version = await reaper.GetAppVersion();
  ui.version.textContent = `REAPER ${version} / ReaWebAPI ${capabilities.version}`;
  ui['api-coverage'].textContent = `${capabilities.api.implemented} bound APIs / ${capabilities.api.official} definitions · ${capabilities.api.available} available in this REAPER · ${capabilities.api.reaperVersion} catalogue`;
  if (capabilities.api.unavailable.length)
    log(`${capabilities.api.unavailable.length} APIs require a newer REAPER version. See Runtime diagnostics for their names.`, 'warn', 'API');
  await reaper.window.setTitle('ReaWebAPI · API Workbench');
  dispose.push(await reaper.events.on('selectionchange', () => { list('fx-list', ['Selection changed. Inspect FX to refresh.']); void refresh(true); }));
  dispose.push(await reaper.events.on('projectchange', state => {
    const switched = projectEpoch !== state.projectEpoch;
    projectEpoch = state.projectEpoch;
    ui['project-name'].textContent = 'Project changed. Read a new snapshot.';
    for (const id of ['cursor-position', 'play-state', 'tempo', 'beat-position']) ui[id].textContent = '—';
    ui['marker-count'].textContent = 'Markers and regions';
    list('marker-list', ['Read the project to refresh.']); list('fx-list', ['Inspect FX to refresh.']);
    void refresh(switched);
  }));
  for (const id of ['read-track', 'log-reaper', 'read-project', 'move-cursor', 'cursor-target', 'run-checks']) ui[id].disabled = false;
  await refresh();
  await readProject();
  log('Connected. Selection and project changes update this page automatically.');
});
