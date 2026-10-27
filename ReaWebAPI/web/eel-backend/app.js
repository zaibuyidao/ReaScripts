'use strict';
const ui = Object.fromEntries([...document.querySelectorAll('[id]')].map(el => [el.id, el]));
const session = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
const pending = new Map();
const sliders = Object.fromEntries(['volume'].map(key => [key, {
  queued: null, flights: new Set(), editing: false, gesture: 0, failed: false,
}]));
const maxSliderFlights = 8;
let requestId = 0, state = null, contextFloor = 0, revisionFloor = 0, pageClosed = false;
function current(context) {
  return !pageClosed && state && context?.context === state.context && context.guid === state.guid;
}
function report(error) { if (!pageClosed) ui.error.textContent = error.message; }
function labels() {
  const volume = Number(ui.volume.value);
  ui['volume-value'].textContent = volume ? `${(20 * Math.log10(volume)).toFixed(1)} dB` : '−∞ dB';
}
function render() {
  const selected = state && state.guid !== '-' && state.context >= contextFloor;
  ui.controls.disabled = !selected;
  ui.name.textContent = selected ? state.name : 'No track selected';
  if (!selected) return;
  for (const [key, slider] of Object.entries(sliders)) {
    if (!slider.editing && ![...slider.flights].some(flight => current(flight.context)) && !slider.queued && state.revision >= revisionFloor)
      ui[key].value = state[key];
  }
  labels();
}
function request(command, value, context = state) {
  if (pageClosed || (command !== 'ready' && command !== 'get-track' && (!context || context.guid === '-')))
    return Promise.reject(new Error('Select a track first.'));
  const id = ++requestId;
  return new Promise((resolve, reject) => {
    const fail = error => {
      const entry = pending.get(id);
      if (!entry) return;
      clearTimeout(entry.timer); pending.delete(id); reject(error);
    };
    const timer = setTimeout(() => fail(new Error(`EEL2 did not confirm ${command}. The command may already have run. Check REAPER before retrying.`)), 10000);
    pending.set(id, {resolve, fail, timer, command, context});
    // Queue acceptance is not execution confirmation. Only an EEL2 ack resolves this request.
    try {
      Promise.resolve(reaper.host.send(`${session} ${id} ${command} ${context?.context ?? 0} ${context?.guid ?? '-'} ${value}`))
        .then(accepted => { if (!accepted) fail(new Error('The message bridge rejected the command.')); }, fail);
    } catch (error) { fail(error); }
  });
}
function onMessage(message) {
  if (pageClosed) return;
  if (message.startsWith('ack ')) {
    const fields = message.split(' ');
    if (fields.length !== 8 || fields[1] !== session) return;
    const entry = pending.get(Number(fields[2]));
    if (!entry) return;
    const revision = Number(fields[3]), context = Number(fields[4]), guid = fields[5], status = fields[6];
    contextFloor = Math.max(contextFloor, context);
    revisionFloor = Math.max(revisionFloor, revision);
    if (status !== 'ok' && status !== 'superseded') {
      entry.fail(new Error(`EEL2 rejected ${entry.command}: ${status}.`));
    } else {
      clearTimeout(entry.timer); pending.delete(Number(fields[2]));
      entry.resolve({revision, context, guid, status, actual: Number(fields[7])});
    }
    ui.controls.disabled = !state || state.guid === '-' || state.context < contextFloor;
    return;
  }
}
function applyState(message) {
  if (!message.startsWith('state ')) return;
  const split = message.indexOf('\n'), fields = message.slice(0, split).split(' ');
  if (split < 0 || fields.length !== 6 || fields[1] !== session) return;
  const revision = Number(fields[2]), context = Number(fields[3]), guid = fields[4];
  if (revision < revisionFloor || revision <= (state?.revision ?? -1) || context < contextFloor) return;
  if (!state || context !== state.context || guid !== state.guid) {
    for (const slider of Object.values(sliders)) {
      slider.queued = null; slider.editing = false; slider.gesture += 1; slider.failed = false;
    }
  }
  state = {revision, context, guid, name: message.slice(split + 1), volume: Number(fields[5])};
  render();
}
// Frames are replaceable state. Execution acknowledgements stay on the message channel.
let latestFrame = null, frameRequest = 0;
function onFrame(frame) {
  if (pageClosed || typeof frame.lua !== 'string') return;
  latestFrame = frame.lua;
  if (!frameRequest) frameRequest = requestAnimationFrame(() => {
    frameRequest = 0;
    if (!pageClosed) applyState(latestFrame);
  });
}
function pumpSlider(key) {
  const slider = sliders[key];
  while (!pageClosed && slider.queued && slider.flights.size < maxSliderFlights) {
    const next = slider.queued; slider.queued = null;
    if (!current(next.context) || next.context.context < contextFloor) continue;
    const flight = {context: next.context};
    slider.flights.add(flight);
    flight.promise = request(key, next.value, next.context).catch(error => {
      if (current(next.context) && next.gesture === slider.gesture) {
        if (!slider.failed) report(error);
        slider.failed = true;
      }
    }).finally(() => {
      slider.flights.delete(flight);
      pumpSlider(key);
      // A snapshot older than the execution ack must never undo the final gesture.
      if (current(next.context)) render();
    });
  }
}
function queueSlider(key) {
  if (pageClosed || ui.controls.disabled) return;
  const slider = sliders[key];
  if (!slider.editing) { slider.gesture += 1; slider.failed = false; }
  slider.editing = true;
  slider.queued = {value: Number(ui[key].value), context: state, gesture: slider.gesture};
  labels(); pumpSlider(key);
}
async function drainSlider(key) {
  const slider = sliders[key];
  while (!pageClosed && (slider.queued || slider.flights.size)) {
    pumpSlider(key);
    await Promise.all([...slider.flights].map(flight => flight.promise));
  }
  render();
}
for (const key of Object.keys(sliders)) {
  ui[key].addEventListener('input', () => queueSlider(key));
  const finish = () => {
    if (pageClosed || ui.controls.disabled) return;
    // Keep the terminal value even if all eight execution slots are occupied.
    queueSlider(key);
    sliders[key].editing = false;
    void drainSlider(key).catch(report);
  };
  ui[key].addEventListener('change', finish);
  ui[key].addEventListener('blur', () => { if (sliders[key].editing) finish(); });
  ui[key].addEventListener('pointercancel', () => { if (sliders[key].editing) finish(); });
}
ui.refresh.addEventListener('click', async () => {
  ui.refresh.disabled = true;
  try { await request('get-track', 0); ui.status.textContent = 'Selection checked by EEL2'; }
  catch (error) { report(error); }
  finally { ui.refresh.disabled = false; }
});
window.addEventListener('pagehide', () => {
  pageClosed = true;
  cancelAnimationFrame(frameRequest); latestFrame = null;
  for (const slider of Object.values(sliders)) slider.queued = null;
  for (const entry of pending.values()) entry.fail(new Error('Page closed.'));
});
(async () => {
  await reaper.events.on('message', onMessage);
  await reaper.events.on('frame', onFrame);
  await request('ready', 0);
  ui.refresh.disabled = false; ui.status.textContent = 'Connected to EEL2';
})().catch(report);
