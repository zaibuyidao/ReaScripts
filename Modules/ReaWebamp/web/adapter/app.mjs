import { installDownloadHandler } from './browser-files.mjs';
import { capabilities } from './diagnostics.mjs';
import { createLibrary } from './library.mjs';
import { createIntegration } from './integration.mjs';
import { createShell } from './shell.mjs';
import { installDesktop } from './desktop.mjs';
import { initializeLanguage, t, localizeMessage } from './i18n.mjs';
import { initializeWindow, installPlayerView } from './player-view.mjs';
import { SETTINGS_KEY, restoreSettings, settingsSnapshot, ownObjectUrls, disposePlayer } from './upstream-state.mjs';

export let player, library, integration;
export const diagnostics = capabilities();
let visualizationFailure = '';
try { visualizationFailure = sessionStorage.getItem('reawebamp.visualizationFailure') || ''; } catch {}
const useVisualization = diagnostics.webgl2 && diagnostics.webAssembly && !visualizationFailure;
let recovering = false;
function recoverVisualization(error) {
  if (disposed || !useVisualization || recovering || !/webgl|shader|butterchurn|webassembly|wasm/i.test(error?.message || String(error))) return false;
  recovering = true;
  try { sessionStorage.setItem('reawebamp.visualizationFailure', String(error?.message || error).slice(0,500)); } catch { recovering = false; return false; }
  reaper.window.reload().catch(report);
  return true;
}
const shell = createShell();
const report = error => { shell.report(localizeMessage(error?.message || String(error))); console.error(error); };
let urls, disposed = false, unsubs = [], saveTimer, previousTracks = new Set();
function cleanup(disposeShell = true) {
  if (disposed) return;
  disposed = true; clearTimeout(saveTimer);
  if (disposeShell) shell.dispose();
  for (const unsubscribe of unsubs.splice(0)) unsubscribe();
  if (player) { persist(); disposePlayer(player); }
  urls?.dispose();
}
function persist() {
  try { localStorage.setItem(SETTINGS_KEY, settingsSnapshot(player)); }
  catch (error) { report(new Error(t('saveError', {message:error.message}))); }
}

async function start() {
  await initializeLanguage();
  if (!window.reaper) throw new Error(t('launchError'));
  const hostCapabilities = await reaper.lifecycle.ready;
  if (!hostCapabilities.runtime?.fs?.mediaURLs) throw new Error(t('versionError'));
  if (!diagnostics.audioContext) throw new Error(t('audioUnsupported'));
  const savedSettings = localStorage.getItem(SETTINGS_KEY);
  const firstLayout = !savedSettings;
  await initializeWindow();
  urls = ownObjectUrls();
  unsubs.push(installDownloadHandler({ onError:report }));
  let Webamp;
  if (useVisualization) ({default:Webamp} = await import('../assets/webamp.butterchurn-bundle.min.mjs'));
  else ({default:Webamp} = await import('../assets/webamp.bundle.min.mjs'));
  if (Webamp.VERSION !== '2.3.1') throw new Error(t('versionMismatch'));
  const layout = { main:{position:{left:0,top:0}}, equalizer:{position:{left:0,top:116}},
    playlist:{position:{left:0,top:232},size:{extraHeight:0,extraWidth:0}} };
  if (useVisualization) layout.milkdrop = {position:{left:275,top:0},size:{extraHeight:8,extraWidth:0}};
  player = new Webamp({ initialTracks:[], enableHotkeys:true, enableMediaSession:false, windowLayout:layout,
    handleSaveListEvent:async tracks => { try { return await library.saveList(tracks); } catch(e) { report(e); return null; } },
    handleLoadListEvent:async () => { try { return await library.loadList(); } catch(e) { report(e); return null; } }
  });
  restoreSettings(player);
  library = await createLibrary(player, urls, report, () => integration?.modes.preserveTracks);
  try { integration = await createIntegration(player, library, urls, report); }
  catch(error) { report(error); }
  const disposeIntegration = async () => { await integration?.dispose(); await library.dispose(); cleanup(); };
  unsubs.push(await reaper.lifecycle.on('before-close', disposeIntegration));
  unsubs.push(await reaper.lifecycle.on('before-reload', disposeIntegration));
  let lastSettings = settingsSnapshot(player);
  unsubs.push(player.store.subscribe(() => {
    const snapshot = settingsSnapshot(player);
    if (snapshot !== lastSettings) { lastSettings = snapshot; clearTimeout(saveTimer); saveTimer = setTimeout(persist, 250); }
    if (integration?.modes.preserveTracks) return;
    const current = new Set(player.getPlaylistTracks().map(track => track.url));
    for (const url of previousTracks) if (!current.has(url) && urls.blobs.has(url)) URL.revokeObjectURL(url);
    previousTracks = current;
  }));
  const audio = player.media._source._audio;
  const mediaError = () => report(new Error(t('mediaError', {code:audio.error?.code})));
  audio.addEventListener('error', mediaError);
  unsubs.push(() => audio.removeEventListener('error', mediaError));
  unsubs.push(player.onClose(() => {
    if (integration?.modes.mode !== 'monitor') player.stop();
    reaper.window.close().catch(error => { player.reopen(); report(error); });
  }));
  unsubs.push(player.onMinimize(() => { reaper.window.hide().catch(report); }));
  document.querySelector('#diagnostics').onclick = async () => {
    try {
      const data = { ...diagnostics, audioState:player.media._context.state, tracks:player.getPlaylistTracks().length,
        objectURLs:urls.blobs.size, monitor:integration?.modes.diagnostics, host:await reaper.debug.getDiagnostics() };
      document.querySelector('#diagnostic-text').textContent = JSON.stringify(data, null, 2);
      document.querySelector('#diagnostic-dialog').showModal();
    } catch(e) { report(e); }
  };
  await reaper.window.setKeyboardCapture(true);
  const view = installPlayerView(player);
  document.querySelector('#reset').onclick = () => view.resetLayout().catch(report);
  unsubs.push(() => view.dispose());
  await player.renderInto(document.querySelector('#player'));
  await library.restore();
  if (savedSettings) restoreSettings(player, {getItem:() => savedSettings});
  if (firstLayout) { view.center(); persist(); }
  unsubs.push(installDesktop(library, report));
  shell.ready(!!integration);
  if (!useVisualization) report(t(visualizationFailure ? 'visualizationFailed' : 'visualizationUnsupported'));
  return player;
}
addEventListener('pagehide', cleanup, {once:true});
addEventListener('beforeunload', cleanup, {once:true});
addEventListener('unhandledrejection', event => { if (!recoverVisualization(event.reason)) report(event.reason); });
addEventListener('error', event => { if (!recoverVisualization(event.error || event.message)) report(event.error || event.message); });
export const ready = start().catch(error => { if (!recoverVisualization(error)) { report(error); cleanup(false); } throw error; });
