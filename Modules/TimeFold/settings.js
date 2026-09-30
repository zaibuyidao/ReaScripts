import { I18n } from './i18n.js';
import { canDeletePreset } from './colors.js';

const i18n = new I18n();
const ui = Object.fromEntries([...document.querySelectorAll('[id]')].map(node => [node.id, node]));
const paletteInputs = Array.from({ length: 8 }, (_, index) => {
  const label = document.createElement('label'); label.className = 'setting color-field';
  const name = document.createElement('span'), input = document.createElement('input'); input.type = 'color';
  input.addEventListener('change', () => action('auto-palette-color', { index, color: input.value }));
  label.append(name, input); ui['auto-color-palette'].append(label);
  return { name, input };
});
const shortcuts = ['settings', 'sidebar', 'create', 'seek', 'edit', 'fold', 'delete', 'moveLabel', 'resizeLabel', 'undo', 'redo', 'navigate', 'zoom', 'play', 'selectRow', 'deleteRow', 'viewportKeys', 'dividerKeys', 'escape'];
let state = null, session = null, updates = Promise.resolve();
let colorTimer = null, pendingColor = null;
let presetKey = null, folderKey = null;
let firstOpen = true;
try { firstOpen = localStorage.getItem('ArrangeNavigator.settingsWindow.initialized') !== '1'; } catch {}
function error(code) { ui.error.textContent = i18n.t(code); ui.error.hidden = false; }
async function action(name, value) {
  if (!state) return;
  try { await reaper.host.send({ type: 'settings-action', session, action: name, ...(value === undefined ? {} : { value }), revision: state.revision }); }
  catch { error('connectionLost'); }
}
const presetName = preset => preset.name || i18n.t(`preset.${preset.id}`);
function currentPreset() { return state.colorSettings.presets.find(preset => preset.id === state.colorSettings.activePreset); }
function renderColors(reset) {
  const settings = state.colorSettings;
  for (const input of document.querySelectorAll('[name="color-mode"]')) input.checked = input.value === settings.mode;
  for (const [mode, id] of [['project', 'project-colors'], ['timefold', 'timefold-colors'], ['auto', 'auto-colors']]) ui[id].hidden = settings.mode !== mode;
  paletteInputs.forEach(({ name, input }, index) => {
    name.textContent = i18n.t('autoPaletteColor', { number: index + 1 });
    if (reset || document.activeElement !== input) input.value = settings.autoPalette[index];
  });
  const key = JSON.stringify([i18n.locale, settings.presets.map(preset => [preset.id, preset.name])]);
  if (key !== presetKey) {
    presetKey = key; ui['view-preset'].replaceChildren();
    for (const preset of settings.presets) {
      const option = document.createElement('option'); option.value = preset.id; option.textContent = presetName(preset); ui['view-preset'].append(option);
    }
  }
  ui['view-preset'].value = settings.activePreset;
  const preset = currentPreset(), rowsKey = JSON.stringify([settings.activePreset, preset.folders.map(folder => folder.id)]);
  const changed = reset || rowsKey !== folderKey;
  if (changed || document.activeElement !== ui['preset-name']) ui['preset-name'].value = presetName(preset);
  ui['preset-delete'].disabled = !canDeletePreset(preset.id);
  if (changed) {
    folderKey = rowsKey; ui['folder-colors'].replaceChildren();
    for (const folder of preset.folders) {
      const row = document.createElement('div'); row.className = 'folder-color';
      const name = document.createElement('input'); name.type = 'text'; name.className = 'folder-name'; name.maxLength = 128; name.required = true;
      const color = document.createElement('input'); color.type = 'color'; color.className = 'folder-swatch';
      const remove = document.createElement('button'); remove.className = 'danger';
      name.addEventListener('input', () => name.setCustomValidity(''));
      name.addEventListener('change', () => {
        const duplicate = currentPreset().folders.some(other => other.id !== folder.id && other.name.trim().toLowerCase() === name.value.trim().toLowerCase());
        name.setCustomValidity(!name.value.trim() || duplicate ? i18n.t('invalidFolderName') : '');
        if (name.reportValidity()) action('folder-update', { presetId: preset.id, folderId: folder.id, name: name.value });
      });
      color.addEventListener('change', () => action('folder-update', { presetId: preset.id, folderId: folder.id, color: color.value }));
      remove.addEventListener('click', () => action('folder-delete', { presetId: preset.id, folderId: folder.id }));
      row.append(name, color, remove); ui['folder-colors'].append(row);
    }
  }
  for (let index = 0; index < preset.folders.length; index++) {
    const folder = preset.folders[index], [name, color, remove] = ui['folder-colors'].children[index].children;
    if (changed || document.activeElement !== name) name.value = folder.name;
    if (changed || document.activeElement !== color) color.value = folder.color;
    name.setAttribute('aria-label', i18n.t('folderName')); color.setAttribute('aria-label', i18n.t('folderColor', { name: folder.name }));
    remove.textContent = i18n.t('deleteFolder'); remove.setAttribute('aria-label', `${i18n.t('deleteFolder')}: ${folder.name}`);
  }
  for (const key of ['tcpHiddenTracks', 'mutedTracks', 'mutedItems']) {
    const select = ui[`visibility-${key}`];
    select.replaceChildren();
    for (const mode of ['show', 'dim', 'hide']) {
      const option = document.createElement('option'); option.value = mode; option.textContent = i18n.t(`visibility.${mode}`); select.append(option);
    }
    select.value = state.visibility[key];
  }
}
async function render(data) {
  if (data.type !== 'settings-state') return;
  const reset = session !== data.session;
  if (reset) { clearTimeout(colorTimer); colorTimer = pendingColor = null; }
  session = data.session; state = data.state;
  if (i18n.locale !== state.language) await i18n.load(state.language);
  i18n.apply(); document.title = i18n.t('settings');
  ui.language.replaceChildren();
  for (const language of state.languages) {
    const option = document.createElement('option'); option.value = language.code; option.textContent = language.name; ui.language.append(option);
  }
  ui.language.value = state.language; ui.language.disabled = false;
  ui['toggle-labels'].checked = state.labelsVisible;
  ui['toggle-label-guides'].checked = state.showLabelGuides;
  renderColors(reset);
  ui['custom-item-color-enabled'].checked = state.customItemColorEnabled;
  ui['custom-item-color'].disabled = !state.customItemColorEnabled;
  if (reset || document.activeElement !== ui['custom-item-color'] && pendingColor === null) ui['custom-item-color'].value = state.customItemColor || '#888888';
  ui.error.hidden = !state.errorCode; if (state.errorCode) error(state.errorCode);
  ui.shortcuts.replaceChildren();
  for (const key of shortcuts) {
    const keys = document.createElement('dt'), description = document.createElement('dd');
    keys.textContent = i18n.t(`shortcut.${key}.keys`); description.textContent = i18n.t(`shortcut.${key}.description`);
    ui.shortcuts.append(keys, description);
  }
  if (firstOpen) {
    await document.fonts.ready;
    await new Promise(resolve => requestAnimationFrame(resolve));
    const size = await reaper.window.getSize(), ratio = window.devicePixelRatio || 1;
    const extra = Math.max(0, ui.settings.scrollHeight + 20 - innerHeight);
    if (extra) await reaper.window.setSize(size.width, Math.ceil(size.height + extra * ratio));
    firstOpen = false;
    try { localStorage.setItem('ArrangeNavigator.settingsWindow.initialized', '1'); } catch {}
  }
}
ui.language.addEventListener('change', () => { ui.language.disabled = true; action('language', ui.language.value); });
ui['toggle-labels'].addEventListener('change', () => action('labels', ui['toggle-labels'].checked));
ui['toggle-label-guides'].addEventListener('change', () => action('label-guides', ui['toggle-label-guides'].checked));
for (const key of ['tcpHiddenTracks', 'mutedTracks', 'mutedItems']) ui[`visibility-${key}`].addEventListener('change', event => action('visibility', { key, mode: event.target.value }));
for (const input of document.querySelectorAll('[name="color-mode"]')) input.addEventListener('change', () => { if (input.checked) action('color-mode', input.value); });
ui['auto-palette-reset'].addEventListener('click', () => action('auto-palette-reset'));
ui['view-preset'].addEventListener('change', () => action('preset-select', ui['view-preset'].value));
ui['preset-name'].addEventListener('input', () => ui['preset-name'].setCustomValidity(''));
ui['preset-name'].addEventListener('change', () => {
  ui['preset-name'].setCustomValidity(ui['preset-name'].value.trim() ? '' : i18n.t('invalidPresetName'));
  if (ui['preset-name'].reportValidity()) action('preset-rename', { presetId: currentPreset().id, name: ui['preset-name'].value });
});
ui['preset-add'].addEventListener('click', () => {
  if (!state) return;
  let number = 1;
  while (state.colorSettings.presets.some(preset => presetName(preset) === i18n.t('newPreset', { number }))) number++;
  action('preset-add', { name: i18n.t('newPreset', { number }) });
});
ui['preset-copy'].addEventListener('click', () => {
  if (state) action('preset-copy', { presetId: currentPreset().id, name: i18n.t('presetCopyName', { name: presetName(currentPreset()).slice(0, 100) }).slice(0, 128) });
});
ui['preset-delete'].addEventListener('click', () => { if (state) action('preset-delete', { presetId: currentPreset().id }); });
ui['folder-add'].addEventListener('click', () => {
  if (!state) return;
  const preset = currentPreset();
  let number = 1;
  while (preset.folders.some(folder => folder.name.toLowerCase() === i18n.t('newFolder', { number }).toLowerCase())) number++;
  action('folder-add', { presetId: preset.id, name: i18n.t('newFolder', { number }), color: '#589bd5' });
});
ui['custom-item-color-enabled'].addEventListener('change', () => action('custom-item-color-enabled', ui['custom-item-color-enabled'].checked));
function flushColor() {
  clearTimeout(colorTimer); colorTimer = null;
  if (pendingColor === null) return;
  const value = pendingColor; pendingColor = null;
  action('custom-item-color', value);
}
ui['custom-item-color'].addEventListener('input', () => {
  pendingColor = ui['custom-item-color'].value;
  if (colorTimer === null) colorTimer = setTimeout(flushColor, 50);
});
ui['custom-item-color'].addEventListener('change', () => { pendingColor = ui['custom-item-color'].value; flushColor(); });
const close = () => reaper.window.close().catch(() => error('connectionLost'));
ui['close-settings'].addEventListener('click', close);
document.addEventListener('keydown', event => {
  if (event.key === 'Escape' || event.ctrlKey && (!event.altKey && (event.code === 'Comma' || event.key === ',') || event.altKey && event.code === 'KeyS')) { event.preventDefault(); close(); }
  else if (event.ctrlKey && event.shiftKey && event.code === 'KeyT') { event.preventDefault(); action('labels', !state?.labelsVisible); }
  else if (event.ctrlKey && !event.altKey && !event.target.closest('input,textarea,select')) {
    if (event.code === 'KeyZ' || event.code === 'KeyY') { event.preventDefault(); action(event.code === 'KeyY' || event.shiftKey ? 'redo' : 'undo'); }
  }
});
async function start() {
  await i18n.load(); document.title = i18n.t('settings');
  await reaper.lifecycle.ready;
  await reaper.window.setIconVisible(false);
  await reaper.events.on('message', text => {
    updates = updates.then(() => render(JSON.parse(text))).catch(() => error('syncFailed'));
  });
  await reaper.window.setDocked(false);
  if (firstOpen) {
    const ratio = window.devicePixelRatio || 1;
    await reaper.window.setSize(Math.round(560 * ratio), Math.round(520 * ratio));
  }
  await reaper.host.send({ type: 'settings-ready' });
}
start().catch(() => error('connectionLost'));
