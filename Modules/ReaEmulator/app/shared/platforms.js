// Local platform mapping; core names remain EmulatorJS aliases.
export const PLATFORMS = [
  { id: 'nes', name: 'Nintendo Entertainment System', short: 'NES / FC', core: 'nes', extensions: ['nes', 'fds', 'unf', 'unif'], aliases: ['fc', 'famicom'] },
  { id: 'snes', name: 'Super Nintendo', short: 'SNES / SFC', core: 'snes', extensions: ['sfc', 'smc', 'fig', 'swc'], aliases: ['sfc', 'superfamicom'] },
  { id: 'gb', name: 'Nintendo Game Boy', short: 'Game Boy', core: 'gb', extensions: ['gb'], aliases: ['gameboy'] },
  { id: 'gbc', name: 'Nintendo Game Boy Color', short: 'Game Boy Color', core: 'gb', extensions: ['gbc'], aliases: ['gameboycolor'] },
  { id: 'gba', name: 'Nintendo Game Boy Advance', short: 'Game Boy Advance', core: 'gba', extensions: ['gba'], aliases: ['gameboyadvance'] },
  { id: 'nds', name: 'Nintendo DS', short: 'Nintendo DS', core: 'nds', extensions: ['nds'], aliases: ['ds'] },
  { id: 'n64', name: 'Nintendo 64', short: 'Nintendo 64', core: 'n64', extensions: ['n64', 'z64', 'v64'], aliases: ['nintendo64'] },
  { id: 'psx', name: 'Sony PlayStation', short: 'PlayStation', core: 'psx', extensions: [], aliases: ['ps', 'ps1', 'playstation'] },
  { id: 'psp', name: 'Sony PlayStation Portable', short: 'PSP', core: 'ppsspp', extensions: ['pbp', 'cso'], aliases: ['ppsspp', 'playstationportable'] },
  { id: 'megadrive', name: 'Sega Mega Drive', short: 'Mega Drive', core: 'segaMD', extensions: ['md', 'smd', 'gen'], aliases: ['genesis', 'segamd', 'md'] },
  { id: 'mastersystem', name: 'Sega Master System', short: 'Master System', core: 'segaMS', extensions: ['sms'], aliases: ['segams', 'sms'] },
  { id: 'gamegear', name: 'Sega Game Gear', short: 'Game Gear', core: 'segaGG', extensions: ['gg'], aliases: ['segagg', 'gg'] },
  { id: 'sega32x', name: 'Sega 32X', short: 'Sega 32X', core: 'sega32x', extensions: ['32x'], aliases: ['32x'] },
  { id: 'segacd', name: 'Sega CD', short: 'Sega CD', core: 'segaCD', extensions: [], aliases: ['megacd'] },
  { id: 'saturn', name: 'Sega Saturn', short: 'Sega Saturn', core: 'segaSaturn', extensions: [], aliases: ['segasaturn', 'ss'] },
  { id: 'pce', name: 'NEC PC Engine', short: 'PC Engine', core: 'pce', extensions: ['pce', 'sgx'], aliases: ['pcengine', 'turbografx16', 'tg16'] },
  { id: 'pcfx', name: 'NEC PC-FX', short: 'PC-FX', core: 'pcfx', extensions: [], aliases: [] },
  { id: 'ngp', name: 'Neo Geo Pocket', short: 'Neo Geo Pocket', core: 'ngp', extensions: ['ngp', 'ngc'], aliases: ['neogeopocket', 'ngpc'] },
  { id: 'ws', name: 'Bandai WonderSwan', short: 'WonderSwan', core: 'ws', extensions: ['ws', 'wsc'], aliases: ['wonderswan', 'wonderswancolor'] },
  { id: 'vb', name: 'Nintendo Virtual Boy', short: 'Virtual Boy', core: 'vb', extensions: ['vb'], aliases: ['virtualboy'] },
  { id: 'lynx', name: 'Atari Lynx', short: 'Atari Lynx', core: 'lynx', extensions: ['lnx'], aliases: ['atarilynx'] },
  { id: 'atari2600', name: 'Atari 2600', short: 'Atari 2600', core: 'atari2600', extensions: ['a26'], aliases: ['2600'] },
  { id: 'atari7800', name: 'Atari 7800', short: 'Atari 7800', core: 'atari7800', extensions: ['a78'], aliases: ['7800'] },
  { id: 'jaguar', name: 'Atari Jaguar', short: 'Atari Jaguar', core: 'jaguar', extensions: ['j64', 'jag'], aliases: ['atarijaguar'] },
  { id: 'coleco', name: 'ColecoVision', short: 'ColecoVision', core: 'coleco', extensions: ['col', 'cv'], aliases: ['colecovision'] },
  { id: 'c64', name: 'Commodore 64', short: 'Commodore 64', core: 'vice_x64sc', extensions: ['d64', 't64', 'crt'], aliases: ['vice', 'commodore64'] },
  { id: 'arcade', name: 'Arcade', short: '街机', core: 'arcade', extensions: [], aliases: ['mame', 'fbneo', 'neogeo'] },
  { id: 'dos', name: 'MS-DOS', short: 'DOS', core: 'dosbox_pure', extensions: ['dosz'], aliases: ['dosbox', 'dosboxpure', 'msdos'] },
  { id: 'unknown', name: '未指定平台', short: '未分类', core: '', extensions: [], aliases: [] },
];

export const platformById = id => PLATFORMS.find(platform => platform.id === id) || PLATFORMS.at(-1);
export const extension = path => String(path).split(/[\\/]/).pop().split('.').pop().toLowerCase();
export const filename = path => String(path).replace(/\\/g, '/').split('/').pop();
export const parentPath = path => String(path).replace(/\\/g, '/').replace(/\/[^/]+\/?$/, '');
export const joinPath = (path, name) => path.replace(/[\\/]+$/, '') + '/' + name;
export function pathKey(path) {
  let value = String(path).replace(/\\/g, '/').replace(/\/$/, '');
  if (/^[a-z]:\//i.test(value) || value.startsWith('//')) value = value.toLowerCase();
  return value;
}
export const withinPath = (path, directory) => pathKey(path) === pathKey(directory) || pathKey(path).startsWith(pathKey(directory) + '/');
export const gameTitle = path => filename(path).replace(/\.[^.]+$/, '').replace(/\s*\([^)]*\)|\s*\[[^\]]*\]/g, '').trim() || filename(path);
const genericExtensions = new Set(['zip', '7z', 'iso', 'chd', 'bin', 'cue', 'm3u', 'img']);
export const isRom = path => genericExtensions.has(extension(path)) || PLATFORMS.some(platform => platform.extensions.includes(extension(path)));
export function inferPlatform(path, selected = 'auto') {
  if (selected !== 'auto' && platformById(selected).id !== 'unknown') return selected;
  const ext = extension(path);
  const exact = PLATFORMS.find(platform => platform.extensions.includes(ext));
  if (exact) return exact.id;
  const segments = parentPath(path).split('/').reverse().map(segment => segment.toLowerCase().replace(/[^a-z0-9]/g, ''));
  for (const segment of segments) {
    const platform = PLATFORMS.find(item => [item.id, ...item.aliases].includes(segment));
    if (platform) return platform.id;
  }
  return 'unknown';
}
