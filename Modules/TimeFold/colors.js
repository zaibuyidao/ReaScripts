const palette = ['#589bd5', '#df914d', '#8d79cc', '#63b899', '#d76f86', '#b3ba5b', '#58b7c6', '#bd8970'];
const defaultAutoPalette = [250, 25, 160, 295, 70, 205, 340, 115].map(hue => oklchColor(0.7, 0.11, hue));
const modes = ['project', 'timefold', 'auto'];
const visibilityModes = ['show', 'dim', 'hide'];
const validColor = value => typeof value === 'string' && /^#[\da-f]{6}$/i.test(value);
const validName = value => typeof value === 'string' && value.trim().length > 0 && value.length <= 128;
const nameKey = value => value.trim().toLowerCase();
const builtinFolders = [
  ['Dialogue', 'Foley', 'Ambience', 'Music', 'SFX', 'UI'],
  ['Dialogue', 'Foley', 'Ambience', 'Music', 'SFX'],
  ['Weapons', 'UI', 'Ambience', 'Music', 'Dialogue', 'Foley'],
  ['Drums', 'Bass', 'Guitar', 'Keys', 'Vocals', 'Strings'],
  []
];
const builtinIds = ['default', 'film', 'game', 'music', 'custom'];

export function defaultColorSettings() {
  return { mode: 'project', autoPalette: [...defaultAutoPalette], activePreset: 'default', presets: builtinIds.map((id, index) => ({
    id, name: '', folders: builtinFolders[index].map((name, i) => ({ id: `${id}-${i}`, name, color: palette[i % palette.length] }))
  })) };
}

export function normalizeColorSettings(saved) {
  const result = defaultColorSettings();
  if (modes.includes(saved?.mode)) result.mode = saved.mode;
  if (Array.isArray(saved?.autoPalette)) result.autoPalette = defaultAutoPalette.map((color, index) => validColor(saved.autoPalette[index]) ? saved.autoPalette[index].toLowerCase() : color);
  if (Array.isArray(saved?.presets)) {
    const ids = new Set();
    const presets = saved.presets.filter(preset => {
      if (!preset || typeof preset.id !== 'string' || !preset.id || ids.has(preset.id) ||
          !(validName(preset.name) || builtinIds.includes(preset.id) && preset.name === '') || !Array.isArray(preset.folders)) return false;
      const folderIds = new Set(), names = new Set();
      for (const folder of preset.folders) {
        if (!folder || typeof folder.id !== 'string' || !folder.id || folderIds.has(folder.id) ||
            !validName(folder.name) || names.has(nameKey(folder.name)) || !validColor(folder.color)) return false;
        folderIds.add(folder.id); names.add(nameKey(folder.name));
      }
      ids.add(preset.id); return true;
    }).map(preset => ({ id: preset.id, name: preset.name, folders: preset.folders.map(folder => ({ id: folder.id, name: folder.name, color: folder.color })) }));
    result.presets = [...result.presets.map(preset => presets.find(saved => saved.id === preset.id) || preset), ...presets.filter(preset => !builtinIds.includes(preset.id))];
  }
  if (result.presets.some(preset => preset.id === saved?.activePreset)) result.activePreset = saved.activePreset;
  return result;
}

export function canDeletePreset(id) { return !builtinIds.includes(id); }

export function updateColorSettings(settings, action, value) {
  if (action === 'color-mode' && modes.includes(value)) return { ...settings, mode: value };
  if (action === 'auto-palette-color' && Number.isInteger(value?.index) && value.index >= 0 && value.index < 8 && validColor(value.color)) {
    return { ...settings, autoPalette: (settings.autoPalette || defaultAutoPalette).map((color, index) => index === value.index ? value.color.toLowerCase() : color) };
  }
  if (action === 'auto-palette-reset') return { ...settings, autoPalette: [...defaultAutoPalette] };
  if (action === 'preset-select' && settings.presets.some(preset => preset.id === value)) return { ...settings, activePreset: value };
  const preset = settings.presets.find(preset => preset.id === value?.presetId);
  if (action === 'preset-add' || action === 'preset-copy' && preset) {
    if (!validName(value?.name)) return settings;
    let number = 1;
    while (settings.presets.some(preset => preset.id === `user-${number}`)) number++;
    const id = `user-${number}`;
    const added = { id, name: value.name.trim(), folders: action === 'preset-copy' ? preset.folders.map(folder => ({ ...folder })) : [] };
    return { ...settings, activePreset: id, presets: [...settings.presets, added] };
  }
  if (!preset) return settings;
  if (action === 'preset-delete' && canDeletePreset(preset.id)) {
    return { ...settings, activePreset: settings.activePreset === preset.id ? 'default' : settings.activePreset, presets: settings.presets.filter(entry => entry !== preset) };
  }
  let updated = preset;
  if (action === 'preset-rename' && validName(value.name)) updated = { ...preset, name: value.name.trim() };
  if (action === 'folder-add' && validName(value.name) && validColor(value.color) && !preset.folders.some(folder => nameKey(folder.name) === nameKey(value.name))) {
    let number = 1;
    while (preset.folders.some(folder => folder.id === `folder-${number}`)) number++;
    updated = { ...preset, folders: [...preset.folders, { id: `folder-${number}`, name: value.name.trim(), color: value.color }] };
  }
  if (action === 'folder-delete') updated = { ...preset, folders: preset.folders.filter(folder => folder.id !== value.folderId) };
  if (action === 'folder-update') {
    const folder = preset.folders.find(folder => folder.id === value.folderId);
    if (folder && (value.name === undefined || validName(value.name) && !preset.folders.some(other => other !== folder && nameKey(other.name) === nameKey(value.name))) &&
        (value.color === undefined || validColor(value.color))) {
      updated = { ...preset, folders: preset.folders.map(entry => entry === folder ? { ...folder, name: value.name?.trim() ?? folder.name, color: value.color ?? folder.color } : entry) };
    }
  }
  return updated === preset ? settings : { ...settings, presets: settings.presets.map(entry => entry === preset ? updated : entry) };
}

