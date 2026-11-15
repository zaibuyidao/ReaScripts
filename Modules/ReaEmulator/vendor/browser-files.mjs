/** Opt-in browser exports through the native save dialog and file API. */
export const MAX_DOWNLOAD_BYTES = 16 * 1024 * 1024;
const CHUNK_BYTES = 256 * 1024;
const active = new WeakSet();
const error = (code, message) => Object.assign(new Error(message), { code });
const cancelled = signal => { if (signal?.aborted) throw error('WRITE_CANCELLED', 'Export cancelled'); };
const tooLarge = () => error('BUFFER_LIMIT', 'Export exceeds the legacy 16 MiB limit');

async function exclusive(host, operation) {
  if (!host?.fs || !host?.dialog) throw error('NO_RUNTIME', 'A ReaWebAPI host is required');
  if (active.has(host)) throw error('WRITE_BUSY', 'An export is already in progress');
  active.add(host);
  try { return await operation(); } finally { active.delete(host); }
}
async function streaming(host) {
  if (typeof host.fs.openWrite !== 'function') return false;
  if (!host.system?.getCapabilities) return true;
  return !!(await host.system.getCapabilities()).runtime?.fs?.streamingWrite;
}
async function selectPath(filename, host, signal) {
  cancelled(signal);
  const name = String(filename || 'download').split(/[\\/]/).pop().replace(/[\x00-\x1f]/g, '_') || 'download';
  const path = await host.dialog.saveFile({ title: 'Save file', initialPath: name });
  cancelled(signal);
  return path;
}
function progress(callback, bytes, total, state) {
  try { callback?.({ bytes, total: total ?? null, state }); } catch (failure) { console.error(failure); }
}
async function writeSource(source, total, filename, host, { signal, onProgress } = {}) {
  const path = await selectPath(filename, host, signal);
  if (path === null) return null;
  const writer = await host.fs.openWrite(path, { overwrite: true, ...(total === undefined ? {} : { expectedBytes: total }) });
  let bytes = 0;
  const complete = () => { progress(onProgress, bytes, total, 'committed'); return path; };
  try {
    cancelled(signal);
    const size = Math.min(CHUNK_BYTES, writer.maxChunkBytes);
    if (!Number.isSafeInteger(size) || size < 1) throw error('PROTOCOL_MISMATCH', 'Invalid writer chunk size');
    for await (const chunk of source(size)) {
      for (let at = 0; at < chunk.byteLength; at += size) {
        cancelled(signal);
        const result = await writer.write(chunk.subarray(at, Math.min(chunk.byteLength, at + size)));
        bytes = result.totalBytes;
        progress(onProgress, bytes, total, 'writing');
      }
    }
    cancelled(signal);
    progress(onProgress, bytes, total, 'committing');
    cancelled(signal);
    await writer.commit();
    return complete();
  } catch (failure) {
    try {
      const state = await writer.abort();
      if (state.state === 'committed') { bytes = state.bytes; return complete(); }
      if (state.cleanupPending) failure.cleanupPending = true;
    } catch (cleanupError) {
      throw Object.assign(error('WRITE_RESULT_UNKNOWN', 'Cannot confirm the export result'), { cause: failure, cleanupError });
    }
    throw failure;
  }
}
async function save(blob, filename, host, options) {
  cancelled(options.signal);
  if (await streaming(host)) {
    return writeSource(async function* (size) {
      for (let offset = 0; offset < blob.size; offset += size) {
        cancelled(options.signal);
        yield new Uint8Array(await blob.slice(offset, offset + size).arrayBuffer());
      }
    }, blob.size, filename, host, options);
  }
  if (blob.size > MAX_DOWNLOAD_BYTES) throw tooLarge();
  const path = await selectPath(filename, host, options.signal);
  if (path === null) return null;
  const bytes = new Uint8Array(await blob.arrayBuffer());
  cancelled(options.signal);
  await host.fs.writeBinary(path, bytes, { overwrite: true });
  progress(options.onProgress, bytes.byteLength, bytes.byteLength, 'committed');
  return path;
}

/** The optional fourth argument adds signal/onProgress without changing existing calls. */
export async function saveBlob(blob, filename, host = globalThis.reaper, options = {}) {
  if (!(blob instanceof Blob)) throw new TypeError('Expected a Blob');
  return exclusive(host, () => save(blob, filename, host, options));
}

async function readDownload(url, signal) {
  if (url.startsWith('data:') && url.length > MAX_DOWNLOAD_BYTES * 3 + 1024) throw tooLarge();
  const response = await fetch(url, { signal });
  if (!response.ok) throw new Error(`Cannot read export: ${response.status}`);
  const reader = response.body.getReader();
  const chunks = [];
  let size = 0;
  try {
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_DOWNLOAD_BYTES) throw tooLarge();
      chunks.push(value);
    }
  } finally {
    try { await reader.cancel(); } catch {} finally { reader.releaseLock(); }
  }
  return new Blob(chunks);
}

/** Handles connected data:/blob: download links. Detached links need an App adapter. */
export function installDownloadHandler({ onError = console.error, onProgress, host = globalThis.reaper, document: doc = globalThis.document } = {}) {
  const controller = new AbortController();
  const signal = controller.signal;
  const listener = event => {
    const anchor = event.target?.closest?.('a[download]');
    if (event.defaultPrevented || !anchor || !/^(data|blob):/.test(anchor.href)) return;
    event.preventDefault();
    const url = anchor.href, name = anchor.download;
    exclusive(host, async () => {
      // Acquire the Blob response before awaiting the dialog or host capability query.
      if (url.startsWith('blob:') && typeof host.fs.openWrite === 'function') {
        const response = await fetch(url, { signal });
        if (!response.ok || !response.body) throw error('FILE_IO', 'Cannot read the Blob URL');
        const reader = response.body.getReader();
        try {
          if (await streaming(host)) {
            const header = response.headers.get('content-length');
            const parsed = header === null ? undefined : Number(header);
            const total = Number.isSafeInteger(parsed) && parsed >= 0 ? parsed : undefined;
            return await writeSource(async function* () {
              for (;;) {
                cancelled(signal);
                const { value, done } = await reader.read();
                if (done) return;
                yield value;
              }
            }, total, name, host, { signal, onProgress });
          }
          const chunks = []; let bytes = 0;
          for (;;) {
            const { value, done } = await reader.read();
            if (done) break;
            bytes += value.byteLength;
            if (bytes > MAX_DOWNLOAD_BYTES) throw tooLarge();
            chunks.push(value);
          }
          return await save(new Blob(chunks), name, host, { signal, onProgress });
        } finally {
          try { await reader.cancel(); } catch {} finally { reader.releaseLock(); }
        }
      }
      const blob = await readDownload(url, signal);
      return save(blob, name, host, { signal, onProgress });
    }).catch(failure => { if (!signal.aborted) onError(failure); });
  };
  doc.addEventListener('click', listener, true);
  return () => { controller.abort(); doc.removeEventListener('click', listener, true); };
}
