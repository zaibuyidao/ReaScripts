export const themePresets = Object.freeze({
  modern: {background:'#181b20',panel:'#222830',text:'#e1e7ef',accent:'#89c7bd',line:'#3c4754'},
  retro: {background:'#efe5ce',panel:'#f7efdd',text:'#40362a',accent:'#83522b',line:'#c1ae87'},
  serious: {background:'#222326',panel:'#2c2e32',text:'#e4e4e7',accent:'#b8bec8',line:'#4a4e57'},
  cyber: {background:'#101321',panel:'#191d32',text:'#e1f5ff',accent:'#45e0dc',line:'#363c60'},
  warm: {background:'#f4e8de',panel:'#fff6ee',text:'#49392f',accent:'#a14d29',line:'#cbb6a6'},
  cold: {background:'#e8f1f6',panel:'#f5fafc',text:'#263f52',accent:'#226184',line:'#adc5d4'},
  anime: {background:'#211e35',panel:'#2d2846',text:'#f3eafa',accent:'#eda6d4',line:'#554b70'},
  forest: {background:'#18251f',panel:'#223129',text:'#e0eade',accent:'#a9c780',line:'#3e5747'},
  mono: {background:'#ececec',panel:'#fafafa',text:'#292929',accent:'#4b4b4b',line:'#bdbdbd'},
  midnight: {background:'#111b2a',panel:'#19283c',text:'#d8e5f5',accent:'#91b8ed',line:'#334963'},
});

export const defaults = Object.freeze({
  version: 1, language: 'en', density: 'comfortable', fxCompact: false,
  listHeights: {fx:0, fxCompact:0, sends:0, receives:0},
  analysis: true, meter: true, spectrum: true, waveform: true, livePeak: false,
  source: 'track', fftSize: 2048, streamRate: 30, drawRate: 30, floor: -90,
  theme: 'reaper', colorBackground: '#181b20', colorPanel: '#20252c', colorText: '#d6dce5', colorAccent: '#89c7bd', colorBorder: '#303740',
  panels: { routing: true, fx: true, parameters: false, items: true, analysis: true, metadata: true, appearance: false, quick: true },
});

