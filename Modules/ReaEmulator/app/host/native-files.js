const BINARY_LIMIT = 16 * 1024 * 1024;
const CHUNK_SIZE = 256 * 1024;

/** Large files use the launcher's bounded, read-only Lua message route. */
export async function readNativeFile(host, path, { signal, onProgress } = {}) {
  const info = await host.fs.stat(path);
  if (!info.exists || info.type !== 'file') throw new Error(`文件不存在：${path}`);
  if (!Number.isSafeInteger(info.size) || info.size < 0) throw new Error('无法获取文件大小。');
  const check = () => { if (signal?.aborted) throw new DOMException('加载已取消', 'AbortError'); };
  check();
  let chunks;
  if (info.size <= BINARY_LIMIT) {
    chunks = [await host.fs.readBinary(path)];
    check();
    if (chunks[0].byteLength !== info.size) throw new Error('文件在加载过程中发生变化，请重试。');
    onProgress?.(info.size, info.size);
  } else {
    chunks = [];
    const nonce = Math.random().toString(36).slice(2);
    let pending, sequence = 0;
    const stop = await host.events.on('message', message => {
      const match = /^REAEMU_(DATA|ERROR)\t([^\t]+)\t(.*)$/.exec(message);
      if (!match || !pending || match[2] !== pending.id) return;
      if (match[1] === 'ERROR') pending.reject(new Error(decodeURIComponent(match[3])));
      else {
        try { pending.resolve(Uint8Array.from(atob(match[3]), char => char.charCodeAt(0))); }
        catch (error) { pending.reject(error); }
      }
    });
    const cancelled = () => pending?.reject(new DOMException('加载已取消', 'AbortError'));
    signal?.addEventListener('abort', cancelled, { once: true });
    try {
      for (let offset = 0; offset < info.size; offset += CHUNK_SIZE) {
        check();
        const length = Math.min(CHUNK_SIZE, info.size - offset);
        let timer;
        try {
          const chunk = await new Promise((resolve, reject) => {
            const id = `${nonce}-${sequence++}`;
            pending = { id, resolve, reject };
            timer = setTimeout(() => reject(new Error('本地文件读取超时。请通过 zaibuyidao_ReaEmulator.lua 启动应用，再重试。')), 10000);
            try {
              Promise.resolve(host.host.send(`REAEMU_READ\t${id}\t${offset}\t${length}\t${info.size}\t${encodeURIComponent(path)}`)).then(sent => {
                if (sent === false) reject(new Error('宿主未接受文件读取请求，请重新打开应用后重试。'));
              }, reject);
            }
            catch (error) { reject(error); }
          });
          if (chunk.byteLength !== length) throw new Error('文件读取不完整，请重试。');
          chunks.push(chunk);
          onProgress?.(offset + length, info.size);
        } finally { clearTimeout(timer); pending = undefined; }
      }
    } finally {
      signal?.removeEventListener('abort', cancelled);
      await stop();
    }
  }
  check();
  return new File(chunks, path.split(/[\\/]/).pop(), { type: 'application/octet-stream' });
}
