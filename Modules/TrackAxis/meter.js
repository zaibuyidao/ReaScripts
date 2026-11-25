import { analysisSources, defaults, toDb, dbText } from './model.js';

const floor = -72, scalePower = 1.8;
const fullScale = [0, -3, -6, -12, -18, -24, -30, -36, -42, -48, -60, floor];
const extraTicks = new Set([-3, -18, -30, -42, -60]);
const peakHalfLife = 150, loudnessHalfLife = 75;
const histogramFloor = -70, histogramBins = 75;
const svgNamespace = 'http://www.w3.org/2000/svg';
// Limit presentation only; native integration, history and clip counters stay intact.
export const meterDbText = value => Number.isFinite(value) && value > floor ? `${value >= 0 ? '+' : ''}${dbText(value)}` : '';
const position = db => Number.isFinite(db) && db > floor ? Math.min(1, (db - floor) / -floor) ** scalePower * 100 : 0;
// Additional ticks need room on both sides of their label.
const scaleTicks = fullScale.map((db, index) => ({
  db,
  minHeight: extraTicks.has(db) ? 24 * 100 / Math.min(
    position(fullScale[index - 1]) - position(db), position(db) - position(fullScale[index + 1])) : 0,
}));
const gridStops = ticks => [...ticks].reverse().flatMap(db => {
  if (db === floor) return ['var(--meter-grid-line) 0 1px', 'transparent 1px'];
  if (db === 0) return ['transparent calc(100% - 1px)', 'var(--meter-grid-line) calc(100% - 1px) 100%'];
  const start = `calc(${position(db)}% - 0.5px)`, end = `calc(${position(db)}% + 0.5px)`;
  return [`transparent ${start}`, `var(--meter-grid-line) ${start} ${end}`, `transparent ${end}`];
}).join(', ');
const node = (tag, className, text = '') => {
  const element = document.createElement(tag); element.className = className; element.textContent = text; return element;
};
const time = seconds => {
  if (!Number.isFinite(seconds)) return '—';
  const total = Math.max(0, Math.floor(seconds)), hours = Math.floor(total / 3600);
  return `${hours ? `${hours}:` : ''}${String(Math.floor(total / 60) % 60).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`;
};
export class NativeMeterView {
  constructor(root, channels, config, t) {
    this.language = config.language; this.t = t; this.strips = []; this.analysisStrips = []; this.root = root;
    this.histogramCounts = new Float64Array(histogramBins);
    this.histogramStep = 0;
    root.replaceChildren();
    const source = this.source = node('span', 'meter-source');
    this.clock = node('output', 'meter-time', '00:00'); this.clock.title = t('meterTime');
    const meta = node('div', 'meter-meta'), caption = node('span', 'meter-caption');
    const legend = this.legend = node('span', 'meter-legend');
    for (const [key, label] of [['sample','Peak'],['rms','RMS'],['true','TP']]) {
      const item = node('span', `meter-legend-item meter-legend-${key}`);
      const keyLabel = node('span', `meter-key meter-key-${key}`, label); keyLabel.title = t(`meterLegend${key}`);
      item.append(keyLabel); legend.append(item);
    }
    caption.append(source, legend); meta.append(caption, this.clock); root.append(meta);
    const bank = this.bank = node('div', 'meter-bank'), scale = this.scale = node('div', 'meter-scale');
    scale.setAttribute('aria-hidden', 'true');
    this.setScaleHeight(config.meterHeight ?? defaults.meterHeight);
    const viewport = node('div', 'meter-viewport'); viewport.tabIndex = 0; viewport.setAttribute('aria-label', t('meterChannels'));
    const lanes = this.lanes = node('div', 'meter-lanes');
    for (const [key, group, suffix, history] of [
      ['rmsMomentary', 'RMS', 'M', 'maxRmsMomentary'], ['rmsIntegrated', 'RMS', 'I'],
      ['lufsMomentary', 'LUFS', 'M', 'maxLufsMomentary'], ['lufsShortTerm', 'LUFS', 'S', 'maxLufsShortTerm'],
      ['loudnessRange', 'LRA', 'LU'], ['lufsIntegrated', 'LUFS', 'I'],
    ]) {
      const range = key === 'loudnessRange', family = group === 'RMS' ? 'rms' : 'lufs';
      const strip = node('div', `meter-strip meter-analysis-strip meter-family-${family}${range ? ' meter-lra' : ''}${history ? ' meter-history' : ''}`);
      const top = this.header(range ? 'RANGE' : history ? 'MAX' : 'INT', range ? 'LU' : family === 'rms' ? 'dBFS' : 'LUFS');
      strip.dataset.metric = key; strip.title = t(key);
      const rail = node('div', 'meter-rail');
      const fill = node('span', 'meter-fill meter-analysis-fill'), max = node('span', 'meter-marker meter-max'); max.hidden = true;
      rail.append(fill, max);
      if (key === 'lufsMomentary') {
        const graph = this.histogram = document.createElementNS(svgNamespace, 'svg');
        this.histogramPath = document.createElementNS(svgNamespace, 'path');
        this.histogramMirror = document.createElementNS(svgNamespace, 'path');
        graph.setAttribute('class', 'meter-histogram');
        graph.setAttribute('viewBox', '0 0 100 100');
        graph.setAttribute('preserveAspectRatio', 'none');
        graph.setAttribute('role', 'img');
        graph.setAttribute('aria-label', t('meterLufsHistogram'));
        graph.append(this.histogramPath, this.histogramMirror);
        rail.append(graph);
      }
      const out = node('output', 'meter-channel-value');
      const label = node('span', 'meter-channel-label', range ? 'LRA' : `${group}-${suffix}`);
      strip.append(top.root, rail, label, out); lanes.append(strip);
      this.analysisStrips.push({key, history, family, range, strip, fill, max, out, top, displayed: 0, target: 0});
    }
    viewport.append(lanes); bank.append(scale, viewport); root.append(bank);

    this.setChannels(channels);
    this.setVisibility(config);
  }
  setScaleHeight(height) {
    const ticks = scaleTicks.filter(tick => height >= tick.minHeight).map(tick => tick.db);
    if (ticks.length === this.scale.childElementCount) return;
    this.scale.replaceChildren(...ticks.map(db => {
      const tick = node('span', db === 0 ? 'meter-zero' : '', String(db));
      tick.style.bottom = `${position(db)}%`;
      return tick;
    }));
    this.root.style.setProperty('--meter-grid-stops', gridStops(ticks));
  }
  get channels() { return this.strips.length; }
  setChannels(channels) {
    while (this.strips.length > channels) this.strips.pop().strip.remove();
    for (let channel = this.strips.length; channel < channels; channel++) {
      const strip = node('div', 'meter-strip meter-history'); strip.dataset.channel = channel;
      const top = this.header('MAX', ''); top.root.title = this.t('maxSamplePeak');
      const rail = node('div', 'meter-rail');
      const peak = node('span', 'meter-fill meter-sample'), rms = node('span', 'meter-fill meter-rms');
      const max = node('span', 'meter-marker meter-max');
      rail.append(peak, rms, max);
      const out = node('output', 'meter-channel-value');
      const label = node('span', 'meter-channel-label', `Peak ${channel + 1}`);
      strip.append(top.root, rail, label, out); this.lanes.insertBefore(strip, this.analysisStrips[0].strip);
      this.strips.push({strip, peak, rms, max, out, top, label, sample: 0, truePeak: 0});
    }
  }
  reset(now = performance.now()) {
    this.values = null;
    this.lastFrame = undefined;
    this.histogramStep = 0;
    this.histogramCounts.fill(0);
    this.histogramPath.removeAttribute('d');
    this.histogramMirror.removeAttribute('d');
    for (const strip of this.strips) strip.sample = strip.truePeak = 0;
    for (const strip of this.analysisStrips) strip.displayed = strip.target = 0;
    const zero = Array(this.strips.length).fill(0);
    this.update({processedSeconds: 0, samplePeak: zero, channelRms: zero, truePeak: zero,
      channelMaxSamplePeak: zero, channelMaxTruePeak: zero, sampleClipCount: zero, truePeakClipCount: zero}, now, false);
  }
  header(label, unit) {
    const root = node('div', 'meter-top');
    const value = node('output', 'meter-top-value'), detail = node('span', 'meter-top-detail', unit);
    root.append(value, detail);
    return {root, value, detail, label};
  }
  setVisibility(config) {
    const compact = config.meterCompact === true, histogram = config.meterLufsHistogram !== false;
    this.root.classList.toggle('meter-compact', compact);
    this.root.classList.toggle('meter-show-histogram', histogram);
    this.histogram.style.display = histogram ? '' : 'none';
    this.histogramPath.setAttribute('transform', compact ? 'matrix(0 -.25 -1 0 100 25)' : 'matrix(.24 0 0 1 76 0)');
    this.histogramMirror.setAttribute('transform', compact ? 'matrix(0 .25 -1 0 100 75)' : 'matrix(-.24 0 0 1 24 0)');
    this.config = config;
    this.peakMode = config.meterPeakMode ?? 'peak';
    this.truePeakMode = this.peakMode.startsWith('true-');
    this.clipMode = this.peakMode.endsWith('-clips');
    const showPeaks = this.peakMode !== 'off';
    const rms = config.meterMetrics.rmsMomentary;
    const outputs = config.source === 'master' && Array.isArray(config.meterOutputs) ? new Set(config.meterOutputs) : null;
    let visible = 0;
    for (const item of this.analysisStrips) item.strip.hidden = !config.meterMetrics[item.key];
    this.strips.forEach((item, channel) => {
      const available = outputs === null || outputs.has(channel);
      item.strip.hidden = !showPeaks || !available;
      item.rms.hidden = !rms;
      item.top.detail.hidden = compact && this.truePeakMode;
      item.label.textContent = `${this.truePeakMode ? 'TP' : 'Peak'} ${channel + 1}`;
      if (available) visible++;
    });
    const mode = analysisSources[config.sourceMode];
    this.source.title = this.t(config.aggregate ? 'aggregateMeterHint' : mode.hint);
    const sourceLabel = this.t(config.aggregate ? 'meterAggregate' : mode.meter);
    this.source.textContent = `${sourceLabel} · ${visible} CH${config.forceMono ? ' · MONO' : ''}`;
    this.legend.querySelector('.meter-legend-sample').hidden = !showPeaks || this.truePeakMode;
    this.legend.querySelector('.meter-legend-true').hidden = !showPeaks || !this.truePeakMode;
    this.legend.querySelector('.meter-legend-rms').hidden = !showPeaks || !rms;
    this.legend.hidden = !showPeaks;
    const peakStrips = showPeaks ? visible : 0;
    const analysisStrips = this.analysisStrips.filter(item => !item.strip.hidden).length;
    const visibleStrips = peakStrips + analysisStrips;
    this.bank.hidden = visibleStrips === 0;
    this.lanes.style.setProperty('--channels', Math.max(1, visibleStrips));
    this.root.style.setProperty('--meter-compact-rows', Math.min(2, peakStrips) + analysisStrips);
    if (histogram) this.paintHistogram();
    if (this.values) {
      this.updatePeakReadouts(this.values);
      this.updateAnalysisReadouts(this.values);
      this.paintLevels();
    }
  }
  update(values, now, collectHistogram, sampleRate) {
    const previous = this.values;
    if (previous && (values.processedSeconds < previous.processedSeconds ||
      values.channelMaxSamplePeak.some((peak, channel) => peak < previous.channelMaxSamplePeak[channel]) ||
      values.channelMaxTruePeak.some((peak, channel) => peak < previous.channelMaxTruePeak[channel]) ||
      values.sampleClipCount.some((count, channel) => count < previous.sampleClipCount[channel]) ||
      values.truePeakClipCount.some((count, channel) => count < previous.truePeakClipCount[channel]))) this.reset(now);
    this.advance(now);
    this.values = values;
    this.lastPeakPacket = this.lastFrame;
    this.clock.textContent = time(values.processedSeconds);
    this.strips.forEach((strip, channel) => {
      strip.sample = Math.max(strip.sample, values.samplePeak[channel]);
      strip.truePeak = Math.max(strip.truePeak, values.truePeak[channel]);
    });
    for (const strip of this.analysisStrips) strip.target = position(values[strip.key]);
    this.updatePeakReadouts(values);
    this.updateAnalysisReadouts(values);
    this.recordHistogram(values.processedSeconds, values.lufsMomentary, collectHistogram, sampleRate);
    this.paintLevels();
  }

