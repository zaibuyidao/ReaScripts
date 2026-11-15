const MAX_PENDING_BYTES = 16 * 1024 * 1024;
const SLICE_BYTES = 256 * 1024;
const active = new WeakSet();
const error = (code, message) => Object.assign(new Error(message), { code });

export function captureScreen(emulator) {
  const setting = (name, fallback) => emulator.getSettingValue(name) || fallback;
  const fps = setting('screenRecordingFPS', emulator.capture.video.fps);
  const upscale = setting('screenRecordUpscale', emulator.capture.video.upscale);
  const aspect = emulator.gameManager.getVideoDimensions('aspect') || 1.333333;
  const rotation = parseInt(setting('videoRotation', 0));
  const turned = rotation === 1 || rotation === 3;
  const canvas = document.createElement('canvas');
  const context = canvas.getContext('2d', { alpha: false });
  let frame, stream, merger, destination, offsetX = 0, offsetY = 0, closed = false;
  const sources = [];
  const resize = () => {
    let width = emulator.canvas.width, height = emulator.canvas.height;
    const originalAspect = width / height;
    if (width >= height) width = height * (turned ? 1 / aspect : aspect);
    else height = width / (turned ? 1 / aspect : aspect);
    canvas.width = width * upscale;
    canvas.height = height * upscale;
    context.imageSmoothingEnabled = false;
    context.scale(upscale, upscale);
    offsetX = originalAspect > width / height ? (emulator.canvas.width - width) / -2 : 0;
    offsetY = originalAspect < width / height ? (emulator.canvas.height - height) / -2 : 0;
  };
  const dispose = () => {
    if (closed) return;
    closed = true;
    cancelAnimationFrame(frame);
    emulator.canvas.removeEventListener('resize', resize);
    for (const source of sources) { try { source.disconnect(merger); } catch {} }
    merger?.disconnect();
    destination?.disconnect();
    for (const track of stream?.getTracks() || []) track.stop();
    canvas.width = canvas.height = 0;
    canvas.remove();
  };
  try {
    resize();
    emulator.canvas.addEventListener('resize', resize);
    stream = canvas.captureStream(fps);
    if (!stream.getVideoTracks().length) throw new Error('Unable to capture video stream');
    const al = emulator.Module?.AL?.currentCtx;
    const gains = Object.values(al?.sources || {}).map(source => source.gain).filter(Boolean);
    if (al?.audioCtx && gains.length) {
      merger = al.audioCtx.createChannelMerger(gains.length);
      destination = al.audioCtx.createMediaStreamDestination();
      for (const gain of gains) { gain.connect(merger); sources.push(gain); }
      merger.connect(destination);
      for (const track of destination.stream.getAudioTracks()) stream.addTrack(track);
    }
    const draw = () => {
      if (closed) return;
      context.drawImage(emulator.canvas, offsetX, offsetY, emulator.canvas.width, emulator.canvas.height);
      frame = requestAnimationFrame(draw);
    };
    frame = requestAnimationFrame(draw);
    return { stream, dispose };
  } catch (failure) { dispose(); throw failure; }
}

