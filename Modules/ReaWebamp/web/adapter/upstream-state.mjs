// Version-bound integration for settings, resource ownership and layout recovery.
export const SETTINGS_KEY = 'reawebamp.settings.v1';
const bands = ['preamp', '60', '170', '310', '600', '1000', '3000', '6000', '12000', '14000', '16000'];
const percent = n => Number.isFinite(n) && n >= 0 && n <= 100;
export function restoreSettings(player, storage = localStorage) {
  let saved;
  try { saved = JSON.parse(storage.getItem(SETTINGS_KEY)); } catch { return; }
  if (!saved || saved.version !== 1) return;
  if (percent(saved.volume)) player.setVolume(saved.volume);
  if (Number.isFinite(saved.balance) && saved.balance >= -100 && saved.balance <= 100)
    player.store.dispatch({ type:'SET_BALANCE', balance:saved.balance });
  if (typeof saved.shuffle === 'boolean' && saved.shuffle !== player.isShuffleEnabled()) player.toggleShuffle();
  if (typeof saved.repeat === 'boolean' && saved.repeat !== player.isRepeatEnabled()) player.toggleRepeat();
  if (typeof saved.doubleSize === 'boolean' && saved.doubleSize !== player.store.getState().display.doubled) player.store.dispatch({ type:'TOGGLE_DOUBLESIZE_MODE' });
  if (typeof saved.eq?.on === 'boolean') player.store.dispatch({ type:saved.eq.on ? 'SET_EQ_ON' : 'SET_EQ_OFF' });
  if (typeof saved.eq?.auto === 'boolean') player.store.dispatch({ type:'SET_EQ_AUTO', value:saved.eq.auto });
  const positions={};
  for(const [id,window] of Object.entries(saved.windows||{})) {
    const current=player.store.getState().windows.genWindows[id];if(!current)continue;
    if(Number.isFinite(window.x)&&Number.isFinite(window.y))positions[id]={x:Math.max(0,Math.min(3000,window.x)),y:Math.max(0,Math.min(3000,window.y))};
    if(current.canResize&&Array.isArray(window.size)&&window.size.length===2&&window.size.every(n=>Number.isInteger(n)&&n>=0&&n<=50))player.store.dispatch({type:'WINDOW_SIZE_CHANGED',windowId:id,size:window.size});
    if(current.canShade&&typeof window.shade==='boolean'&&current.shade!==window.shade)player.store.dispatch({type:'TOGGLE_WINDOW_SHADE_MODE',windowId:id});
    if(id!=='main'&&typeof window.open==='boolean'&&current.open!==window.open)player.store.dispatch({type:'TOGGLE_WINDOW',windowId:id});
  }
  if(Object.keys(positions).length)player.store.dispatch({type:'UPDATE_WINDOW_POSITIONS',absolute:true,positions});
  for (const band of bands) if (percent(saved.eq?.sliders?.[band]))
    player.store.dispatch({ type:'SET_BAND_VALUE', band, value:saved.eq.sliders[band] });
}
export function settingsSnapshot(player) {
  const {media, equalizer, display, windows} = player.store.getState();
  return JSON.stringify({ version:1, volume:media.volume, balance:media.balance, shuffle:media.shuffle,
    repeat:media.repeat, doubleSize:display.doubled, windows:Object.fromEntries(Object.entries(windows.genWindows).map(([id,w])=>[id,{x:w.position.x,y:w.position.y,size:w.size,open:w.open,shade:w.shade}])), eq:{ on:equalizer.on, auto:equalizer.auto, sliders:equalizer.sliders } });
}
export function ownObjectUrls() {
  const blobs = new Map(), create = URL.createObjectURL, revoke = URL.revokeObjectURL;
  URL.createObjectURL = function(blob) { const url = create.call(URL, blob); blobs.set(url, blob); return url; };
  URL.revokeObjectURL = function(url) { blobs.delete(String(url)); return revoke.call(URL, url); };
  return { blobs, dispose() {
    for (const url of blobs.keys()) revoke.call(URL, url);
    blobs.clear(); URL.createObjectURL = create; URL.revokeObjectURL = revoke;
  } };
}
export function disposePlayer(player) {
  player.stop();
  const context = player.media._context;
  const audio = player.media._source._audio;
  player.dispose();
  audio.removeAttribute('src'); audio.load();
  if (context.state !== 'closed') void context.close().catch(console.error);
}
