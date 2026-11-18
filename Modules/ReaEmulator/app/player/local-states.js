const databaseName = 'EmulatorJS-states';
const storeName = 'states';
const indexKey = '?EJS_KEYS!';
const metadataKey = key => `ReaEmulator:state:${key}`;
let writes = Promise.resolve();

async function digest(bytes) {
  const hash = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(hash), value => value.toString(16).padStart(2, '0')).join('');
}

export async function gameSaveName(game) {
  const hash = await digest(new TextEncoder().encode(game.id));
  return `${game.filename.replace(/\.[^.]+$/, '')}-${hash.slice(0, 24)}`;
}

export async function gameStateKey(game) {
  // EmulatorJS strips these characters in getBaseFileName().
  const base = (await gameSaveName(game)).replace(/[#<$+%>!`&*'|{}/\\?"=@:^\r\n]/gi, '').trim();
  return `${base}.state`;
}

function withStates(mode, operation) {
  return new Promise((resolve, reject) => {
    const open = indexedDB.open(databaseName, 1);
    open.onerror = () => reject(open.error);
    open.onupgradeneeded = () => open.result.createObjectStore(storeName);
    open.onsuccess = () => {
      const db = open.result;
      try {
        const transaction = db.transaction(storeName, mode);
        const result = operation(transaction.objectStore(storeName));
        transaction.oncomplete = () => { db.close(); resolve(result()); };
        transaction.onabort = () => { db.close(); reject(transaction.error); };
      } catch (error) {
        db.close();
        reject(error);
      }
    };
  });
}

export async function readLocalState(key) {
  if (!globalThis.indexedDB) return null;
  await writes;
  const { bytes, metadata } = await withStates('readonly', table => {
    const state = table.get(key);
    const details = table.get(metadataKey(key));
    return () => ({ bytes: state.result, metadata: details.result });
  });
  if (!ArrayBuffer.isView(bytes) || !bytes.byteLength) return null;
  // Earlier releases wrote only the bytes. A rollback may also replace them.
  const verified = metadata?.hash && metadata.hash === await digest(bytes) ? metadata : null;
  return { bytes, core: verified?.core ?? null, savedAt: verified?.savedAt ?? null };
}

export function writeLocalState(key, bytes, core) {
  const savedAt = new Date().toISOString();
  const write = writes.then(async () => {
    const hash = await digest(bytes);
    await withStates('readwrite', table => {
      const index = table.get(indexKey);
      index.onsuccess = () => {
        const keys = Array.isArray(index.result) ? index.result : [];
        if (!keys.includes(key)) table.put([...keys, key], indexKey);
      };
      table.put(bytes, key);
      table.put({ core, savedAt, hash }, metadataKey(key));
      return () => undefined;
    });
  });
  writes = write.catch(() => {});
  return write;
}

export function pendingLocalStateWrites() {
  return writes;
}