  advance(now) {
    const elapsed = this.lastFrame === undefined ? 0 : Math.max(0, now - this.lastFrame);
    this.lastFrame = Math.max(now, this.lastFrame ?? now);
    if (!elapsed || !this.values) return;
    const decay = 0.5 ** (elapsed / peakHalfLife);
    // A packet's peak is the floor until the next packet arrives. Release that
    // floor as well if the source stops delivering audio.
    const hold = Math.max(80, 2000 / (this.config.streamRate || 30));
    const staleDecay = 0.5 ** (Math.max(0, now - this.lastPeakPacket - hold) / peakHalfLife);
    this.strips.forEach((strip, channel) => {
      strip.sample = Math.max(strip.sample * decay, this.values.samplePeak[channel] * staleDecay);
      strip.truePeak = Math.max(strip.truePeak * decay, this.values.truePeak[channel] * staleDecay);
      if (strip.sample < 1e-6) strip.sample = 0;
      if (strip.truePeak < 1e-6) strip.truePeak = 0;
    });
    const smoothing = 1 - 0.5 ** (elapsed / loudnessHalfLife);
    for (const strip of this.analysisStrips) {
      if (strip.range) continue;
      strip.displayed += (strip.target - strip.displayed) * smoothing;
      if (Math.abs(strip.target - strip.displayed) < 0.01) strip.displayed = strip.target;
    }
  }

