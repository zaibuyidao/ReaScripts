'use strict';
const el = id => document.getElementById(id), canvas = el('view'), ctx = canvas.getContext('2d');
let current = null, watching = null, queued = false;
const frameCanvas = document.createElement('canvas');
const show = value => JSON.stringify(value, (_, item) => typeof item === 'bigint' ? String(item) : item, 2);
const report = error => { el('status').textContent = `${error.code || 'ERROR'}: ${error.message}`; };
const action = fn => async () => { try { await fn(); } catch (error) { report(error); } };
function draw() {
  queued = false;
  const packet = current?.latest(); if (!packet) return;
  const info = current.info, data = packet.data;
  el('status').textContent = `${info.kind} · sequence ${packet.sequence} · producer drops ${packet.producerDropped} · consumer drops ${current.dropped}`;
  ctx.fillStyle = '#10141c'; ctx.fillRect(0, 0, canvas.width, canvas.height);
  if (info.kind === 'frame') {
    const pixels = new Uint8ClampedArray(info.width * info.height * 4);
    for (let y = 0; y < info.height; ++y) pixels.set(packet.bytes.subarray(y * info.stride, y * info.stride + info.width * 4), y * info.width * 4);
    if (info.format === 'bgra8') for (let i = 0; i < pixels.length; i += 4) [pixels[i], pixels[i + 2]] = [pixels[i + 2], pixels[i]];
    const image = frameCanvas; if (image.width !== info.width || image.height !== info.height) { image.width = info.width; image.height = info.height; }
    image.getContext('2d').putImageData(new ImageData(pixels, info.width, info.height), 0, 0);
    ctx.imageSmoothingEnabled = false; ctx.drawImage(image, 0, 0, canvas.width, canvas.height);
  } else if (info.kind === 'midi') {
    const view = new DataView(packet.bytes.buffer, packet.bytes.byteOffset, packet.bytes.byteLength);
    el('info').textContent = `Device ${view.getUint32(0, true) & 65535}: ` + Array.from(packet.bytes.subarray(16), byte => byte.toString(16).padStart(2, '0')).join(' ');
    while (current.read()) {}
  } else if (info.kind === 'meter') {
    ctx.fillStyle = '#71d5b0';
    for (let channel = 0; channel < info.channels; ++channel) ctx.fillRect(20, 30 + channel * 60, Math.min(1, data[channel]) * 820, 32);
    el('info').textContent = show({ peak: Array.from(data.slice(0, info.channels)), rms: Array.from(data.slice(info.channels, info.channels * 2)), lufs: Array.from(data.slice(info.channels * 2, info.channels * 2 + 3), value => Number.isFinite(value) ? value.toFixed(1) : '−∞') });
  } else if (data instanceof Float32Array) {
    const stride = info.kind === 'waveform' ? info.channels * 2 : info.channels || 1;
    ctx.strokeStyle = '#71d5b0'; ctx.beginPath();
    for (let i = 0, count = Math.floor(data.length / stride); i < count; ++i) {
      const x = i * canvas.width / Math.max(1, count - 1);
      const value = info.kind === 'spectrum' ? Math.max(-90, 20 * Math.log10(Math.max(1e-8, data[i * stride]))) / 90 + 1 : (data[i * stride] + 1) / 2;
      const y = canvas.height * (1 - value); if (i) ctx.lineTo(x, y); else ctx.moveTo(x, y);
    }
    ctx.stroke(); if (info.kind === 'audio') while (current.read()) {}
  } else el('info').textContent = `${packet.bytes.length} bytes`;
}
async function detach() { if (current) await current.close(); current = null; el('close').disabled = true; }
el('open').onclick = action(async () => {
  await detach();
  const kind = el('kind').value;
  current = kind === 'named stream' ? await reaper.stream.open(el('name').value) : kind === 'midi' ? await reaper.system.openMIDIInput(Number(el('midi').value)) : await reaper.audio.openStream(kind, { source: el('source').value, fftSize: 2048, updateRate: 30 });
  el('info').textContent = show(current.info); el('close').disabled = false;
  current.on('data', () => { if (!queued) { queued = true; requestAnimationFrame(draw); } });
  current.on('error', report); current.on('close', error => { el('status').textContent = error.code; el('close').disabled = true; });
});
el('close').onclick = action(detach);
el('devices').onclick = action(async () => { el('events').textContent = show({ devices: await reaper.system.getDevices(), displays: await reaper.system.getDisplays() }); });
el('watch').onclick = action(async () => {
  const path = await reaper.dialog.selectFolder({ title: 'Watch folder' }); if (!path) return;
  if (watching) await watching();
  watching = await reaper.fs.watch(path, event => { el('events').textContent = show(event); });
  el('unwatch').disabled = false; el('events').textContent = `Watching ${path}`;
});
el('unwatch').onclick = action(async () => { if (watching) await watching(); watching = null; el('unwatch').disabled = true; });
(async () => {
  await reaper.lifecycle.ready;
  for (const device of (await reaper.system.getDevices()).midiInputs) { const option = document.createElement('option'); option.value = device.id; option.textContent = `${device.name}${device.present ? '' : ' (offline)'}`; el('midi').append(option); }
  el('open').disabled = false; el('status').textContent = 'Ready';
})().catch(report);
