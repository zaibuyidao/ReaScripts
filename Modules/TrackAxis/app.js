import { defaults, preferences, meterHeightRange, themePresets, themePalette, toDb, fromDb, dbText, routeKnobPosition, routeKnobVolume, filterTracks, recentSearches, filterFX, fxFormat, sortFX, hardwareOutputChannels, isSettingsShortcut, CommandQueue } from './model.js';
import { AudioAnalysis, drawOverview } from './audio.js';

const $ = id => document.getElementById(id);
const el = (tag, className = '', text = '') => { const n = document.createElement(tag); n.className = className; n.textContent = text; return n; };
const storageKey = 'trackaxis.preferences.v1', searchHistoryKey = 'trackaxis.searchHistory.v1';
let searchHistory = [], searchView = null;
let prefs = preferences(), locale = {}, english = {}, languages = [], session = null, api, audio;
let state = {}, connected = false, dirty = new Set(), catalog = [], dialogContext, overviewRevision = 0, overviewKey = '', overviewData;
let disposed = false, closing = false, cleanupPromise, unsubscribe, lifecycleStop, projectStop;
let nativeTheme, gestureSequence = 0, fxDrag = null;
let routePicker, modeSwitching;
const isMaster = () => state.tracks?.mode === 'master';
const routeExpansion = new Map(), routeScroll = new Map();
const listLayouts = new Map(), listScroll = new Map();
let listResizeHandle;
const gestures = new Map(), iconCache = new Map();
const rendered = new Map();
const t = (key, values = {}) => (locale[key] ?? english[key] ?? key).replace(/\{(\w+)\}/g, (_, name) => values[name] ?? `{${name}}`);
const report = error => { $('status').textContent = t(typeof error === 'string' ? error : error?.message || 'unknownError'); };
const context = () => ({session, selectionKey: state.tracks?.key || ''});
const current = c => c.session === session && c.selectionKey === state.tracks?.key;
const queue = new CommandQueue(message => api.host.send(message), context, error => {
  modeSwitching = null; renderMode();
  rendered.clear(); Object.keys(renderers).forEach(id => dirty.add(id)); report(error);
}, () => setTimeout(flushRender, 0));

function act(command, captured = context(), replaceKey = '') {
  if (!connected || !current(captured)) { report('staleState'); return; }
  $('status').textContent = '';
  queue.enqueue(Object.fromEntries(Object.entries(command).filter(([,value]) => value !== undefined)), replaceKey);
}
function renderMode() {
  const master = isMaster(); document.body.dataset.mode = master ? 'master' : 'track';
  document.body.classList.toggle('empty-selection',!state.tracks?.count);
  for (const mode of ['track','master']) {
    const control = $(`mode-${mode}`);
    control.setAttribute('aria-pressed', mode === (master ? 'master' : 'track'));
    control.disabled = !connected || !state.tracks || !!modeSwitching;
  }
  for (const id of ['parameters','items','appearance']) $(`panel-${id}`).hidden = master;
  $('search').closest('.search-wrap').hidden = master;
  $('inspector').inert = !!modeSwitching;
}
function switchMode(mode) {
  if (!connected || modeSwitching || mode === (isMaster() ? 'master' : 'track')) return;
  for (const finish of [...gestures.values()]) finish();
  document.activeElement?.blur(); closePanMenu(); closeRecordMenu(); closeMeterMenu(); closeSearch(true);
  modeSwitching = mode; renderMode(); act({action:'mode',value:mode});
}
$('mode-track').onclick = () => switchMode('track');
$('mode-master').onclick = () => switchMode('master');
function savePreferences(next) {
  try { localStorage.setItem(storageKey, JSON.stringify(next)); return true; }
  catch { report('preferencesFailed'); return false; }
}
function applyTheme() {
  const {scheme, ...colors} = themePalette(prefs, nativeTheme);
  for (const [key,value] of Object.entries(colors)) document.documentElement.style.setProperty(`--${key}`,value);
  document.documentElement.style.colorScheme = scheme;
  if (overviewData && !$('overview').hidden) drawOverview($('overview-canvas'), overviewData);
}
function trackIcon(path) {
  const img = el('img','track-icon'); img.alt = t('trackIcon'); img.title = path; img.draggable = false;
  if (!iconCache.has(path)) {
    const promise = api.fs.readBinary(path).then(bytes => URL.createObjectURL(new Blob([bytes],{type:/\.png$/i.test(path) ? 'image/png' : 'image/jpeg'})));
    iconCache.set(path,promise);
    if (iconCache.size > 32) {
      const oldest = iconCache.keys().next().value;
      iconCache.get(oldest).then(url => URL.revokeObjectURL(url)).catch(() => {}); iconCache.delete(oldest);
    }
  }
  iconCache.get(path).then(url => { if (!disposed) img.src = url; }).catch(() => { img.hidden = true; img.title = t('iconUnavailable'); iconCache.delete(path); });
  img.onerror = () => { img.hidden = true; };
  return img;
}
async function chooseTrackIcon(c) {
  try {
    const path = await api.dialog.openFile({title:t('setIcon'),initialPath:state.tracks.iconDirectory,filters:[{name:t('images'),extensions:['png','jpg','jpeg']}]});
    if (path) act({action:'setIcon',path},c);
  } catch (error) { report(error); }
}
async function language(code) {
  const chosen = languages.find(item => item.code === code) || languages[0];
  const response = await fetch(`./locales/${chosen.code}.json`);
  if (!response.ok) throw Error('languageFailed');
  locale = await response.json(); prefs.language = chosen.code;
  document.documentElement.lang = chosen.code;
  document.querySelectorAll('[data-i18n]').forEach(n => { n.textContent = t(n.dataset.i18n); });
  document.querySelectorAll('[data-placeholder]').forEach(n => { n.placeholder = t(n.dataset.placeholder); n.setAttribute('aria-label', t(n.dataset.placeholder)); });
  document.querySelectorAll('[data-title]').forEach(n => { n.title = t(n.dataset.title); n.setAttribute('aria-label', t(n.dataset.title)); });
  document.querySelectorAll('[data-analysis-kind]').forEach(n => { n.title = `${t(n.dataset.analysisKind)} · ${t('restartAnalysis')}`; n.setAttribute('aria-label',n.title); });
  $('connection').textContent = t(connected ? 'connected' : 'disconnected');
}
function button(label, handler, className = '', title = label) {
  const b = el('button', className, t(label)); b.type = 'button'; b.title = t(title); b.onclick = handler; return b;
}
function literalButton(label, handler, className = '', title = label) {
  const b = button('', handler, className); b.textContent = label; b.title = title; return b;
}
function fxIcon(control, pathData) {
  const ns = 'http://www.w3.org/2000/svg', svg = document.createElementNS(ns,'svg'), path = document.createElementNS(ns,'path');
  for (const [key,value] of Object.entries({viewBox:'0 0 24 24',fill:'none',stroke:'currentColor','stroke-width':'1.7','stroke-linecap':'round','stroke-linejoin':'round','aria-hidden':'true',focusable:'false'})) svg.setAttribute(key,value);
  path.setAttribute('d',pathData); svg.append(path);
  control.setAttribute('aria-label',control.title); control.replaceChildren(svg); return control;
}
function row(label, control) { const n = el('div', 'row'); n.append(el('span', '', t(label)), control); return n; }
function hint(text) { return el('p', 'hint', t(text)); }
function commitField(input, change) {
  let committed = input.value;
  const commit = () => {
    if (input.value === committed) return;
    if (!input.checkValidity()) { input.reportValidity(); return; }
    committed = input.value; change(input.value);
  };
  input.onchange = commit; input.onblur = commit;
  input.onkeydown = event => { if (event.key === 'Enter' && input.tagName !== 'TEXTAREA') { event.preventDefault(); input.blur(); } };
  return () => { committed = input.value; };
}
function numeric(label, value, options, change, mixed = false) {
  const input = el('input'); input.type = 'number';
  Object.assign(input, options); input.setAttribute('aria-label', t(label));
  input.value = Number.isFinite(value) ? Number(value.toFixed(6)) : '';
  input.placeholder = mixed ? t('mixed') : '—';
  commitField(input, value => { if (value !== '') change(Number(value)); });
  return row(label, input);
}
function select(label, value, choices, change, mixed = false) {
  const input = el('select'); input.setAttribute('aria-label', t(label));
  if (mixed || value == null) { const o = el('option', '', mixed ? t('mixed') : '—'); o.value = ''; o.disabled = true; input.append(o); }
  for (const [v, text, literal] of choices) { const o = el('option', '', literal ? text : t(text)); o.value = v; input.append(o); }
  if (value != null && !choices.some(x => String(x[0]) === String(value))) { const o = el('option', '', t('currentValue', {value})); o.value = value; o.disabled = true; input.append(o); }
  input.value = value == null ? '' : value;
  input.onchange = () => change(Number(input.value));
  return row(label, input);
}
function toggle(label, value, change, mixed = false) {
  const b = button(label, () => {
    value = mixed || !value ? 1 : 0; mixed = false;
    b.setAttribute('aria-pressed', !!value); change(value);
  });
  b.setAttribute('aria-pressed', mixed ? 'mixed' : !!value);
  if (mixed) b.title = `${t(label)} · ${t('mixed')}`;
  return b;
}
function checkbox(label, value, change, mixed = false) {
  const input = el('input'); input.type = 'checkbox'; input.checked = !!value; input.indeterminate = mixed;
  input.setAttribute('aria-label', t(label)); input.onchange = () => change(input.checked ? 1 : 0);
  const node = el('div', 'check'); node.append(input, el('span', '', t(label))); return node;
}
function liveRange(range, change, preview = () => {}) {
  let id, last, idle, keepAlive;
  const captured = context();
  const finish = () => {
    clearTimeout(idle); clearInterval(keepAlive);
    if (!id) return;
    act({action: 'gestureEnd', gesture: id}, captured);
    gestures.delete(range); id = null; setTimeout(flushRender, 0);
  };
  range.onpointerdown = event => { if (event.button === 0) range.setPointerCapture?.(event.pointerId); };
  range.oninput = () => {
    preview();
    if (range.value === last) return;
    last = range.value;
    if (!id) {
      id = `drag-${Date.now()}-${++gestureSequence}`; gestures.set(range, finish);
      keepAlive = setInterval(() => { if (current(captured)) api.host.send({type: 'gesturePing', gesture: id}).catch(report); else finish(); }, 1000);
    }
    change(Number(range.value), id);
    clearTimeout(idle);
    if (!range._scrubbing && !range.matches(':active') && !range.hasPointerCapture?.(range._pointerId)) idle = setTimeout(finish, 350);
  };
  range.addEventListener('pointerdown', event => { range._pointerId = event.pointerId; });
  range.onchange = () => { range.oninput(); finish(); };
  range.onpointerup = finish; range.onpointercancel = finish; range.onlostpointercapture = finish;
  range.onblur = finish;
}
function fader(label, value, mixed, change, type = 'volume') {
  const isVolume = type === 'volume';
  const display = n => isVolume ? Math.max(-90, toDb(n)) : n * 100;
  const convert = n => isVolume ? fromDb(n) : n / 100;
  const n = el('div', 'fader'), range = el('input'), number = el('input');
  range.type = 'range'; number.type = 'number';
  for (const input of [range, number]) {
    input.min = isVolume ? -90 : -100; input.max = isVolume ? 12 : 100; input.step = isVolume ? 0.1 : 1;
    input.setAttribute('aria-label', `${t(label)} ${isVolume ? '(dB)' : '(%)'}`);
  }
  range.value = value == null ? (isVolume ? -12 : 0) : display(value);
  number.value = value == null ? '' : Number(display(value).toFixed(1)); number.placeholder = mixed ? t('mixed') : '—';
  const show = () => {
    range.title = mixed && number.value === '' ? t('mixed') : isVolume ? `${number.value <= -90 ? '−∞' : number.value} dB` : type === 'width' ? `${number.value}%` : Number(number.value) === 0 ? t('center') : `${Math.abs(number.value)}% ${t(Number(number.value) < 0 ? 'left' : 'right')}`;
    range.setAttribute('aria-valuetext', range.title);
  };
  const markCommitted = commitField(number, value => { if (value !== '') { range.value = value; show(); change(convert(Number(value))); } });
  liveRange(range, (value, gesture) => change(convert(value), gesture), () => { number.value = range.value; markCommitted(); show(); });
  range.ondblclick = event => {
    event.preventDefault(); range.value = 0;
    range.dispatchEvent(new Event('input', {bubbles: true}));
    range.dispatchEvent(new Event('change', {bubbles: true}));
  };
  const caption = el('span', '', t(label));
  show(); n.append(caption, range, number); return n;
}
function field(label, value, change, mixed = false, multiline = false) {
  const input = el(multiline ? 'textarea' : 'input');
  if (!multiline) input.type = 'text';
  input.maxLength = multiline ? 32768 : 1024; input.value = value ?? ''; input.placeholder = mixed ? t('mixed') : '';
  input.setAttribute('aria-label', t(label)); commitField(input, change);
  if (!multiline) return row(label, input);
  const container = el('div'); container.append(el('span', 'notes-label', t(label)), input); return container;
}
function arrangeColumns(grid,height,minimum,columns = 2) {
  const gap = parseFloat(getComputedStyle(grid).rowGap) || 0;
  const count = Math.max(1,Math.floor((height + gap) / (minimum + gap)));
  for (const [index,card] of [...grid.children].entries()) {
    card.style.gridColumn = Math.floor(index % (count * columns) / count) + 1;
    card.style.gridRow = Math.floor(index / (count * columns)) * count + index % count + 1;
  }
  return count;
}
function listResizer(viewport,key,selector,label,arrange) {
  const currentHeight = () => viewport.getBoundingClientRect().height;
  const handle = el('div','list-resizer'); handle.tabIndex = 0;
  handle.setAttribute('role','separator'); handle.setAttribute('aria-orientation','horizontal');
  handle.setAttribute('aria-label',`${t(label)} · ${t('resizeList')}`); handle.title = t('resizeList');
  const measure = () => {
    const card = viewport.querySelector(selector), height = card?.getBoundingClientRect().height;
    if (!viewport.isConnected || !height) return null;
    const details = card.querySelector('.route-details');
    const minimum = Math.ceil(height - (details && !details.hidden ? details.getBoundingClientRect().height : 0));
    const gap = parseFloat(getComputedStyle(card.parentElement).rowGap) || 0;
    return {minimum,defaultHeight:minimum * 3 + gap * 2};
  };
  const layout = () => {
    const sizes = measure(); if (!sizes) return;
    const height = Math.max(sizes.minimum,prefs.listHeights[key] || sizes.defaultHeight);
    viewport.style.maxHeight = height + 'px';
    viewport.style.height = prefs.listHeights[key] ? height + 'px' : '';
    arrange?.(height,sizes.minimum);
    handle.setAttribute('aria-valuemin',sizes.minimum); handle.setAttribute('aria-valuemax',4000);
    handle.setAttribute('aria-valuenow',Math.round(currentHeight()));
  };
  const resize = height => {
    const sizes = measure(); if (!sizes) return;
    prefs.listHeights[key] = Math.max(sizes.minimum,Math.min(4000,height)); layout();
  };
  let drag;
  handle.onpointerdown = event => {
    if (event.button !== 0) return;
    event.preventDefault(); handle.setPointerCapture(event.pointerId); handle.focus({preventScroll:true});
    drag = {y:event.clientY,height:currentHeight()}; listResizeHandle = handle;
  };
  handle.onpointermove = event => { if (drag) resize(drag.height + event.clientY - drag.y); };
  const finish = () => {
    if (!drag) return;
    drag = null; listResizeHandle = null; savePreferences(prefs); setTimeout(flushRender,0);
  };
  handle.onpointerup = finish; handle.onpointercancel = finish; handle.onlostpointercapture = finish;
  handle.onkeydown = event => {
    if (!['ArrowUp','ArrowDown','Home'].includes(event.key)) return;
    event.preventDefault(); resize(event.key === 'Home' ? 0 : currentHeight() + (event.key === 'ArrowDown' ? 16 : -16)); savePreferences(prefs);
  };
  handle.ondblclick = () => { prefs.listHeights[key] = 0; layout(); savePreferences(prefs); };
  handle.hidden = !viewport.querySelector(selector);
  listLayouts.set(key,{viewport,layout}); queueMicrotask(layout);
  return handle;
}
function layoutLists() {
  for (const [key,entry] of listLayouts) {
    if (!entry.viewport.isConnected) listLayouts.delete(key); else entry.layout();
  }
}
window.addEventListener('resize',layoutLists);
document.addEventListener('toggle',layoutLists,true);
function editable(id, render, force = false) {
  const root = $(id);
  const tr = state.tracks || {}, v = tr.values || {}, m = tr.mixed || {};
  const fields = keys => keys.map(k => [v[k], !!m[k]]);
  const inputs = {
    'track-header': [tr.count, tr.refs, tr.parent, tr.folder, fields(['name','color','icon'])],
    mixer: fields(['volume','pan','width','panMode','panModeEffective','panLeft','panRight','mute','solo','arm','phase','mono','monitor','monitorItems','preservePDC']),
    routing: [tr.count,state.routing,v.mainSend,v.channels,state.index,prefs.routingCompact], fx: [tr.count,state.fx,state.parameters?.guid,prefs.fxCompact,v.fxEnabled],
    'fx-parameters': state.parameters,
    parameters: [fields(['panMode','automation','input','midiMap','recordMode','recordOutput','recordLatency','monitor','monitorItems','preservePDC']),state.inputs],
    items: state.items, metadata: state.metadata, appearance: fields(['color','icon','tcp','mcp']),
    quick: [tr.count,tr.parent,tr.masterVisible,fields(['mute','solo','arm'])],
  };
  const signature = JSON.stringify([session,tr.key,prefs.language,inputs[id]]);
  if (!force && rendered.get(id) === signature) { dirty.delete(id); return; }
  const editing = root.contains(document.activeElement) && document.activeElement.matches('textarea,input[type=text],input[type=number],input[type=color]');
  if (!force && (editing || root.contains(listResizeHandle) || [...gestures.keys()].some(node => root.contains(node)) || fxDrag && id === 'fx' || queue.busy)) { dirty.add(id); return; }
  dirty.delete(id); root.replaceChildren(...render()); rendered.set(id, signature);
}
function flushRender() {
  if (disposed || queue.busy) return;
  for (const id of [...dirty]) renderers[id]?.();
}
document.addEventListener('focusout', () => setTimeout(flushRender, 0));
const automationChoices = ['trimRead', 'read', 'touch', 'write', 'latch', 'latchPreview'].map((k, i) => [i, k]);
const monitorChoices = [[0, 'off'], [1, 'monitorInput'], [2, 'tapeMonitor']];
const panModeChoices = [[-1,'projectDefault'],[3,'panBalance'],[5,'panStereo'],[6,'panDual']];
const recordChoices = ['recordInput','recordStereo','recordNone','recordStereoLatency','recordMIDI','recordMono','recordMonoLatency','recordMIDIOverdub','recordMIDIReplace','recordMIDITouch','recordMultichannel','recordMultichannelLatency','recordForceMono','recordForceStereo','recordForceMultichannel','recordForceMIDI','recordMIDILatch'].map((key,value) => [value,key]);
const recordGroups = {recordMIDIGroup:[7,8,9,16],recordOutputGroup:[10,11,1,3,5,6,4],recordForceGroup:[12,13,14,15]};
function setTrack(field, value, c, gesture) { act({action: 'setTrack', field, value, gesture}, c, `track:${field}:${gesture || ''}`); }
function panModeSelect(v, m, c) {
  return select('panMode', v.panMode, panModeChoices, n => setTrack('panMode',n,c), m.panMode);
}

