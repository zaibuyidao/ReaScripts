'use strict';
const log = document.querySelector('#log');
const write = (name, data) => {
  const lines = log.textContent.split('\n').filter(Boolean);
  lines.push(`${name}: ${JSON.stringify(data)}`);
  log.textContent = lines.slice(-100).join('\n'); log.scrollTop = log.scrollHeight;
};
const names = ['trackSelectionChanged','trackStateChanged','transportChanged','projectChanged',
  'markersChanged','regionsChanged','currentRegionChanged','loopPointsChanged','timeSelectionChanged'];
let disposers = [], serviceDisposers = [], busy = false;
const run = async action => {
  try { await action(); } catch (error) { write(error.code || 'ERROR', error.message); }
};
const unsubscribe = async () => {
  const all = [...disposers, ...serviceDisposers]; disposers = []; serviceDisposers = [];
  await Promise.all(all.map(dispose => dispose()));
};
const subscribe = async () => {
  if (busy) return;
  busy = true;
  try {
    await unsubscribe();
    for (const name of names) disposers.push(await reaper.events.on(name, data => write(name, data)));
    disposers.push(await reaper.events.on('message', data => write('Lua echo', data)));
    const service = reaper.host.service('test');
    try {
      serviceDisposers.push(await service.on('changed', data => write('test.changed', data)));
      serviceDisposers.push(await service.on('unloaded', data => write('test.unloaded', data)));
    } catch (error) { write(error.code, 'Optional test extension is not registered'); }
  } finally { busy = false; }
};
for (const button of document.querySelectorAll('button')) button.disabled = true;
run(async () => {
  await reaper.lifecycle.ready;
  const info = await reaper.host.service('runtime').invoke('getInfo');
  document.querySelector('#status').textContent = `Connected · v${info.version} · Native runtime active`;
  for (const button of document.querySelectorAll('button')) button.disabled = false;
  const actions = {
    subscribe, unsubscribe,
    ping: async () => write('test.ping', await reaper.host.service('test').invoke('ping')),
    send: () => reaper.host.service('test').send('message', {text:'Hello from WebView'}),
    pending: async () => write('test.pending', await reaper.host.service('test').invoke('pending')),
    unregister: () => reaper.host.service('test').send('unregister'),
    lua: () => reaper.host.send({method:'echo',payload:'Lua and Native coexist'}),
    dock: async () => reaper.window.setDocked(!await reaper.window.isDocked()),
    clear: () => { log.textContent = ''; }
  };
  for (const [id, action] of Object.entries(actions)) document.getElementById(id).onclick = () => run(action);
  await reaper.lifecycle.on('cleanup', unsubscribe);
  await subscribe();
});