  draw(now) {
    if (!this.values) return;
    this.advance(now);
    this.paintLevels();
  }

  paintLevels() {
    if (this.peakMode !== 'off') for (const strip of this.strips) {
      if (strip.strip.hidden) continue;
      const db = toDb(this.truePeakMode ? strip.truePeak : strip.sample);
      strip.peak.style.setProperty('--meter-level', `${position(db)}%`);
      if (!this.clipMode) {
        const text = meterDbText(db);
        if (strip.out.textContent !== text) strip.out.textContent = text;
        strip.out.classList.toggle('meter-over', db > 0);
      }
    }
    for (const strip of this.analysisStrips) {
      if (!strip.range && !strip.strip.hidden) strip.fill.style.setProperty('--meter-level', `${strip.displayed}%`);
    }
  }

  updatePeakReadouts(values) {
    if (this.peakMode === 'off') return;
    const maximum = this.truePeakMode ? values.channelMaxTruePeak : values.channelMaxSamplePeak;
    const counts = this.truePeakMode ? values.truePeakClipCount : values.sampleClipCount;
    const unit = this.truePeakMode ? 'dBTP' : 'dBFS';
    const maxLabel = this.t(this.truePeakMode ? 'maxTruePeak' : 'maxSamplePeak');
    this.strips.forEach((strip, channel) => {
      const rms = toDb(values.channelRms[channel]), max = toDb(maximum[channel]);
      const count = counts[channel], clipped = count > 0n || max > 0;
      strip.rms.style.setProperty('--meter-level', `${position(rms)}%`);
      strip.max.style.setProperty('--meter-offset', `${position(max)}%`);
      strip.max.hidden = !(max > floor);
      strip.top.value.textContent = meterDbText(max);
      strip.top.detail.textContent = unit;
      strip.top.root.title = maxLabel;
      strip.strip.classList.toggle('meter-clipped', clipped);
      strip.top.value.classList.toggle('meter-over', clipped);
      if (this.clipMode) {
        strip.out.textContent = count > 999n ? '>999' : count > 0n || maximum[channel] > 0 ? String(count) : '';
        strip.out.classList.toggle('meter-over', count > 0n);
      }
      strip.strip.title = `CH ${channel + 1} · ${maxLabel}\n${this.t('meterClips')} ${count} · RMS ${meterDbText(rms)} dBFS`;
    });
  }

