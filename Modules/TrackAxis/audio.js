import { toDb, dbText } from './model.js';

const colors = ['#8dc7b9', '#8da9d8', '#c5a4d9', '#d4b87a', '#90bccd', '#cf999b'];
function canvasContext(canvas) {
  const ratio = window.devicePixelRatio || 1;
  const width = Math.max(1, Math.round(canvas.clientWidth * ratio));
  const height = Math.max(1, Math.round(canvas.clientHeight * ratio));
  if (canvas.width !== width || canvas.height !== height) { canvas.width = width; canvas.height = height; }
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, width, height);
  const style = getComputedStyle(canvas);
  return {ctx, width, height, accent: style.getPropertyValue('--accent').trim() || colors[0], line:style.getPropertyValue('--line').trim() || '#29333d', muted:style.getPropertyValue('--muted').trim() || '#8b9baa'};
}
function waveform(canvas, channels) {
  const {ctx, width, height, accent, line, muted} = canvasContext(canvas);
  const lane = height / Math.max(1, channels.length);
  channels.forEach((data, c) => {
    const middle = lane * (c + 0.5), scale = lane * 0.43;
    ctx.strokeStyle = line; ctx.beginPath(); ctx.moveTo(0, middle); ctx.lineTo(width, middle); ctx.stroke();
    ctx.strokeStyle = c === 0 ? accent : colors[c % colors.length]; ctx.beginPath();
    for (let i = 0; i < data.min.length; i++) {
      const x = i * width / data.min.length;
      ctx.moveTo(x, middle - data.max[i] * scale); ctx.lineTo(x, middle - data.min[i] * scale);
    }
    ctx.stroke(); ctx.fillStyle = muted; ctx.font = '10px sans-serif'; ctx.fillText(`CH ${c + 1}`, 7, lane * c + 13);
  });
}
export function drawOverview(canvas, data) { waveform(canvas, data.data); }

