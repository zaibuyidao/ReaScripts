import {localFileHref, normalizePath, resolveLocalPath} from './ReaperLinks.js';

export const transferMessages = {
  moveToProject: ['Move to Project', '移动到工程', '移動到專案', 'プロジェクトへ移動', '프로젝트로 이동'],
  moveToGlobal: ['Move to Global', '移动到全局', '移動到全域', 'グローバルへ移動', '전역으로 이동'],
  moveNote: ['Move Note', '移动笔记', '移動筆記', 'ノートを移動', '노트 이동'],
  movingNote: ['Moving note…', '正在移动笔记…', '正在移動筆記…', 'ノートを移動中…', '노트 이동 중…'],
  noteMoved: ['Note moved', '笔记已移动', '筆記已移動', 'ノートを移動しました', '노트가 이동되었습니다'],
  moveSaveFirst: ['Save your changes before moving this note?', '移动前需要保存修改，是否保存？', '移動前需要儲存修改，是否儲存？', '移動前に変更を保存しますか？', '이동하기 전에 변경 사항을 저장할까요?'],
  moveNameConflict: ['The destination already contains this name or a draft. Enter a different note name.', '目标中已有同名笔记或草稿，请输入其他名称。', '目標中已有同名筆記或草稿，請輸入其他名稱。', '移動先に同名のノートまたは下書きがあります。別の名前を入力してください。', '대상에 같은 이름의 노트 또는 초안이 있습니다. 다른 이름을 입력하세요.'],
  error_TRANSFER_SAVE_PROJECT: ['Save the REAPER project before moving notes between scopes.', '请先保存 REAPER 工程，再移动笔记。', '請先儲存 REAPER 專案，再移動筆記。', 'ノートを移動する前に REAPER プロジェクトを保存してください。', '노트를 이동하기 전에 REAPER 프로젝트를 저장하세요.'],
  error_TRANSFER_PROJECT_CHANGED: ['The active REAPER project changed. The move was cancelled.', '当前 REAPER 工程已改变，移动已取消。', '目前的 REAPER 專案已變更，移動已取消。', 'アクティブなプロジェクトが変わったため、移動を中止しました。', '활성 REAPER 프로젝트가 변경되어 이동이 취소되었습니다.'],
  error_TRANSFER_SAME_ROOT: ['Both scopes use the same folder. No move is needed.', '两个范围使用同一目录，无需移动。', '兩個範圍使用同一目錄，無需移動。', '両方の範囲が同じフォルダーを使用しています。移動は不要です。', '두 범위가 같은 폴더를 사용하므로 이동할 필요가 없습니다.'],
  error_TRANSFER_VERIFY_FAILED: ['The destination could not be verified. The original note was kept.', '目标校验失败，原笔记已保留。', '目標校驗失敗，原筆記已保留。', '移動先の検証に失敗しました。元のノートは保持されています。', '대상을 확인하지 못했습니다. 원본 노트는 보존되었습니다.'],
  error_TRANSFER_RECOVERY_REQUIRED: ['The move needs attention. Check both folders and their .reafolio-trash recovery files before retrying.', '移动需要恢复处理，请检查两边目录及其中的 .reafolio-trash 恢复文件后再试。', '移動需要復原處理，請檢查兩邊目錄及其中的 .reafolio-trash 復原檔案後再試。', '移動の復元が必要です。両方のフォルダーと .reafolio-trash を確認してください。', '이동을 복구해야 합니다. 두 폴더와 .reafolio-trash 복구 파일을 확인하세요.'],
  error_TRANSFER_OPEN_FAILED: ['The note was moved, but its destination could not be opened.', '笔记已移动，但无法打开目标位置。', '筆記已移動，但無法開啟目標位置。', 'ノートは移動しましたが、移動先を開けませんでした。', '노트는 이동했지만 대상 위치를 열지 못했습니다.'],
};

const fail = code => { throw Object.assign(new Error(code), {code}); };
const fold = value => value.normalize('NFC').toLowerCase();
const uuid = /^[\da-f]{8}(?:-[\da-f]{4}){3}-[\da-f]{12}$/i;
const digest = async value => [...new Uint8Array(await crypto.subtle.digest('SHA-256',
  typeof value === 'string' ? new TextEncoder().encode(value) : value))]
  .map(byte => byte.toString(16).padStart(2, '0')).join('');