/** Recording bytes are retained only until their sequential native write completes. */
export async function startRecording(emulator, {
  host = globalThis.reaper,
  Recorder = globalThis.MediaRecorder,
  capture = captureScreen,
  page = globalThis,
} = {}) {
  if (active.has(emulator)) throw error('WRITE_BUSY', 'A recording is already in progress');
  active.add(emulator);
  let writer, media, recorder, detach = () => {};
  let failure, finishing = false, stopping = false, tail = Promise.resolve();
  let pendingBytes = 0, peakPendingBytes = 0, totalBytes = 0, writtenBytes = 0;
  let resolveDone, rejectDone;
  const done = new Promise((resolve, reject) => { resolveDone = resolve; rejectDone = reject; });
  done.catch(() => {});
  const cleanup = () => {
    detach();
    media?.dispose();
    active.delete(emulator);
  };
  const finish = async () => {
    if (finishing) return;
    finishing = true;
    try {
      media?.dispose();
      await tail;
      if (failure) throw failure;
      const result = await writer.commit();
      resolveDone(result);
    } catch (problem) {
      try {
        const state = await writer.abort();
        if (state.state === 'committed') { resolveDone({ path: state.path, bytes: state.bytes }); return; }
        if (state.cleanupPending) problem.cleanupPending = true;
      } catch (cleanupError) {
        problem = Object.assign(error('WRITE_RESULT_UNKNOWN', 'Cannot confirm the recording file result'), { cause: problem, cleanupError });
      }
      rejectDone(problem);
    } finally { cleanup(); }
  };
  const stop = () => {
    if (stopping) return;
    stopping = true;
    if (recorder.state !== 'inactive') {
      try { recorder.stop(); } catch (problem) { failure ||= problem; void finish(); }
    } else void finish();
  };
  const fail = problem => { failure ||= problem; stop(); };
  try {
    const limits = (await host?.system?.getCapabilities())?.runtime?.fs?.streamingWrite;
    if (!host?.fs?.openWrite || !limits) throw new Error('Recording requires ReaWebAPI 0.3.9.44 or later with streaming file writes');
    const format = emulator.getSettingValue('screenRecordFormat') || emulator.capture.video.format;
    if (typeof Recorder !== 'function' || !Recorder.isTypeSupported('video/' + format)) {
      throw new Error('The selected recording format is not supported');
    }
    const name = String(emulator.getBaseFileName()).split(/[\\/]/).pop().replace(/[\x00-\x1f]/g, '_');
    const path = await host.dialog.saveFile({ title: 'Record video', initialPath: `${name}-${new Date().toISOString().replace(/[:.]/g, '-')}.${format}` });
    if (path === null) { active.delete(emulator); return null; }
    writer = await host.fs.openWrite(path, { overwrite: true });
    const size = Math.min(SLICE_BYTES, writer.maxChunkBytes);
    if (!Number.isSafeInteger(size) || size < 1) throw new Error('Invalid writer chunk size');
    media = capture(emulator);
    recorder = new Recorder(media.stream, {
      mimeType: 'video/' + format,
      videoBitsPerSecond: emulator.getSettingValue('screenRecordVideoBitrate') || emulator.capture.video.videoBitrate,
      audioBitsPerSecond: emulator.getSettingValue('screenRecordAudioBitrate') || emulator.capture.video.audioBitrate,
    });
    recorder.addEventListener('dataavailable', event => {
      const blob = event.data;
      if (failure || !blob.size) return;
      if (pendingBytes + blob.size > MAX_PENDING_BYTES) {
        fail(error('RECORDING_BACKLOG', 'Recording stopped: buffered data exceeded 16 MiB. No recording file was committed.'));
        return;
      }
      if (totalBytes + blob.size > limits.maxFileBytes) {
        fail(error('BUFFER_LIMIT', 'Recording exceeded the host file-size limit'));
        return;
      }
      totalBytes += blob.size;
      pendingBytes += blob.size;
      peakPendingBytes = Math.max(peakPendingBytes, pendingBytes);
      tail = tail.then(async () => {
        try {
          if (failure) return;
          for (let at = 0; at < blob.size; at += size) {
            const bytes = new Uint8Array(await blob.slice(at, at + size).arrayBuffer());
            if (failure) return;
            const result = await writer.write(bytes);
            writtenBytes = result.totalBytes;
          }
        } catch (problem) { fail(problem); }
        finally { pendingBytes -= blob.size; }
      });
    });
    recorder.addEventListener('error', event => fail(event.error || new Error('Video recording failed')));
    recorder.addEventListener('stop', () => { stopping = true; void finish(); });
    const leave = () => { fail(error('WRITE_CANCELLED', 'Recording cancelled because the page closed')); media.dispose(); };
    page.addEventListener('pagehide', leave, { once: true });
    detach = () => page.removeEventListener('pagehide', leave);
    recorder.start(1000);
    return {
      stop, done,
      cancel: () => fail(error('WRITE_CANCELLED', 'Recording cancelled')),
      get stats() { return { pendingBytes, peakPendingBytes, totalBytes, writtenBytes }; },
    };
  } catch (problem) {
    try { if (writer) await writer.abort(); }
    catch (cleanupError) { problem = Object.assign(error('WRITE_RESULT_UNKNOWN', 'Cannot confirm recording cleanup'), { cause: problem, cleanupError }); }
    finally { cleanup(); }
    throw problem;
  }
}
