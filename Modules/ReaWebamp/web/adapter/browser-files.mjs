/** Opt-in browser downloads through the existing native save dialog and file API. */
export const MAX_DOWNLOAD_BYTES = 16 * 1024 * 1024;

function tooLarge() {
  return Object.assign(new Error('Browser export exceeds 16 MiB'), { code: 'BUFFER_LIMIT' });
}

export async function saveBlob(blob, filename, host = globalThis.reaper) {
  if (!(blob instanceof Blob)) throw new TypeError('Expected a Blob');
  if (blob.size > MAX_DOWNLOAD_BYTES) throw tooLarge();
  const name = String(filename || 'download').split(/[\\/]/).pop().replace(/[\x00-\x1f]/g, '_') || 'download';
  const path = await host.dialog.saveFile({ title: 'Save file', initialPath: name });
  if (path === null) return null;
  await host.fs.writeBinary(path, new Uint8Array(await blob.arrayBuffer()), { overwrite: true });
  return path;
}

async function readDownload(url, signal) {
  // Reject oversized data URLs before decoding. Blob responses are read with a bound.
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
    await reader.cancel();
    reader.releaseLock();
  }
  return new Blob(chunks);
}

/** Handles connected <a download> elements with data: or blob: URLs only. */
export function installDownloadHandler({ onError = console.error, host = globalThis.reaper, document: doc = globalThis.document } = {}) {
  const controller = new AbortController();
  let busy = false;
  const listener = event => {
    const anchor = event.target?.closest?.('a[download]');
    if (event.defaultPrevented || !anchor || !/^(data|blob):/.test(anchor.href)) return;
    event.preventDefault();
    if (busy) return;
    busy = true;
    const url = anchor.href, name = anchor.download;
    (async () => {
      try {
        const blob = await readDownload(url, controller.signal);
        if (!controller.signal.aborted) await saveBlob(blob, name, host);
      } catch (error) {
        if (!controller.signal.aborted) onError(error);
      } finally { busy = false; }
    })();
  };
  doc.addEventListener('click', listener, true);
  return () => {
    controller.abort();
    doc.removeEventListener('click', listener, true);
  };
}