const signature = text => {
  const bytes = new TextEncoder().encode(text);
  let a = 2166136261, b = 5381;
  for (const byte of bytes) { a = Math.imul(a ^ byte, 16777619); b = Math.imul(b, 33) ^ byte; }
  return `${bytes.length}:${a >>> 0}:${b >>> 0}`;
};

// Return URL spans, leaving code, labels, titles and surrounding Markdown intact.
export function markdownDestinations(text, {codeRanges} = {}) {
  const spans = [], ignored = codeRanges ? [...codeRanges] : [], definitions = [];
  const lines = [...text.matchAll(/[^\r\n]*(?:\r\n|\r|\n|$)/g)];
  let fence;
  for (const line of lines) {
    if (!line[0]) continue;
    const marker = /^ {0,3}(`{3,}|~{3,})/.exec(line[0]);
    if (codeRanges) continue;
    if (fence) {
      ignored.push([line.index, line.index + line[0].length]);
      if (marker && marker[1][0] === fence[0] && marker[1].length >= fence.length &&
          /^\s*$/.test(line[0].slice(marker[0].length))) fence = null;
    } else if (marker) {
      fence = marker[1]; ignored.push([line.index, line.index + line[0].length]);
    } else if (/^(?: {4}|\t)/.test(line[0])) ignored.push([line.index, line.index + line[0].length]);
  }
  for (const match of text.matchAll(/<!--[^]*?-->/g)) ignored.push([match.index, match.index + match[0].length]);
  const blocked = position => ignored.some(([a, b]) => position >= a && position < b);
  const definitionPattern = codeRanges ? /^[ \t]*\[(?:\\.|[^\]\\\r\n])+\]:[ \t]*/gm : /^ {0,3}\[(?:\\.|[^\]\\\r\n])+\]:[ \t]*/gm;
  for (const match of text.matchAll(definitionPattern)) {
    if (blocked(match.index) || match[0].trimStart().startsWith('[^')) continue;
    definitions.push(match.index + match[0].length);
    const end = text.indexOf('\n', match.index);
    ignored.push([match.index, end < 0 ? text.length : end]);
  }
  const escaped = position => { let n = 0; while (text[--position] === '\\') n++; return n % 2; };
  function destination(start) {
    while (/\s/.test(text[start] || '') && start < text.length) start++;
    if (text[start] === '<') {
      let end = start + 1;
      while (end < text.length && (text[end] !== '>' || escaped(end)) && !/[\r\n]/.test(text[end])) end++;
      return text[end] === '>' ? {start: start + 1, end} : null;
    }
    let end = start, depth = 0;
    while (end < text.length) {
      if (text[end] === '\\' && end + 1 < text.length) { end += 2; continue; }
      if (text[end] === '(') depth++;
      else if (text[end] === ')') { if (!depth) break; depth--; }
      if (/\s/.test(text[end]) && !depth) break;
      end++;
    }
    return end > start && !depth ? {start, end} : null;
  }
  const brackets = [];
  for (let i = 0; i < text.length; i++) {
    if (blocked(i)) continue;
    if (text[i] === '`' && !escaped(i)) {
      let end = i; while (text[end] === '`') end++;
      const token = text.slice(i, end); let close = text.indexOf(token, end);
      while (close >= 0 && (text[close - 1] === '`' || text[close + token.length] === '`'))
        close = text.indexOf(token, close + token.length);
      if (close >= 0) { ignored.push([i, close + token.length]); i = close + token.length - 1; }
    } else if (text[i] === '[' && !escaped(i)) brackets.push(i);
    else if (text[i] === ']' && !escaped(i) && brackets.length) {
      brackets.pop();
      if (text[i + 1] === '(') {
        const span = destination(i + 2);
        if (span) {
          let close = span.end + (text[span.end] === '>' ? 1 : 0);
          while (/\s/.test(text[close] || '') && close < text.length) close++;
          if (['"', "'", '('].includes(text[close])) {
            const quote = text[close] === '(' ? ')' : text[close]; close++;
            while (close < text.length && (text[close] !== quote || escaped(close))) close++;
            close++; while (/\s/.test(text[close] || '') && close < text.length) close++;
          }
          if (text[close] === ')') { spans.push(span); i = close; }
        }
      }
    }
  }
  for (const start of definitions) { const span = destination(start); if (span) spans.push(span); }
  for (const match of text.matchAll(/<(?:img|a)\b[^>]*>/gi)) {
    if (blocked(match.index)) continue;
    for (const attr of match[0].matchAll(/\b(?:src|href)\s*=\s*(["'])([^]*?)\1/gi)) {
      const start = match.index + attr.index + attr[0].indexOf(attr[1]) + 1;
      spans.push({start, end: start + attr[2].length, html: true});
    }
  }
  return spans.sort((a, b) => a.start - b.start).filter((span, i, all) => !i || span.start >= all[i - 1].end);
}

function decodeLink(value, html) {
  if (html) value = value.replace(/&(?:amp|quot|apos|lt|gt);|&#(?:x[\da-f]+|\d+);/gi, entity => {
    const named = {'&amp;': '&', '&quot;': '"', '&apos;': "'", '&lt;': '<', '&gt;': '>'};
    if (named[entity.toLowerCase()]) return named[entity.toLowerCase()];
    const hex = /^&#x/i.test(entity); return String.fromCodePoint(parseInt(entity.slice(hex ? 3 : 2, -1), hex ? 16 : 10));
  });
  else value = value.replace(/\\([!"#$%&'()*+,\-./:;<=>?@[\]\\^_`{|}~])/g, '$1');
  return value;
}

export class NoteTransfers {
  constructor(repo, {validateTitle, allowedRoot}) {
    Object.assign(this, {repo, validateTitle, allowedRoot});
  }

  async checked(root, relative, required = false) {
    if (typeof relative !== 'string' || !relative || relative.split('/').some(part =>
      !part || part === '.' || part === '..' || /[<>:"\\|?*\x00-\x1f\x7f]/.test(part))) fail('UNSAFE_PATH');
    const path = root.replace(/\/$/, '') + '/' + relative;
    const info = await this.repo.host.fs.stat(path);
    if (this.repo.pathKey(info.path) !== this.repo.pathKey(path)) fail('UNSAFE_PATH');
    if (required && (!info.exists || info.type !== 'file')) fail('FILE_NOT_FOUND');
    return {path, info};
  }

  async directory(root, relative) {
    let current = '';
    for (const part of relative.split('/')) {
      current += (current ? '/' : '') + part;
      let entry = await this.checked(root, current);
      if (!entry.info.exists) {
        try { await this.repo.host.fs.makeDirectory(entry.path); }
        catch (error) { if (error.code !== 'FILE_EXISTS') throw error; }
        entry = await this.checked(root, current);
      }
      if (!entry.info.exists || entry.info.type !== 'directory') fail('WORKSPACE_UNAVAILABLE');
    }
  }

  async validateRoot(root) {
    if (typeof root !== 'string' || !root || normalizePath(root) !== root || !await this.allowedRoot(root)) fail('UNSAFE_PATH');
    const info = await this.repo.host.fs.stat(root);
    if (!info.exists || info.type !== 'directory' || this.repo.pathKey(info.path) !== this.repo.pathKey(root)) fail('UNSAFE_PATH');
  }

  async available(root, title) {
    this.validateTitle(title);
    const filename = title + '.md';
    if ((await this.repo.host.fs.readDirectory(root)).some(entry => fold(entry.name) === fold(filename))) return false;
    const draftKey = JSON.stringify([this.repo.pathKey(root), fold(title)]);
    return !this.repo.drafts[draftKey] && !globalThis.localStorage?.getItem('reafolio.draft:' + draftKey);
  }

  async text(root, filename) {
    const entry = await this.checked(root, filename);
    if (!entry.info.exists) return null;
    if (entry.info.type !== 'file') fail('UNSAFE_PATH');
    return this.repo.host.fs.readText(entry.path);
  }

  async archive(root, filename, raw, token) {
    this.validateTitle(filename.slice(0, -3));
    await this.validateRoot(root);
    await this.directory(root, '.reafolio-trash');
    const prefix = '.reafolio-trash/' + token;
    const backup = await this.text(root, prefix + '.md');
    const active = await this.text(root, filename);
    if (backup !== null) {
      if (backup === raw && active === null) return;
      fail('FILE_RECOVERY_REQUIRED');
    }
    if (active !== raw) fail('CONFLICT');
    const manifest = await this.checked(root, prefix + '.json');
    if (!manifest.info.exists) await this.repo.host.fs.writeText(manifest.path,
      JSON.stringify({operation: 'delete', title: filename.slice(0, -3), filename, time: new Date().toISOString()}), {overwrite: false});
    else if (JSON.parse(await this.repo.host.fs.readText(manifest.path)).filename !== filename) fail('UNSAFE_PATH');
    try {
      await this.repo.backend.request('delete-note', {root, filename, token, expected: signature(raw), expectedText: raw});
    } catch (error) {
      // A host timeout may arrive after the archive completed; inspect before retrying.
      if (await this.text(root, filename) === null && await this.text(root, prefix + '.md') === raw) return;
      throw error;
    }
  }

  async journal(record) {
    const entry = await this.checked(this.repo.dataPath, 'transfers/' + record.token + '.json');
    await this.repo.host.fs.writeText(entry.path, JSON.stringify(record), {overwrite: true});
    // Directory markers let startup skip completed history without reading every journal.
    if (['complete', 'aborted', 'rolled-back'].includes(record.phase)) {
      const marker = await this.checked(this.repo.dataPath, 'transfers/' + record.token + '.done');
      await this.repo.host.fs.writeText(marker.path, record.phase, {overwrite: true});
    }
  }

  async records({includeCompleted = false, signal} = {}) {
    signal?.throwIfAborted();
    const dir = await this.checked(this.repo.dataPath, 'transfers');
    signal?.throwIfAborted();
    if (!dir.info.exists) return [];
    if (dir.info.type !== 'directory') fail('UNSAFE_PATH');
    const records = [];
    const entries = await this.repo.host.fs.readDirectory(dir.path);
    const completed = new Set(entries.filter(entry => entry.type === 'file' && entry.name.endsWith('.done'))
      .map(entry => entry.name.slice(0, -5)));
    for (const entry of entries) {
      signal?.throwIfAborted();
      if (entry.type !== 'file' || !uuid.test(entry.name.slice(0, -5)) || !entry.name.endsWith('.json')) continue;
      if (!includeCompleted && completed.has(entry.name.slice(0, -5))) continue;
      const record = JSON.parse(await this.text(this.repo.dataPath, 'transfers/' + entry.name));
      if (record.version !== 1 || record.token !== entry.name.slice(0, -5) || !uuid.test(record.archiveToken) || !uuid.test(record.rollbackToken) ||
          typeof record.sourceRoot !== 'string' || typeof record.targetRoot !== 'string' ||
          typeof record.filename !== 'string' || typeof record.destination !== 'string' ||
          !/^[a-f0-9]{64}$/.test(record.sourceHash) || !/^[a-f0-9]{64}$/.test(record.targetHash) || !Array.isArray(record.assets)) fail('FILE_RECOVERY_REQUIRED');
      this.validateTitle(record.filename?.slice(0, -3)); this.validateTitle(record.destination?.slice(0, -3));
      if (!/\.md$/i.test(record.filename) || !/\.md$/i.test(record.destination)) fail('UNSAFE_PATH');
      records.push(record);
    }
    return records;
  }

  async protectedTexts(root, signal) {
    const texts = [];
    for (const record of await this.records({signal})) {
      signal?.throwIfAborted();
      if (['complete', 'aborted', 'rolled-back'].includes(record.phase) || this.repo.pathKey(record.targetRoot) !== this.repo.pathKey(root)) continue;
      const staged = await this.text(root, '.reafolio-trash/transfer-' + record.token + '.pending.md');
      if (staged === null || await digest(staged) !== record.targetHash) fail('IMAGE_USAGE_INCOMPLETE');
      texts.push(staged);
    }
    return texts;
  }

  async rewrite(raw, sourceRoot, targetRoot, token, destinations = markdownDestinations) {
    const assets = [], mapped = new Map(), replacements = [];
    for (const span of destinations(raw)) {
      const href = decodeLink(raw.slice(span.start, span.end), span.html);
      if (!href || href.startsWith('#') || /^(?!file:)[a-z][\w+.-]*:/i.test(href) && !/^[a-z]:[\\/]/i.test(href)) continue;
      const suffix = /^[^?#]*([?#][^]*)$/.exec(href)?.[1] || '';
      const path = resolveLocalPath(suffix ? href.slice(0, -suffix.length) : href, {root: sourceRoot, filename: 'note.md'});
      let replacement;
      const relative = path.slice(sourceRoot.length + 1);
      if (this.repo.pathKey(path).startsWith(this.repo.pathKey(sourceRoot) + '/') && /\.(png|jpe?g|gif|webp|bmp)$/i.test(relative)) {
        const identity = this.repo.pathKey(path);
        let asset = mapped.get(identity);
        if (!asset) {
          let source = await this.checked(sourceRoot, relative);
          if (!source.info.exists) source = await this.checked(sourceRoot, '.reafolio-trash/' + relative, true);
          if (source.info.type !== 'file' || source.info.size > 8388608) fail('IMAGE_TOO_LARGE');
          const bytes = new Uint8Array(await this.repo.host.fs.readBinary(source.path));
          if (bytes.byteLength > 8388608) fail('IMAGE_TOO_LARGE');
          const destination = 'attachments/move-' + token + '-' + assets.length + '.' + relative.split('.').pop().toLowerCase();
          asset = {destination, hash: await digest(bytes), source: source.path.slice(sourceRoot.length + 1)};
          assets.push(asset); mapped.set(identity, asset);
        }
        replacement = './' + asset.destination + suffix;
      } else if (/^(?:file:|[a-z]:[\\/]|\/)/i.test(href)) continue;
      else replacement = localFileHref(path) + suffix;
      if (span.html) replacement = replacement.replaceAll('&', '&amp;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');
      replacements.push({...span, replacement});
    }
    for (const {start, end, replacement} of replacements.reverse()) raw = raw.slice(0, start) + replacement + raw.slice(end);
    return {raw, assets};
  }

  async verifyAssets(record) {
    for (const asset of record.assets) {
      if (!new RegExp('^attachments/move-' + record.token + '-\\d+\\.(png|jpe?g|gif|webp|bmp)$', 'i').test(asset.destination) ||
          !/^[a-f0-9]{64}$/.test(asset.hash)) fail('UNSAFE_PATH');
      let file = await this.checked(record.targetRoot, asset.destination);
      if (!file.info.exists) {
        const archived = await this.checked(record.targetRoot, '.reafolio-trash/' + asset.destination, true);
        const bytes = new Uint8Array(await this.repo.host.fs.readBinary(archived.path));
        if (await digest(bytes) !== asset.hash) fail('IMAGE_VERIFY_FAILED');
        await this.directory(record.targetRoot, 'attachments');
        await this.repo.host.fs.writeBinary(file.path, bytes, {overwrite: false});
        file = await this.checked(record.targetRoot, asset.destination, true);
      }
      if (file.info.type !== 'file' || file.info.size > 8388608 ||
          await digest(new Uint8Array(await this.repo.host.fs.readBinary(file.path))) !== asset.hash) fail('IMAGE_VERIFY_FAILED');
    }
  }

  async move({sourceRoot, targetRoot, note, title, destinations, assertCurrent = async () => {}}) {
    if (this.running || this.repo.busy || this.repo.images.pending || !this.repo.backend) fail('BUSY');
    this.running = true; this.repo.busy = true;
    this.repo.writeRevision = (this.repo.writeRevision || 0) + 1;
    let record;
    try {
      await this.validateRoot(sourceRoot); await this.validateRoot(targetRoot);
      if (this.repo.pathKey(sourceRoot) === this.repo.pathKey(targetRoot)) fail('TRANSFER_SAME_ROOT');
      if (!await this.available(targetRoot, title)) fail('FILE_EXISTS');
      if (await this.text(sourceRoot, note.filename) !== note.raw) fail('CONFLICT');
      const token = crypto.randomUUID();
      const prepared = await this.rewrite(note.raw, sourceRoot, targetRoot, token, destinations);
      if (new TextEncoder().encode(prepared.raw).length > 16777213) fail('BUFFER_LIMIT');
      record = {version: 1, token, archiveToken: crypto.randomUUID(), rollbackToken: crypto.randomUUID(),
        sourceRoot, targetRoot, filename: note.filename, destination: title + '.md', phase: 'prepared',
        sourceHash: await digest(note.raw), targetHash: await digest(prepared.raw),
        assets: prepared.assets.map(({destination, hash}) => ({destination, hash}))};
      await this.directory(this.repo.dataPath, 'transfers');
      await this.directory(targetRoot, '.reafolio-trash');
      // This staging note also protects attachments from normal orphan cleanup.
      const staged = await this.checked(targetRoot, '.reafolio-trash/transfer-' + token + '.pending.md');
      await this.repo.host.fs.writeText(staged.path, prepared.raw, {overwrite: false});
      await this.journal(record);
      for (const asset of prepared.assets) {
        const source = await this.checked(sourceRoot, asset.source, true);
        const bytes = new Uint8Array(await this.repo.host.fs.readBinary(source.path));
        if (bytes.byteLength > 8388608 || await digest(bytes) !== asset.hash) fail('CONFLICT');
        await this.directory(targetRoot, 'attachments');
        const target = await this.checked(targetRoot, asset.destination);
        await this.repo.host.fs.writeBinary(target.path, bytes, {overwrite: false});
      }
      await assertCurrent();
      if (!await this.available(targetRoot, title)) fail('FILE_EXISTS');
      const target = await this.checked(targetRoot, record.destination);
      await this.repo.host.fs.writeText(target.path, prepared.raw, {overwrite: false});
      record.created = true; record.phase = 'copied'; await this.journal(record);
      if (await this.text(targetRoot, record.destination) !== prepared.raw) fail('TRANSFER_VERIFY_FAILED');
      await this.verifyAssets(record);
      record.phase = 'target-verified'; await this.journal(record);
      await assertCurrent();
      await this.archive(sourceRoot, note.filename, note.raw, record.archiveToken);
      if (await this.text(targetRoot, record.destination) !== prepared.raw) fail('TRANSFER_VERIFY_FAILED');
      await this.verifyAssets(record);
      record.phase = 'complete'; await this.journal(record);
      this.repo.notes.delete(fold(note.title)); this.repo.baselines.delete(fold(note.title));
      delete this.repo.metadata[sourceRoot + '/' + note.filename];
      return {title, sourceRoot, targetRoot, token};
    } catch (error) {
      if (record) {
        try { await this.reconcile(record, false); }
        catch { error.code = 'TRANSFER_RECOVERY_REQUIRED'; }
        if (record.phase === 'complete') return {title, sourceRoot, targetRoot, token: record.token};
      }
      throw error;
    } finally {
      this.repo.writeRevision++; this.repo.busy = false; this.running = false;
      this.repo.scheduleImageSync();
    }
  }

  async reconcile(record, resume) {
    await this.validateRoot(record.sourceRoot); await this.validateRoot(record.targetRoot);
    const source = await this.text(record.sourceRoot, record.filename);
    const target = await this.text(record.targetRoot, record.destination);
    const sourceMatches = source !== null && await digest(source) === record.sourceHash;
    const targetMatches = target !== null && await digest(target) === record.targetHash;
    if (source === null) {
      const backup = await this.text(record.sourceRoot, '.reafolio-trash/' + record.archiveToken + '.md');
      if (backup === null || await digest(backup) !== record.sourceHash) fail('TRANSFER_RECOVERY_REQUIRED');
      if (targetMatches) {
        try { await this.verifyAssets(record); record.phase = 'complete'; await this.journal(record); return; }
        catch { /* Restore the original if the target or its attachments are incomplete. */ }
      }
      const original = await this.checked(record.sourceRoot, record.filename);
      await this.repo.host.fs.writeText(original.path, backup, {overwrite: false});
      record.phase = 'restored'; await this.journal(record); fail('TRANSFER_RECOVERY_REQUIRED');
    }
    if (resume && sourceMatches && targetMatches && record.phase === 'target-verified') {
      await this.verifyAssets(record);
      await this.archive(record.sourceRoot, record.filename, source, record.archiveToken);
      record.phase = 'complete'; await this.journal(record); return;
    }
    if (targetMatches && record.created) await this.archive(record.targetRoot, record.destination, target, record.rollbackToken);
    else if (target !== null) fail('TRANSFER_RECOVERY_REQUIRED');
    record.phase = targetMatches ? 'rolled-back' : 'aborted'; await this.journal(record);
  }

  async recover(root) {
    if (this.running) return [];
    const issues = [];
    this.running = true;
    try {
      for (const record of await this.records()) {
        if (['complete', 'aborted', 'rolled-back'].includes(record.phase) ||
            ![record.sourceRoot, record.targetRoot].some(path => this.repo.pathKey(path) === this.repo.pathKey(root))) continue;
        try { await this.reconcile(record, true); }
        catch (error) { issues.push('transfer ' + record.token + ': ' + (error.code || 'FILE_IO')); }
      }
    } catch (error) { issues.push('transfers: ' + (error.code || 'FILE_IO')); }
    finally { this.running = false; }
    return issues;
  }
}
