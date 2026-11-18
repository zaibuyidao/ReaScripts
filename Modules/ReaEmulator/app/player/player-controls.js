import { finishRecording } from '../host/integration.js';
import { reloadView } from '../shared/navigation.js';
import { readNativeFile } from '../host/native-files.js';
import { extension } from '../shared/platforms.js';
import { pendingLocalStateWrites, readLocalState, writeLocalState } from './local-states.js';
import { createExitEmulationButton, createQuickLoadButton, createSaveQuitButton, emulatorLanguages, labelContextMenuButton, menuLabels } from './player-romm-menu.js';

const storage = globalThis.localStorage;
const locale = storage?.getItem('user:1:settings.locale') || storage?.getItem('settings.locale') || 'zh_CN';
const localeTag = locale.replace('_', '-');
export const playerLanguage = emulatorLanguages.includes(localeTag) ? localeTag
  : emulatorLanguages.find(language => language.split('-')[0] === localeTag.split('-')[0]) || 'en-US';
export const playerLabel = key => menuLabels[locale]?.[key] || menuLabels.en_US[key];
const stateKey = emulator => `${emulator.getBaseFileName()}.state`;
let leaving = false;
let choosingSave = false;

const saveQuickState = (emulator, bytes) => writeLocalState(stateKey(emulator), bytes, emulator.getCore());

export async function leavePlayer(saveState = false) {
  if (leaving) return;
  leaving = true;
  const emulator = window.EJS_emulator;
  let resumeOnFailure = false;
  try {
    let state;
    if (saveState) {
      resumeOnFailure = !emulator.paused;
      emulator.pause();
      // A threaded core may still be finishing its last frame.
      await new Promise(resolve => setTimeout(resolve, 50));
      state = emulator.gameManager.getState()?.slice();
      if (!state?.byteLength) throw new Error(playerLabel('stream-save-state-failed'));
    }
    await finishRecording();
    if (emulator?.started && !emulator.failedToStart && emulator.gameManager) {
      emulator.gameManager.saveSaveFiles();
      const fs = emulator.gameManager.FS;
      if (fs?.syncfs) await new Promise((resolve, reject) => fs.syncfs(false, error => error ? reject(error) : resolve()));
    }
    if (state) await saveQuickState(emulator, state);
    else await pendingLocalStateWrites();
    await reloadView(null);
  } catch (error) {
    leaving = false;
    if (resumeOnFailure) emulator.play();
    alert(error?.message || (saveState ? playerLabel('stream-save-state-failed') : String(error)));
  }
}

export function adaptPlayerEvents(emulator, trackState = false) {
  // The standalone listener restarts the core before teardown, which can trap inside WASM.
  const dispatch = emulator.callEvent;
  emulator.callEvent = function(event, ...args) {
    if (event === 'exit' && this.started && !this.failedToStart) {
      void leavePlayer();
      return 1;
    }
    if (trackState && event === 'saveState' && this.saveInBrowserSupported() && this.getSettingValue('save-state-location') === 'browser') {
      if (!leaving) {
        saveQuickState(this, args[0].state).then(
          () => this.displayMessage(this.localization('SAVE SAVED TO BROWSER')),
          () => this.displayMessage(playerLabel('stream-save-state-failed')),
        );
      }
      return 1;
    }
    return dispatch.call(this, event, ...args);
  };
}

export async function restoreQuickState(emulator, booting = false) {
  if (leaving) return false;
  try {
    const state = await readLocalState(stateKey(emulator));
    if (leaving) return false;
    if (!state) {
      emulator.displayMessage(playerLabel(booting ? 'resume-failed' : 'no-states-available'));
      return false;
    }
    if (state.core && state.core !== emulator.getCore()) {
      const hint = playerLabel('state-incompatible-core').replace('{emulator}', state.core);
      emulator.displayMessage(hint);
      return false;
    }
    emulator.gameManager.loadState(state.bytes);
    emulator.displayMessage(playerLabel('quick-state-loaded'));
    return true;
  } catch {
    emulator.displayMessage(playerLabel(booting ? 'resume-failed' : 'stream-load-state-failed'));
    return false;
  }
}