  alert(value) {
    const config = this.config;
    if (config.meterRedAlert && value >= config.meterRedLevel) return 'red';
    if (config.meterYellowAlert && value >= config.meterYellowLevel) return 'yellow';
    return '';
  }

  updateAnalysisReadouts(values) {
    for (const strip of this.analysisStrips) {
      const value = values[strip.key], max = values[strip.history];
      if (strip.range) {
        // LRA is a span in LU, positioned between its native LUFS bounds.
        // It must not be plotted as an absolute dBFS level from zero.
        const low = position(values.loudnessRangeLow), high = position(values.loudnessRangeHigh);
        strip.fill.style.setProperty('--meter-offset', `${low}%`); strip.fill.style.setProperty('--meter-level', `${Math.max(0, high - low)}%`);
        strip.fill.hidden = high <= low;
        strip.strip.title = `${this.t(strip.key)} · ${dbText(value)} LU · ${meterDbText(values.loudnessRangeLow)} / ${meterDbText(values.loudnessRangeHigh)} LUFS`;
      } else {
        strip.strip.title = `${this.t(strip.key)} · ${meterDbText(value)}`;
        if (strip.family === 'lufs') {
          strip.fill.dataset.alert = strip.out.dataset.alert = this.alert(value);
          const topAlert = this.alert(strip.history ? max : value);
          strip.top.value.dataset.alert = strip.max.dataset.alert = topAlert;
        }
      }
      const format = strip.range ? amount => amount > 0 ? dbText(amount) : '' : meterDbText;
      strip.top.value.textContent = format(strip.history ? max : value);
      strip.top.root.title = `${strip.top.label} · ${strip.strip.title}${strip.history ? ` · ${meterDbText(max)}` : ''}`;
      strip.out.textContent = format(value);
      strip.max.hidden = !(max > floor); strip.max.style.setProperty('--meter-offset', `${position(max)}%`);
    }
  }

