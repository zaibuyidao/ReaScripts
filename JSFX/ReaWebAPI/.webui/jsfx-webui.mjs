const resourceCRC = (() => {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i++) { let c = i; for (let n = 0; n < 8; n++) c = (c >>> 1) ^ ((c & 1) ? 0xedb88320 : 0); table[i] = c; }
  return bytes => { let value = 0xffffffff; for (const byte of bytes) value = table[(value ^ byte) & 255] ^ (value >>> 8); return (value ^ 0xffffffff) >>> 0; };
})();
function resourceChannel(info, upload, total, renew, validate, failure) {
  let socket, connecting, sequence = 1n, pending, busy = false, closed = false, transport = info.transport;
  const id = info.transferId, idBytes = new TextEncoder().encode(id);
  if (idBytes.length !== 64 || info.maxChunkBytes !== 262144 || transport?.mode !== 'jsfxResourceV1')
    throw failure('PROTOCOL_MISMATCH', 'Invalid JSFX resource descriptor');
  const connect = async () => {
    if (closed) throw failure('TRANSFER_NOT_FOUND', 'JSFX resource transfer closed');
    if (socket?.readyState === 1) return;
    if (connecting) return connecting;
    connecting = (async () => {
      if (!transport) { const next = await renew(); if (next.transferId !== id) throw failure('PROTOCOL_MISMATCH', 'JSFX transfer identity changed'); transport = next.transport; }
      validate();
      const url = transport.url; transport = undefined;
      await new Promise((resolve, reject) => {
        const ws = socket = new WebSocket(url); ws.binaryType = 'arraybuffer';
        const timer = setTimeout(() => { ws.close(); reject(failure('TIMEOUT', 'JSFX resource connection timed out')); }, 5000);
        ws.onopen = () => { clearTimeout(timer); resolve(); };
        ws.onerror = () => { clearTimeout(timer); reject(failure('TRANSPORT_ERROR', 'JSFX resource connection failed')); };
        ws.onclose = () => {
          clearTimeout(timer); reject(failure('TRANSPORT_ERROR', 'JSFX resource connection closed'));
          if (socket === ws) { socket = undefined; pending?.reject(failure('TRANSPORT_ERROR', 'JSFX resource connection closed')); }
        };
        ws.onmessage = event => {
          if (!pending || socket !== ws) return;
          try {
            if (!(event.data instanceof ArrayBuffer) || event.data.byteLength < 104 || event.data.byteLength > 262248)
              throw failure('PROTOCOL_MISMATCH', 'Invalid JSFX resource reply');
            const bytes = new Uint8Array(event.data), view = new DataView(event.data), payload = bytes.subarray(104);
            if (bytes[0] !== 82 || bytes[1] !== 87 || bytes[2] !== 82 || bytes[3] !== 1 || bytes[4] !== (upload ? 1 : 2) ||
                bytes[6] || bytes[7] || view.getUint32(100, true) || idBytes.some((byte, i) => byte !== bytes[32 + i]))
              throw failure('PROTOCOL_MISMATCH', 'Invalid JSFX resource reply identity');
            const received = view.getBigUint64(8, true);
            if (received < sequence) return;
            if (received !== sequence || view.getBigUint64(16, true) !== BigInt(pending.offset) || view.getUint32(96, true) !== resourceCRC(payload))
              throw failure('PROTOCOL_MISMATCH', 'Invalid JSFX resource reply sequence or checksum');
            if (bytes[5] === 3 && view.getUint32(28, true) === 1 && view.getUint32(24, true) === payload.length) {
              const code = new TextDecoder('utf-8', { fatal: true }).decode(payload);
              throw failure(code, 'JSFX resource chunk was rejected');
            }
            if (bytes[5] !== 2 || view.getUint32(28, true) || view.getUint32(24, true) !== pending.length || payload.length !== (upload ? 0 : pending.length))
              throw failure('PROTOCOL_MISMATCH', 'Invalid JSFX resource acknowledgement');
            pending.resolve(payload.slice());
          } catch (error) { pending?.reject(error); }
        };
      });
    })().finally(() => { connecting = undefined; });
    return connecting;
  };
  return {
    upload,
    close() { closed = true; pending?.reject(failure('TRANSFER_NOT_FOUND', 'JSFX resource transfer closed')); socket?.close(); socket = undefined; },
    async exchange(offset, value) {
      validate();
      if (closed) throw failure('TRANSFER_NOT_FOUND', 'JSFX resource transfer closed');
      if (busy) throw failure('QUEUE_LIMIT', 'Wait for the current JSFX resource chunk acknowledgement');
      if (upload && !(value instanceof Uint8Array)) throw failure('INVALID_ARGUMENT', 'Expected Uint8Array resource bytes');
      const length = upload ? value.byteLength : value;
      if (!Number.isSafeInteger(offset) || offset < 0 || !Number.isSafeInteger(length) || length < 0 || length > info.maxChunkBytes || offset + length > total)
        throw failure('INVALID_ARGUMENT', 'Invalid JSFX resource byte range');
      const bytes = new Uint8Array(104 + (upload ? length : 0)), view = new DataView(bytes.buffer);
      bytes.set([82, 87, 82, 1, upload ? 1 : 2, 1]); bytes.set(idBytes, 32);
      view.setBigUint64(8, sequence, true); view.setBigUint64(16, BigInt(offset), true); view.setUint32(24, length, true);
      if (upload) bytes.set(value, 104); view.setUint32(96, resourceCRC(bytes.subarray(104)), true);
      busy = true;
      try {
        for (let attempt = 0; ; attempt++) {
          try {
            await connect(); validate();
            const result = await new Promise((resolve, reject) => {
              const timer = setTimeout(() => reject(failure('TIMEOUT', 'JSFX resource acknowledgement timed out')), 3000);
              pending = { offset, length, resolve: data => { clearTimeout(timer); resolve(data); }, reject: error => { clearTimeout(timer); reject(error); } };
              try { socket.send(bytes); } catch (error) { pending.reject(failure('TRANSPORT_ERROR', error.message)); }
            });
            sequence++; return upload ? { offset, acceptedBytes: length } : result;
          } catch (error) {
            if (attempt >= 2 || !['TIMEOUT', 'TRANSPORT_ERROR'].includes(error.code) || closed) throw error;
          } finally { pending = undefined; }
        }
      } finally { busy = false; }
    }
  };
}

