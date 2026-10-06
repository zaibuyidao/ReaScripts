import { toDb, dbText } from './model.js';

const floor = -80, ceiling = 6;
// Limit presentation only; native integration, history and clip counters stay intact.
export const meterDbText = value => Number.isFinite(value) && value < floor ? '<−80' : dbText(value);
const position = db => Number.isFinite(db) ? Math.max(0, Math.min(100, (db - floor) / (ceiling - floor) * 100)) : 0;
const node = (tag, className, text = '') => {
  const element = document.createElement(tag); element.className = className; element.textContent = text; return element;
};
const level = amplitude => meterDbText(toDb(amplitude));
const time = seconds => {
  if (!Number.isFinite(seconds)) return '—';
  const total = Math.max(0, Math.floor(seconds)), hours = Math.floor(total / 3600);
  return `${hours ? `${hours}:` : ''}${String(Math.floor(total / 60) % 60).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`;
};
export class NativeMeterView {
  constructor(root, channels, config, t) {
    this.channels = channels; this.t = t; this.strips = []; this.analysisStrips = []; this.root = root;
    root.replaceChildren(); root.style.minHeight = '';
    const sourceKey = config.source === 'master' ? 'meterOutput' : config.source === 'input' ? 'meterInput' : config.aggregate ? 'meterAggregate' : 'meterPreFX';
    this.sourceLabel = t(sourceKey);
    const source = this.source = node('span', 'meter-source');
    source.title = t(config.source === 'master' ? 'masterHint' : config.source === 'input' ? 'inputHint' : config.aggregate ? 'aggregateMeterHint' : 'preFXHint');
    this.clock = node('output', 'meter-time', '00:00'); this.clock.title = t('meterTime');
    const meta = node('div', 'meter-meta'), caption = node('span', 'meter-caption');
    const legend = node('span', 'meter-legend');
    for (const [key, label] of [['sample','Peak'],['rms','RMS'],['true','TP']]) {
      const item = node('span', `meter-legend-item meter-legend-${key}`);
      const keyLabel = node('span', `meter-key meter-key-${key}`, label); keyLabel.title = t(`meterLegend${key}`);
      item.append(keyLabel); legend.append(item);
    }
    caption.append(source, legend); meta.append(caption, this.clock); root.append(meta);
    const bank = node('div', 'meter-bank'), scale = node('div', 'meter-scale');
    scale.setAttribute('aria-hidden', 'true');
    for (const db of [6, 0, -6, -12, -24, -36, -48, -60, -80]) {
      const tick = node('span', db === 0 ? 'meter-zero' : '', db > 0 ? `+${db}` : String(db));
      tick.style.bottom = `${position(db)}%`; scale.append(tick);
    }
    const viewport = node('div', 'meter-viewport'); viewport.tabIndex = 0; viewport.setAttribute('aria-label', t('meterChannels'));
    const lanes = this.lanes = node('div', 'meter-lanes');
    for (let channel = 0; channel < channels; channel++) {
      const strip = node('div', 'meter-strip meter-history'); strip.dataset.channel = channel;
      const top = this.header('MAX', ''); top.root.title = t('maxSamplePeak');
      const rail = node('div', 'meter-rail');
      const peak = node('span', 'meter-fill meter-sample'), rms = node('span', 'meter-fill meter-rms');
      const truePeak = node('span', 'meter-marker meter-true'), max = node('span', 'meter-marker meter-max');
      rail.append(peak, rms, max, truePeak);
      const out = node('output', 'meter-channel-value', '−∞');
      const label = node('span', 'meter-channel-label', `Peak ${channel + 1}`);
      strip.append(top.root, rail, label, out); lanes.append(strip);
      this.strips.push({strip, peak, rms, truePeak, max, out, top});
    }
    for (const [key, group, suffix, history] of [
      ['rmsMomentary', 'RMS', 'M', 'maxRmsMomentary'], ['rmsIntegrated', 'RMS', 'I'],
      ['lufsMomentary', 'LUFS', 'M', 'maxLufsMomentary'], ['lufsShortTerm', 'LUFS', 'S', 'maxLufsShortTerm'], ['lufsIntegrated', 'LUFS', 'I'],
      ['loudnessRange', 'LRA', 'LU'],
    ]) {
      const range = key === 'loudnessRange', family = group === 'RMS' ? 'rms' : 'lufs';
      const strip = node('div', `meter-strip meter-analysis-strip meter-family-${family}${range ? ' meter-lra' : ''}${history ? ' meter-history' : ''}`);
      const top = this.header(range ? 'RANGE' : history ? 'MAX' : 'INT', range ? 'LU' : family === 'rms' ? 'dBFS' : 'LUFS');
      strip.dataset.metric = key; strip.title = t(key);
      const rail = node('div', 'meter-rail');
      const fill = node('span', 'meter-fill meter-analysis-fill'), max = node('span', 'meter-marker meter-max'); max.hidden = true;
      rail.append(fill, max);
      const out = node('output', 'meter-channel-value', '−∞');
      const label = node('span', 'meter-channel-label', range ? 'LRA' : `${group}-${suffix}`);
      strip.append(top.root, rail, label, out); lanes.append(strip);
      this.analysisStrips.push({key, history, family, range, strip, fill, max, out, top});
    }
    viewport.append(lanes); bank.append(scale, viewport); root.append(bank);

    this.setVisibility(config);
  }
  header(label, unit) {
    const root = node('div', 'meter-top');
    const value = node('output', 'meter-top-value', '—'), detail = node('span', 'meter-top-detail', unit);
    root.append(value, detail);
    return {root, value, detail, label};
  }
  setVisibility(config) {
    this.root.classList.toggle('meter-compact', config.meterCompact === true);
    const rms = config.meterShowRms === true, lufs = config.meterShowLufs !== false;
    const outputs = config.source === 'master' && Array.isArray(config.meterOutputs) ? new Set(config.meterOutputs) : null;
    let visible = 0;
    for (const item of this.analysisStrips) item.strip.hidden = !(item.family === 'rms' ? rms : lufs) || config.meterMetrics?.[item.key] === false;
    this.strips.forEach((item, channel) => {
      item.strip.hidden = outputs !== null && !outputs.has(channel);
      item.rms.hidden = !rms;
      if (!item.strip.hidden) visible++;
    });
    this.source.textContent = `${this.sourceLabel} · ${visible} CH${config.forceMono ? ' · MONO' : ''}`;
    this.root.querySelector('.meter-legend-rms').hidden = !rms;
    this.lanes.style.setProperty('--channels', Math.max(1, visible + this.analysisStrips.filter(item => !item.strip.hidden).length));
  }
  update(values) {
    this.clock.textContent = time(values.processedSeconds);
    this.strips.forEach((strip, c) => {
      const sample = toDb(values.samplePeak[c]), rms = toDb(values.channelRms[c]), tp = toDb(values.truePeak[c]);
      strip.peak.style.setProperty('--meter-level', `${position(sample)}%`); strip.rms.style.setProperty('--meter-level', `${position(rms)}%`);
      strip.truePeak.style.setProperty('--meter-offset', `${position(tp)}%`); strip.truePeak.hidden = !Number.isFinite(tp);
      const max = toDb(values.channelMaxSamplePeak[c]);
      strip.max.style.setProperty('--meter-offset', `${position(max)}%`); strip.max.hidden = !Number.isFinite(max);
      strip.top.value.textContent = meterDbText(max);
      const trueClipped = values.truePeakClipCount[c] > 0n || values.channelMaxTruePeak[c] > 1;
      const clipped = values.sampleClipCount[c] > 0n || max > 0 || trueClipped;
      strip.strip.classList.toggle('meter-clipped', clipped);
      strip.top.value.classList.toggle('meter-over', clipped);
      strip.top.detail.textContent = `TP ${level(values.channelMaxTruePeak[c])}`;
      strip.top.detail.classList.toggle('meter-over', trueClipped);
      strip.top.detail.title = `${this.t('maxTruePeak')} · ${level(values.channelMaxTruePeak[c])}`;
      strip.out.textContent = meterDbText(sample);
      strip.out.classList.toggle('meter-over', sample > 0);
      const counts = `Clip ${values.sampleClipCount[c]} · TP clip ${values.truePeakClipCount[c]}`;
      strip.strip.title = `CH ${c + 1} · Peak ${meterDbText(sample)} dBFS · TP ${meterDbText(tp)} dBTP · RMS ${meterDbText(rms)} dBFS\nMax ${meterDbText(max)} dBFS · TP max ${level(values.channelMaxTruePeak[c])} dBTP\n${counts}`;
    });
    for (const strip of this.analysisStrips) {
      // RMS and loudness arrive in dBFS/LUFS already. Preserve native window and
      // integration timing; no synthetic animation or second amplitude conversion.
      const value = values[strip.key], max = values[strip.history];
      if (strip.range) {
        // LRA is a span in LU, positioned between its native LUFS bounds.
        // It must not be plotted as an absolute dBFS level from zero.
        const low = position(values.loudnessRangeLow), high = position(values.loudnessRangeHigh);
        strip.fill.style.setProperty('--meter-offset', `${low}%`); strip.fill.style.setProperty('--meter-level', `${Math.max(0, high - low)}%`);
        strip.fill.hidden = high <= low;
        strip.strip.title = `${this.t(strip.key)} · ${dbText(value)} LU · ${meterDbText(values.loudnessRangeLow)} / ${meterDbText(values.loudnessRangeHigh)} LUFS`;
      } else {
        strip.fill.style.setProperty('--meter-level', `${position(value)}%`);
        strip.strip.title = `${this.t(strip.key)} · ${meterDbText(value)}`;
      }
      const format = strip.range ? dbText : meterDbText;
      strip.top.value.textContent = format(strip.history ? max : value);
      strip.top.root.title = `${strip.top.label} · ${strip.strip.title}${strip.history ? ` · ${meterDbText(max)}` : ''}`;
      strip.out.textContent = format(value);
      strip.max.hidden = !Number.isFinite(max); strip.max.style.setProperty('--meter-offset', `${position(max)}%`);
    }
  }
}
