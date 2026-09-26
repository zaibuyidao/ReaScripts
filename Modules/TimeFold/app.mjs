import { I18n } from './i18n.mjs';
import { clamp, createTimeMap, interpolatedPosition, createTrackMap, viewportBands, nativeAtY, packLabels, labelContrast, zoomRange } from './model.mjs';

const i18n = new I18n();
const ui = Object.fromEntries([...document.querySelectorAll('[id]')].map(node => [node.id, node]));
const bridge = window.reaper;
const t = (key, values) => i18n.t(key, values);
let session = null, revision = 0, labels = [], tracks = [], projectLength = 1, defaultItemColor = '#888888';
let sample = null, staging = null, clockOffset = null, lastReceive = 0, layout = null;
let connected = false, loaded = false, stateError = false, errorCode = null;
let width = 1, height = 1, guideHeight = 1, pixelRatio = 0, map = createTimeMap(1, 1, []);
let resizePending = true, labelsVisible = false, sidebarRatio = 0.25, labelHeight = 18;
let showLabelGuides = true, guidesDirty = true;
let trackMap = createTrackMap([], 1), viewDirty = true, snapshotKey = null, selectedLabel = null, canUndo = false, canRedo = false;
let dirty = true, gesture = null, editing = null, viewPending = null, viewTimer = null, viewInFlight = false;
let previewView = null, previewAt = 0, lastCursor = '';
let labelNodes = new Map();
let ackSequence = 0, ackTimer = null;
let snapSequence = 0, snapPending = null, snapTimer = null, snapQueued = null, notice = null;
let languages = [], settingsKey = null;
let editorSequence = 0;

function acknowledge(data) {
  if (!Number.isSafeInteger(data.sequence)) return;
  ackSequence = Math.max(ackSequence, data.sequence);
  if (ackTimer) return;
  ackTimer = setTimeout(() => {
    ackTimer = null;
    bridge.host.send({ type: 'ack', session, sequence: ackSequence }).catch(() => {});
  }, 8);
}

