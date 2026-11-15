import { installDownloadHandler } from './vendor/browser-files.mjs';

export async function connectHost(onError) {
  if (!globalThis.reaper?.lifecycle) return;
  await reaper.lifecycle.ready;
  await reaper.window.setKeyboardCapture(true);
  await reaper.window.setDawKeyboard(false);
  const dispose = installDownloadHandler({ onError });
  const click = HTMLAnchorElement.prototype.click;
  // EmulatorJS exports through detached anchors. Connect them for the SDK's capture listener.
  HTMLAnchorElement.prototype.click = function () {
    if (!this.isConnected && this.hasAttribute('download') && /^(blob|data):/.test(this.href)) {
      this.hidden = true;
      document.body.append(this);
      try { return click.call(this); } finally { this.remove(); }
    }
    return click.call(this);
  };
  addEventListener('pagehide', () => { dispose(); HTMLAnchorElement.prototype.click = click; }, { once: true });
}

export async function capabilities() {
  const canvas = document.createElement('canvas');
  const gl = canvas.getContext('webgl2');
  const result = {
    userAgent: navigator.userAgent, origin: location.origin,
    wasm: typeof WebAssembly === 'object', webgl2: !!gl,
    indexedDB: typeof indexedDB !== 'undefined', audio: !!(window.AudioContext || window.webkitAudioContext),
    gamepad: typeof navigator.getGamepads === 'function',
    crossOriginIsolated: !!window.crossOriginIsolated, sharedArrayBuffer: false,
    wasmSharedMemory: false, worker: null, blobWorker: null,
    mediaRecorder: typeof MediaRecorder === 'function',
  };
  gl?.getExtension('WEBGL_lose_context')?.loseContext();
  try { result.sharedArrayBuffer = new SharedArrayBuffer(4).byteLength === 4; } catch {}
  try { result.wasmSharedMemory = new WebAssembly.Memory({ initial: 1, maximum: 1, shared: true }).buffer instanceof SharedArrayBuffer; } catch {}
  if (globalThis.reaper?.lifecycle) {
    result.host = await reaper.debug.getDiagnostics();
    const browser = result.host.webRuntime?.browser;
    result.worker = browser?.worker ?? null;
    result.blobWorker = browser?.blobWorker ?? null;
  }
  return result;
}

export async function requireCoreSupport(core, threads = false) {
  const needsThreads = threads || ['ppsspp', 'psp', 'dosbox_pure', 'dos'].includes(core);
  if (!needsThreads) return;
  const available = await capabilities();
  if (!available.crossOriginIsolated || !available.sharedArrayBuffer || !available.wasmSharedMemory ||
      (available.host && (available.worker !== true || available.blobWorker !== true))) {
    throw new Error('This core requires cross-origin isolation, shared WebAssembly memory and Workers. Use ReaWebAPI 0.3.9.43 or later with webRuntime.crossOriginIsolation="required", then close all App windows and reopen. Linux also requires WebKitGTK with isolated-process SharedArrayBuffer support.');
  }
  if (['ppsspp', 'psp'].includes(core) && !available.webgl2) {
    throw new Error('The PSP core requires WebGL2. Check the WebView graphics backend.');
  }
}