export function preferences(raw = {}) {
  const p = { ...defaults, panels: { ...defaults.panels }, listHeights: {...defaults.listHeights} };
  if (!raw || raw.version !== 1) return p;
  for (const key of ['analysis', 'meter', 'spectrum', 'waveform', 'livePeak', 'fxCompact']) if (typeof raw[key] === 'boolean') p[key] = raw[key];
  for (const key of Object.keys(p.listHeights)) if (Number.isFinite(raw.listHeights?.[key]) && raw.listHeights[key] >= 0 && raw.listHeights[key] <= 4000) p.listHeights[key] = raw.listHeights[key];
  for (const [key, choices] of Object.entries({density: ['comfortable', 'compact'], source: ['track', 'master', 'input'], fftSize: [512, 1024, 2048, 4096, 8192], streamRate: [10, 20, 30, 60], drawRate: [15, 30, 60], floor: [-60, -90, -120]})) {
    if (choices.includes(raw[key])) p[key] = raw[key];
  }
  if (typeof raw.language === 'string' && /^[a-zA-Z-]{2,16}$/.test(raw.language)) p.language = raw.language;
  if (['reaper', ...Object.keys(themePresets), 'custom'].includes(raw.theme)) p.theme = raw.theme;
  for (const key of ['colorBackground','colorPanel','colorText','colorAccent','colorBorder']) if (/^#[\da-f]{6}$/i.test(raw[key] || '')) p[key] = raw[key];
  for (const key of Object.keys(p.panels)) if (typeof raw.panels?.[key] === 'boolean') p.panels[key] = raw.panels[key];
  return p;
}
export function themePalette(prefs, theme) {
  const preset = Object.hasOwn(themePresets, prefs.theme) ? themePresets[prefs.theme] : null;
  const native = prefs.theme === 'reaper' && theme?.available ? theme.colors : {};
  const rgb = hex => hex.slice(1).match(/../g).map(part => parseInt(part, 16));
  const mix = (a, b, ratio) => '#' + rgb(a).map((v, i) => Math.round(v + (rgb(b)[i] - v) * ratio).toString(16).padStart(2, '0')).join('');
  const light = color => rgb(color).reduce((sum, value, i) => sum + value * [0.2126, 0.7152, 0.0722][i], 0) > 150;
  const get = (key, fallback) => /^#[\da-f]{6}$/i.test(native?.[key] || '') ? native[key] : fallback;
  const background = get('col_main_bg', preset?.background ?? prefs.colorBackground), text = get('col_main_text', preset?.text ?? prefs.colorText);
  const panel = get('col_main_bg', preset?.panel ?? prefs.colorPanel), control = get('col_buttonbg', get('buttonface', native?.col_main_bg ? panel : mix(panel, text, 0.06)));
  const controlText = get('buttontext', text);
  const accent = get('genlist_selbg', preset?.accent ?? prefs.colorAccent), activeText = get('genlist_selfg', light(accent) ? '#101010' : '#ffffff');
  return {background, text, panel, control, accent, 'control-text': controlText,
    field: get('col_main_editbk', mix(background, text, 0.035)),
    line: get('col_main_3dsh', preset?.line ?? prefs.colorBorder),
    toolbar: get('col_main_bg2', panel), 'toolbar-text': get('col_main_text2', text),
    muted: native?.col_main_text ? text : mix(text, background, preset ? 0.28 : 0.4),
    hover: mix(control, controlText, 0.09), active: accent, 'active-text': activeText,
    'accent-text': native?.col_main_text ? text : accent,
    'range-track': mix(panel, text, 0.28),
    danger: light(control) ? '#9e2020' : '#ffaaaa', warning: light(background) ? '#794b13' : '#f0b58b',
    scheme: light(background) ? 'light' : 'dark'};
}
export const toDb = value => !Number.isFinite(value) || value < 0 ? NaN : value > 0 ? 20 * Math.log10(value) : -Infinity;
export const fromDb = db => db <= -90 ? 0 : 10 ** (db / 20);
export const dbText = value => value === -Infinity ? '−∞' : Number.isFinite(value) ? value.toFixed(1) : '—';
export function filterTracks(rows, query) {
  const terms = query.toLocaleLowerCase().trim().split(/\s+/).filter(Boolean);
  return rows.filter(row => terms.every(term => `${row.number} ${row.name} ${row.tags}`.toLocaleLowerCase().includes(term)));
}
export function filterFX(rows, query) {
  const normalize = text => text.normalize('NFKC').toLocaleLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
  const terms = normalize(query).split(/\s+/).filter(Boolean);
  return rows.filter(row => { const name = normalize(row.name); return terms.every(term => name.includes(term)); });
}
const fxFormats = ['VST', 'VSTi', 'VST3', 'VST3i', 'CLAP', 'CLAPi', 'JS', 'FXCHAIN'];
export function fxFormat(fx) {
  const prefix = (fx.format || fx.name.split(':')[0]).trim().toUpperCase().replace(/^VST2/, 'VST');
  if (/\.rfxchain$/i.test(fx.ident || '') || ['FX CHAIN','FXCHAIN'].includes(prefix)) return 'FXCHAIN';
  return fxFormats.find(format => format.toUpperCase() === prefix) || (fx.name.includes(':') ? prefix : 'other');
}
export function sortFX(rows) {
  const rank = fx => { const i = fxFormats.indexOf(fxFormat(fx)); return i < 0 ? fxFormats.length : i; };
  return [...rows].sort((a,b) => rank(a) - rank(b) || fxFormat(a).localeCompare(fxFormat(b)) || a.name.localeCompare(b.name, undefined, {numeric:true,sensitivity:'base'}) || (a.ident || '').localeCompare(b.ident || ''));
}
export function channelMapping(source, destination) {
  if (source < 0) return null;
  const encodedCount = source >> 10;
  const count = encodedCount === 0 ? 2 : encodedCount === 1 ? 1 : encodedCount * 2;
  return {source: (source & 1023) + 1, destination: (destination & 1023) + 1,
    count, destinationCount: destination & 1024 ? 1 : count};
}
export function isSettingsShortcut(event) {
  return event.ctrlKey && !event.metaKey && !event.shiftKey && !event.repeat &&
    ((!event.altKey && (event.code === 'Comma' || event.key === ',')) || (event.altKey && (event.code === 'KeyS' || event.key?.toLowerCase() === 's')));
}

// One in-flight command, with replacement only for the same pending target/field.
export class CommandQueue {
  constructor(send, context, onError, onSettled = () => {}) {
    this.send = send; this.context = context; this.onError = onError; this.onSettled = onSettled;
    this.pending = []; this.active = null; this.id = 0;
  }
  enqueue(command, replaceKey = '') {
    if (this.pending.length >= 64) { this.onError('queueFull'); return; }
    const message = { ...command, ...this.context(), type: 'command', id: ++this.id };
    const key = replaceKey && `${message.session}:${message.selectionKey}:${replaceKey}`;
    const entry = {message, key};
    const index = key ? this.pending.findIndex(x => x.key === key) : -1;
    if (index >= 0) this.pending[index] = entry; else this.pending.push(entry);
    this.pump();
  }
  pump() {
    if (this.active || !this.pending.length) return;
    const entry = this.active = this.pending.shift();
    this.timer = setTimeout(() => this.finish(entry.message.id, false, 'connectionLost'), 5000);
    Promise.resolve().then(() => this.active === entry ? this.send(entry.message) : undefined).catch(error => this.finish(entry.message.id, false, error.message));
  }
  finish(id, ok, error) {
    if (this.active?.message.id !== id) return;
    clearTimeout(this.timer); this.active = null;
    if (!ok) { this.pending = []; this.onError(error); }
    this.onSettled(); this.pump();
  }
  clear() { clearTimeout(this.timer); this.pending = []; this.active = null; }
  drain(timeout = 750) {
    const deadline = Date.now() + timeout;
    return new Promise(resolve => {
      const check = () => { if (!this.busy || Date.now() >= deadline) resolve(!this.busy); else setTimeout(check, 10); };
      check();
    });
  }
  get busy() { return !!this.active || !!this.pending.length; }
}