  recordHistogram(seconds, loudness, collect, sampleRate) {
    // The native analyzer publishes new momentary values on 100 ms boundaries.
    // Several stream packets can carry the same analysis step.
    const step = sampleRate > 0
      ? Math.floor(Math.round(seconds * sampleRate) / Math.max(1, Math.round(sampleRate / 10)))
      : Math.floor(seconds * 10 + 1e-4);
    if (step <= this.histogramStep) return;
    this.histogramStep = step;
    if (!collect || !Number.isFinite(loudness)) return;
    const uncorrected = loudness + (this.config.forceMono ? 3 : 0);
    const bin = Math.trunc((uncorrected - histogramFloor) * 10);
    if (bin < 0) return;
    this.histogramCounts[Math.min(histogramBins - 1, Math.floor(bin / 10))]++;
    if (this.config.meterLufsHistogram !== false) this.paintHistogram();
  }

  paintHistogram() {
    const max = Math.max(...this.histogramCounts);
    if (!max) return;
    const start = histogramFloor - (this.config.forceMono ? 3 : 0);
    const axisLength = (this.config.meterCompact ? this.histogram.clientWidth : this.histogram.clientHeight) || 100;
    const contour = ['M0 100'];
    let lastPixel = 0, count = 0;
    // Join consecutive widths and combine bins that map to the same pixel.
    for (let bin = 0; bin <= this.histogramCounts.length; bin++) {
      const pixel = Math.floor(position(start + bin - 0.5) * axisLength / 100);
      if (pixel > lastPixel) {
        const width = Math.min(1, count / max) * 100;
        contour.push(`L${width} ${100 - pixel / axisLength * 100}`);
        lastPixel = pixel;
        count = 0;
      }
      count += this.histogramCounts[bin] ?? 0;
    }
    const path = `${contour.join(' ')} H0Z`;
    this.histogramPath.setAttribute('d', path);
    this.histogramMirror.setAttribute('d', path);
  }
}