function report(code) {
  errorCode = code;
  ui.error.textContent = t(code);
  ui.error.hidden = false; publishSettings();
}
function clearError() {
  errorCode = null;
  ui.error.hidden = true; publishSettings();
}
async function send(type, data = {}) {
  if (!connected || session === null) return false;
  try {
    await bridge.host.send({ type, session, ...data });
    return true;
  } catch (error) {
    if (error?.code === 'INVALID_ARGUMENT' || error?.code === 'MESSAGE_LIMIT') report('syncFailed');
    else { connected = false; controls(); report('connectionLost'); }
    return false;
  }
}
function controls() {
  ui.tracks.setAttribute('aria-disabled', String(!connected));
  ui.viewport.setAttribute('aria-disabled', String(!connected));
  ui['toggle-all'].disabled = !connected || stateError || !labels.length;
  publishSettings();
  for (const button of ui['label-list'].querySelectorAll('button')) button.disabled = !connected || stateError;
}
function displayName(label) { return label.name || t('labelDefault', { number: i18n.numbers.format(label.id) }); }
function labelRange(label) { return t('range', { start: i18n.time(label.start, true), end: i18n.time(label.finish, true) }); }
function storePreferences() {
  try { localStorage.setItem('ArrangeNavigator.ui', JSON.stringify({ language: i18n.locale, labelsVisible, sidebarRatio, labelHeight, showLabelGuides })); } catch {}
}
function setPanel(visible) {
  labelsVisible = visible;
  ui['label-panel'].hidden = !visible;
  ui['sidebar-divider'].hidden = !visible;
  applyPanels(); resizePending = true;
}
function labelHeightLimit() { return Math.max(0, Math.floor(ui.timeline.parentElement.clientHeight * 0.4)); }
function applyPanels() {
  const mainWidth = ui.main.clientWidth;
  const panelWidth = Math.round(mainWidth * clamp(sidebarRatio, Math.min(96 / Math.max(1, mainWidth), 0.4), 0.4));
  ui['label-panel'].style.width = `${panelWidth}px`;
  ui['sidebar-divider'].setAttribute('aria-valuenow', String(Math.round(panelWidth / Math.max(1, mainWidth) * 100)));
  ui['sidebar-divider'].setAttribute('aria-valuemin', '0'); ui['sidebar-divider'].setAttribute('aria-valuemax', '40');
  const maxHeight = labelHeightLimit();
  const h = Math.round(clamp(labelHeight, Math.min(18, maxHeight), maxHeight));
  ui.timeline.style.height = `${h}px`;
  ui['label-divider'].hidden = !labels.length;
  ui['label-divider'].setAttribute('aria-valuemin', '1');
  ui['label-divider'].setAttribute('aria-valuemax', String(Math.max(1, Math.floor(maxHeight / 18))));
  ui['label-divider'].setAttribute('aria-valuenow', String(Math.max(1, Math.floor(h / 18))));
}
function refreshText() {
  i18n.apply(); setPanel(labelsVisible);
  ui.empty.textContent = t(loaded ? 'emptyProject' : 'waiting');
  ui.empty.hidden = loaded && tracks.length > 0;
  if (errorCode) ui.error.textContent = t(errorCode);
  renderLabels(); dirty = true;
}
function rebuildMap() {
  const labelEnd = labels.reduce((end, label) => Math.max(end, label.finish), 0);
  const length = Math.max(1, projectLength, labelEnd);
  map = createTimeMap(length, width, labels);
  trackMap = createTrackMap(tracks, height);
  positionLabels();
  viewDirty = true; dirty = true;
  lastCursor = '';
}
function resize() {
  resizePending = false; applyPanels();
  const w = Math.max(1, ui.tracks.clientWidth), h = Math.max(1, ui.tracks.clientHeight), ratio = window.devicePixelRatio || 1;
  const gh = Math.max(1, ui.timeline.parentElement.clientHeight);
  if (w === width && h === height && gh === guideHeight && ratio === pixelRatio) return;
  width = w; height = h; guideHeight = gh; pixelRatio = ratio;
  for (const canvas of [ui.arrangement, ui['label-guides'], ui.cursor]) {
    canvas.width = Math.round(width * ratio); canvas.height = Math.round((canvas === ui['label-guides'] ? guideHeight : height) * ratio);
    canvas.getContext('2d').setTransform(ratio, 0, 0, ratio, 0, 0);
  }
  rebuildMap();
}
function viewRange() {
  return previewView || { start: sample?.viewStart ?? 0, finish: sample?.viewEnd ?? 1, top: sample?.viewTop ?? 0 };
}
function drawTracks() {
  const ctx = ui.arrangement.getContext('2d');
  ctx.clearRect(0, 0, width, height);
  ctx.fillStyle = '#111419'; ctx.fillRect(0, 0, width, height);
  const rows = trackMap.rows;
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i], y = row.top, h = row.height;
    ctx.fillStyle = i % 2 ? '#222831' : '#1a2028'; ctx.fillRect(0, y, width, h);
    const inset = Math.min(3, h * 0.16);
    for (const item of row.items) {
      ctx.fillStyle = item.color || defaultItemColor;
      for (const [a, b] of map.visible(item.start, item.finish)) ctx.fillRect(a, y + inset, Math.max(1, b - a), Math.max(0.5, h - inset * 2));
    }
  }
  for (const segment of map.segments) if (segment.folded) {
    const x = segment.left, w = segment.right - segment.left;
    ctx.fillStyle = '#302b39'; ctx.fillRect(x, 0, w, height);
    ctx.save(); ctx.beginPath(); ctx.rect(x, 0, w, height); ctx.clip();
    ctx.strokeStyle = '#65566d55'; ctx.beginPath();
    for (let y = -w; y < height; y += 12) { ctx.moveTo(x, y); ctx.lineTo(x + w, y + w); }
    ctx.stroke(); ctx.restore();
  }
  viewDirty = true;
}
function positionViewports() {
  viewDirty = false;
  const view = viewRange(), bands = viewportBands(trackMap, layout, view.top);
  const left = map.toX(view.start), w = map.toX(view.finish) - left;
  while (ui.viewport.children.length > bands.length) ui.viewport.lastElementChild.remove();
  bands.forEach((band, index) => {
    let node = ui.viewport.children[index];
    if (!node) {
      node = document.createElement('div'); node.className = 'viewport'; node.tabIndex = 0;
      node.setAttribute('role', 'group'); ui.viewport.append(node);
    }
    node.dataset.pinned = String(band.pinned);
    node.hidden = w <= 0;
    Object.assign(node.style, { left: `${left}px`, top: `${band.top}px`, width: `${w}px`, height: `${Math.max(1, band.bottom - band.top)}px` });
    node.setAttribute('aria-label', t(band.pinned ? 'pinnedViewport' : 'viewRange', { start: i18n.time(view.start, true), end: i18n.time(view.finish, true) }));
  });
}
function positionLabels() {
  guidesDirty = true;
  applyPanels(); ui.timeline.hidden = !labels.length;
  const rects = [];
  for (const label of [...labels].sort((a, b) => a.start - b.start || a.id - b.id)) {
    const node = labelNodes.get(label.id);
    if (!node) continue;
    const value = gesture?.kind === 'label' && gesture.label.id === label.id ? gesture.preview : label;
    let left = map.toX(value.start), w = Math.max(8, map.toX(value.finish) - left);
    if (label.collapsed) {
      node.style.width = 'max-content'; node.style.maxWidth = `${width}px`;
      w = Math.min(Math.max(8, width - left), Math.max(32, node.getBoundingClientRect().width));
    }
    rects.push({ id: label.id, left, width: w });
  }
  const lanes = Math.max(1, Math.floor(ui.timeline.clientHeight / 18)), ratio = window.devicePixelRatio || 1;
  packLabels(rects, lanes).forEach((rect, index) => {
    const node = labelNodes.get(rect.id);
    const left = Math.round(rect.left * ratio) / ratio, right = Math.round((rect.left + rect.width) * ratio) / ratio;
    Object.assign(node.style, { left: `${left}px`, width: `${right - left + 1}px`, top: `${rect.lane * 18}px`, zIndex: String(index + 1) });
  });
}
function drawLabelGuides() {
  guidesDirty = false;
  const ctx = ui['label-guides'].getContext('2d');
  ctx.clearRect(0, 0, width, guideHeight);
  if (!showLabelGuides) return;
  const bounds = ui['label-guides'].getBoundingClientRect(), lines = new Map();
  for (const label of [...labels].sort((a, b) => a.start - b.start || a.id - b.id)) {
    const node = labelNodes.get(label.id);
    if (!node) continue;
    const rect = node.getBoundingClientRect(), startY = rect.bottom - bounds.top;
    for (const edge of [rect.left, rect.right - 1]) {
      const x = clamp(Math.round((edge - bounds.left) * pixelRatio) / pixelRatio, 0, Math.max(0, width - 1));
      lines.set(x, { startY: Math.min(startY, lines.get(x)?.startY ?? startY), color: label.color || '#718e86' });
    }
  }
  for (const [x, line] of lines) {
    ctx.fillStyle = line.color;
    ctx.fillRect(x, line.startY, 1, Math.max(0, guideHeight - line.startY));
  }
}
function selectLabel(label) {
  if (!connected) return;
  selectedLabel = label.id; send('seek', { position: label.start });
  for (const row of ui['label-list'].children) row.setAttribute('aria-selected', String(Number(row.dataset.id) === selectedLabel));
}
function renderLabels() {
  ui.labels.replaceChildren(); ui['label-list'].replaceChildren(); labelNodes = new Map();
  ui['label-count'].textContent = i18n.numbers.format(labels.length);
  ui['no-labels'].hidden = labels.length > 0;
  ui['toggle-all'].textContent = t(labels.some(label => !label.collapsed) ? 'collapseAll' : 'expandAll');
  for (const label of [...labels].sort((a, b) => a.start - b.start || a.id - b.id)) {
    const node = document.createElement('div');
    node.className = 'time-label'; node.dataset.id = label.id; node.dataset.collapsed = label.collapsed;
    node.title = `${displayName(label)} · ${labelRange(label)}`;
    node.textContent = displayName(label);
    const color = label.color || '#718e86';
    const contrast = labelContrast(color);
    Object.assign(node.style, { backgroundColor: color, borderColor: contrast === '#ffffff' ? '#ffffff70' : '#10151b99', color: contrast });
    node.tabIndex = 0; node.setAttribute('role', 'button'); node.setAttribute('aria-label', node.title);
    if (!label.collapsed) for (const side of ['start', 'finish']) {
      const edge = document.createElement('span'); edge.className = `edge ${side}`; edge.dataset.edge = side; edge.setAttribute('aria-hidden', 'true'); node.append(edge);
    }
    node.addEventListener('dblclick', event => { if (!event.ctrlKey && !event.altKey) openEditor(label); });
    node.addEventListener('keydown', event => {
      if (event.key === 'Enter') { event.preventDefault(); send('seek', { position: label.start }); openEditor(label); }
    });
    ui.labels.append(node); labelNodes.set(label.id, node);
    const card = document.createElement('div'); card.className = 'label-card'; card.dataset.id = label.id;
    card.tabIndex = 0; card.setAttribute('role', 'option'); card.setAttribute('aria-selected', String(selectedLabel === label.id));
    card.title = `${displayName(label)} · ${labelRange(label)}`;
    const swatch = document.createElement('span'); swatch.className = 'swatch'; swatch.style.backgroundColor = color; swatch.setAttribute('aria-hidden', 'true');
    const name = document.createElement('strong'); name.textContent = displayName(label);
    card.append(swatch, name);
    for (const [key, glyph, action] of [
      [label.collapsed ? 'expand' : 'collapse', label.collapsed ? '▸' : '▾', () => changeLabel('update', { ...label, collapsed: !label.collapsed })],
      ['edit', '⋯', () => openEditor(label)]
    ]) {
      const button = document.createElement('button'); button.textContent = glyph; button.title = t(key); button.setAttribute('aria-label', t(key));
      button.addEventListener('click', event => { event.stopPropagation(); action(); }); card.append(button);
    }
    card.addEventListener('pointerdown', event => { if (event.button === 0) selectLabel(label); });
    card.addEventListener('click', event => { if (event.detail === 0 && !event.target.closest('button')) selectLabel(label); });
    card.addEventListener('dblclick', event => { if (!event.target.closest('button')) openEditor(label); });
    card.addEventListener('keydown', event => {
      if (event.target !== card) return;
      if (event.key === 'Enter') { event.preventDefault(); selectLabel(label); openEditor(label); }
      if (event.key === 'Delete') { event.preventDefault(); changeLabel('delete', { id: label.id }); }
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        event.preventDefault(); const next = event.key === 'ArrowDown' ? card.nextElementSibling : card.previousElementSibling;
        if (next) { next.focus(); selectLabel(labels.find(label => label.id === Number(next.dataset.id))); }
      }
    });
    ui['label-list'].append(card);
  }
  positionLabels(); controls();
}
function changeLabel(action, label, expectedRevision = revision) {
  if (stateError) return;
  clearError();
  return send('label', { action, revision: expectedRevision, ...label });
}
function openEditor(label = null, start, finish) {
  if (!connected || stateError) return;
  const a = start ?? (sample?.selectionEnd > sample?.selectionStart ? sample.selectionStart : sample?.cursor ?? 0);
  const b = finish ?? (sample?.selectionEnd > sample?.selectionStart ? sample.selectionEnd : a + 10);
  editing = { label, revision, session, request: ++editorSequence };
  const current = editing;
  send('editor-open', { state: { request: editing.request, revision, language: i18n.locale,
    ...(label ? { id: label.id } : {}), start: label?.start ?? a, finish: label?.finish ?? b,
    name: label?.name ?? '', color: label?.color || '#718e86', collapsed: label?.collapsed ?? false } }).then(sent => { if (!sent && editing === current) editing = null; });
}
async function editorAction(data) {
  if (!editing || data.request !== editing.request || editing.session !== session) return;
  let sent = false;
  if (data.action === 'save') {
    const value = data.value;
    if (!value || !Number.isFinite(value.start) || !Number.isFinite(value.finish) || value.start < 0 || value.finish > 1e9 || value.finish - value.start < 0.01) return;
    sent = await changeLabel(editing.label ? 'update' : 'create', { ...(editing.label ? { id: editing.label.id } : {}),
      start: value.start, finish: value.finish, name: value.name, color: value.color, collapsed: editing.label?.collapsed ?? false }, editing.revision);
  } else if (data.action === 'delete' && editing.label) sent = await changeLabel('delete', { id: editing.label.id }, editing.revision);
  if (sent) send('editor-close', { request: data.request });
}
ui['toggle-all'].addEventListener('click', () => { clearError(); send('label-batch', { action: 'collapse', collapsed: labels.some(label => !label.collapsed), revision }); });
function publishSettings(force = false) {
  if (!connected) return;
  const state = { language: i18n.locale, languages, labelsVisible, showLabelGuides, canUndo, canRedo, stateError, revision, notice, errorCode };
  const key = JSON.stringify(state);
  if (force || key !== settingsKey) { settingsKey = key; send('settings-state', { state }); }
}
async function settingsAction(data) {
  if (data.action === 'language') {
    try { await i18n.load(data.value); storePreferences(); refreshText(); await send('locale', { locale: i18n.locale }); }
    catch { report('languageFailed'); }
  } else if (data.action === 'labels') { setPanel(data.value === true); storePreferences(); }
  else if (data.action === 'label-guides') { showLabelGuides = data.value === true; guidesDirty = true; storePreferences(); }
  else if (data.action === 'fit') queueView(0, map.length);
  else if (data.action === 'undo' || data.action === 'redo') send('history', { action: data.action });
  else if (data.action === 'markers' || data.action === 'regions') {
    clearError(); notice = null;
    send('label-batch', { action: data.action, revision: data.revision });
  }
  publishSettings(true);
}

