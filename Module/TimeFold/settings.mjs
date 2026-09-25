import { I18n } from './i18n.mjs';

const i18n = new I18n();
const ui = Object.fromEntries([...document.querySelectorAll('[id]')].map(node => [node.id, node]));
const shortcuts = ['settings', 'sidebar', 'create', 'seek', 'edit', 'fold', 'delete', 'moveLabel', 'resizeLabel', 'undo', 'redo', 'navigate', 'zoom', 'play', 'selectRow', 'deleteRow', 'viewportKeys', 'dividerKeys', 'escape'];
let state = null, session = null, updates = Promise.resolve();
let firstOpen = true;
try { firstOpen = localStorage.getItem('ArrangeNavigator.settingsWindow.initialized') !== '1'; } catch {}
function error(code) { ui.error.textContent = i18n.t(code); ui.error.hidden = false; }
async function action(name, value) {
  if (!state) return;
  try { await reaper.host.send({ type: 'settings-action', session, action: name, ...(value === undefined ? {} : { value }), revision: state.revision }); }
  catch { error('connectionLost'); }
}
async function render(data) {
  if (data.type !== 'settings-state') return;
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
  ui.undo.disabled = state.stateError || !state.canUndo; ui.redo.disabled = state.stateError || !state.canRedo;
  ui.fit.disabled = false;
  ui['import-markers'].disabled = ui['import-regions'].disabled = state.stateError;
  ui['settings-status'].textContent = state.notice ? i18n.t(state.notice.code, { count: i18n.numbers.format(state.notice.count) }) : '';
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
for (const name of ['fit', 'undo', 'redo']) ui[name].addEventListener('click', () => action(name));
for (const name of ['markers', 'regions']) ui[`import-${name}`].addEventListener('click', () => action(name));
const close = () => reaper.window.close().catch(() => error('connectionLost'));
ui['close-settings'].addEventListener('click', close);
document.addEventListener('keydown', event => {
  if (event.key === 'Escape' || event.ctrlKey && !event.altKey && event.code === 'Comma') { event.preventDefault(); close(); }
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