/** Connect only from a JSFX Hosted WebView. REAPER owns parameter state. */
export async function connectJSFX(reaper = globalThis.reaper, onError = console.error) {
  const failure = (code, message, details) => Object.assign(new Error(message), { code, details });
  const runtime = await reaper.lifecycle.ready;
  const version = runtime?.runtime?.jsfx?.protocolVersion;
  if (version === undefined) throw failure('UNSUPPORTED', 'This runtime does not expose the JSFX protocol');
  if (version !== 1) throw failure('PROTOCOL_MISMATCH', 'Unsupported JSFX protocol version');
  const service = reaper.host.service('jsfx');
  const listeners = new Set(), visibility = new Set(), capabilityListeners = new Set(), observed = new Map();
  const dataListeners = new Set(), operationListeners = new Set(), consumers = new Set();
  const dataRevisions = new Map(), operationRevisions = new Map();
  const transfers = new Map();
  let capabilityRequest = 0;
  const closeTransfers = () => {
    const cleanup = [...transfers].map(([transferId, transfer]) => {
      transfer.close(); return invoke(transfer.upload ? 'abortResourceUpload' : 'closeResourceDownload', { transferId });
    });
    transfers.clear(); return Promise.allSettled(cleanup);
  };
  const releaseCommands = async () => capabilities?.commands?.some(command => command.continuous)
    ? freeze(await invoke('releaseCommands')) : Object.freeze({ released: false });
  const closeConsumers = () => Promise.allSettled([...consumers].map(stream => stream.close()).concat(closeTransfers(),releaseCommands()));
  let sessionId, state, revision = 0n, activation = 0, active = false, disposed = false, disposePromise;
  let gesture, running, queue = [], capabilities, continuousFocused = true;
  const stops = [];
  const freeze = value => {
    if (value && typeof value === 'object' && !Object.isFrozen(value)) {
      for (const item of Object.values(value)) freeze(item);
      Object.freeze(value);
    }
    return value;
  };
  const revisionOf = value => {
    if (typeof value !== 'string' || !/^(0|[1-9][0-9]*)$/.test(value)) throw failure('PROTOCOL_MISMATCH', 'Invalid JSFX revision');
    return BigInt(value);
  };
  const notify = (set, value) => { for (const fn of set) { try { fn(value); } catch (error) { onError(error); } } };
  const subscribe = async (set, fn) => {
    if (disposed) throw failure('FX_UNBOUND', 'JSFX connection is disposed');
    if (typeof fn !== 'function') throw failure('INVALID_ARGUMENT', 'Expected a listener');
    set.add(fn); return async () => { set.delete(fn); };
  };
  const invoke = async (method, data = {}) => {
    const expectedSession = method === 'getCapabilities' ? undefined : sessionId;
    const reply = await service.invoke(method, { ...data, ...(expectedSession ? { sessionId: expectedSession } : {}) });
    if (!reply || typeof reply.ok !== 'boolean') throw failure('PROTOCOL_MISMATCH', 'Invalid JSFX result envelope');
    if (!reply.ok) throw failure(reply.error?.code || 'PROTOCOL_MISMATCH', reply.error?.message || 'Invalid JSFX error', reply.error?.details);
    if (typeof reply.sessionId !== 'string' || !reply.sessionId || (expectedSession && (reply.sessionId !== expectedSession || sessionId !== expectedSession)))
      throw failure('STALE_SESSION', 'The JSFX instance session changed');
    return reply.data;
  };
  const current = () => {
    if (disposed) throw failure('FX_UNBOUND', 'JSFX connection is disposed');
    if (!active) throw failure('FX_STALE', 'JSFX editor is inactive');
    return activation;
  };
  const cancelQueued = error => { for (const item of queue) item.reject(error); queue = []; };
  const apply = next => {
    if (disposed || next.sessionId !== sessionId || next.activation < activation) return;
    const nextRevision = revisionOf(next.revision);
    if (next.activation > activation) { revision = 0n; observed.clear(); }
    const newerSnapshot = state && next.activation === activation && nextRevision < revision;
    const parameters = next.parameters.map(parameter => {
      const newer = observed.get(parameter.index);
      const merged = { ...parameter, ...(newer && newer.revision > nextRevision ? newer.parameter : {}) };
      observed.set(parameter.index, { revision: newer && newer.revision > nextRevision ? newer.revision : nextRevision, parameter: merged });
      return merged;
    });
    revision = nextRevision > revision ? nextRevision : revision;
    state = freeze({ ...(newerSnapshot ? state : next), parameters, revision: String(revision) });
    activation = next.activation; active = next.active;
    notify(listeners, state);
  };
  const merge = (parameters, nextRevision, eventActivation) => {
    if (disposed || eventActivation !== activation || !active) return;
    const nr = revisionOf(nextRevision), updated = state?.parameters.map(p => ({ ...p }));
    for (const parameter of parameters) {
      if (observed.get(parameter.index)?.revision > nr) continue;
      observed.set(parameter.index, { revision: nr, parameter });
      if (updated?.[parameter.index]) Object.assign(updated[parameter.index], parameter);
    }
    if (nr > revision) revision = nr;
    if (state) { state = freeze({ ...state, parameters: updated, revision: String(revision) }); notify(listeners, state); }
  };
  const refresh = async () => {
    if (disposed) throw failure('FX_UNBOUND', 'JSFX connection is disposed');
    const next = await invoke('getParamState'); apply(next); return state;
  };
  const getCapabilities = async () => {
    if (disposed) throw failure('FX_UNBOUND', 'JSFX connection is disposed');
    const request = ++capabilityRequest, next = await invoke('getCapabilities');
    if (request !== capabilityRequest) return capabilities;
    if (next.protocolVersion !== 1) throw failure('PROTOCOL_MISMATCH', 'Unsupported JSFX protocol version');
    if (sessionId && next.sessionId !== sessionId) {
      gesture = undefined; cancelQueued(failure('STALE_SESSION', 'The JSFX instance session changed'));
      revision = 0n; observed.clear(); dataRevisions.clear(); operationRevisions.clear(); state = undefined;
      await closeConsumers();
    }
    revisionOf(next.capabilityRevision);
    if (request !== capabilityRequest) return capabilities;
    if (sessionId === next.sessionId && capabilities && revisionOf(next.capabilityRevision) < revisionOf(capabilities.capabilityRevision)) return capabilities;
    sessionId = next.sessionId; capabilities = freeze(next); return capabilities;
  };
  const present = async () => {
    if (!active || disposed) return { presented: false };
    const at = activation;
    try { return await invoke('present', { activation: at }); }
    catch (error) { if (!disposed && active && activation === at) throw error; return { presented: false }; }
  };
  try {
    await getCapabilities();
    stops.push(await service.on('paramsChanged', event => {
      if (disposed || event.sessionId !== sessionId || event.activation < activation || (state && (!active || event.activation !== activation))) return;
      if (event.activation > activation) { activation = event.activation; revision = 0n; observed.clear(); }
      // Before the first snapshot only the delta is available.
      if (!state) {
        const nr = revisionOf(event.revision);
        if (nr > revision) revision = nr;
        for (const parameter of event.parameters)
          if (!observed.has(parameter.index) || observed.get(parameter.index).revision < nr)
            observed.set(parameter.index, { revision: nr, parameter });
      } else merge(event.parameters, event.revision, event.activation);
    }));
    stops.push(await service.on('capabilitiesChanged', event => {
      if (disposed || (event.sessionId === sessionId && revisionOf(event.capabilityRevision) <= revisionOf(capabilities.capabilityRevision))) return;
      getCapabilities().then(async () => { if (!state) await refresh(); notify(capabilityListeners, event); }).catch(onError);
    }));
    stops.push(await service.on('dataStateChanged', event => {
      if (disposed || event.sessionId !== sessionId) return;
      const next = revisionOf(event.revision);
      if ((dataRevisions.get(event.id) ?? -1n) >= next) return;
      dataRevisions.set(event.id, next); notify(dataListeners, freeze(event));
    }));
    stops.push(await service.on('operationChanged', event => {
      if (disposed || event.sessionId !== sessionId) return;
      const next = revisionOf(event.revision);
      if ((operationRevisions.get(event.operationId) ?? -1n) >= next) return;
      if (!operationRevisions.has(event.operationId) && operationRevisions.size >= 256) operationRevisions.delete(operationRevisions.keys().next().value);
      operationRevisions.set(event.operationId, next); notify(operationListeners, freeze(event));
    }));
    stops.push(await service.on('visibilityChanged', event => {
      if (disposed || event.sessionId !== sessionId || event.activation < activation) return;
      if (event.activation > activation) { revision = 0n; observed.clear(); }
      activation = event.activation; active = event.active; gesture = undefined;
      closeConsumers().catch(onError);
      cancelQueued(failure('FX_STALE', 'JSFX editor activation changed'));
      if (state) state = freeze({ ...state, active, activation });
      if (event.paramState) apply(event.paramState);
      notify(visibility, active);
      if (active) {
        const at = activation;
        getCapabilities().then(async () => {
          if (disposed || !active || activation !== at) return;
          if (!event.paramState) await refresh();
          if (active && activation === at) await present();
        }).catch(onError);
      }
    }));
    await refresh();
  } catch (error) { await Promise.allSettled(stops.map(off => off())); throw error; }
  // The caller renders the initial snapshot before native presentation.
  setTimeout(() => present().catch(onError), 0);
  const validIndex = index => {
    if (!Number.isInteger(index) || index < 0 || index >= state.count) throw failure('INVALID_ARGUMENT', 'Invalid parameter index');
    if (state.parameters[index]?.reserved || state.parameters[index]?.readOnly) throw failure('INVALID_ARGUMENT', 'The JSFX parameter is reserved');
  };
  const validValues = values => {
    if (!Array.isArray(values) || !values.length || values.length > 259) throw failure('INVALID_ARGUMENT', 'Expected bounded parameter values');
    const indices = new Set();
    for (const item of values) {
      if (!item || typeof item !== 'object') throw failure('INVALID_ARGUMENT', 'Expected parameter values');
      validIndex(item.index);
      if (indices.has(item.index) || !Number.isFinite(item.normalized) || item.normalized < 0 || item.normalized > 1)
        throw failure('INVALID_ARGUMENT', 'Expected unique indices and normalized values in [0,1]');
      indices.add(item.index);
    }
  };
  const drain = () => {
    if (running) return running;
    running = (async () => {
      while (queue.length) {
        const item = queue.shift();
        try {
          if (item.gesture) await item.gesture.opening;
          if (disposed || !active || item.activation !== activation || (item.gesture && gesture !== item.gesture))
            throw failure('FX_STALE', 'JSFX editor activation changed');
          const result = await invoke(item.group ? 'setParams' : 'setParam', {
            ...(item.group ? { values: item.values } : item.values[0]), activation: item.activation,
            ...(item.gesture ? { gestureId: item.gesture.id } : {})
          });
          if (disposed || !active || item.activation !== activation) throw failure('FX_STALE', 'JSFX editor activation changed');
          const parameters = item.group ? result.applied : [result.parameter];
          // A newer pending pointer value owns the display until its host reply.
          merge(parameters.filter(p => !queue.some(q => q.values.some(v => v.index === p.index))), result.revision, item.activation);
          item.resolve(item.group ? result : { applied: true, superseded: false, ...result });
        } catch (error) {
          item.reject(error);
          if (item.gesture) {
            item.gesture.error = error;
            cancelQueued(error);
            if (error.code === 'PARTIAL_WRITE') { gesture = undefined; refresh().catch(onError); }
          }
        }
      }
    })().finally(() => { running = undefined; });
    return running;
  };
  const enqueue = (values, group) => {
    const at = current(); validValues(values);
    if (gesture?.closing || (gesture && gesture.group !== group) || (group && !gesture))
      throw failure('GESTURE_BUSY', 'Finish the active parameter gesture first');
    if (gesture?.error) throw gesture.error;
    if (gesture && values.some(v => !gesture.indices.includes(v.index))) throw failure('INVALID_ARGUMENT', 'Parameter is outside the active gesture');
    if (gesture && !group) {
      const previous = queue.findIndex(item => item.gesture === gesture && !item.group && item.values[0].index === values[0].index);
      if (previous >= 0) queue.splice(previous, 1)[0].resolve({ applied: false, superseded: true });
    }
    if (queue.length >= 16) throw failure('QUEUE_LIMIT', 'JSFX parameter queue is full');
    const result = new Promise((resolve, reject) => queue.push({ values, group, gesture, activation: at, resolve, reject }));
    drain(); return result;
  };
  const begin = async (indices, group) => {
    const at = current();
    if (gesture || running || queue.length) throw failure('GESTURE_BUSY', 'Finish the active parameter operation first');
    validValues(indices.map(index => ({ index, normalized: 0 })));
    const g = { indices: [...indices], group, activation: at }; gesture = g;
    g.opening = invoke(group ? 'beginParamEditGroup' : 'beginParamEdit', { ...(group ? { indices } : { index: indices[0] }), activation: at });
    try {
      const result = await g.opening; g.id = result.gestureId;
      if (disposed || !active || activation !== at) throw failure('FX_STALE', 'JSFX editor activation changed');
      return result;
    } catch (error) { if (gesture === g) gesture = undefined; g.error = error; cancelQueued(error); throw error; }
  };
  const finish = async group => {
    const g = gesture;
    if (!g) return state;
    if (g.group !== group) throw failure('GESTURE_BUSY', 'Finish the active parameter gesture first');
    g.closing = true;
    try {
      await g.opening;
      if (running) await running;
      if (g.error) throw g.error;
    } finally {
      try { if (g.id) await invoke(group ? 'endParamEditGroup' : 'endParamEdit', { gestureId: g.id, activation: g.activation }); }
      finally { if (gesture === g) gesture = undefined; }
    }
    return refresh();
  };
  const native = (category, id) => {
    if (disposed) throw failure('FX_UNBOUND', 'JSFX connection is disposed');
    if (capabilities.status === 'parameterOnly') throw failure('UNSUPPORTED', 'This JSFX has no native data channel');
    if (category && (!capabilities[category]?.some(item => item.id === id))) throw failure('CAPABILITY_UNAVAILABLE', 'The JSFX capability is not declared');
  };
  const operation = async (method, data, options = {}) => {
    if (!options || typeof options !== 'object' || Array.isArray(options)) throw failure('INVALID_ARGUMENT', 'Expected JSFX operation options');
    const requestId = options.requestId ?? globalThis.crypto.randomUUID();
    try { return freeze(await invoke(method, { ...data, requestId, activation: current() })); }
    catch (error) { error.requestId = requestId; throw error; }
  };
  const rememberTransfer = (info, upload, total, renew) => {
    const at = current(), session = sessionId;
    const validate = () => { if (current() !== at || sessionId !== session) throw failure('STALE_SESSION', 'JSFX resource session changed'); };
    const previous = transfers.get(info.transferId);
    if (!previous) transfers.set(info.transferId, resourceChannel(info, upload, total, renew, validate, failure));
    const { transport, pending, ...publicInfo } = info; return freeze(publicInfo);
  };
  const resourceTransfer = (id, upload) => {
    native();
    const transfer = transfers.get(id);
    if (!transfer || transfer.upload !== upload) throw failure('TRANSFER_NOT_FOUND', 'JSFX resource transfer not found');
    return transfer;
  };
  if (globalThis.addEventListener) {
    const release = () => {
      continuousFocused = false;
      releaseCommands().catch(error => {
        if (!['FX_UNBOUND','FX_STALE','STALE_SESSION'].includes(error.code)) onError(error);
      });
    };
    const focus = () => { continuousFocused = true; };
    globalThis.addEventListener('blur', release);
    globalThis.addEventListener('focus', focus);
    stops.push(async () => {
      globalThis.removeEventListener('blur', release);
      globalThis.removeEventListener('focus', focus);
    });
  }
  return Object.freeze({
    params: Object.freeze({
      get snapshot() { return state; }, getState: refresh,
      onChange: fn => subscribe(listeners, fn),
      beginEdit: index => begin([index], false),
      set: async (index, normalized) => enqueue([{ index, normalized }], false),
      endEdit: () => finish(false),
      beginEditGroup: async indices => {
        if (!Array.isArray(indices)) throw failure('INVALID_ARGUMENT', 'Expected parameter indices');
        return begin(indices, true);
      },
      setMany: async values => { validValues(values); return enqueue(values.map(v => ({ index: v.index, normalized: v.normalized })), true); },
      endEditGroup: () => finish(true),
      async reset(index) {
        current(); validIndex(index);
        if (gesture) throw failure('GESTURE_BUSY', 'Finish the active parameter gesture first');
        const value = state.parameters[index]?.defaultNormalized;
        if (value === null || value === undefined) throw failure('UNSUPPORTED', 'REAPER does not expose a default for this parameter');
        await enqueue([{ index, normalized: value }], false); return refresh();
      }
    }),
    dataState: Object.freeze({
      async get(id) { native('dataStates', id); return freeze(await invoke('getDataState', { id })); },
      async set(id, value, options) {
        native('dataStates', id); revisionOf(options?.expectedRevision);
        return operation('setDataState', { id, value, expectedRevision: options.expectedRevision }, options);
      },
      async onChange(id, fn) {
        native('dataStates', id);
        if (typeof fn !== 'function') throw failure('INVALID_ARGUMENT', 'Expected a listener');
        return subscribe(dataListeners, event => { if (event.id === id) fn(event); });
      }
    }),
    streams: Object.freeze({ async open(id, options = {}) {
      native('streams', id); const at = current(), session = sessionId;
      const opened = await invoke('openStream', { id, options, activation: at });
      const stream = await reaper.stream.open(opened.streamName);
      if (disposed || !active || activation !== at || sessionId !== session) {
        await stream.close(); throw failure('FX_STALE', 'JSFX editor activation changed');
      }
      consumers.add(stream); stream.on('close', () => consumers.delete(stream)); return stream;
    } }),
    commands: Object.freeze({
      async invoke(id, args, options) {
        native('commands', id);
        if (!continuousFocused && capabilities.commands.some(command => command.id === id && command.continuous))
          throw failure('FX_STALE', 'The JSFX editor lost focus');
        return operation('invokeCommand', { id, args }, options);
      },
      async release() { native(); return releaseCommands(); }
    }),
    operations: Object.freeze({
      async get(operationId) { native(); return freeze(await invoke('getOperation', { operationId })); },
      async find(requestId) { native(); return freeze(await invoke('findOperation', { requestId })); },
      async cancel(operationId) { native(); return freeze(await invoke('cancelOperation', { operationId })); },
      async onChange(fn) { native(); return subscribe(operationListeners, fn); }
    }),
    resources: Object.freeze({
      async beginUpload(id, options) {
        native('resources', id);
        if (!options || !Number.isSafeInteger(options.totalBytes) || options.totalBytes < 0) throw failure('INVALID_ARGUMENT', 'Expected JSFX upload options');
        const requestId = options.requestId ?? globalThis.crypto.randomUUID();
        const data = { id, format: options.format, totalBytes: options.totalBytes, metadata: options.metadata ?? {} };
        const renew = () => operation('beginResourceUpload', data, { requestId });
        const info = await renew();
        return rememberTransfer(info, true, options.totalBytes, renew);
      },
      async writeChunk(transferId, offset, bytes) { return freeze(await resourceTransfer(transferId, true).exchange(offset, bytes)); },
      async commitUpload(transferId, options) {
        native(); revisionOf(options?.expectedRevision);
        if (typeof options.checksum !== 'string' || !/^[a-f0-9]{64}$/.test(options.checksum)) throw failure('INVALID_ARGUMENT', 'Expected a SHA-256 hex checksum');
        const result = await operation('commitResourceUpload', { transferId, expectedRevision: options.expectedRevision, checksum: options.checksum }, options);
        transfers.get(transferId)?.close(); transfers.delete(transferId); return result;
      },
      async abortUpload(transferId) {
        native(); transfers.get(transferId)?.close(); transfers.delete(transferId);
        return freeze(await invoke('abortResourceUpload', { transferId }));
      },
      async openDownload(id, options = {}) {
        native('resources', id); const at = current(), session = sessionId;
        if (options.revision !== undefined) revisionOf(options.revision);
        const data = { id, ...(options.revision === undefined ? {} : { revision: options.revision }) };
        let info; const deadline = Date.now() + 300000;
        const renew = () => invoke('openResourceDownload', { ...data, ...(info?.transferId ? { transferId: info.transferId } : {}), activation: current() });
        try {
          do {
            if (Date.now() >= deadline) throw failure('TIMEOUT', 'JSFX download snapshot timed out');
            if (current() !== at || sessionId !== session) throw failure('STALE_SESSION', 'JSFX resource session changed');
            info = await renew();
            if (info.pending) await new Promise(resolve => setTimeout(resolve, 30));
          } while (info.pending);
          return rememberTransfer(info, false, info.totalBytes, renew);
        } catch (error) {
          if (info?.transferId) await invoke('closeResourceDownload', { transferId: info.transferId }).catch(() => {});
          throw error;
        }
      },
      async readChunk(transferId, offset, length) { return resourceTransfer(transferId, false).exchange(offset, length); },
      async closeDownload(transferId) {
        native(); transfers.get(transferId)?.close(); transfers.delete(transferId);
        return freeze(await invoke('closeResourceDownload', { transferId }));
      }
    }),
    get active() { return active && !disposed; },
    getCapabilities, getDiagnostics: () => invoke('getDiagnostics'), present,
    onCapabilitiesChange: fn => subscribe(capabilityListeners, fn),
    onVisibilityChange: fn => subscribe(visibility, fn),
    dispose() {
      if (disposePromise) return disposePromise;
      const g = gesture; disposed = true; cancelQueued(failure('FX_UNBOUND', 'JSFX connection is disposed'));
      disposePromise = (async () => {
        try {
          if (g?.opening) { try { await g.opening; } catch {} }
          if (running) await running;
          if (g?.id) {
            try { await invoke(g.group ? 'endParamEditGroup' : 'endParamEdit', { gestureId: g.id, activation: g.activation }); }
            catch (error) {
              if (!['FX_UNBOUND', 'FX_STALE', 'STALE_SESSION'].includes(error.code)) throw error;
            }
          }
        } finally {
          await closeConsumers();
          const results = await Promise.allSettled(stops.map(off => off()));
          listeners.clear(); visibility.clear(); capabilityListeners.clear(); dataListeners.clear(); operationListeners.clear();
          const error = results.find(r => r.status === 'rejected'); if (error) throw error.reason;
        }
      })();
      return disposePromise;
    }
  });
}
