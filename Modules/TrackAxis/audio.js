import { toDb } from './model.js';
import { NativeMeterView } from './meter.js';

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

export function spectrumTicks(width, ceiling, measure) {
  if (width <= 0 || !Number.isFinite(ceiling) || ceiling <= 20) return [];
  const tick = hz => {
    const label = hz >= 1000 ? `${Number((hz / 1000).toFixed(1))} kHz` : `${hz} Hz`;
    const position = Math.log(hz / 20) / Math.log(ceiling / 20), size = measure(label);
    const left = hz === 20 ? 0 : hz === ceiling ? width - size : position * width - size / 2;
    return {hz, label, position, left, right:left + size};
  };
  const ticks = [tick(20), tick(ceiling)];
  // Keep decades first, then fill the available gaps with intermediate bands.
  for (const hz of [1000, 100, 10000, 50, 500, 5000, 200, 2000]) {
    if (hz >= ceiling) continue;
    const next = tick(hz);
    if (ticks.every(other => next.right + 10 <= other.left || next.left >= other.right + 10)) ticks.push(next);
  }
  return ticks.sort((a, b) => a.hz - b.hz);
}

export class AudioAnalysis {
  constructor(api, root, translate) {
    this.api = api; this.root = root; this.t = translate;
    this.entries = new Map(); this.pending = new Set();
    this.frame = 0; this.lastDraw = 0; this.closed = false;
    this.draw = this.draw.bind(this);
  }
  status(kind, text) { this.root.querySelector(`#analysis-${kind} .analysis-status`).textContent = text; }
  enabled(kind) {
    return !this.closed && this.config?.active && this.config[kind] && this.root.querySelector(`#analysis-${kind}`).open;
  }
  configure(config) {
    const before = this.config;
    config = {...config, aggregate: config.aggregate === true && (config.source === 'selected-track' || config.source?.startsWith('track:'))};
    this.config = config;
    for (const kind of ['meter', 'spectrum', 'waveform']) this.root.querySelector(`#analysis-${kind}`).hidden = !config[kind];
    const changed = !before || ['source', 'aggregate', 'master', 'session', 'trackKey', 'fftSize', 'streamRate', 'language'].some(key => config[key] !== before[key]);
    const meterChanged = !before || ['forceMono', 'integratedMode', 'resetOnPlaybackStart'].some(key => config[key] !== before[key]);
    for (const kind of ['meter', 'spectrum', 'waveform']) {
      const entry = this.entries.get(kind);
      if (entry && (changed || kind === 'meter' && meterChanged || !this.enabled(kind))) this.detach(kind, entry);
      if (this.enabled(kind) && !this.entries.has(kind)) this.open(kind);
      if (!this.enabled(kind)) this.clear(kind);
    }
    this.meterView?.setVisibility(config);
    if (!this.frame && config.active) this.frame = requestAnimationFrame(this.draw);
    if (!config.active && this.frame) { cancelAnimationFrame(this.frame); this.frame = 0; }
  }
  clear(kind) {
    const card = this.root.querySelector(`#analysis-${kind}`);
    const readout = card.querySelector('.readout');
    if (readout?.children.length) readout.style.minHeight = `${readout.getBoundingClientRect().height}px`;
    readout?.replaceChildren();
    if (kind === 'meter') this.meterView = null;
    const canvas = card.querySelector('canvas');
    if (canvas) canvas.getContext('2d').clearRect(0, 0, canvas.width, canvas.height);
    this.status(kind, this.t('paused'));
  }
  detach(kind, entry) {
    entry.cancelled = true;
    clearTimeout(entry.retry);
    if (this.entries.get(kind) === entry) this.entries.delete(kind);
    if (entry.stream) {
      const closing = entry.stream.close().catch(() => {}).finally(() => this.pending.delete(closing));
      this.pending.add(closing);
    }
  }
  failed(kind, entry, error) {
    if (entry.cancelled || entry.failed) return;
    entry.failed = true;
    this.clear(kind);
    const delays = [250, 1000, 3000];
    // A hardware producer can disappear between creation and consumer attachment
    // when the device format changes. Recreate it instead of reusing the old name.
    if (['TRANSPORT_ERROR', 'TIMEOUT', 'UNSUPPORTED_FORMAT', 'STREAM_NOT_FOUND'].includes(error?.code) && entry.attempt < delays.length) {
      this.status(kind, this.t('connecting'));
      entry.retry = setTimeout(() => {
        if (entry.cancelled || !this.enabled(kind)) return;
        this.detach(kind, entry);
        this.open(kind, entry.attempt + 1);
      }, delays[entry.attempt]);
    } else this.status(kind, error?.message || this.t('analysisUnavailable'));
  }
  open(kind, attempt = 0) {
    const entry = {cancelled: false, stream: null, attempt};
    this.entries.set(kind, entry);
    this.clear(kind); this.status(kind, this.t('connecting'));
    const config = this.config;
    const opening = (async () => {
      try {
        if (!this.api?.audio?.openStream) throw Error(this.t('streamUnavailable'));
        if (!config.source) throw Error(this.t('singleTrack'));
        if (kind === 'meter' && !this.api.audio.decodeMeter) throw Error(this.t('meterUnavailable'));
        const options = {source: config.source, fftSize: config.fftSize, updateRate: config.streamRate};
        if (config.aggregate) options.aggregate = true;
        if (kind === 'meter') Object.assign(options, {
          forceMono: config.forceMono === true, integratedMode: config.integratedMode || 'playback-only',
          resetOnPlaybackStart: config.resetOnPlaybackStart !== false,
        });
        const stream = await this.api.audio.openStream(kind, options);
        if (entry.cancelled || this.closed) { await stream.close(); return; }
        entry.stream = stream;
        const stopped = error => {
          if (entry.cancelled) return;
          this.failed(kind, entry, {code: error?.code, message: `${this.t('analysisUnavailable')} · ${error?.code || ''}`});
        };
        this.status(kind, this.t('waitingAudio'));
        stream.on('error', stopped); stream.on('close', stopped);
      } catch (error) { this.failed(kind, entry, error); }
    })().finally(() => this.pending.delete(opening));
    this.pending.add(opening);
  }
  async resetMeter() {
    const entry = this.entries.get('meter');
    if (!entry || entry.resetting || !this.enabled('meter')) return;
    if (entry.failed || entry.stream?.closed) {
      this.detach('meter', entry); this.open('meter'); return;
    }
    if (!entry.stream) return;
    entry.resetting = true; entry.resetError = false;
    const button = this.root.querySelector('#meter-reset');
    if (button) button.disabled = true;
    // The RPC queues a native reset. Only a subsequent packet may update the display.
    entry.resetPacket = entry.stream.latest();
    try {
      if (!this.api.audio.resetMeter) throw Error(this.t('meterUnavailable'));
      await this.api.audio.resetMeter(entry.stream.info.name);
    } catch (error) {
      entry.resetPacket = null;
      if (!entry.cancelled) { entry.resetError = true; this.status('meter', error.message || this.t('analysisUnavailable')); }
    } finally {
      entry.resetting = false;
      if (button) button.disabled = false;
    }
  }
  draw(now) {
    this.frame = 0;
    if (this.closed || !this.config?.active) return;
    if (now - this.lastDraw >= 1000 / this.config.drawRate) {
      this.lastDraw = now;
      for (const [kind, entry] of this.entries) {
        if (!this.enabled(kind) || entry.failed || !entry.stream || entry.stream.closed) continue;
        const packet = entry.stream.latest();
        if (!packet) continue;
        const info = entry.stream.info, data = packet.data;
        if (!(data instanceof Float32Array) || !info.channels) continue;
        if (kind === 'meter') {
          if (entry.resetting || entry.resetPacket && (packet === entry.resetPacket || packet.sequence !== undefined && packet.sequence === entry.resetPacket.sequence)) continue;
          if (packet === entry.lastPacket || packet.sequence !== undefined && packet.sequence === entry.lastPacket?.sequence) continue;
          try {
            const values = this.api.audio.decodeMeter(data, info.channels);
            entry.lastPacket = packet; entry.resetPacket = null; entry.attempt = 0;
            if (!entry.resetError) this.status(kind, '');
            this.meter(info.channels, values);
          } catch (error) {
            this.failed(kind, entry, {message: this.t('meterUnavailable')});
          }
        } else this.status(kind, '');
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
    }
    this.frame = requestAnimationFrame(this.draw);
  }
  meter(channels, values) {
    if (!this.meterView || this.meterView.channels !== channels) {
      this.meterView = new NativeMeterView(this.root.querySelector('#analysis-meter .readout'), channels, this.config, this.t);
    }
    this.meterView.update(values);
  }
  spectrum(info, data) {
    const canvas = this.root.querySelector('#analysis-spectrum canvas');
    const {ctx, width, height, accent, line} = canvasContext(canvas);
    const count = Math.floor(data.length / info.channels), ceiling = Math.min(20000, info.sampleRate / 2);
    const binHz = info.binHz || info.sampleRate / info.fftSize;
    if (!Number.isFinite(binHz) || ceiling <= 20) return;
    if (!this.spectrumAxis || this.spectrumAxis.width !== canvas.clientWidth || this.spectrumAxis.ceiling !== ceiling) {
      const axis = this.root.querySelector('#analysis-spectrum .axis');
      ctx.font = getComputedStyle(axis).font;
      const ticks = spectrumTicks(canvas.clientWidth, ceiling, text => ctx.measureText(text).width);
      axis.replaceChildren(...ticks.map(tick => {
        const label = document.createElement('span'); label.textContent = tick.label;
        label.style.left = `${tick.position * 100}%`; return label;
      }));
      this.spectrumAxis = {width:canvas.clientWidth, ceiling, ticks};
    }
    ctx.strokeStyle = line; ctx.lineWidth = 1;
    for (let i = 1; i < 4; i++) { ctx.beginPath(); ctx.moveTo(0, height * i / 4); ctx.lineTo(width, height * i / 4); ctx.stroke(); }
    for (const tick of this.spectrumAxis.ticks) {
      const x = tick.position * width;
      ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke();
    }
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
  restart(target) {
    for (const [kind, entry] of this.entries) if (!target || kind === target) this.detach(kind, entry);
    this.configure(this.config);
  }
  async close() {
    this.closed = true; cancelAnimationFrame(this.frame); this.frame = 0;
    for (const [kind, entry] of this.entries) this.detach(kind, entry);
    await Promise.allSettled([...this.pending]);
  }
}
