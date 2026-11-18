import { extension, filename, gameTitle, inferPlatform, isRom, joinPath, parentPath, pathKey, withinPath } from '../shared/platforms.js';

export const emptyLibrary = () => ({ version: 1, directories: [], games: [] });
const abort = signal => { if (signal?.aborted) throw new DOMException('扫描已取消', 'AbortError'); };
const imageExtensions = ['png', 'jpg', 'jpeg', 'webp'];
const skipDirectories = new Set(['bios', 'firmware', 'covers', 'artwork', 'images', 'screenshots', 'saves', 'states', 'system volume information', '$recycle.bin']);
export const exclusionTypes = ['EXCLUDED_PLATFORMS', 'EXCLUDED_SINGLE_FILES', 'EXCLUDED_SINGLE_EXT', 'EXCLUDED_MULTI_FILES'];

export function createExclusionMatcher(rules = {}, directories = []) {
  if (!exclusionTypes.some(key => rules[key]?.length)) return () => false;
  const sets = Object.fromEntries(exclusionTypes.map(key => [key, new Set((rules[key] || []).map(value => value.toLowerCase()))]));
  return (path, platform, isDirectory = false) => {
    const name = filename(path).toLowerCase();
    if (sets.EXCLUDED_PLATFORMS.has(platform?.toLowerCase())) return true;
    if (isDirectory && (sets.EXCLUDED_PLATFORMS.has(name) || sets.EXCLUDED_MULTI_FILES.has(name))) return true;
    if (!isDirectory && (sets.EXCLUDED_SINGLE_FILES.has(name) || sets.EXCLUDED_SINGLE_EXT.has(extension(name)))) return true;
    if (!sets.EXCLUDED_PLATFORMS.size && !sets.EXCLUDED_MULTI_FILES.size) return false;
    let folder = isDirectory ? path : parentPath(path);
    while (directories.some(root => withinPath(folder, root.path))) {
      const folderName = filename(folder).toLowerCase();
      if (sets.EXCLUDED_PLATFORMS.has(folderName) || sets.EXCLUDED_MULTI_FILES.has(folderName)) return true;
      const parent = parentPath(folder);
      if (parent === folder) break;
      folder = parent;
    }
    return false;
  };
}

export function validateLibrary(value) {
  if (value?.version !== 1 || !Array.isArray(value.directories) || !Array.isArray(value.games) ||
      value.directories.some(item => typeof item?.path !== 'string' || !item.path || typeof item.platform !== 'string') ||
      value.games.some(item => typeof item?.id !== 'string' || typeof item.path !== 'string' || typeof item.platform !== 'string' || typeof item.title !== 'string')) {
    throw new Error('游戏库文件格式不正确。请先备份 library.json，再检查文件内容。');
  }
  if (new Set(value.games.map(game => game.id)).size !== value.games.length) throw new Error('游戏库包含重复记录。');
  return value;
}