export function normalizeVisibility(prefs) {
  return Object.fromEntries([['tcpHiddenTracks', 'showTCPHiddenTracks'], ['mutedTracks', 'showMutedTracks'], ['mutedItems', 'showMutedItems']].map(([key, legacy]) => [key,
    visibilityModes.includes(prefs?.visibility?.[key]) ? prefs.visibility[key] : prefs?.[legacy] === false ? 'hide' : 'show'
  ]));
}

export function trackVisibility(track, visibility) {
  const states = [track.visible === false ? visibility.tcpHiddenTracks : 'show', track.muted ? visibility.mutedTracks : 'show'];
  return states.includes('hide') ? 'hide' : states.includes('dim') ? 'dim' : 'show';
}

function colorToOklch(color) {
  const [r, g, b] = color.slice(1).match(/../g).map(value => parseInt(value, 16) / 255)
    .map(value => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4);
  const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  const lightness = 0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s;
  const a = 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s;
  const labB = 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s;
  const chroma = Math.hypot(a, labB);
  return [Math.max(0, Math.min(1, lightness)), chroma < 0.000001 ? 0 : chroma, Math.atan2(labB, a) * 180 / Math.PI];
}

function oklchColor(lightness, chroma, hue) {
  const angle = hue * Math.PI / 180;
  const convert = value => {
    const a = value * Math.cos(angle), b = value * Math.sin(angle);
    const l = (lightness + 0.3963377774 * a + 0.2158037573 * b) ** 3;
    const m = (lightness - 0.1055613458 * a - 0.0638541728 * b) ** 3;
    const s = (lightness - 0.0894841775 * a - 1.2914855480 * b) ** 3;
    return [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
      -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s];
  };
  const inGamut = channels => channels.every(value => value >= -0.0000001 && value <= 1.0000001);
  let channels = convert(chroma);
  if (!inGamut(channels)) {
    let low = 0, high = chroma;
    for (let i = 0; i < 20; i++) {
      const mid = (low + high) / 2;
      if (inGamut(convert(mid))) low = mid; else high = mid;
    }
    channels = convert(low);
  }
  return '#' + channels.map(channel => {
    const value = channel <= 0.0031308 ? channel * 12.92 : 1.055 * channel ** (1 / 2.4) - 0.055;
    return Math.round(Math.max(0, Math.min(1, value)) * 255).toString(16).padStart(2, '0');
  }).join('');
}

function autoColorTracks(tracks, settings) {
  const autoPalette = (settings.autoPalette || defaultAutoPalette).map(color => {
    const [lightness, chroma, hue] = colorToOklch(color);
    return [color, ...[1, 2, 3].map(depth => oklchColor(Math.min(1, lightness + depth * 0.02), Math.max(0, chroma - depth * 0.012), hue))];
  });
  let depth = 0, folderIndex = 0, family = null;
  return tracks.map(track => {
    const delta = Number.isInteger(track.folderDepth) ? track.folderDepth : 0;
    if (depth === 0) family = delta > 0 ? autoPalette[folderIndex++ % autoPalette.length] : null;
    const displayColor = family ? family[Math.min(depth, 3)] : null;
    depth = Math.max(0, depth + delta);
    return { ...track, displayColor };
  });
}

function shade(color, index) {
  if (!index) return color;
  const amount = [0.16, -0.16, 0.08, -0.08][(index - 1) % 4];
  return '#' + color.slice(1).match(/../g).map(value => {
    const channel = parseInt(value, 16);
    return Math.round(channel + (amount > 0 ? 255 - channel : channel) * amount).toString(16).padStart(2, '0');
  }).join('');
}

export function colorTracks(tracks, settings) {
  if (settings.mode === 'project') return tracks;
  if (settings.mode === 'auto') return autoColorTracks(tracks, settings);
  const preset = settings.presets.find(preset => preset.id === settings.activePreset);
  const folders = new Map((preset?.folders || []).map(folder => [nameKey(folder.name), folder.color]));
  let depth = 0, parentColor = null, child = 0;
  return tracks.map(track => {
    const delta = Number.isInteger(track.folderDepth) ? track.folderDepth : 0;
    if (depth === 0) {
      parentColor = null; child = 0;
      if (delta > 0) parentColor = folders.get(nameKey(track.name || '')) || null;
    }
    const displayColor = parentColor ? shade(parentColor, child++) : null;
    depth = Math.max(0, depth + delta);
    return { ...track, displayColor };
  });
}

export function itemDisplayColor(item, track, settings, customEnabled, customColor, fallback) {
  if (settings.mode === 'project') return customEnabled && customColor && item.uncolored ? customColor : item.color || fallback;
  return track.displayColor || item.color || track.color || fallback;
}
