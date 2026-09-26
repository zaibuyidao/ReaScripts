export const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

export function createTrackMap(tracks, height) {
  const pinned = tracks.filter(track => track.pinned), normal = tracks.filter(track => !track.pinned);
  const units = rows => rows.reduce((sum, row) => sum + 1 + (row.spacer ? 0.25 : 0), 0);
  const p = units(pinned), n = units(normal), separator = p && n ? Math.min(3, height * 0.01) : 0;
  const available = height - separator;
  const pinnedHeight = n ? Math.min(available * 0.4, Math.max(available * p / Math.max(1, p + n), Math.min(pinned.length * 6, available * 0.25))) : available;
  const rows = [], append = (group, start, size, total) => {
    let y = start;
    for (const track of group) {
      if (track.spacer) y += size / total * 0.25;
      const h = size / total;
      rows.push({ ...track, top: y, height: h }); y += h;
    }
  };
  if (p) append(pinned, 0, pinnedHeight, p);
  if (n) append(normal, p ? pinnedHeight + separator : 0, p ? available - pinnedHeight : height, n);
  return { rows, separator: separator ? pinnedHeight : null, height };
}

export function viewportBands(trackMap, geometry, scroll = geometry?.scroll ?? 0) {
  if (!geometry) return [];
  const native = new Map(geometry.rows.map(row => [row.id, row]));
  const pinnedBottom = geometry.rows.reduce((bottom, row) => row.pinned && row.visible && row.height > 0 ? Math.max(bottom, row.y + row.height) : bottom, 0);
  const boundary = clamp(Math.max(pinnedBottom, geometry.clientHeight - geometry.page), 0, geometry.clientHeight), bands = [];
  let previous = -2;
  for (let index = 0; index < trackMap.rows.length; index++) {
    const row = trackMap.rows[index], source = native.get(row.id);
    if (!source?.visible || source.height <= 0 || source.pinned !== row.pinned) continue;
    const y = source.y + (source.pinned ? 0 : geometry.scroll - scroll);
    const a = Math.max(y, source.pinned ? 0 : boundary), b = Math.min(y + source.height, source.pinned ? boundary : geometry.clientHeight);
    if (b <= a) continue;
    const top = row.top + (a - y) / source.height * row.height, bottom = row.top + (b - y) / source.height * row.height;
    const last = bands.at(-1);
    if (last && index === previous + 1 && last.pinned === row.pinned) last.bottom = bottom;
    else bands.push({ pinned: row.pinned, top, bottom });
    previous = index;
  }
  return bands;
}

export function nativeAtY(trackMap, geometry, y) {
  if (!geometry) return 0;
  const native = new Map(geometry.rows.map(row => [row.id, row]));
  const rows = trackMap.rows.filter(row => !row.pinned && native.get(row.id)?.height > 0 && native.get(row.id)?.visible);
  if (!rows.length) return geometry.scroll;
  const value = (row, end = false) => native.get(row.id).y + geometry.scroll + (end ? native.get(row.id).height : 0);
  if (y <= rows[0].top) return value(rows[0]);
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    if (y <= row.top + row.height) return value(row) + clamp((y - row.top) / row.height, 0, 1) * native.get(row.id).height;
    const next = rows[i + 1];
    if (next && y < next.top) return value(row, true) + (y - row.top - row.height) / (next.top - row.top - row.height) * (value(next) - value(row, true));
  }
  return value(rows.at(-1), true);
}

export function packLabels(rects, rows) {
  const ends = Array.from({ length: rows }, () => -Infinity);
  return rects.map(rect => {
    let lane = ends.findIndex(end => Math.abs(end - rect.left) <= 1e-7);
    if (lane < 0) lane = ends.findIndex(end => end <= rect.left + 1e-7);
    if (lane < 0) lane = ends.indexOf(Math.min(...ends));
    ends[lane] = rect.left + rect.width;
    return { ...rect, lane };
  });
}

export function labelContrast(color) {
  const rgb = color.slice(1).match(/../g).map(value => parseInt(value, 16) / 255).map(value => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4);
  return rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722 > 0.179 ? '#10151b' : '#ffffff';
}

export function zoomRange(view, anchor, delta, length) {
  const span = view.finish - view.start;
  anchor = clamp(anchor, view.start, view.finish);
  const ratio = span > 0 ? (anchor - view.start) / span : 0.5;
  const next = clamp(span * Math.exp(clamp(delta, -200, 200) * 0.003), 0.05, Math.max(60, length * 4));
  const start = Math.max(0, anchor - next * ratio);
  return { start, finish: start + next };
}

export function createTimeMap(length, width, labels) {
  length = Math.max(1, length);
  width = Math.max(1, width);
  const folds = [];
  for (const label of labels.filter(label => label.collapsed).sort((a, b) => a.start - b.start)) {
    const start = clamp(label.start, 0, length), finish = clamp(label.finish, 0, length);
    if (finish <= start) continue;
    const last = folds.at(-1);
    if (last && start <= last.finish) last.finish = Math.max(last.finish, finish);
    else folds.push({ start, finish });
  }
  const hidden = folds.reduce((sum, fold) => sum + fold.finish - fold.start, 0);
  const gap = folds.length ? Math.min(18, width * 0.65 / folds.length) : 0;
  const scale = (width - gap * folds.length) / Math.max(0.000001, length - hidden);
  const segments = [];
  let time = 0, x = 0;
  function add(finish, folded) {
    if (finish <= time) return;
    const nextX = x + (folded ? (hidden >= length ? width / folds.length : gap) : (finish - time) * scale);
    segments.push({ start: time, finish, left: x, right: nextX, folded });
    time = finish; x = nextX;
  }
  for (const fold of folds) { add(fold.start, false); add(fold.finish, true); }
  add(length, false);
  const lookup = (value, key) => {
    let lo = 0, hi = segments.length - 1;
    while (lo < hi) { const mid = (lo + hi) >> 1; if (value > segments[mid][key]) lo = mid + 1; else hi = mid; }
    return segments[lo];
  };
  return {
    segments, length, width,
    toX(value) {
      const time = clamp(value, 0, length), segment = lookup(time, 'finish');
      return segment.left + (time - segment.start) / (segment.finish - segment.start) * (segment.right - segment.left);
    },
    toTime(value) {
      const x = clamp(value, 0, width), segment = lookup(x, 'right');
      return segment.start + (x - segment.left) / (segment.right - segment.left) * (segment.finish - segment.start);
    },
    visible(start, finish) {
      const result = [];
      for (const segment of segments) {
        if (segment.start >= finish) break;
        if (segment.folded || segment.finish <= start) continue;
        const a = Math.max(start, segment.start), b = Math.min(finish, segment.finish);
        result.push([this.toX(a), this.toX(b)]);
      }
      return result;
    }
  };
}

export function interpolatedPosition(sample, now, clockOffset) {
  if (!sample) return 0;
  if (!(sample.playState & 1) || sample.playState & 2) return sample.position;
  const age = clamp(now - (sample.timestamp - clockOffset), 0, 180);
  let position = sample.position + age / 1000 * sample.rate;
  if (sample.repeatEnabled && sample.loopEnd > sample.loopStart && sample.position < sample.loopEnd && position >= sample.loopEnd) {
    position = sample.loopStart + (position - sample.loopStart) % (sample.loopEnd - sample.loopStart);
  }
  return position;
}
