'use strict';
const $ = id => document.getElementById(id);
const pending = new Map(), subscriptions = new Set(), streams = new Map();
let socket = null, sequence = 0;
function log(label, value) {
  const line = `${label}${value === undefined ? '' : '\n' + JSON.stringify(value, null, 2)}\n\n`;
  $('log').textContent = ($('log').textContent + line).slice(-64000);
  $('log').scrollTop = $('log').scrollHeight;
}
function call(method, params = {}) {
  if (!socket || socket.readyState !== WebSocket.OPEN) return Promise.reject(new Error('Connect first.'));
  const id = ++sequence;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`${method}: response timeout`)); }, 35000);
    pending.set(id, {resolve, reject, timer});
    socket.send(JSON.stringify({type: 'request', id, method, params}));
  });
}
function disconnected() {
  $('commands').disabled = true;
  $('connect').disabled = false;
  $('disconnect').disabled = true;
  $('status').textContent = 'Disconnected';
  for (const entry of pending.values()) { clearTimeout(entry.timer); entry.reject(new Error('Connection closed.')); }
  pending.clear(); subscriptions.clear();
  for (const entry of streams.values()) entry.socket.close();
  streams.clear();
}
async function connect() {
  const port = Number($('port').value), token = $('token').value.trim();
  if (!Number.isInteger(port) || port < 1 || port > 65535 || !token) throw new Error('Enter a valid port and access token.');
  $('connect').disabled = true;
  $('status').textContent = 'Connecting';
  const connection = socket = new WebSocket(`ws://127.0.0.1:${port}`);
  connection.onmessage = event => {
    const message = JSON.parse(event.data);
    if (message.type === 'event') { log(message.service ? `${message.service}.${message.event}` : message.event, message); return; }
    const entry = pending.get(message.id);
    if (!entry) return;
    pending.delete(message.id); clearTimeout(entry.timer);
    if (message.error) entry.reject(new Error(`${message.error.code}: ${message.error.message}`));
    else entry.resolve(message.result);
  };
  connection.onclose = () => { if (socket === connection) { socket = null; disconnected(); log('Disconnected. Session resources released by the server.'); } };
  await new Promise((resolve, reject) => { connection.onopen = resolve; connection.onerror = () => reject(new Error('Connection failed. Check REAPER Preferences and the port.')); });
  log('Authenticated', await call('auth.authenticate', {token, protocolVersion: 1}));
  $('commands').disabled = false; $('disconnect').disabled = false; $('status').textContent = 'Connected';
  log('system.getInfo', await call('system.getInfo'));
}
function action(id, handler) { $(id).onclick = () => Promise.resolve().then(handler).catch(error => log('Error', error.message)); }
action('connect', connect);
action('disconnect', () => socket?.close());
action('info', async () => log('system.getInfo', await call('system.getInfo')));
action('capabilities', async () => log('system.getCapabilities', await call('system.getCapabilities')));
action('call', async () => log('CountTracks', await call('api.call', {name: 'CountTracks', args: [0]})));
action('batch', async () => log('api.batch', await call('api.batch', {calls: [{method: 'CountTracks', args: [0]}, {method: 'GetPlayState', args: []}]})));
action('service', async () => log('runtime.getInfo', await call('service.invoke', {service: 'runtime', method: 'getInfo'})));
action('subscribe', async () => {
  const result = await call('events.subscribe', {event: 'transportChanged'});
  subscriptions.add(result.subscriptionId); log('Subscribed', result);
});
action('unsubscribe', async () => {
  for (const subscriptionId of subscriptions) { await call('events.unsubscribe', {subscriptionId}); subscriptions.delete(subscriptionId); }
  log('Unsubscribed');
});
action('open-stream', async () => {
  const descriptor = await call('stream.open', {name: $('stream-name').value.trim()});
  const binary = new WebSocket(descriptor.endpoint); binary.binaryType = 'arraybuffer';
  const entry = {socket: binary, frames: 0, reported: 0}; streams.set(descriptor.consumerId, entry);
  binary.onmessage = event => {
    const view = new DataView(event.data);
    if (view.byteLength < 40 || view.getUint32(0, false) !== 0x52575301) { binary.close(); log('Invalid stream packet'); return; }
    ++entry.frames;
    if (performance.now() - entry.reported > 1000 || entry.frames === 1) {
      entry.reported = performance.now();
      log('Stream', {name: descriptor.info.name, frames: entry.frames, sequence: view.getBigUint64(8, true).toString(), bytes: view.byteLength - 40});
    }
    binary.send(new Uint8Array([1]));
  };
  binary.onerror = () => log('Stream connection failed');
  binary.onclose = () => log('Stream connection closed', descriptor.info.name);
  log('Stream opened', {consumerId: descriptor.consumerId, info: descriptor.info});
});
action('close-stream', async () => {
  for (const [consumerId, entry] of streams) {
    await call('stream.close', {consumerId}); entry.socket.close(); streams.delete(consumerId);
  }
  log('Streams closed');
});
$('clear').onclick = () => { $('log').textContent = ''; };