export class AudioAnalysis {
  constructor(api, root, translate) {
    this.api = api; this.root = root; this.t = translate;
    this.entries = new Map(); this.pending = new Set(); this.revision = 0;
    this.frame = 0; this.lastDraw = 0; this.closed = false; this.peakBusy = false;
    this.draw = this.draw.bind(this);
  }
  status(kind, text) { this.root.querySelector(`#analysis-${kind} .analysis-status`).textContent = text; }
  enabled(kind) {
    return !this.closed && this.config?.active && this.config[kind] && this.root.querySelector(`#analysis-${kind}`).open;
  }
  configure(config) {
    const before = this.config;
    this.config = config;
    for (const kind of ['meter', 'spectrum', 'waveform', 'livePeak']) this.root.querySelector(`#analysis-${kind}`).hidden = !config[kind];
    const changed = !before || ['source', 'session', 'trackKey', 'fftSize', 'streamRate'].some(key => config[key] !== before[key]);
    if (changed) { this.revision++; this.peak = null; this.peakHandle = null; this.peakRevision = -1; }
    for (const kind of ['meter', 'spectrum', 'waveform']) {
      const entry = this.entries.get(kind);
      if (entry && (changed || !this.enabled(kind))) this.detach(kind, entry);
      if (this.enabled(kind) && !this.entries.has(kind)) this.open(kind);
      if (!this.enabled(kind)) this.clear(kind);
    }
    if (!this.enabled('livePeak')) { this.peak = null; this.clear('livePeak'); }
    if (this.enabled('livePeak') && !config.track) this.status('livePeak', this.t('singleTrack'));
    if (!this.frame && config.active) this.frame = requestAnimationFrame(this.draw);
    if (!config.active && this.frame) { cancelAnimationFrame(this.frame); this.frame = 0; }
  }
  clear(kind) {
    const card = this.root.querySelector(`#analysis-${kind}`);
    const readout = card.querySelector('.readout');
    if (readout?.children.length) readout.style.minHeight = `${readout.getBoundingClientRect().height}px`;
    readout?.replaceChildren();
    const canvas = card.querySelector('canvas');
    if (canvas) canvas.getContext('2d').clearRect(0, 0, canvas.width, canvas.height);
    this.status(kind, this.t('paused'));
  }
  detach(kind, entry) {
    entry.cancelled = true;
    if (this.entries.get(kind) === entry) this.entries.delete(kind);
    if (entry.stream) {
      const closing = entry.stream.close().catch(() => {}).finally(() => this.pending.delete(closing));
      this.pending.add(closing);
    }
  }
  open(kind) {
    const entry = {cancelled: false, stream: null};
    this.entries.set(kind, entry);
    this.clear(kind); this.status(kind, this.t('connecting'));
    const config = this.config;
    const opening = (async () => {
      try {
        if (!this.api?.audio?.openStream) throw Error(this.t('streamUnavailable'));
        if (!config.source) throw Error(this.t('singleTrack'));
        const stream = await this.api.audio.openStream(kind, {source: config.source, fftSize: config.fftSize, updateRate: config.streamRate});
        if (entry.cancelled || this.closed) { await stream.close(); return; }
        entry.stream = stream;
        const stopped = error => {
          if (entry.cancelled) return;
          this.clear(kind); this.status(kind, `${this.t('analysisUnavailable')} · ${error?.code || ''}`);
        };
        stream.on('error', stopped); stream.on('close', stopped);
        this.status(kind, this.t('waitingAudio'));
      } catch (error) { if (!entry.cancelled) this.status(kind, error.message || this.t('analysisUnavailable')); }
    })().finally(() => this.pending.delete(opening));
    this.pending.add(opening);
  }
  async readPeak() {
    if (this.peakBusy || !this.config.track || !this.enabled('livePeak')) return;
    const revision = this.revision, config = this.config;
    this.peakBusy = true;
    try {
      if (!this.api?.audio?.getTrackMeter) throw Error(this.t('meterUnavailable'));
      if (this.peakRevision !== revision) {
        const handle = await this.api.GetTrack(0, config.track.number - 1);
        if (!handle || await this.api.GetTrackGUID(handle) !== config.track.guid) throw Error(this.t('staleState'));
        if (revision !== this.revision) return;
        this.peakHandle = handle; this.peakRevision = revision;
      }
      const result = await this.api.audio.getTrackMeter(this.peakHandle);
      if (revision === this.revision && this.enabled('livePeak')) {
        this.peak = result; this.status('livePeak', '');
      }
    } catch (error) {
      if (revision === this.revision) { this.peak = null; this.clear('livePeak'); this.status('livePeak', error.message); }
    } finally { this.peakBusy = false; }
  }
  draw(now) {
    this.frame = 0;
    if (this.closed || !this.config?.active) return;
    if (now - this.lastDraw >= 1000 / this.config.drawRate) {
      this.lastDraw = now;
      for (const [kind, entry] of this.entries) {
        if (!this.enabled(kind) || !entry.stream || entry.stream.closed) continue;
        const packet = entry.stream.latest();
        if (!packet) continue;
        this.status(kind, '');
        const info = entry.stream.info, data = packet.data;
        if (!(data instanceof Float32Array) || !info.channels) continue;
        if (kind === 'meter') {
          if (data.length < info.channels * 2 + 4) { this.clear(kind); this.status(kind, this.t('analysisUnavailable')); continue; }
          this.meter(kind, info.channels, data);
        }
        if (kind === 'spectrum') this.spectrum(info, data);
        if (kind === 'waveform') {
          const buckets = Math.floor(data.length / (info.channels * 2));
          const channels = Array.from({length: info.channels}, (_, c) => ({
            min: Array.from({length: buckets}, (_, i) => data[(i * info.channels + c) * 2]),
            max: Array.from({length: buckets}, (_, i) => data[(i * info.channels + c) * 2 + 1]),
          }));
          waveform(this.root.querySelector('#analysis-waveform canvas'), channels);
        }
      }
      if (this.enabled('livePeak')) {
        if (now - (this.lastPeak || 0) >= 1000 / Math.min(30, this.config.streamRate)) { this.lastPeak = now; this.readPeak(); }
        if (this.peak) this.meter('livePeak', this.peak.channels, this.peak.peak, true);
      }
    }
    this.frame = requestAnimationFrame(this.draw);
  }
  meter(kind, channels, data, peakOnly = false) {
    const root = this.root.querySelector(`#analysis-${kind} .readout`);
    const signature = `${channels}:${peakOnly}`;
    if (root.dataset.layout !== signature || !root.children.length) {
      root.dataset.layout = signature; root.replaceChildren();
      for (let c = 0; c < channels; c++) {
        const row = document.createElement('div'); row.className = 'meter-channel';
        const label = document.createElement('span'); label.textContent = `CH ${c + 1}`;
        const bar = document.createElement('div'); bar.className = 'meter-bar'; bar.append(document.createElement('span'));
        row.append(label, bar, document.createElement('output')); root.append(row);
        if (!peakOnly) { const values = document.createElement('div'); values.className = 'meter-numbers'; root.append(values); }
      }
      if (!peakOnly) {
        const grid = document.createElement('div'); grid.className = 'lufs-grid';
        for (const key of ['momentary', 'shortTerm', 'integrated']) {
          const cell = document.createElement('div'), label = document.createElement('span');
          label.textContent = this.t(key); cell.append(document.createElement('output'), label); grid.append(cell);
        }
        root.append(grid);
      }
      root.style.minHeight = '';
    }
    root.querySelectorAll('.meter-channel').forEach((row, c) => {
      const db = toDb(data[c]);
      row.querySelector('.meter-bar span').style.width = `${Number.isNaN(db) ? 0 : Math.max(0, Math.min(100, (db + 60) / 60 * 100))}%`;
      row.querySelector('output').textContent = `${dbText(db)} dBFS`;
      if (!peakOnly) row.nextElementSibling.textContent = `Peak ${dbText(db)} dBFS  ·  RMS ${dbText(toDb(data[channels + c]))} dBFS`;
    });
    if (!peakOnly) root.querySelectorAll('.lufs-grid output').forEach((out, i) => { out.textContent = `${dbText(data[channels * 2 + i])} LUFS`; });
  }
  spectrum(info, data) {
    const {ctx, width, height, accent, line} = canvasContext(this.root.querySelector('#analysis-spectrum canvas'));
    const count = Math.floor(data.length / info.channels), ceiling = Math.min(20000, info.sampleRate / 2);
    const binHz = info.binHz || info.sampleRate / info.fftSize;
    if (!Number.isFinite(binHz) || ceiling <= 20) return;
    ctx.strokeStyle = line; ctx.lineWidth = 1;
    for (let i = 1; i < 4; i++) { ctx.beginPath(); ctx.moveTo(0, height * i / 4); ctx.lineTo(width, height * i / 4); ctx.stroke(); }
    for (let c = 0; c < info.channels; c++) {
      ctx.strokeStyle = c === 0 ? accent : colors[c % colors.length]; ctx.beginPath(); let started = false;
      for (let i = 1; i < count; i++) {
        const hz = i * binHz;
        if (hz < 20 || hz > ceiling) continue;
        const db = Math.max(this.config.floor, Math.min(0, toDb(data[i * info.channels + c])));
        const x = Math.log(hz / 20) / Math.log(ceiling / 20) * width, y = height * db / this.config.floor;
        if (!started) ctx.moveTo(x, y); else ctx.lineTo(x, y); started = true;
      }
      ctx.stroke();
    }
  }
  restart() {
    for (const [kind, entry] of this.entries) this.detach(kind, entry);
    this.peakRevision = -1; this.configure(this.config);
  }
  async close() {
    this.closed = true; this.revision++; cancelAnimationFrame(this.frame); this.frame = 0;
    for (const [kind, entry] of this.entries) this.detach(kind, entry);
    await Promise.allSettled([...this.pending]);
  }
}