function queueView(start, finish, top = viewRange().top) {
  if (!connected) return;
  const span = clamp(finish - start, 0.05, 1e9);
  const a = clamp(start, 0, 1e9 - span);
  viewPending = previewView = { start: a, finish: a + span, top: clamp(top, layout?.minimum ?? 0, layout?.maximum ?? 0) };
  previewAt = performance.now(); viewDirty = true;
  if (!viewTimer && !viewInFlight) viewTimer = setTimeout(flushView, 35);
}
async function flushView() {
  viewTimer = null;
  if (!viewPending || viewInFlight) return;
  const pending = viewPending; viewPending = null; viewInFlight = true;
  await send('view', pending);
  viewInFlight = false;
  if (viewPending) viewTimer = setTimeout(flushView, 35);
}
function eventTime(event, mapping = map) {
  return mapping.toTime(event.clientX - ui.tracks.getBoundingClientRect().left);
}
function showSelection(start, finish, mapping) {
  const a = mapping.toX(start), b = mapping.toX(finish);
  ui.selection.hidden = false; ui.selection.style.left = `${Math.min(a, b)}px`; ui.selection.style.width = `${Math.abs(b - a)}px`;
}
function edgePosition(target, event) {
  const delta = eventTime(event, target.mapping) - target.start;
  return target.edge === 'start' ? clamp(target.label.start + delta, 0, target.label.finish - 0.01) : clamp(target.label.finish + delta, target.label.start + 0.01, 1e9);
}
function requestSnap(target, position, final = false) {
  const request = ++snapSequence, segment = target.mapping.segments.find(segment => position <= segment.finish) || target.mapping.segments.at(-1);
  const secondsPerPixel = (segment.finish - segment.start) / Math.max(1e-9, segment.right - segment.left);
  snapPending = { request, target, final, revision: target.revision };
  send('snap', { request, position, secondsPerPixel, minimum: target.edge === 'start' ? 0 : target.label.start + 0.01, maximum: target.edge === 'start' ? target.label.finish - 0.01 : 1e9 });
}
function flushSnap() {
  snapTimer = null;
  if (snapPending || !snapQueued) return;
  const value = snapQueued; snapQueued = null;
  requestSnap(value.target, value.position);
}
function queueSnap(target, position) {
  snapQueued = { target, position };
  if (!snapPending && !snapTimer) snapTimer = setTimeout(flushSnap, 16);
}
function pointerDown(event) {
  if (!connected || event.button !== 0 || editing) return;
  cancelGesture();
  const node = event.target.closest('.time-label');
  if (node) {
    const label = labels.find(label => label.id === Number(node.dataset.id));
    if (!label) return;
    event.preventDefault(); if (!event.target.dataset.edge) selectLabel(label);
    if (stateError) return;
    if (event.altKey) { changeLabel('delete', { id: label.id }); return; }
    if (event.ctrlKey) { changeLabel('update', { ...label, collapsed: !label.collapsed }); return; }
    if (event.shiftKey) { openEditor(label); return; }
    if (label.collapsed) return;
    gesture = { kind: 'label', label, preview: { ...label }, edge: event.target.dataset.edge, start: eventTime(event), mapping: map, revision };
  } else if (event.ctrlKey && !stateError) {
    gesture = { kind: 'create', start: eventTime(event), mapping: map };
  } else if (event.target.closest('.viewport')) {
    gesture = { kind: 'view', view: { ...viewRange() }, start: eventTime(event), mapping: map, pinned: event.target.closest('.viewport').dataset.pinned === 'true', trackMapping: trackMap, geometry: layout, areaTop: ui.tracks.getBoundingClientRect().top };
  } else {
    gesture = { kind: 'seek', start: eventTime(event), mapping: map };
  }
  Object.assign(gesture, { x: event.clientX, y: event.clientY, pointer: event.pointerId, element: event.currentTarget, moved: false });
  event.currentTarget.setPointerCapture(event.pointerId); event.preventDefault();
}
function pointerMove(event) {
  if (!gesture || gesture.final || event.pointerId !== gesture.pointer) return;
  if (Math.hypot(event.clientX - gesture.x, event.clientY - gesture.y) > 3) gesture.moved = true;
  const delta = eventTime(event, gesture.mapping) - gesture.start;
  if (gesture.kind === 'view' && gesture.moved) queueView(gesture.view.start + delta, gesture.view.finish + delta, gesture.view.top + (gesture.pinned ? 0 : nativeAtY(gesture.trackMapping, gesture.geometry, event.clientY - gesture.areaTop) - nativeAtY(gesture.trackMapping, gesture.geometry, gesture.y - gesture.areaTop)));
  if (gesture.kind === 'create' && gesture.moved) {
    const end = eventTime(event, gesture.mapping);
    showSelection(gesture.start, end, gesture.mapping);
  }
  if (gesture.kind === 'label' && gesture.moved) {
    const { label, edge } = gesture;
    if (edge) {
      const position = edgePosition(gesture, event);
      if (!sample?.snapEnabled) gesture.preview[edge] = position;
      queueSnap(gesture, position);
    } else {
      gesture.preview.start = clamp(label.start + delta, 0, 1e9 - (label.finish - label.start));
      gesture.preview.finish = gesture.preview.start + label.finish - label.start;
    }
    positionLabels();
  }
}
function cancelGesture() {
  clearTimeout(snapTimer); snapTimer = snapQueued = snapPending = null;
  const previous = gesture; gesture = null;
  if (previous?.element.hasPointerCapture(previous.pointer)) previous.element.releasePointerCapture(previous.pointer);
  ui.selection.hidden = true; positionLabels();
}
function pointerUp(event) {
  if (!gesture || event.pointerId !== gesture.pointer) return;
  const finished = gesture;
  if (finished.kind === 'label' && finished.edge && finished.moved) {
    clearTimeout(snapTimer); snapTimer = snapQueued = snapPending = null;
    finished.final = true;
    requestSnap(finished, edgePosition(finished, event), true);
    return;
  }
  cancelGesture();
  if (finished.kind === 'label' && finished.moved) changeLabel('update', finished.preview, finished.revision);
  if (finished.kind === 'create' && finished.moved) {
    const end = eventTime(event, finished.mapping), start = Math.min(end, finished.start), finish = Math.max(end, finished.start);
    if (finish - start >= 0.01) openEditor(null, start, finish);
  }
  if ((finished.kind === 'seek' || finished.kind === 'view') && !finished.moved) send('seek', { position: finished.start });
}
for (const element of [ui.timeline, ui.tracks]) {
  element.addEventListener('pointerdown', pointerDown);
  element.addEventListener('pointermove', pointerMove);
  element.addEventListener('pointerup', pointerUp);
  element.addEventListener('pointercancel', cancelGesture);
  element.addEventListener('lostpointercapture', () => { if (gesture?.element === element && !gesture.final) cancelGesture(); });
  element.addEventListener('wheel', event => {
    if (!connected) return;
    event.preventDefault();
    const delta = event.deltaY * (event.deltaMode === 1 ? 16 : event.deltaMode === 2 ? height : 1);
    const next = zoomRange(viewRange(), eventTime(event), delta, map.length);
    queueView(next.start, next.finish);
  }, { passive: false });
}
ui.viewport.addEventListener('keydown', event => {
  const view = viewRange(), horizontal = (view.finish - view.start) * 0.1, vertical = (sample?.viewHeight || 1) * 0.1;
  if (!['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(event.key)) return;
  event.preventDefault();
  const dx = event.key === 'ArrowLeft' ? -horizontal : event.key === 'ArrowRight' ? horizontal : 0;
  const dy = event.target.dataset.pinned === 'true' ? 0 : event.key === 'ArrowUp' ? -vertical : event.key === 'ArrowDown' ? vertical : 0;
  queueView(view.start + dx, view.finish + dx, view.top + dy);
});
document.addEventListener('keydown', event => {
  if (event.ctrlKey && !event.altKey && (event.code === 'Comma' || event.key === ',')) {
    event.preventDefault(); if (!editing) { cancelGesture(); publishSettings(true); send('settings-open'); } return;
  }
  if (event.ctrlKey && event.shiftKey && event.code === 'KeyT') { event.preventDefault(); setPanel(!labelsVisible); storePreferences(); publishSettings(); return; }
  if (event.ctrlKey && !event.altKey && !event.target.closest?.('input,textarea,[contenteditable=true]') && !editing) {
    if (event.code === 'KeyZ' || event.code === 'KeyY') { event.preventDefault(); send('history', { action: event.code === 'KeyY' || event.shiftKey ? 'redo' : 'undo' }); return; }
  }
  if (event.key === 'Escape' && (gesture || snapPending)) { cancelGesture(); return; }
  if (event.code !== 'Space' || event.repeat || event.ctrlKey || event.altKey || event.metaKey || editing) return;
  if (event.target.closest?.('input,textarea,select,[contenteditable=true]')) return;
  event.preventDefault(); send('transport');
});

for (const [element, horizontal] of [[ui['sidebar-divider'], true], [ui['label-divider'], false]]) {
  let drag = null;
  element.addEventListener('pointerdown', event => {
    if (event.button !== 0) return;
    cancelGesture(); drag = { pointer: event.pointerId, x: event.clientX, y: event.clientY, ratio: ui['label-panel'].getBoundingClientRect().width / ui.main.clientWidth, labelHeight: ui.timeline.clientHeight };
    element.setPointerCapture(event.pointerId); event.preventDefault();
  });
  element.addEventListener('pointermove', event => {
    if (!drag || event.pointerId !== drag.pointer) return;
    if (horizontal) sidebarRatio = clamp(drag.ratio + (drag.x - event.clientX) / ui.main.clientWidth, Math.min(96 / ui.main.clientWidth, 0.4), 0.4);
    else labelHeight = clamp(drag.labelHeight + event.clientY - drag.y, Math.min(18, labelHeightLimit()), labelHeightLimit());
    applyPanels(); positionLabels(); resizePending = true;
  });
  const release = () => { drag = null; storePreferences(); };
  element.addEventListener('pointerup', release); element.addEventListener('pointercancel', release); element.addEventListener('lostpointercapture', release);
  element.addEventListener('keydown', event => {
    const increase = horizontal ? event.key === 'ArrowLeft' : event.key === 'ArrowDown';
    const decrease = horizontal ? event.key === 'ArrowRight' : event.key === 'ArrowUp';
    if (!increase && !decrease) return;
    event.preventDefault();
    if (horizontal) sidebarRatio = clamp(sidebarRatio + (increase ? 0.02 : -0.02), Math.min(96 / ui.main.clientWidth, 0.4), 0.4);
    else labelHeight = clamp(labelHeight + (increase ? 18 : -18), Math.min(18, labelHeightLimit()), labelHeightLimit());
    applyPanels(); positionLabels(); resizePending = true; storePreferences();
  });
}
function receive(text) {
  let data;
  try { data = JSON.parse(text); } catch { report('syncFailed'); return; }
  if (data.type === 'hello') {
    if (session !== data.session) {
      cancelGesture(); editing = null;
      session = data.session; sample = staging = layout = clockOffset = snapshotKey = null; selectedLabel = null; canUndo = canRedo = false;
      ackSequence = 0; clearTimeout(ackTimer); ackTimer = null;
      tracks = []; labels = []; projectLength = 1; loaded = false; stateError = false;
      notice = null;
      viewPending = previewView = null; clearTimeout(viewTimer); viewTimer = null;
      clearError(); rebuildMap();
    }
    languages = data.languages; settingsKey = null;
    acknowledge(data);
    connected = true; lastReceive = performance.now(); controls(); refreshText(); return;
  }
  if (data.session !== session) return;
  acknowledge(data);
  lastReceive = performance.now();
  if (!connected) {
    connected = true;
    if (errorCode === 'connectionLost') clearError();
    controls(); refreshText();
  }
  if (data.type === 'snap') {
    if (!snapPending || snapPending.request !== data.request || snapPending.revision !== revision) return;
    const pending = snapPending; snapPending = null;
    if (gesture !== pending.target || !Number.isFinite(data.position)) return;
    gesture.preview[gesture.edge] = data.position; positionLabels();
    if (pending.final) changeLabel('update', gesture.preview, gesture.revision);
    else if (snapQueued) flushSnap();
  } else if (data.type === 'notice') {
    if (!['importedLabels', 'noLabelsImported'].includes(data.code)) return;
    notice = data; publishSettings();
  } else if (data.type === 'editor-action') {
    editorAction(data).catch(() => report('syncFailed'));
  } else if (data.type === 'editor-closed') {
    if (editing?.request === data.request) editing = null;
  } else if (data.type === 'settings-action') {
    settingsAction(data).catch(() => report('syncFailed'));
  } else if (data.type === 'settings-request') {
    publishSettings(true);
  } else if (data.type === 'labels') {
    cancelGesture();
    labels = data.labels; revision = data.revision; stateError = data.stateError; canUndo = data.canUndo; canRedo = data.canRedo;
    if (stateError) report('stateInvalid');
    else if (errorCode === 'stateInvalid') clearError();
    rebuildMap(); renderLabels(); controls();
  } else if (data.type === 'layout') {
    layout = data; viewDirty = true;
  } else if (data.type === 'begin') {
    staging = { generation: data.generation, tracks: [], defaultItemColor: data.defaultItemColor, length: data.length };
  } else if (data.type === 'chunk' && staging?.generation === data.generation) {
    for (const record of data.records) {
      if (record.kind === 'track') staging.tracks[record.index - 1] = { ...record, items: [] };
      else if (record.kind === 'item' && staging.tracks[record.track - 1]) { staging.tracks[record.track - 1].items.push(record); }
    }
  } else if (data.type === 'end' && staging?.generation === data.generation) {
    staging.length = Math.max(data.length ?? staging.length, ...staging.tracks.map(track => track.items.reduce((end, item) => Math.max(end, item.finish), 0)));
    const key = JSON.stringify([staging.tracks, staging.length, staging.defaultItemColor]);
    if (key === snapshotKey) { staging = null; return; }
    snapshotKey = key;
    tracks = staging.tracks; defaultItemColor = staging.defaultItemColor; projectLength = staging.length;
    staging = null; loaded = true;
    rebuildMap(); refreshText();
  } else if (data.type === 'transport') {
    const offset = data.timestamp - performance.now();
    clockOffset = clockOffset === null ? offset : Math.max(clockOffset, offset);
    if (sample?.viewStart !== data.viewStart || sample?.viewEnd !== data.viewEnd || sample?.viewTop !== data.viewTop || sample?.viewHeight !== data.viewHeight) viewDirty = true;
    sample = data;
    if (previewView && !viewPending && !viewInFlight && (!gesture || gesture.kind !== 'view') && performance.now() - previewAt > 120) { previewView = null; viewDirty = true; }
  } else if (data.type === 'error') { cancelGesture(); report(Object.hasOwn(i18n.fallback, data.code) ? data.code : 'syncFailed'); }
}
function frame(now) {
  if (connected && now - lastReceive > 5000) { connected = false; cancelGesture(); controls(); report('connectionLost'); }
  if (resizePending || pixelRatio !== window.devicePixelRatio) resize();
  if (dirty) { drawTracks(); dirty = false; }
  if (guidesDirty) drawLabelGuides();
  if (viewDirty) positionViewports();
  const position = interpolatedPosition(sample, now, clockOffset ?? 0);
  const x = map.toX(position), edit = map.toX(sample?.cursor ?? 0);
  const cursorKey = `${x.toFixed(1)}:${edit.toFixed(1)}:${height}:${sample?.playState}`;
  if (cursorKey !== lastCursor) {
    lastCursor = cursorKey;
    const ctx = ui.cursor.getContext('2d'); ctx.clearRect(0, 0, width, height);
    if (sample) {
      if (sample.playState & 1) { ctx.fillStyle = '#d2dbe366'; ctx.fillRect(edit, 0, 1, height); }
      ctx.fillStyle = sample.playState & 4 ? '#ed9989' : '#b9e4d1'; ctx.fillRect(x, 0, 1.5, height);
      ctx.beginPath(); ctx.moveTo(x - 4, 0); ctx.lineTo(x + 5, 0); ctx.lineTo(x, 7); ctx.fill();
    }
  }
  requestAnimationFrame(frame);
}

async function start() {
  await i18n.load();
  let preferred = 'en';
  try { const prefs = JSON.parse(localStorage.getItem('ArrangeNavigator.ui')); preferred = prefs?.language || 'en'; labelsVisible = prefs?.labelsVisible === true; showLabelGuides = prefs?.showLabelGuides !== false; if (Number.isFinite(prefs?.sidebarRatio)) sidebarRatio = clamp(prefs.sidebarRatio, 0.05, 0.4); if (Number.isFinite(prefs?.labelHeight)) labelHeight = clamp(prefs.labelHeight === 27 ? 18 : prefs.labelHeight, 18, 1000); } catch {}
  if (preferred !== 'en') { try { await i18n.load(preferred); } catch { report('languageFailed'); } }
  storePreferences(); refreshText();
  const observer = new ResizeObserver(() => { resizePending = true; }); observer.observe(ui.tracks); observer.observe(ui.main);
  requestAnimationFrame(frame);
  if (!bridge?.host || !bridge?.events) { report('bridgeMissing'); return; }
  try {
    await bridge.lifecycle.ready;
    await bridge.window.setIconVisible(false);
    await bridge.events.on('message', receive);
    await bridge.events.on('projectchange', () => { send('refresh'); }).catch(() => {});
    await bridge.host.send({ type: 'ready', locale: i18n.locale });
    setTimeout(() => { if (session === null) report('connectionLost'); }, 5000);
  } catch { report('connectionLost'); }
}
start().catch(() => { if (Object.keys(i18n.fallback).length) report('syncFailed'); });