export async function loadLocalSave(emulator) {
  if (choosingSave || leaving) return;
  choosingSave = true;
  try {
    const path = await reaper.dialog.openFile({ title: playerLabel('load-save-or-state') });
    if (!path || leaving) return;
    const format = extension(path);
    if (!['state', 'sav', 'srm'].includes(format)) throw new Error(playerLabel('stream-load-state-failed'));
    const file = await readNativeFile(reaper, path);
    if (leaving) return;
    const bytes = new Uint8Array(await file.arrayBuffer());
    if (leaving) return;
    if (!bytes.length) throw new Error(playerLabel('stream-load-state-failed'));
    const manager = emulator.gameManager;
    if (format === 'state') {
      manager.loadState(bytes);
    } else {
      const target = manager.getSaveFilePath();
      manager.FS.mkdirTree(target.slice(0, target.lastIndexOf('/')));
      manager.FS.writeFile(target, bytes);
      manager.loadSaveFiles();
    }
  } catch (error) {
    emulator.displayMessage(error?.message || playerLabel('stream-load-state-failed'));
  } finally {
    choosingSave = false;
  }
}

function mountFullscreenExit(emulator, signal) {
  const button = document.getElementById('player-exit-fullscreen');
  const stage = emulator.elements?.parent;
  if (!button || !stage || !globalThis.reaper?.lifecycle) return;
  stage.append(button);
  button.setAttribute('aria-label', playerLabel('exit-full-screen'));
  const fullscreen = () => {
    const element = document.fullscreenElement || document.webkitFullscreenElement;
    return element === stage || element === document.documentElement;
  };
  let timeout, cooldown = false;
  function hide() {
    clearTimeout(timeout);
    button.hidden = true;
  }
  function reset() {
    hide();
    cooldown = false;
  }
  function syncControls() {
    reset();
    const buttons = emulator.elements.bottomBar?.fullscreen;
    if (!buttons || emulator.config.buttonOpts.fullscreen.visible === false) return;
    buttons[0].style.display = fullscreen() ? 'none' : '';
    buttons[1].style.display = fullscreen() ? '' : 'none';
  }
  syncControls();
  for (const event of ['fullscreenchange', 'webkitfullscreenchange']) document.addEventListener(event, syncControls, { signal });
  document.addEventListener('pointerlockchange', reset, { signal });
  signal.addEventListener('abort', reset, { once: true });
  document.addEventListener('pointermove', event => {
    if (!fullscreen() || event.pointerType !== 'mouse' || document.pointerLockElement || document.webkitPointerLockElement) return;
    // Chromium uses a 3 DIP trigger and a larger buffer for moving to the button.
    if (event.clientY >= 90) reset();
    if (event.clientY > 3 || !button.hidden || cooldown) return;
    button.hidden = false;
    cooldown = true;
    timeout = setTimeout(hide, 3000);
  }, { passive: true, signal });
  button.addEventListener('click', async () => {
    if (!fullscreen()) return;
    try {
      if (document.exitFullscreen) await document.exitFullscreen();
      else emulator.toggleFullscreen(false);
    } catch (error) { emulator.displayMessage(error.message); }
  });
}

export function mountPlayerMenu(emulator, signal) {
  if (!document.querySelector('#game .ejs_menu_bar')) return;
  const buttonAction = (create, action, labelKey, callback) => {
    const label = playerLabel(labelKey);
    const button = create(label);
    button.dataset.reaemulatorAction = action;
    button.setAttribute('aria-label', label);
    button.addEventListener('click', callback);
  };
  const canSaveState = emulator.gameManager.supportsStates?.() && emulator.saveInBrowserSupported();
  labelContextMenuButton(playerLabel('context-menu'));
  if (canSaveState) {
    const saveLocation = emulator.preGetSetting('save-state-location')
      ?? emulator.config.defaultOptions?.['save-state-location'] ?? 'browser';
    emulator.changeSettingOption('save-state-location', saveLocation, true);
    buttonAction(createQuickLoadButton, 'quick-load', 'load-latest-state', () => { void restoreQuickState(emulator); });
  }
  buttonAction(createExitEmulationButton, 'quit', 'quit', () => { void leavePlayer(); });
  if (canSaveState) buttonAction(createSaveQuitButton, 'save-quit', 'save-and-quit', () => { void leavePlayer(true); });
  mountFullscreenExit(emulator, signal);
}
