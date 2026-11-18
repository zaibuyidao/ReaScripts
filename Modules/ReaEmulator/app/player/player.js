import { LibraryStore } from '../library/library-store.js';
import { platformById } from '../shared/platforms.js';
import { readNativeFile } from '../host/native-files.js';
import { currentView } from '../shared/navigation.js';
import { gameSaveName } from './local-states.js';
import { adaptPlayerEvents, leavePlayer, loadLocalSave, mountPlayerMenu, playerLabel, playerLanguage, restoreQuickState } from './player-controls.js';

const view = currentView();
const gameId = view?.gameId;
const loading = document.getElementById('player-loading');
const message = document.getElementById('player-message');
const controller = new AbortController();
addEventListener('pagehide', () => controller.abort(), { once: true });
for (const link of document.querySelectorAll('#player-loading a')) {
  link.textContent = playerLabel('back-to-game-details');
  link.addEventListener('click', event => { event.preventDefault(); void leavePlayer(); });
}
window.EJS_ready = () => {
  adaptPlayerEvents(window.EJS_emulator, !!gameId);
  loading.hidden = true;
};

if (gameId) {
  loading.hidden = false;
  message.textContent = playerLabel('loading');
  try {
    await window.reaEmulatorHostReady;
    const store = await new LibraryStore(reaper).open();
    const game = store.value.games.find(item => item.id === gameId);
    if (!game) throw new Error('游戏记录不存在，请返回游戏库重新选择。');
    const platform = platformById(game.platform);
    const core = view.core || platform.core;
    if (!core) throw new Error('请在游戏库中为该游戏指定平台。');
    document.title = `ReaEmulator · ${game.title}`;
    // Validate the core before spending time reading a large ROM.
    await window.reaEmulatorBeforeStart(core);
    const dataLabel = playerLabel('loading');
    message.textContent = `${dataLabel} ${game.filename}`;
    const file = await readNativeFile(reaper, game.path, { signal: controller.signal, onProgress: (bytes, total) => {
      message.textContent = `${dataLabel} ${game.filename} (${Math.round((total ? bytes / total : 1) * 100)}%)`;
    } });
    let bios;
    const biosPath = view.biosPath === undefined ? game.biosPath : view.biosPath;
    if (biosPath) bios = await readNativeFile(reaper, biosPath, { signal: controller.signal });
    const previousBeforeStart = window.reaEmulatorBeforeStart;
    window.reaEmulatorBeforeStart = async core => {
      const options = await previousBeforeStart(core);
      const loadButton = options.EJS_Buttons?.loadState;
      return {
        EJS_disableDatabases: false,
        EJS_language: playerLanguage,
        EJS_disableAutoLang: false,
        EJS_backgroundImage: new URL('../../assets/logos/romm_logo_xbox_one_circle_boot.svg', import.meta.url).href,
        EJS_backgroundColor: view.backgroundColor || '#0e1015',
        EJS_alignStartButton: 'center',
        EJS_color: '#A453FF',
        ...options,
        ...(view.resumeLocalState ? { EJS_loadStateURL: null } : {}),
        EJS_Buttons: {
          ...options.EJS_Buttons,
          exitEmulation: false,
          loadState: loadButton === false ? false : { ...loadButton, displayName: playerLabel('load-save-or-state') },
        },
        ...(bios ? { EJS_biosUrl: bios } : {}),
      };
    };
    window.EJS_onLoadState = () => { void loadLocalSave(window.EJS_emulator); };
    let started = false;
    const onStarted = async () => {
      if (started) return;
      started = true;
      loading.hidden = true;
      mountPlayerMenu(window.EJS_emulator, controller.signal);
      if (view.resumeLocalState) void restoreQuickState(window.EJS_emulator, true);
      await store.patchGame(game.id, { lastPlayedAt: Date.now() });
    };
    window.EJS_onGameStart = () => { onStarted().catch(error => console.error('Could not initialize the player session', error)); };
    message.textContent = playerLabel('loading');
    const saveName = await gameSaveName(game);
    await window.run(false, undefined, { url: file, core, filename: game.filename, name: saveName });
  } catch (error) {
    if (error.name !== 'AbortError') {
      loading.hidden = false;
      message.textContent = error.message || String(error);
      console.error(error);
    }
  }
}