/** Scan names and metadata only; ROM bytes are read when Play is pressed. */
export async function scanDirectory(fs, directory, { signal, onProgress, excluded = () => false } = {}) {
  const root = await fs.stat(directory.path);
  if (!root.exists || root.type !== 'directory') throw new Error(`目录不存在：${directory.path}`);
  const games = [], errors = [], visited = new Set();
  const pending = [{ path: root.path || directory.path, depth: 0 }];
  let scanned = 0;
  while (pending.length) {
    abort(signal);
    const { path, depth } = pending.pop();
    if (excluded(path, undefined, true)) continue;
    if (visited.has(pathKey(path))) continue;
    visited.add(pathKey(path));
    let entries;
    try { entries = await fs.readDirectory(path); }
    catch (error) { errors.push({ path, message: error.message }); continue; }
    abort(signal);
    const images = new Map(entries.filter(item => item.type === 'file' && imageExtensions.includes(extension(item.name))).map(item => [item.name.toLowerCase(), item.path || joinPath(path, item.name)]));
    const covers = entries.find(item => item.type === 'directory' && /^(covers|artwork|images)$/i.test(item.name));
    if (covers) {
      try {
        for (const item of await fs.readDirectory(covers.path || joinPath(path, covers.name))) {
          if (item.type === 'file' && imageExtensions.includes(extension(item.name)) && !images.has(item.name.toLowerCase())) images.set(item.name.toLowerCase(), item.path || joinPath(covers.path || joinPath(path, covers.name), item.name));
        }
      } catch (error) { errors.push({ path: covers.path || joinPath(path, covers.name), message: error.message }); }
    }
    const referenced = new Set();
    for (const item of entries.filter(item => item.type === 'file' && ['cue', 'm3u'].includes(extension(item.name)))) {
      try {
        const text = await fs.readText(item.path || joinPath(path, item.name));
        const names = extension(item.name) === 'cue' ? [...text.matchAll(/^\s*FILE\s+(?:"([^"]+)"|(\S+))/gmi)].map(match => match[1] || match[2]) : text.split(/\r?\n/).map(line => line.trim()).filter(line => line && !line.startsWith('#'));
        for (const name of names) if (!name.includes('/') && !name.includes('\\')) referenced.add(name.toLowerCase());
      } catch (error) { errors.push({ path: item.path || joinPath(path, item.name), message: error.message }); }
    }
    for (const entry of entries) {
      const fullPath = entry.path || joinPath(path, entry.name);
      if (entry.type === 'directory') {
        if (!entry.name.startsWith('.') && !skipDirectories.has(entry.name.toLowerCase()) && !excluded(fullPath, undefined, true)) {
          if (depth < 40) pending.push({ path: fullPath, depth: depth + 1 });
          else errors.push({ path: fullPath, message: '目录层级超过 40 层，已跳过' });
        }
      } else if (entry.type === 'file' && isRom(entry.name) && !referenced.has(entry.name.toLowerCase())) {
        const platform = inferPlatform(fullPath, directory.platform);
        if (excluded(fullPath, platform)) continue;
        const stem = entry.name.replace(/\.[^.]+$/, '').toLowerCase();
        const coverPath = imageExtensions.map(ext => images.get(`${stem}.${ext}`)).find(Boolean) || '';
        games.push({ id: pathKey(fullPath), path: fullPath, filename: entry.name, title: gameTitle(fullPath), platform, coverPath, size: entry.size, missing: false });
      }
    }
    scanned += 1;
    onProgress?.({ directories: scanned, games: games.length, path });
  }
  abort(signal);
  return { games, errors };
}

export class LibraryStore {
  constructor(host) { this.host = host; this.value = emptyLibrary(); this.queue = Promise.resolve(); this.path = ''; }
  async open() {
    this.path = joinPath(await this.host.app.getDataPath(), 'library.json');
    const info = await this.host.fs.stat(this.path);
    if (info.exists) this.value = validateLibrary(JSON.parse(await this.host.fs.readText(this.path)));
    return this;
  }
  update(mutate) {
    const next = this.queue.catch(() => {}).then(async () => {
      const draft = JSON.parse(JSON.stringify(this.value));
      const result = mutate(draft);
      validateLibrary(draft);
      await this.host.fs.writeText(this.path, JSON.stringify(draft), { overwrite: true });
      this.value = draft;
      return result;
    });
    this.queue = next;
    return next;
  }
  async addDirectory(path, platform = 'auto') {
    await this.update(draft => {
      const item = draft.directories.find(directory => pathKey(directory.path) === pathKey(path));
      if (item) item.platform = platform;
      else draft.directories.push({ path, platform });
    });
  }
  async importFile(path, platform = 'auto') {
    const info = await this.host.fs.stat(path);
    if (!info.exists || info.type !== 'file' || !isRom(path)) throw new Error('请选择支持的 ROM 文件。');
    path = info.path || path;
    const id = pathKey(path);
    await this.update(draft => {
      const game = draft.games.find(item => item.id === id);
      const detectedPlatform = inferPlatform(path, platform);
      const platformOverride = platform !== 'auto' && platform === detectedPlatform;
      if (game) {
        Object.assign(game, { manual: true, missing: false, size: info.size });
        if (platformOverride) Object.assign(game, { platform, platformOverride });
      } else {
        draft.games.push({ id, path, filename: filename(path), title: gameTitle(path), platform: detectedPlatform, coverPath: '', size: info.size, addedAt: Date.now(), lastPlayedAt: 0, favorite: false, manual: true, missing: false, ...(platformOverride ? { platformOverride } : {}) });
      }
    });
    return this.value.games.find(item => item.id === id);
  }
  patchGame(id, patch) {
    return this.update(draft => {
      const game = draft.games.find(item => item.id === id);
      if (!game) throw new Error('游戏记录已不存在。');
      for (const key of ['title', 'platform', 'coverPath', 'biosPath', 'favorite', 'lastPlayedAt']) if (key in patch) game[key] = patch[key];
      if ('platform' in patch) game.platformOverride = true;
      if ('coverPath' in patch) game.coverOverride = true;
    });
  }
  removeGame(id) { return this.update(draft => { draft.games = draft.games.filter(game => game.id !== id); }); }
  removeDirectory(path) {
    return this.update(draft => {
      draft.directories = draft.directories.filter(directory => pathKey(directory.path) !== pathKey(path));
      draft.games = draft.games.filter(game => game.manual || draft.directories.some(directory => withinPath(game.path, directory.path)));
    });
  }
  async scan({ signal, onProgress } = {}) {
    const results = [], errors = [];
    // Take a snapshot so root edits cannot change an in-flight scan.
    const directories = this.value.directories.map(item => ({ ...item }));
    const excluded = createExclusionMatcher(this.value.rommExclusions, directories);
    for (const directory of directories) {
      abort(signal);
      try {
        const result = await scanDirectory(this.host.fs, directory, { signal, onProgress, excluded });
        results.push({ directory, ...result });
        errors.push(...result.errors);
      } catch (error) {
        if (error.name === 'AbortError') throw error;
        errors.push({ path: directory.path, message: error.message });
      }
    }
    abort(signal);
    await this.update(draft => {
      const records = new Map(draft.games.map(game => [game.id, game]));
      for (const { directory, games, errors: failed } of results) {
        if (!draft.directories.some(item => pathKey(item.path) === pathKey(directory.path))) continue;
        const found = new Set(games.map(game => game.id));
        for (const game of records.values()) {
          if (withinPath(game.path, directory.path) && !found.has(game.id) && !excluded(game.path, game.platform) && !failed.some(item => withinPath(game.path, item.path))) game.missing = true;
        }
        for (const game of games) {
          const previous = records.get(game.id);
          records.set(game.id, previous ? { ...game, ...previous, size: game.size, missing: false,
            platform: previous.platformOverride ? previous.platform : game.platform,
            coverPath: previous.coverOverride ? previous.coverPath : game.coverPath } : { ...game, favorite: false, lastPlayedAt: 0, addedAt: Date.now() });
        }
      }
      draft.games = [...records.values()];
    });
    return { errors, count: this.value.games.length };
  }
}