function renderHeader(force = false) {
  editable('track-header', () => {
    const tr = state.tracks, c = context(); if (!tr?.count) return [];
    const title = el('div', 'track-title');
    if (isMaster()) {
      title.append(el('h1', '', 'MASTER'));
      $('track-header').style.setProperty('--track-color', 'var(--accent)');
      return [title];
    }
    if (tr.count === 1 && tr.values.icon) {
      const icon = button('setIcon',() => chooseTrackIcon(c),'track-icon-button');
      icon.setAttribute('aria-label',t('setIcon')); icon.replaceChildren(trackIcon(tr.values.icon)); title.append(icon);
    }
    if (tr.count === 1) {
      const input = el('input'); input.type = 'text'; input.value = tr.values.name; input.maxLength = 1024; input.id = 'track-name'; input.setAttribute('aria-label', t('trackName'));
      commitField(input, value => act({action: 'rename', value}, c));
      input.addEventListener('blur',() => { input.scrollLeft = 0; }); input.title = tr.values.name;
      title.append(el('span', 'track-number', String(tr.refs[0].number).padStart(2, '0')), input);
    } else title.append(el('h1', '', t('selectedTracks', {count: tr.count})));
    const color = el('input'); color.type = 'color'; color.value = tr.values.color || '#6e9992'; color.title = t(tr.mixed.color ? 'mixed' : 'trackColor'); color.setAttribute('aria-label', t('trackColor'));
    color.onchange = () => act({action: 'color', value: color.value}, c); title.append(color);
    const info = el('div', 'track-context');
    if (tr.parent) info.append(literalButton(tr.parent.name, () => act({action: 'selectTrack', guid: tr.parent.guid}, c), 'subtle', t('parentTrack')));
    else if (tr.count === 1) info.append(el('span', '', t(tr.folder > 0 ? 'folderTrack' : 'rootTrack')));
    if (tr.count > 1) info.append(el('span', 'mixed-hint', t('multiHint')));
    if (tr.mixed.color) info.append(el('span', 'mixed-hint', t('mixedColor')));
    const result = [title, info];
    $('track-header').style.setProperty('--track-color', tr.values.color || '#6e9992');
    return result;
  }, force);
}
function renderMixer(force = false) {
  editable('mixer', () => {
    const {values: v = {}, mixed: m = {}} = state.tracks || {}, c = context();
    const controls = el('div', 'mix-buttons');
    for (const key of isMaster() ? ['mute','solo','envelopes','phase','mono'] : ['mute','solo','arm','envelopes','phase']) {
      if (key === 'envelopes') {
        const control = button(key,() => act({action:'quick',operation:key},c));
        control.disabled = state.tracks?.count !== 1; controls.append(control); continue;
      }
      const control = toggle(key === 'mono' ? v.mono ? 'mono' : 'stereo' : key, v[key], n => {
        if (key === 'mono') control.textContent = control.title = t(n ? 'mono' : 'stereo');
        setTrack(key,n,c);
      },m[key]);
      if (key === 'arm') {
        control.oncontextmenu = event => { event.preventDefault(); openRecordMenu(event,control,c,'monitor'); };
        control.onkeydown = event => {
          if (event.key === 'ContextMenu' || event.shiftKey && event.key === 'F10') { event.preventDefault(); openRecordMenu(null,control,c,'monitor'); }
        };
      }
      controls.append(control);
    }
    const mode = v.panModeEffective ?? v.panMode;
    const pan = m.panModeEffective ? [panModeSelect(v,m,c)] : mode === 6
      ? [fader('panLeft',v.panLeft,m.panLeft,(n,g) => setTrack('panLeft',n,c,g),'pan'), fader('panRight',v.panRight,m.panRight,(n,g) => setTrack('panRight',n,c,g),'pan')]
      : [fader('pan',v.pan,m.pan,(n,g) => setTrack('pan',n,c,g),'pan')];
    if (!m.panModeEffective && mode === 5) pan.push(fader('width',v.width,m.width,(n,g) => setTrack('width',n,c,g),'width'));
    for (const control of pan) {
      control.oncontextmenu = event => { event.preventDefault(); openPanMenu(event, control, c); };
      control.onkeydown = event => {
        if (event.key === 'ContextMenu' || event.shiftKey && event.key === 'F10') { event.preventDefault(); openPanMenu(null, control, c); }
      };
    }
    const faders = el('div','mixer-faders');
    faders.append(fader('volume',v.volume,m.volume,(n,g) => setTrack('volume',n,c,g)),...pan);
    return [faders,controls];
  }, force);
}
let panMenuAnchor;
function closePanMenu(restoreFocus = false) {
  $('pan-menu').hidden = true;
  if (restoreFocus && panMenuAnchor?.isConnected) panMenuAnchor.querySelector('input')?.focus();
  panMenuAnchor = null;
}
function openPanMenu(event, anchor, captured) {
  closeRecordMenu();
  const menu = $('pan-menu'), tr = state.tracks;
  panMenuAnchor = anchor; menu.replaceChildren();
  menu.setAttribute('aria-label', t('panMode'));
  for (const [mode, label] of panModeChoices) {
    const option = button(label, () => { closePanMenu(true); setTrack('panMode', mode, captured); });
    option.setAttribute('role', 'menuitemradio');
    option.setAttribute('aria-checked', !tr.mixed.panMode && tr.values.panMode === mode);
    menu.append(option);
  }
  menu.hidden = false;
  const rect = (anchor.querySelector('input,select') || anchor).getBoundingClientRect();
  menu.style.left = `${Math.max(4, Math.min(event?.clientX ?? rect.left, innerWidth - menu.offsetWidth - 4))}px`;
  menu.style.top = `${Math.max(4, Math.min(event?.clientY ?? rect.bottom, innerHeight - menu.offsetHeight - 4))}px`;
  (menu.querySelector('[aria-checked=true]') || menu.firstElementChild).focus();
}
$('pan-menu').onkeydown = event => {
  const options = [...$('pan-menu').children], i = options.indexOf(document.activeElement);
  if (['ArrowDown','ArrowUp','Home','End'].includes(event.key)) {
    event.preventDefault(); options[event.key === 'Home' ? 0 : event.key === 'End' ? options.length - 1 : (i + (event.key === 'ArrowDown' ? 1 : -1) + options.length) % options.length].focus();
  } else if (event.key === 'Escape' || event.key === 'Tab') { event.preventDefault(); closePanMenu(true); }
};
document.addEventListener('pointerdown', event => { if (!$('pan-menu').contains(event.target)) closePanMenu(); }, true);
window.addEventListener('blur', () => closePanMenu());
window.addEventListener('resize', () => closePanMenu());
document.addEventListener('scroll', () => closePanMenu(), true);
let recordMenuContext, recordMenuHover;
function closeRecordMenu(focus = false) {
  clearTimeout(recordMenuHover);
  $('record-menu').hidden = true;
  if (focus && recordMenuContext?.anchor.isConnected) recordMenuContext.anchor.focus();
  recordMenuContext = null;
}
function recordMenuRows(kind, captured) {
  const {values:v,mixed:m} = state.tracks;
  const item = (label,field,value,checked) => ({label,checked,run:() => setTrack(field,value,captured)});
  const recording = value => item(t(recordChoices[value][1]),'recordMode',value,!m.recordMode && v.recordMode === value);
  if (kind === 'recordMode') return [recording(0),
    ...Object.entries(recordGroups).map(([group,values]) => ({label:t(group),submenu:group,checked:!m.recordMode && values.includes(v.recordMode)})),recording(2)];
  if (kind === 'recordMIDIGroup' || kind === 'recordForceGroup') return recordGroups[kind].map(recording);
  if (kind === 'recordOutputGroup') return [
    ...[10,1,5,4].map(value => ({...recording(value),checked:!m.recordMode && (v.recordMode === value || value !== 4 && v.recordMode === (value === 1 ? 3 : value + 1)),run:() => setTrack('recordMode',v.recordLatency && value !== 4 ? value === 1 ? 3 : value + 1 : value,captured)})),
    {separator:true},
    ...[[0,'recordOutputPostFader'],[2,'recordOutputPostFX'],[1,'recordOutputPreFX']].map(([value,label]) => item(t(label),'recordOutput',value,!m.recordOutput && v.recordOutput === value)),
    {...item(t('recordLatency'),'recordLatency',v.recordLatency ? 0 : 1,m.recordLatency ? 'mixed' : !!v.recordLatency),checkbox:true,disabled:m.recordMode || ![1,3,5,6,10,11].includes(v.recordMode)}
  ];
  if (kind === 'monitor') return [
    ...[[1,'monitorInput'],[2,'tapeMonitor']].map(([value,label]) => item(t(label),'monitor',v.monitor === value && !m.monitor ? 0 : value,m.monitor ? 'mixed' : v.monitor === value)),
    ...[['monitorItems','monitorItems'],['preservePDC','preservePDC']].map(([field,label]) => item(t(label),field,m[field] || !v[field] ? 1 : 0,m[field] ? 'mixed' : !!v[field]))
  ];
  const input = Number.isInteger(v.input) ? v.input : -1, midi = input >= 0 && !!(input & 4096);
  if (kind === 'input') return [
    ...['mono','stereo','midi'].map(group => ({label:t(`input${group[0].toUpperCase()}${group.slice(1)}`),submenu:group,checked:!m.input && input >= 0 && (group === 'midi' ? midi : !midi && (group === 'stereo' ? !!(input & 1024) : !(input & 3072)))})),
    item(t('inputNone'),'input',-1,!m.input && input < 0)
  ];
  if (kind === 'sourceChannel') return Array.from({length:17},(_,channel) => item(channel ? t('midiChannel',{channel}) : t('allChannels'),'input',(midi ? input & ~31 : 4096 | 63 << 5) | channel,!m.input && midi && (input & 31) === channel));
  if (kind === 'mapChannel') return Array.from({length:17},(_,channel) => item(channel ? t('midiChannel',{channel}) : t('sourceChannel'),'midiMap',channel,m.midiMap ? 'mixed' : v.midiMap === channel));
  const rows = (state.inputs?.[kind] || []).map(source => item(source.translated ? t(source.label) : source.label,'input',source.value | (kind === 'midi' && midi ? input & 31 : 0),!m.input && (kind === 'midi' ? midi && (input & ~31) === source.value : input === source.value)));
  if (kind === 'midi') rows.push({label:t('sourceChannel'),submenu:'sourceChannel'},{label:t('mapInputChannel'),submenu:'mapChannel'});
  return rows;
}
function trimRecordMenu(level) {
  for (const pane of recordMenuContext.panes.splice(level + 1)) {
    pane.parent?.setAttribute('aria-expanded','false'); pane.node.remove();
  }
}
function recordMenuWidths(kind,captured) {
  const widths = [], menu = $('record-menu');
  const measure = (kind,level) => {
    const node = el('div','record-menu-panel'); node.dataset.kind = kind; menu.append(node);
    widths[level] = Math.max(widths[level] || 0,node.getBoundingClientRect().width); node.remove();
    for (const choice of recordMenuRows(kind,captured)) if (choice.submenu) measure(choice.submenu,level + 1);
  };
  measure(kind,0);
  const scale = Math.min(1,(document.documentElement.clientWidth - 8) / widths.reduce((sum,width) => sum + width,0));
  return widths.map(width => Math.floor(width * scale));
}
function positionRecordMenu() {
  const {rect,x,y,panes,widths} = recordMenuContext, width = document.documentElement.clientWidth;
  const cascadeWidth = widths.reduce((sum,width) => sum + width,0) - widths.length + 1;
  for (const [level,pane] of panes.entries()) {
    const box = pane.node.getBoundingClientRect(), row = pane.parent?.getBoundingClientRect();
    let left = Math.min(x ?? rect.left,width - cascadeWidth - 4), top = y ?? rect.bottom;
    if (row) {
      const parent = panes[level-1].node.getBoundingClientRect();
      left = parent.right - 1; top = row.top;
    }
    pane.node.style.left = `${Math.max(4,Math.min(left,width - box.width - 4))}px`;
    pane.node.style.top = `${Math.max(4,Math.min(top,innerHeight - box.height - 4))}px`;
  }
}
function focusRecordPane(pane) {
  (pane.node.querySelector('[aria-checked=true]:not(:disabled)') || pane.node.querySelector('button:not(:disabled)'))?.focus();
}
function expandRecordMenu(kind,level,parent,focus = false) {
  if (!recordMenuContext) return;
  if (!current(recordMenuContext.captured)) { closeRecordMenu(); return; }
  let pane = recordMenuContext.panes[level + 1];
  if (pane?.parent !== parent) {
    trimRecordMenu(level); pane = appendRecordMenu(kind,level + 1,parent);
    parent.setAttribute('aria-expanded','true'); positionRecordMenu();
  }
  if (focus) focusRecordPane(pane);
}
function appendRecordMenu(kind,level,parent) {
  const {captured} = recordMenuContext, node = el('div','record-menu-panel');
  node.dataset.kind = kind; node.dataset.level = level; node.setAttribute('role','menu');
  node.style.width = `${recordMenuContext.widths[level]}px`;
  node.setAttribute('aria-label',parent?.textContent || t(kind));
  const pane = {kind,node,parent}; recordMenuContext.panes.push(pane);
  node.onscroll = () => { if (recordMenuContext?.panes[level]?.node === node) trimRecordMenu(level); };
  for (const choice of recordMenuRows(kind,captured)) {
    if (choice.separator) { node.append(el('hr')); continue; }
    const control = literalButton(choice.label,() => {
      clearTimeout(recordMenuHover);
      if (choice.submenu) expandRecordMenu(choice.submenu,level,control,true);
      else { closeRecordMenu(true); choice.run(); }
    });
    control.disabled = !!choice.disabled;
    const caption = el('span','',choice.label); control.replaceChildren(caption);
    control.setAttribute('role',kind === 'monitor' || choice.checkbox ? 'menuitemcheckbox' : choice.submenu ? 'menuitem' : 'menuitemradio');
    if (choice.checked !== undefined) control.setAttribute('aria-checked',choice.checked);
    if (choice.submenu) {
      control.setAttribute('aria-haspopup','menu'); control.setAttribute('aria-expanded','false');
      control.dataset.submenu = choice.submenu;
    }
    control.onpointerenter = event => {
      if (event.pointerType === 'touch') return;
      clearTimeout(recordMenuHover);
      recordMenuHover = setTimeout(() => {
        if (!control.isConnected || !recordMenuContext) return;
        if (choice.submenu) expandRecordMenu(choice.submenu,level,control);
        else { trimRecordMenu(level); positionRecordMenu(); }
      },120);
    };
    control.onpointerleave = () => clearTimeout(recordMenuHover);
    node.append(control);
  }
  if (!node.children.length) node.append(hint('none'));
  $('record-menu').append(node); return pane;
}
function recordMenuSignature() {
  const {values,mixed} = state.tracks;
  return JSON.stringify(['monitor','monitorItems','preservePDC','input','midiMap','recordMode','recordOutput','recordLatency'].map(key => [values[key],mixed[key]]));
}
function refreshRecordMenu(force = false) {
  if (!recordMenuContext) return;
  if (!current(recordMenuContext.captured)) { closeRecordMenu(); return; }
  const signature = recordMenuSignature();
  if (!force && recordMenuContext.signature === signature) return;
  recordMenuContext.signature = signature;
  clearTimeout(recordMenuHover);
  const path = recordMenuContext.panes.map(pane => pane.kind), active = document.activeElement;
  const focusLevel = active.closest('.record-menu-panel')?.dataset.level, caption = active.textContent;
  recordMenuContext.panes = []; $('record-menu').replaceChildren();
  appendRecordMenu(path[0],0);
  for (let level = 1; level < path.length; level++) {
    const parent = recordMenuContext.panes[level - 1].node.querySelector(`[data-submenu="${path[level]}"]`);
    if (!parent) break;
    appendRecordMenu(path[level],level,parent); parent.setAttribute('aria-expanded','true');
  }
  positionRecordMenu();
  if (focusLevel !== undefined) {
    const pane = recordMenuContext.panes[focusLevel];
    if (pane) ([...pane.node.children].find(control => control.textContent === caption) || pane.node.querySelector('button'))?.focus();
  }
}
function openRecordMenu(event,anchor,captured,kind) {
  closePanMenu(); closeRecordMenu();
  recordMenuContext = {anchor,captured,kind,panes:[],rect:anchor.getBoundingClientRect(),x:event?.clientX,y:event?.clientY,signature:recordMenuSignature()};
  $('record-menu').replaceChildren(); $('record-menu').hidden = false;
  recordMenuContext.widths = recordMenuWidths(kind,captured);
  const pane = appendRecordMenu(kind,0); positionRecordMenu(); focusRecordPane(pane);
}
function recordSelect(label,caption,captured,kind) {
  const control = literalButton(caption,() => openRecordMenu(null,control,captured,kind),'record-select');
  control.id = `record-${kind}`; control.setAttribute('aria-label',t(label)); control.setAttribute('aria-haspopup','menu');
  control.replaceChildren(el('span','',caption)); return row(label,control);
}
function inputCaption(v,m) {
  if (m.input) return t('mixed');
  if (v.input < 0) return t('inputNone');
  const midi = !!(v.input & 4096), group = midi ? 'midi' : v.input & 1024 ? 'stereo' : 'mono';
  const source = state.inputs?.[group]?.find(row => row.value === (midi ? v.input & ~31 : v.input));
  const name = source ? source.translated ? t(source.label) : source.label : t('currentValue',{value:v.input});
  return midi ? `${name} · ${v.input & 31 ? t('midiChannel',{channel:v.input & 31}) : t('allChannels')}` : name;
}
$('record-menu').onkeydown = event => {
  const active = document.activeElement, pane = active.closest('.record-menu-panel');
  if (!pane || !recordMenuContext) return;
  clearTimeout(recordMenuHover);
  const level = Number(pane.dataset.level), options = [...pane.querySelectorAll('button:not(:disabled)')], i = options.indexOf(active);
  if (['ArrowDown','ArrowUp','Home','End'].includes(event.key)) {
    event.preventDefault(); trimRecordMenu(level); positionRecordMenu();
    options[event.key === 'Home' ? 0 : event.key === 'End' ? options.length-1 : (i+(event.key === 'ArrowDown' ? 1 : -1)+options.length)%options.length]?.focus();
  } else if (event.key === 'ArrowRight' && active.dataset.submenu) { event.preventDefault(); active.click(); }
  else if (event.key === 'ArrowLeft' && level > 0) {
    event.preventDefault(); const parent = recordMenuContext.panes[level].parent;
    trimRecordMenu(level - 1); positionRecordMenu(); parent.focus();
  }
  else if (event.key === 'Escape' || event.key === 'Tab') { event.preventDefault(); closeRecordMenu(true); }
};
document.addEventListener('pointerdown',event => { if (!$('record-menu').contains(event.target)) closeRecordMenu(); },true);
window.addEventListener('blur',() => closeRecordMenu());
window.addEventListener('resize',() => closeRecordMenu());
document.addEventListener('scroll',event => { if (!$('record-menu').contains(event.target)) closeRecordMenu(); },true);
function routeKnob(volume, target, change, feedback) {
  let start;
  const knob = el('div','route-knob'); knob.tabIndex = 0; knob.value = routeKnobPosition(volume);
  knob.setAttribute('role','slider'); knob.setAttribute('aria-label',t('volume')); knob.setAttribute('aria-orientation','vertical');
  knob.setAttribute('aria-valuemin',-90); knob.setAttribute('aria-valuemax',12);
  fxIcon(knob,'M7.5 19.794 A9 9 0 1 1 16.5 19.794'); knob.setAttribute('aria-label',t('volume'));
  const path = knob.querySelector('path'); path.setAttribute('pathLength',100);
  const preview = () => {
    const value = routeKnobVolume(Number(knob.value)), db = toDb(value);
    path.setAttribute('stroke-dasharray',`${Number(knob.value) * 100} 100`);
    knob.setAttribute('aria-valuenow',Math.max(-90,db)); knob.setAttribute('aria-valuetext',`${dbText(db)} dB`);
    knob.title = t('routeSendTooltip',{target,value:db === -Infinity ? '−∞' : db.toFixed(2)});
    feedback?.(Number(knob.value),`${dbText(db)} dB`,!!start && knob._dragged);
  };
  liveRange(knob,(position,gesture) => change(routeKnobVolume(position),gesture),preview);
  const capture = knob.onpointerdown;
  knob.onpointerdown = event => {
    knob._dragged = false;
    if (event.button !== 0 || event.altKey || event.shiftKey || event.ctrlKey || event.metaKey) return;
    event.preventDefault(); capture(event); knob.focus({preventScroll:true});
    start = {y:event.clientY,value:Number(knob.value)};
  };
  const set = value => { knob.value = Math.max(0,Math.min(1,value)); knob.dispatchEvent(new Event('input',{bubbles:true})); };
  knob.onpointermove = event => {
    if (!start) return;
    if (Math.abs(event.clientY-start.y) > 1) knob._dragged = true;
    set(start.value + (start.y - event.clientY) / 160);
  };
  for (const type of ['pointerup','pointercancel','lostpointercapture','blur']) knob.addEventListener(type,() => { start = null; preview(); });
  knob.onkeydown = event => {
    const delta = {ArrowUp:0.01,ArrowRight:0.01,ArrowDown:-0.01,ArrowLeft:-0.01,PageUp:0.1,PageDown:-0.1}[event.key];
    if (delta === undefined && !['Home','End'].includes(event.key)) return;
    event.preventDefault(); set(event.key === 'Home' ? 0 : event.key === 'End' ? 1 : Number(knob.value) + delta);
    knob.dispatchEvent(new Event('change',{bubbles:true}));
  };
  knob.ondblclick = event => {
    if (event.altKey || event.shiftKey || event.ctrlKey || event.metaKey) return;
    event.preventDefault(); set(0.5); knob.dispatchEvent(new Event('change',{bubbles:true}));
  };
  preview(); return knob;
}
function routeChannels(label, value, change, source = false) {
  const choices = Array.from({length: 64}, (_, i) => [i * 2, `${i * 2 + 1}/${i * 2 + 2}`, true]);
  if (source) choices.unshift([-1, 'none']);
  return select(label, value, choices, change);
}
function renderRouting(force = false) {
  editable('routing', () => {
    const routing = state.routing, tr = state.tracks, c = context();
    $('routing-count').textContent = routing?.rows?.length || '0';
    if (tr?.count !== 1) return [hint('singleTrack')];
    const master = isMaster(), columns = el('div', `routing-columns${master ? ' hardware-outputs' : ''}`);
    const controls = el('div',`route-controls${master ? ' hardware-outputs' : ''}`);
    const groups = master ? [[1,'hardwareOutputs','addHardwareOutput']] : [[0,'sends','addSend'],[-1,'receives','addReceive']];
    for (const [category, label, addLabel] of groups) {
      const column = el('section', 'route-column');
      column.dataset.category = category;
      const picker = button(addLabel, () => {
        routePicker = {category, captured:c}; $('route-title').textContent = t(addLabel);
        $('route-search').value = ''; renderRouteCatalog(); $('route-dialog').showModal(); $('route-search').focus();
      }, 'route-add');
      picker.setAttribute('aria-haspopup', 'dialog');
      picker.dataset.category = category; controls.append(picker);
      const rows = (routing?.rows || []).filter(row => row.category === category);
      column.hidden = !rows.length;
      const list = el('div', `route-list${prefs.routingCompact ? ' route-compact' : ''}`);
      list.setAttribute('aria-label', t(label));
      list.onscroll = () => routeScroll.set(category, list.scrollTop);
      for (const route of rows) {
        const update = (field, value, gesture) => act({action: 'route', category, index: route.index, routeKey: state.routing?.routeKey, field, value, gesture}, c, `route:${category}:${route.index}:${field}:${gesture || ''}`);
        const card = el('div', 'route-card'), head = el('div', 'route-head');
        const routeName = route.name || route.peer?.name || t('unavailable');
        const peer = el('span','route-name',(route.peer?.number ?? (category === 1 ? (route.destinationChannels & 1023) + 1 : route.index + 1)) + ': ' + routeName); peer.title = peer.textContent;
        if (prefs.routingCompact) {
          const name = literalButton('',() => {},'route-compact-name',t('routingCompactHint'));
          name.append(peer);
          const caption = peer.textContent;
          const target = route.peer ? t('routeTrackTarget',route.peer) : `${t('hardwareOutput')} "${routeName}"`;
          const knob = routeKnob(route.volume,target,(value,gesture) => update('volume',value,gesture),(position,text,active) => {
            card.classList.toggle('route-editing',active);
            card.style.setProperty('--route-level',position);
            peer.textContent = active ? text : caption;
          });
          card.classList.toggle('route-muted',!!route.mute); name.setAttribute('aria-pressed',!!route.mute);
          card.onclick = event => {
            if (knob._dragged && knob.contains(event.target)) return;
            if (knob.contains(event.target) && !event.altKey && !event.shiftKey && !event.ctrlKey && !event.metaKey) return;
            const command = event.altKey ? {action:'routeDelete'} : event.shiftKey ? {action:'route',field:'mute',value:route.mute ? 0 : 1} : {action:'routeOpen'};
            event.preventDefault(); event.stopPropagation();
            act({...command,category,index:route.index,routeKey:state.routing?.routeKey},c);
          };
          card.append(name,knob); list.append(card); continue;
        }
        const mute = toggle('mute', route.mute, n => update('mute', n)); mute.textContent = 'M'; mute.setAttribute('aria-label',t('mute'));
        const phase = fxIcon(toggle('routePhase',route.phase,n => update('phase',n)),'M19 5L5 19 M19 12a7 7 0 1 1-14 0 7 7 0 0 1 14 0');
        const mono = fxIcon(toggle('routeMono',route.mono,n => update('mono',n)),'M3 5h4l5 7-5 7H3 M12 12h9 M17 8l4 4-4 4');
        phase.classList.add('route-phase'); mono.classList.add('route-mono');
        const modes = [[0,'postFader'],[3,'postFX'],[1,'preFX'],...(!master ? [[8,'preReceive']] : [])];
        const mode = route.mode === 2 ? 3 : route.mode, modeWrap = el('div','route-mode');
        const modeSelect = select('sendMode',mode,modes,n => update('mode',n)).querySelector('select');
        modeSelect.title = t(modes.find(row=>row[0]===mode)?.[1] || 'sendMode');
        const modeText = el('span','',modeSelect.title); modeText.setAttribute('aria-hidden','true');
        modeWrap.append(modeText,modeSelect);
        const identity = `${route.index}:${route.peer?.guid}`, details = el('div', 'route-details');
        details.id = `route-details-${category}-${route.index}`; details.hidden = routeExpansion.get(category) !== identity;
        const expand = literalButton('⋯', () => {
          const open = details.hidden;
          routeExpansion.set(category, open ? identity : null);
          for (const node of list.querySelectorAll('.route-details')) node.hidden = true;
          for (const node of list.querySelectorAll('.route-expand')) node.setAttribute('aria-expanded', 'false');
          details.hidden = !open; expand.setAttribute('aria-expanded', open); layoutLists();
        }, 'route-expand', t('routeDetails'));
        expand.setAttribute('aria-label', t('routeDetails')); expand.setAttribute('aria-expanded', !details.hidden); expand.setAttribute('aria-controls', details.id);
        const title = el('div','route-title');
        const remove = button('delete',() => act({action:'routeDelete',category,index:route.index,routeKey:state.routing?.routeKey},c),'route-delete');
        title.append(peer,remove); head.append(title, mute, phase, mono, modeWrap, expand);
        card.append(head, fader('volume', route.volume, false, (n,g) => update('volume',n,g)));
        details.append(fader('pan',route.pan,false,(n,g) => update('pan',n,g),'pan'));
        if (master) {
          const count = tr.values.channels;
          const sources = [[-1,'none'],...Array.from({length:count - 1},(_,i) => [i,`${i + 1}/${i + 2}`,true]),...Array.from({length:count},(_,i) => [1024 + i,String(i + 1),true])];
          details.append(select('sourceChannels',route.sourceChannels,sources,n => update('sourceChannels',n)),
            select('hardwareOutput',route.destinationChannels,(routing.outputs || []).map(output => [output.value,output.label,true]),n => update('destinationChannels',n)));
        } else details.append(routeChannels('sourceChannels',route.sourceChannels,n => update('sourceChannels',n),true), routeChannels('destinationChannels',route.destinationChannels,n => update('destinationChannels',n)));
        card.append(details); list.append(card);
      }
      const arrange = (height,minimum) => { list.dataset.rows = arrangeColumns(list,height,minimum,master ? 1 : 2); };
      column.append(list,listResizer(list,label + (prefs.routingCompact ? 'Compact' : ''),'.route-card',label,arrange));
      queueMicrotask(() => { if (list.isConnected) list.scrollTop = routeScroll.get(category) || 0; });
      columns.append(column);
    }
    const channels = select('trackChannels',tr.values.channels,Array.from({length:64},(_,i) => [(i+1)*2,String((i+1)*2),true]),n => setTrack('channels',n,c));
    if (master) return [columns,controls,channels];
    const options = el('div','route-options'), mainSend = checkbox('mainSend',tr.values.mainSend,n => setTrack('mainSend',n,c));
    mainSend.querySelector('span').title = t('mainSend');
    options.append(mainSend,channels);
    return [columns,controls,options];
  }, force);
}
function renderRouteCatalog() {
  const root = $('route-catalog'); root.replaceChildren();
  if (!routePicker) return;
  const {category, captured} = routePicker;
  if (category === 1) {
    const terms = $('route-search').value.toLocaleLowerCase().trim().split(/\s+/).filter(Boolean);
    const outputs = (state.routing?.outputs || []).filter(output => terms.every(term => output.label.toLocaleLowerCase().includes(term)));
    if (!outputs.length) root.append(hint(state.routing?.outputs?.length ? 'noResults' : 'noHardwareOutputs'));
    for (const output of outputs) {
      const pick = literalButton(output.label, () => {
        act({action:'routeAdd',category,output:output.value}, captured); $('route-dialog').close();
      });
      pick.dataset.output = output.value; root.append(pick);
    }
    return;
  }
  const rows = filterTracks(state.index || [], $('route-search').value).filter(track => track.guid !== state.tracks?.refs?.[0]?.guid);
  if (!rows.length) root.append(hint('noResults'));
  for (const track of rows) {
    const pick = literalButton(`${track.number} · ${track.name}`, () => {
      act({action:'routeAdd',category,peer:track.guid}, captured); $('route-dialog').close();
    });
    pick.dataset.guid = track.guid; root.append(pick);
  }
}
$('route-search').oninput = renderRouteCatalog;
$('route-dialog').onclose = () => { routePicker = null; };
$('route-dialog').addEventListener('keydown', event => {
  if (!['ArrowDown','ArrowUp','Home','End'].includes(event.key)) return;
  if (event.target === $('route-search') && ['Home','End'].includes(event.key)) return;
  const rows = [...$('route-catalog').querySelectorAll('button')]; if (!rows.length) return;
  event.preventDefault();
  const i = rows.indexOf(document.activeElement);
  rows[event.key === 'Home' ? 0 : event.key === 'End' ? rows.length - 1 : (i + (event.key === 'ArrowDown' ? 1 : -1) + rows.length) % rows.length].focus();
});
function confirmDelete(message, action, c) {
  const dialog = $('confirm-dialog');
  if (dialog.open) return;
  $('confirm-message').textContent = message; dialog.returnValue = '';
  dialog.onclose = () => { if (dialog.returnValue === 'delete') act({...action, confirmed: true}, c); };
  dialog.showModal();
}
function bindFXDrag(card, fx, c) {
  card.dataset.guid = fx.guid;
  const handle = card.querySelector('.fx-head');
  let start, dragged = false;
  handle.addEventListener('click',event => { if (dragged) { event.preventDefault(); event.stopImmediatePropagation(); dragged = false; } },true);
  handle.onpointerdown = event => {
    dragged = false;
    if (event.button !== 0 || event.altKey || event.shiftKey || event.ctrlKey || event.metaKey) return;
    handle.setPointerCapture(event.pointerId);
    start = {x:event.clientX,y:event.clientY};
  };
  handle.onpointermove = event => {
    if (!start || !fxDrag && Math.hypot(event.clientX-start.x,event.clientY-start.y) < 5) return;
    if (!fxDrag) { dragged = true; fxDrag = {guid:fx.guid,context:c}; handle.setPointerCapture(event.pointerId); card.classList.add('dragging'); }
    event.preventDefault();
    document.querySelectorAll('.fx-card.drop-target').forEach(node => node.classList.remove('drop-target'));
    const target = document.elementFromPoint(event.clientX,event.clientY)?.closest('.fx-card');
    fxDrag.target = target?.dataset.guid;
    if (target && target !== card) target.classList.add('drop-target');
    const viewport = card.closest('.fx-viewport'), bounds = viewport.getBoundingClientRect();
    if (event.clientY < bounds.top + 24 || event.clientY > bounds.bottom - 24) viewport.scrollBy(0,event.clientY < bounds.top + 24 ? -14 : 14);
  };
  const finish = event => {
    if (fxDrag?.guid === fx.guid) {
      const target = fxDrag.target;
      fxDrag = null; card.classList.remove('dragging');
      document.querySelectorAll('.fx-card.drop-target').forEach(node => node.classList.remove('drop-target'));
      if (event.type === 'pointerup' && target && target !== fx.guid) act({action:'fx',guid:fx.guid,operation:'move',target},c);
      setTimeout(flushRender,0);
    }
    start = null;
  };
  handle.onpointerup = finish; handle.onpointercancel = finish; handle.onlostpointercapture = finish;
  handle.onkeydown = event => {
    if (!event.altKey || !['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(event.key)) return;
    event.preventDefault();
    const column = Number(card.style.gridColumn), row = Number(card.style.gridRow);
    const [dx,dy] = {ArrowLeft:[-1,0],ArrowRight:[1,0],ArrowUp:[0,-1],ArrowDown:[0,1]}[event.key];
    const neighbor = [...card.parentElement.children].find(node => Number(node.style.gridColumn) === column + dx && Number(node.style.gridRow) === row + dy);
    const target = state.fx?.rows.find(item => item.guid === neighbor?.dataset.guid);
    if (target) act({action:'fx',guid:fx.guid,operation:'move',target:target.guid},c);
  };
}
function renderFX(force = false) {
  editable('fx', () => {
    const rows = state.fx?.rows || [], c = context();
    $('fx-count').textContent = rows.length;
    if (state.tracks?.count !== 1) return [hint('singleTrack')];
    const grid = el('div',`fx-grid${prefs.fxCompact ? ' fx-compact' : ''}`), viewport = el('div','fx-viewport');
    viewport.append(grid); viewport.onscroll = () => listScroll.set('fx',viewport.scrollTop);
    for (const fx of rows) {
      const command = (operation, extra = {}) => act({action:'fx',guid:fx.guid,operation,...extra},c);
      const card = el('div',`fx-card${state.parameters?.guid === fx.guid ? ' selected' : ''}`);
      const head = el(prefs.fxCompact ? 'button' : 'div','fx-head'); head.title = t('dragFX'); head.tabIndex = 0;
      head.setAttribute('aria-label', `${fx.index+1} · ${fx.name} · ${t('dragFX')}`);
      const pick = el('span','fx-name',String(fx.index+1).padStart(2,'0') + ' ' + fx.name.replace(/^(VST3?|AU|JS|CLAP):\s*/,'')); pick.title = fx.name;
      head.append(pick);
      if (prefs.fxCompact) {
        head.type = 'button'; head.title = `${fx.name}\n${t('fxCompactHint')}`;
        head.setAttribute('aria-label',`${fx.index+1} · ${fx.name}`);
        card.classList.toggle('bypassed',!fx.enabled); card.classList.toggle('offline',fx.offline);
        head.onclick = event => {
          if (event.altKey) command('delete',{confirmed:true});
          else if (event.shiftKey) command('enabled',{value:!fx.enabled});
          else if (event.ctrlKey || event.metaKey) command('offline',{value:!fx.offline});
          else command('open');
        };
        card.append(head); bindFXDrag(card,fx,c); grid.append(card); continue;
      }
      const actions = el('div','fx-actions');
      const enabled = fxIcon(toggle('enabled',fx.enabled,n => command('enabled',{value:!!n})),'M12 3v9 M6.3 5.8a8 8 0 1 0 11.4 0');
      const offline = fxIcon(toggle('offline',fx.offline,n => command('offline',{value:!!n})),'M8 3v4 M16 3v4 M6 7h12v5a6 6 0 0 1-6 6v3 M6 10v2a6 6 0 0 0 3 5.2 M3 3l18 18');
      const expanded = state.parameters?.guid === fx.guid;
      const parameters = toggle('fxParameterToggle',expanded,n => {
        parameters.setAttribute('aria-expanded',!!n);
        act({action:'fxSelect',guid:fx.guid,visible:!!n},c);
      });
      parameters.className = 'fx-parameters-toggle'; parameters.title = `${t('fxParameters')} · ${fx.name}`;
      parameters.setAttribute('aria-expanded',expanded); parameters.setAttribute('aria-controls','fx-parameter-panel');
      const open = fxIcon(button('open',() => command('open'),'fx-open'),'M10 4H4v16h16v-6 M14 4h6v6 M20 4l-9 9');
      fxIcon(parameters,'M3 6h4 M11 6h10 M3 18h10 M17 18h4 M11 6a2 2 0 1 0-4 0 2 2 0 1 0 4 0 M17 18a2 2 0 1 0-4 0 2 2 0 1 0 4 0');
      const remove = fxIcon(button('delete',() => confirmDelete(t('deleteFXPrompt',{name:fx.name}),{action:'fx',guid:fx.guid,operation:'delete'},c),'danger'),'M4 6h16 M9 6V3h6v3 M6 6l1 15h10l1-15 M10 10v7 M14 10v7');
      actions.append(enabled,offline,open,parameters,remove);
      card.append(head,actions); bindFXDrag(card,fx,c); grid.append(card);
    }
    const add = button('addFX',() => {
      dialogContext = c; $('fx-search').value = ''; $('fx-name').value = ''; $('fx-dialog').showModal(); renderCatalog(); $('fx-search').focus(); act({action:'fxCatalog'},c);
    },'fx-add');
    const controls = el('div','fx-controls'); let enabled = !!state.tracks.values.fxEnabled;
    const power = button(enabled ? 'fxEnabled' : 'fxDisabled',() => {
      enabled = !enabled; power.textContent = power.title = t(enabled ? 'fxEnabled' : 'fxDisabled');
      power.setAttribute('aria-pressed',enabled); rendered.delete('fx'); setTrack('fxEnabled',enabled ? 1 : 0,c);
    },'fx-enable');
    power.setAttribute('aria-pressed',enabled); controls.append(add,power);
    queueMicrotask(() => queueMicrotask(() => { if (viewport.isConnected) viewport.scrollTop = listScroll.get('fx') || 0; }));
    const arrange = (height,minimum) => {
      viewport.dataset.rows = arrangeColumns(grid,height,minimum);
    };
    return [...(rows.length ? [viewport,listResizer(viewport,prefs.fxCompact ? 'fxCompact' : 'fx','.fx-card','fx',arrange)] : []),controls];
  },force);
}
function renderFXParameters(force = false) {
  const panel = $('fx-parameter-panel'), identity = `${session}:${state.tracks?.key}:${state.parameters?.guid}`;
  panel.hidden = prefs.fxCompact || !state.parameters?.guid;
  const fx = state.fx?.rows?.find(row => row.guid === state.parameters?.guid);
  $('fx-parameter-title').textContent = fx ? `${t('fxParameters')} · ${fx.name}` : t('fxParameters');
  $('fx-parameter-title').title = $('fx-parameter-title').textContent;
  editable('fx-parameters', () => {
    const p = state.parameters, c = context();
    if (prefs.fxCompact || !p?.guid) return [];
    const viewport = el('div', 'fx-parameter-viewport'), grid = el('div', 'fx-parameter-grid');
    const previous = $('fx-parameters').querySelector('.fx-parameter-viewport');
    const scrollTop = previous?.dataset.identity === identity ? previous.scrollTop : 0;
    viewport.dataset.identity = identity;
    viewport.append(grid);
    queueMicrotask(() => { if (viewport.isConnected) viewport.scrollTop = scrollTop; });
    for (const param of p.rows) {
      const line = el('div', 'fx-parameter'), head = el('div', 'row'), range = el('input');
      range.type = 'range'; range.min = 0; range.max = 1; range.step = 0.001; range.value = param.value; range.setAttribute('aria-label', param.name);
      const out = el('output', '', param.formatted);
      const label = el('label', '', param.name); label.title = param.name; out.title = param.formatted;
      head.append(label, out);
      liveRange(range, (value,gesture) => act({action: 'fx', guid: p.guid, operation: 'parameter', parameter: param.index, value, gesture}, c, `fx:${p.guid}:${param.index}:${gesture || ''}`), () => { out.textContent = `${Math.round(range.value * 1000) / 10}%`; });
      line.append(head, range); grid.append(line);
    }
    return [viewport];
  }, force);
}
function renderParameters(force = false) {
  editable('parameters', () => {
    const v = state.tracks?.values || {}, m = state.tracks?.mixed || {}, c = context();
    return [panModeSelect(v,m,c),
      select('automation', v.automation, automationChoices, n => setTrack('automation', n, c), m.automation),
      recordSelect('input',inputCaption(v,m),c,'input'),
      recordSelect('recordMode',m.recordMode ? t('mixed') : t(recordChoices.find(row => row[0] === v.recordMode)?.[1] || 'recordInput'),c,'recordMode'),
      recordSelect('monitor',m.monitor ? t('mixed') : t(monitorChoices.find(row=>row[0] === v.monitor)?.[1] || 'off'),c,'monitor')];
  }, force);
}
function renderItems(force = false) {
  editable('items', () => {
    const items = state.items, c = context(); $('items-count').textContent = items?.count || '0';
    const newKey = `${session}:${items?.itemKey}:${JSON.stringify(items?.source)}`;
    if (newKey !== overviewKey) {
      overviewKey = newKey; overviewRevision++; overviewData = null; $('overview-status').textContent = '';
      const canvas = $('overview-canvas'); canvas.getContext('2d').clearRect(0,0,canvas.width,canvas.height);
      $('overview').setAttribute('aria-busy', 'false');
      if (items?.count === 1 && items.source?.overview) queueMicrotask(loadOverview);
    }
    $('overview').hidden = !items?.source?.overview;
    if (!items?.count) return [hint('noItems')];
    const v = items.values, m = items.mixed;
    const update = (field, value) => act({action: 'setItem', itemKey: items.itemKey, field, value}, c, `item:${items.itemKey}:${field}`);
    const result = [];
    if (items.count > 1) result.push(hint(t('selectedItems', {count: items.count})), hint('multiItemHint'));
    result.push(numeric('position', v.position, {min: 0, max: 1e9, step: 0.001}, n => update('position', n), m.position), numeric('length', v.length, {min: 0.000001, max: 1e9, step: 'any'}, n => update('length', n), m.length));
    const toggles = el('div', 'item-toggles');
    for (const key of ['mute','lock','loop']) toggles.append(toggle(key, v[key], n => update(key,n), m[key])); result.push(toggles);
    const takeAvailable = v.takeName != null || m.takeName;
    if (takeAvailable) {
      const control = field('takeName', v.takeName, n => update('takeName', n), m.takeName);
      control.querySelector('input').disabled = items.takesAvailable === false; result.push(control);
    }
    for (const [key, min, max, step] of [['rate',0.01,16,0.01],['pitch',-120,120,0.01],['offset',0,1e9,0.001]]) {
      const control = numeric(key, v[key], {min,max,step}, n => update(key, n), m[key]);
      if (items.takesAvailable === false || v[key] == null && !m[key]) control.querySelector('input').disabled = true;
      result.push(control);
    }
    result.push(row('takeCount', el('span', '', m.takeCount ? t('mixed') : String(v.takeCount))));
    if (items.source) {
      const s = items.source, info = el('dl', 'info-grid');
      for (const [label, text] of [['sourceFile', s.path || t('unavailable')], ['format', s.format], ['sampleRate', s.sampleRate > 0 ? `${s.sampleRate} Hz` : '—'], ['channels', s.channels], ['sourceDuration', `${s.duration.toFixed(3)} ${s.durationIsQN ? 'QN' : 's'}`]]) {
        const detail = el('dd',label === 'sourceFile' ? 'source-path' : '',String(text)); detail.title = String(text);
        info.append(el('dt', '', t(label)),detail);
      }
      result.push(info);
      if (!s.overview) result.push(hint('overviewUnavailable'));
    }
    return result;
  }, force);
}
function renderMetadata(force = false) {
  editable('metadata', () => {
    const d = state.metadata, c = context();
    if (!d) return [];
    if (d.invalid) return [hint('metadataInvalid')];
    return [...['category', 'notes'].map(key => field(key, d.values[key], value => act({action: 'setMetadata', field: key, value}, c, `metadata:${key}`), d.mixed[key], key === 'notes')), hint('metadataHint')];
  }, force);
}
function renderAppearance(force = false) {
  editable('appearance', () => {
    const v = state.tracks?.values || {}, m = state.tracks?.mixed || {}, c = context();
    const color = el('input'); color.type = 'color'; color.value = v.color || '#6e9992'; color.setAttribute('aria-label', t('trackColor')); color.onchange = () => act({action: 'color', value: color.value}, c);
    const icon = el('div','track-icon-row');
    icon.append(v.icon ? trackIcon(v.icon) : el('span','hint',t(m.icon ? 'mixed' : 'noIcon')));
    icon.append(button('setIcon',() => chooseTrackIcon(c)));
    const remove = button('removeIcon',() => act({action:'setIcon',path:''},c)); remove.disabled = !v.icon && !m.icon; icon.append(remove);
    const visibility = el('div','track-visibility');
    visibility.append(checkbox('tcp', v.tcp, n => setTrack('tcp', n, c), m.tcp), checkbox('mcp', v.mcp, n => setTrack('mcp', n, c), m.mcp));
    return [row('trackIcon',icon), row(m.color ? 'mixedColor' : 'trackColor',color),
      button('defaultColor',() => act({action:'color',value:''},c)), visibility];
  }, force);
}
function renderQuick(force = false) {
  editable('quick', () => {
    const c = context(), tr = state.tracks;
    if (!tr?.count) return [];
    const master = toggle('masterTrack',tr.masterVisible,() => act({action:'quick',operation:'master'},c));
    if (isMaster()) return [button('openChain', () => act({action:'quick',operation:'chain'},c)),master];
    const result = [];
    const rename = button('rename', () => { $('track-name')?.focus(); $('track-name')?.select(); }); rename.disabled = tr.count !== 1; result.push(rename);
    for (const [key, label] of [['duplicate','duplicateTrack'],['chain','openChain'],['parent','parentTrack'],['previous','previousTrack'],['next','nextTrack']]) {
      const b = button(label, () => act({action: 'quick', operation: key}, c));
      b.disabled = key !== 'duplicate' && tr.count !== 1 || key === 'parent' && !tr.parent; result.push(b);
    }
    for (const key of ['spacerBefore','spacerAfter']) result.push(button(key,() => act({action:'quick',operation:key},c)));
    result.push(master);
    result.push(button('deleteTrack', () => confirmDelete(t('deleteTracksPrompt', {count: tr.count}), {action: 'quick', operation: 'delete'}, c), 'danger'));
    return result;
  }, force);
}
const renderers = {'track-header': renderHeader, mixer: renderMixer, routing: renderRouting, fx: renderFX, 'fx-parameters': renderFXParameters, parameters: renderParameters, items: renderItems, metadata: renderMetadata, appearance: renderAppearance, quick: renderQuick};
function renderAll(force = false) { renderMode(); for (const render of Object.values(renderers)) render(force); renderSearch(); configureAudio(); }
function configureAudio() {
  for (const [id, key] of [['meter-toggle-rms', 'meterShowRms'], ['meter-toggle-lufs', 'meterShowLufs']]) {
    $(id).setAttribute('aria-pressed', prefs[key]);
  }
  if (!audio) return;
  const track = state.tracks?.count === 1 ? state.tracks.refs[0] : null;
  const master = isMaster(), source = master ? 'master' : prefs.source === 'track' ? track ? `track:${track.guid}` : null : prefs.source;
  $('analysis-notice').textContent = !prefs.analysis ? t('analysisDisabled') : '';
  audio.configure({...prefs, session, trackKey: state.tracks?.key, track, source, master,
    meterOutputs: source === 'master' ? hardwareOutputChannels(state.hardwareRouting?.rows) : null,
    aggregate: !master && prefs.source === 'track' && !!track && state.tracks.aggregate === true,
    active: !disposed && !closing && connected && !!state.tracks?.count && prefs.analysis && $('panel-analysis').open && !document.hidden});
}
function rememberSearch(query = $('search').value) {
  const next = recentSearches(searchHistory,prefs.searchHistoryLimit,query);
  if (JSON.stringify(next) === JSON.stringify(searchHistory)) return;
  searchHistory = next;
  try { localStorage.setItem(searchHistoryKey,JSON.stringify(next)); }
  catch { report('searchHistoryFailed'); }
}
function closeSearch(remember = false) {
  if (remember) rememberSearch();
  searchView = null; renderSearch();
}
function selectSearchResult(index) {
  const rows = [...$('search-results').querySelectorAll('[role=option]')];
  if (!rows.length) return;
  const selected = rows[(index + rows.length) % rows.length];
  rows.forEach(node => node.setAttribute('aria-selected',node === selected));
  $('search').setAttribute('aria-activedescendant',selected.id);
  selected.scrollIntoView({block:'nearest'});
}
function renderSearch() {
  const root = $('search-results'), input = $('search'), query = input.value.trim();
  const history = searchView === 'history', open = !isMaster() && (history || searchView === 'results' && !!query);
  root.hidden = !open; root.replaceChildren();
  input.setAttribute('aria-expanded',open); input.removeAttribute('aria-activedescendant');
  $('search-history-toggle').setAttribute('aria-expanded',open && history);
  $('search-history-toggle').disabled = prefs.searchHistoryLimit === 0;
  root.setAttribute('aria-label',t(history ? 'searchHistory' : 'searchPlaceholder'));
  if (!open) return;
  const option = () => {
    const b = el('button','search-result'); b.type = 'button'; b.tabIndex = -1;
    b.id = 'search-option-' + root.querySelectorAll('[role=option]').length;
    b.setAttribute('role','option'); b.setAttribute('aria-selected','false');
    root.append(b); return b;
  };
  if (history) {
    if (!searchHistory.length) root.append(hint('searchHistoryEmpty'));
    for (const query of searchHistory) {
      const b = option(); b.append(el('span','track-name',query)); b.title = query;
      b.onclick = () => { input.value = query; rememberSearch(query); searchView = 'results'; renderSearch(); input.focus(); };
    }
    return;
  }
  const matches = filterTracks(state.index || [],query);
  if (!matches.length) root.append(hint('noResults'));
  for (const track of matches.slice(0,100)) {
    const b = option(), swatch = el('span','swatch'); swatch.style.background = track.color || '#6e9992';
    b.append(swatch,el('span','track-number',String(track.number)),el('span','track-name',track.name));
    const c = context();
    b.onclick = () => { rememberSearch(query); act({action:'selectTrack',guid:track.guid},c); input.value = ''; closeSearch(); input.focus(); };
  }
  if (matches.length > 100) root.append(hint(t('moreResults',{count:matches.length - 100})));
}
const searchWrap = $('search').closest('.search-wrap');
$('search-history-toggle').onclick = () => {
  const open = searchView !== 'history' || $('search-results').hidden;
  $('search').focus(); searchView = open ? 'history' : null; renderSearch();
};
$('search').onfocus = () => {
  if (!searchView && $('search').value.trim()) { searchView = 'results'; renderSearch(); }
};
searchWrap.addEventListener('keydown',event => {
  if (event.isComposing || event.target === $('search-history-toggle')) return;
  if (['ArrowDown','ArrowUp'].includes(event.key)) {
    event.preventDefault();
    if ($('search-results').hidden) { searchView = $('search').value.trim() ? 'results' : prefs.searchHistoryLimit ? 'history' : null; renderSearch(); }
    const rows = [...$('search-results').querySelectorAll('[role=option]')];
    const index = rows.findIndex(node => node.getAttribute('aria-selected') === 'true');
    selectSearchResult(index < 0 ? event.key === 'ArrowDown' ? 0 : rows.length - 1 : index + (event.key === 'ArrowDown' ? 1 : -1));
    $('search').focus();
  } else if (event.key === 'Enter' && event.target === $('search')) {
    event.preventDefault();
    const selected = $('search-results').querySelector('[aria-selected=true]');
    if (selected) selected.click();
    else { rememberSearch(); searchView = $('search').value.trim() ? 'results' : null; renderSearch(); }
  }
});
searchWrap.addEventListener('focusout',event => { if (!searchWrap.contains(event.relatedTarget)) closeSearch(true); });
document.addEventListener('pointerdown',event => { if (!searchWrap.contains(event.target)) closeSearch(true); },true);
let catalogMatches = [], catalogShown = 0, catalogActive = -1, appendCatalog;
function selectCatalog(index,scroll = true) {
  if (!catalogMatches.length) return;
  catalogActive = Math.max(0,Math.min(index,catalogMatches.length - 1));
  while (catalogShown <= catalogActive) appendCatalog();
  for (const node of $('fx-catalog').querySelectorAll('[role=option]')) node.setAttribute('aria-selected',Number(node.dataset.index) === catalogActive);
  const selected = $(`fx-option-${catalogActive}`);
  $('fx-search').setAttribute('aria-activedescendant',selected.id);
  if (scroll) selected.scrollIntoView({block:'nearest'});
  return selected;
}
function renderCatalog() {
  const root = $('fx-catalog'); root.replaceChildren();
  const matches = filterFX(catalog, $('fx-search').value);
  catalogMatches = matches; catalogShown = 0; catalogActive = -1;
  $('fx-search').removeAttribute('aria-activedescendant');
  $('fx-catalog-status').textContent = catalog.length ? t('fxResults', {count: matches.length}) : t('fxCatalogHint');
  const more = button('showMore', () => appendCatalog(true), 'catalog-more');
  appendCatalog = (focus = false) => {
    more.remove(); let first;
    for (const [offset,fx] of matches.slice(catalogShown, catalogShown + 100).entries()) {
      const format = fxFormat(fx);
      const pick = literalButton(fx.name, () => { act({action: 'fxAdd', name: fx.ident || fx.name}, dialogContext); $('fx-dialog').close(); });
      const index = catalogShown + offset;
      pick.id = `fx-option-${index}`; pick.dataset.index = index;
      pick.setAttribute('role','option'); pick.setAttribute('aria-selected','false');
      pick.onpointermove = event => { if (event.movementX || event.movementY) selectCatalog(index,false); };
      pick.onfocus = () => selectCatalog(index,false);
      pick.dataset.format = format; root.append(pick); first ||= pick;
    }
    catalogShown = Math.min(catalogShown + 100, matches.length);
    if (catalogShown < matches.length) root.append(more);
    if (focus) first?.focus();
  };
  root.onscroll = () => { if (catalogShown < matches.length && root.scrollHeight - root.scrollTop - root.clientHeight < 80) appendCatalog(); };
  appendCatalog(); root.scrollTop = 0;
}
$('fx-dialog').addEventListener('keydown',event => {
  if (event.isComposing || event.target !== $('fx-search') && !$('fx-catalog').contains(event.target)) return;
  if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
    event.preventDefault();
    const selected = selectCatalog(catalogActive < 0 ? 0 : catalogActive + (event.key === 'ArrowDown' ? 1 : -1));
    if (event.target !== $('fx-search')) selected?.focus();
  } else if (event.key === 'Enter' && event.target === $('fx-search')) {
    event.preventDefault(); selectCatalog(catalogActive < 0 ? 0 : catalogActive)?.click();
  }
});
function receive(raw) {
  let message;
  try { message = JSON.parse(raw); } catch { return; }
  if (message.type === 'ack') { queue.finish(message.id, message.ok, message.error); return; }
  if (message.type === 'catalog' && message.session === session) { catalog = sortFX(message.rows); renderCatalog(); return; }
  if (message.type !== 'state' || !Number.isInteger(message.session)) return;
  if (session != null && message.session < session) return;
  if (message.session !== session) {
    closePanMenu(); closeRecordMenu();
    routeExpansion.clear(); routeScroll.clear(); listScroll.clear();
    session = message.session; state = {}; modeSwitching = null; queue.clear(); dirty.clear();
    overviewRevision++; overviewData = null;
    for (const id of ['confirm-dialog', 'fx-dialog', 'route-dialog']) { $(id).returnValue = 'cancel'; $(id).close(); }
  }
  const oldKey = state.tracks?.key, oldItemKey = state.items?.itemKey;
  state[message.part] = message.data;
  connected = true; document.body.classList.add('connected'); $('connection').textContent = t('connected');
  if (message.part === 'theme') { nativeTheme = message.data; applyTheme(); }
  else if (message.part === 'tracks') {
    if (modeSwitching === message.data.mode) modeSwitching = null;
    renderMode();
    const changed = oldKey !== message.data.key;
    if (changed) {
      closePanMenu(); closeRecordMenu();
      routeExpansion.clear(); routeScroll.clear(); listScroll.clear();
      for (const part of ['routing', 'fx', 'parameters', 'items', 'metadata']) delete state[part];
      for (const id of ['confirm-dialog', 'fx-dialog', 'route-dialog']) { $(id).returnValue = 'cancel'; $(id).close(); }
    }
    $('empty').hidden = message.data.count > 0; $('inspector').hidden = !message.data.count;
    $('project-name').textContent = message.data.projectName || t('unsavedProject');
    if (changed) renderAll(true);
    else { renderHeader(); renderMixer(); renderParameters(); renderAppearance(); renderQuick(); renderRouting(); renderFX(); configureAudio(); refreshRecordMenu(); }
  } else if (message.part === 'routing') { renderRouting(); configureAudio(); if ($('route-dialog').open) renderRouteCatalog(); }
  else if (message.part === 'hardwareRouting') configureAudio();
  else if (message.part === 'fx') { renderFX(); renderFXParameters(); }
  else if (message.part === 'parameters') { renderFXParameters(); renderFX(); }
  else if (message.part === 'items') renderItems(oldItemKey !== message.data.itemKey);
  else if (message.part === 'metadata') renderMetadata();
  else if (message.part === 'inputs') { renderParameters(); refreshRecordMenu(true); }
  else if (message.part === 'index') { renderSearch(); renderRouting(); if ($('route-dialog').open) renderRouteCatalog(); }
}
function fillSettings(value) {
  const form = $('settings-form');
  for (const [key, v] of Object.entries(value)) {
    const control = form.elements.namedItem(key); if (!control) continue;
    if (control.type === 'checkbox') control.checked = v; else control.value = v;
  }
  form.elements.source.disabled = isMaster();
  if (isMaster()) form.elements.source.value = 'master';
  updateAnalysisHint();
  $('custom-colors').hidden = form.elements.theme.value !== 'custom';
}
function openSettings() {
  if ($('settings-dialog').open || document.querySelector('dialog[open]')) return;
  closePanMenu(); closeRecordMenu(); closeMeterMenu(); closeSearch(true);
  fillSettings(prefs); $('settings-dialog').showModal();
}
function applyPreferences() {
  applyTheme();
  applyMeterHeight();
  document.body.dataset.density = prefs.density;
  if (prefs.fxCompact && state.parameters?.guid) act({action:'fxSelect',guid:state.parameters.guid,visible:false});
  document.querySelectorAll('[data-panel]').forEach(panel => { panel.open = prefs.panels[panel.dataset.panel]; });
  renderAll(true);
}
$('settings-open').onclick = openSettings;
document.addEventListener('keydown', event => {
  if (isSettingsShortcut(event)) { event.preventDefault(); event.stopPropagation(); openSettings(); }
  if (event.key === 'Escape' && !document.querySelector('dialog[open]')) { $('search').value = ''; closeSearch(); }
}, true);
document.querySelectorAll('[data-close]').forEach(b => { b.onclick = () => $(b.dataset.close).close(); });
$('settings-reset').onclick = () => fillSettings(defaults);
function updateAnalysisHint() {
  const source = $('settings-form').elements.source.value;
  $('analysis-setting-hint').textContent = t(source === 'master' ? 'masterHint' : source === 'input' ? 'inputHint' : 'preFXHint');
}
$('settings-form').elements.source.onchange = updateAnalysisHint;
$('settings-form').elements.theme.onchange = () => { $('custom-colors').hidden = $('settings-form').elements.theme.value !== 'custom'; };
$('settings-form').onsubmit = async event => {
  event.preventDefault();
  const next = {...prefs};
  for (const control of event.currentTarget.elements) {
    if (!control.name || control.disabled) continue;
    next[control.name] = control.type === 'checkbox' ? control.checked : ['fftSize','streamRate','drawRate','floor','searchHistoryLimit'].includes(control.name) ? Number(control.value) : control.value;
  }
  const old = prefs;
  try {
    prefs = preferences(next); await language(prefs.language);
    if (!savePreferences(prefs)) { prefs = old; await language(old.language); return; }
    rememberSearch(''); $('settings-dialog').close(); applyPreferences(); audio?.restart();
  } catch (error) { prefs = old; report(error); }
};
document.querySelectorAll('[data-panel]').forEach(panel => panel.addEventListener('toggle', () => {
  if (prefs.panels[panel.dataset.panel] !== panel.open) { prefs.panels[panel.dataset.panel] = panel.open; savePreferences(prefs); }
  if (panel.dataset.panel === 'analysis') configureAudio();
}));
document.querySelectorAll('.analysis-card').forEach(card => card.addEventListener('toggle', configureAudio));
$('meter-reset').onclick = event => { event.preventDefault(); event.stopPropagation(); audio?.resetMeter(); };
function applyMeterHeight() {
  $('analysis-meter').style.setProperty('--meter-height', `${prefs.meterHeight}px`);
  const handle = $('meter-resizer');
  handle.setAttribute('aria-valuemin', meterHeightRange.min);
  handle.setAttribute('aria-valuemax', meterHeightRange.max);
  handle.setAttribute('aria-valuenow', prefs.meterHeight);
}
{
  const handle = $('meter-resizer');
  let drag;
  const resize = height => {
    prefs.meterHeight = Math.max(meterHeightRange.min, Math.min(meterHeightRange.max, Math.round(height)));
    applyMeterHeight();
  };
  handle.onpointerdown = event => {
    if (event.button !== 0 || drag) return;
    event.preventDefault(); handle.setPointerCapture(event.pointerId); handle.focus({preventScroll:true});
    drag = {pointer:event.pointerId, y:event.clientY, height:prefs.meterHeight};
    handle.classList.add('resizing');
  };
  handle.onpointermove = event => {
    if (drag?.pointer === event.pointerId) resize(drag.height + event.clientY - drag.y);
  };
  const finish = event => {
    if (drag?.pointer !== event.pointerId) return;
    drag = null; handle.classList.remove('resizing'); savePreferences(prefs);
  };
  handle.onpointerup = finish; handle.onpointercancel = finish; handle.onlostpointercapture = finish;
  handle.onkeydown = event => {
    if (!['ArrowUp','ArrowDown','Home','End'].includes(event.key)) return;
    event.preventDefault();
    resize(event.key === 'Home' ? meterHeightRange.min : event.key === 'End' ? meterHeightRange.max : prefs.meterHeight + (event.key === 'ArrowDown' ? 16 : -16));
    savePreferences(prefs);
  };
  handle.ondblclick = () => { resize(defaults.meterHeight); savePreferences(prefs); };
}
for (const [id, key] of [['meter-toggle-rms', 'meterShowRms'], ['meter-toggle-lufs', 'meterShowLufs']]) {
  $(id).onclick = event => {
    event.preventDefault(); event.stopPropagation();
    closeMeterMenu();
    const next = {...prefs, [key]: !prefs[key]};
    if (savePreferences(next)) { prefs = next; configureAudio(); }
  };
}
const meterChoices = {
  rms: [['rmsMomentary','RMS-M'], ['rmsIntegrated','RMS-I']],
  lufs: [['lufsMomentary','LUFS-M'], ['lufsShortTerm','LUFS-S'], ['lufsIntegrated','LUFS-I'], ['loudnessRange','LRA']],
};
let meterMenuAnchor;
function closeMeterMenu(restoreFocus = false) {
  $('meter-menu').hidden = true;
  meterMenuAnchor?.setAttribute('aria-expanded', 'false');
  if (restoreFocus && meterMenuAnchor?.isConnected) meterMenuAnchor.focus();
  meterMenuAnchor = null;
}
function openMeterMenu(family, event) {
  event.preventDefault(); event.stopPropagation();
  closePanMenu(); closeRecordMenu(); closeMeterMenu();
  const menu = $('meter-menu'), anchor = $(`meter-toggle-${family}`);
  meterMenuAnchor = anchor; menu.replaceChildren();
  menu.setAttribute('aria-label', family.toUpperCase());
  for (const [key, label] of meterChoices[family]) {
    const option = el('button', '', label); option.type = 'button'; option.title = t(key);
    option.dataset.metric = key; option.setAttribute('role', 'menuitemcheckbox');
    option.setAttribute('aria-checked', prefs.meterMetrics[key]);
    option.onclick = () => {
      const next = {...prefs, meterMetrics: {...prefs.meterMetrics, [key]: !prefs.meterMetrics[key]}};
      if (savePreferences(next)) {
        prefs = next; option.setAttribute('aria-checked', prefs.meterMetrics[key]); configureAudio();
      }
    };
    menu.append(option);
  }
  menu.hidden = false; anchor.setAttribute('aria-expanded', 'true');
  const rect = anchor.getBoundingClientRect();
  const pointer = event.type === 'contextmenu' && (event.clientX || event.clientY);
  menu.style.left = `${Math.max(4, Math.min(pointer ? event.clientX : rect.left, innerWidth - menu.offsetWidth - 4))}px`;
  menu.style.top = `${Math.max(4, Math.min(pointer ? event.clientY : rect.bottom, innerHeight - menu.offsetHeight - 4))}px`;
  menu.firstElementChild.focus({preventScroll:true});
}
for (const family of Object.keys(meterChoices)) {
  const anchor = $(`meter-toggle-${family}`);
  anchor.oncontextmenu = event => openMeterMenu(family, event);
  anchor.onkeydown = event => {
    if (event.key === 'ContextMenu' || event.key === 'F10' && event.shiftKey || event.key === 'ArrowDown') openMeterMenu(family, event);
  };
}
$('meter-menu').oncontextmenu = event => event.preventDefault();
$('meter-menu').onkeydown = event => {
  const options = [...$('meter-menu').children], index = options.indexOf(document.activeElement);
  if (['ArrowDown','ArrowUp','Home','End'].includes(event.key)) {
    event.preventDefault();
    options[event.key === 'Home' ? 0 : event.key === 'End' ? options.length - 1 : (index + (event.key === 'ArrowDown' ? 1 : -1) + options.length) % options.length].focus();
  } else if (event.key === 'Escape' || event.key === 'Tab') { event.preventDefault(); event.stopPropagation(); closeMeterMenu(true); }
};
document.addEventListener('pointerdown', event => { if (!$('meter-menu').contains(event.target)) closeMeterMenu(); }, true);
document.addEventListener('scroll', event => { if (!$('meter-menu').contains(event.target)) closeMeterMenu(); }, true);
window.addEventListener('blur', () => closeMeterMenu());
window.addEventListener('resize', () => closeMeterMenu());
for (const kind of ['spectrum','waveform']) {
  $(`${kind}-restart`).onclick = event => { event.preventDefault(); event.stopPropagation(); audio?.restart(kind); };
}
document.addEventListener('visibilitychange', configureAudio);
$('search').oninput = () => { searchView = $('search').value.trim() ? 'results' : null; renderSearch(); };
$('fx-search').oninput = renderCatalog;
$('fx-add-form').onsubmit = event => { event.preventDefault(); const name = $('fx-name').value.trim(); if (name) { act({action: 'fxAdd', name}, dialogContext); $('fx-dialog').close(); } };
async function loadOverview() {
  const source = state.items?.source; if (!source?.overview) return;
  const revision = ++overviewRevision; $('overview').setAttribute('aria-busy', 'true'); $('overview-status').textContent = t('loading');
  try {
    if (!api?.audio?.getWaveform) throw Error('overviewUnavailable');
    const data = await api.audio.getWaveform(source.path, {points: 1024});
    if (revision !== overviewRevision || disposed) return;
    overviewData = data; drawOverview($('overview-canvas'), data); $('overview-status').textContent = '';
  } catch (error) { if (revision === overviewRevision) $('overview-status').textContent = t(error.message || 'overviewUnavailable'); }
  finally { if (revision === overviewRevision) $('overview').setAttribute('aria-busy', 'false'); }
}
const overviewSize = new ResizeObserver(() => {
  if (overviewData && $('overview-canvas').clientWidth && $('overview-canvas').clientHeight) drawOverview($('overview-canvas'), overviewData);
});
overviewSize.observe($('overview-canvas'));
function cleanup() {
  if (cleanupPromise) return cleanupPromise;
  closing = true; overviewRevision++;
  overviewSize.disconnect(); closePanMenu(); closeRecordMenu(); closeMeterMenu(); closeSearch(true);
  for (const finish of [...gestures.values()]) finish();
  if (document.activeElement?.matches('input,textarea,select')) document.activeElement.blur();
  cleanupPromise = (async () => {
    await Promise.allSettled([audio?.close(), queue.drain()]);
    disposed = true; queue.clear();
    await Promise.allSettled([unsubscribe?.(), lifecycleStop?.(), projectStop?.()]);
    for (const promise of iconCache.values()) promise.then(url => URL.revokeObjectURL(url)).catch(() => {});
  })();
  return cleanupPromise;
}
window.addEventListener('pagehide', () => { cleanup().catch(() => {}); });

fetch('./app.json').then(response => response.json()).then(({version}) => {
  if (typeof version !== 'string' || !version.trim()) return;
  $('app-version').textContent = `v${version.trim()}`;
  $('app-version').hidden = false;
}).catch(() => {});

(async () => {
  try {
    languages = await (await fetch('./locales/languages.json')).json();
    english = await (await fetch('./locales/en.json')).json();
    try { prefs = preferences(JSON.parse(localStorage.getItem(storageKey))); } catch { prefs = preferences(); }
    try { searchHistory = recentSearches(JSON.parse(localStorage.getItem(searchHistoryKey)),prefs.searchHistoryLimit); } catch { searchHistory = []; }
    for (const lang of languages) { const option = el('option', '', lang.name); option.value = lang.code; $('setting-language').append(option); }
    const themes = $('settings-form').elements.theme;
    for (const id of Object.keys(themePresets)) {
      const option = el('option'); option.value = id; option.dataset.i18n = `theme${id[0].toUpperCase()}${id.slice(1)}`;
      themes.insertBefore(option, themes.querySelector('[value="custom"]'));
    }
    await language(prefs.language); applyPreferences();
    api = window.reaper;
    if (!api?.host || !api?.events) throw Error('launchHint');
    await api.lifecycle.ready;
    await api.window.setIconVisible(false);
    audio = new AudioAnalysis(api, $('panel-analysis'), t);
    unsubscribe = await api.events.on('message', receive);
    projectStop = await api.events.on('project-loaded', () => {
      if (closing || disposed) return;
      connected = false; queue.clear(); configureAudio();
      api.host.send({type: 'projectLoaded'}).catch(report);
    });
    if (api.lifecycle.on) lifecycleStop = await api.lifecycle.on('cleanup', cleanup);
    await api.host.send({type: 'ready'});
  } catch (error) { report(error); $('connection').textContent = t('disconnected'); }
})();
