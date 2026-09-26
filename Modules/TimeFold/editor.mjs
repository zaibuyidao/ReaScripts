import { I18n } from './i18n.mjs';

const i18n = new I18n();
const ui = Object.fromEntries([...document.querySelectorAll('[id]')].map(node => [node.id, node]));
let state = null, session = null, updates = Promise.resolve(), firstOpen = true;
try { firstOpen = localStorage.getItem('ArrangeNavigator.editorWindow.initialized') !== '1'; } catch {}
function error(code) { ui['form-error'].textContent = i18n.t(code); }
function enable(value) { ui['save-label'].disabled = ui['delete-label'].disabled = !value; }
async function render(data) {
  if (data.type !== 'editor-state') return;
  const reset = session !== data.session || state?.request !== data.state.request;
  session = data.session; state = data.state;
  if (i18n.locale !== state.language) await i18n.load(state.language);
  i18n.apply();
  document.title = ui['editor-title'].textContent = i18n.t(state.id === undefined ? 'addLabel' : 'editLabel');
  if (reset) {
    ui['label-name'].value = state.name;
    ui['label-color'].value = state.color;
    ui['label-start'].value = String(Number(state.start.toFixed(9)));
    ui['label-end'].value = String(Number(state.finish.toFixed(9)));
    ui['delete-label'].hidden = state.id === undefined;
    ui['form-error'].textContent = '';
  }
  if (firstOpen) {
    await document.fonts.ready;
    await new Promise(resolve => requestAnimationFrame(resolve));
    const size = await reaper.window.getSize(), ratio = window.devicePixelRatio || 1;
    const height = Math.ceil(size.height + (ui.editor.scrollHeight + 2 - innerHeight) * ratio);
    await reaper.window.setSize(size.width, height);
    firstOpen = false;
    try { localStorage.setItem('ArrangeNavigator.editorWindow.initialized', '1'); } catch {}
  }
  enable(true); ui.editor.dataset.ready = 'true';
  if (reset) ui['label-name'].focus();
}
async function action(name, value) {
  if (!state) return;
  enable(false);
  try { await reaper.host.send({ type: 'editor-action', session, request: state.request, action: name, ...(value ? { value } : {}) }); }
  catch { enable(true); error('connectionLost'); }
}
ui['label-form'].addEventListener('submit', event => {
  event.preventDefault();
  const start = Number(ui['label-start'].value), finish = Number(ui['label-end'].value);
  if (!Number.isFinite(start) || !Number.isFinite(finish) || start < 0 || finish > 1e9 || finish - start < 0.01) { error('invalidRange'); return; }
  action('save', { start, finish, name: ui['label-name'].value.trim(), color: ui['label-color'].value });
});
ui['delete-label'].addEventListener('click', () => action('delete'));
const close = () => reaper.window.close().catch(() => error('connectionLost'));
ui.cancel.addEventListener('click', close);
document.addEventListener('keydown', event => { if (event.key === 'Escape') { event.preventDefault(); close(); } });
async function start() {
  await i18n.load();
  await reaper.lifecycle.ready;
  await reaper.window.setIconVisible(false);
  await reaper.events.on('message', text => { updates = updates.then(() => render(JSON.parse(text))).catch(() => error('syncFailed')); });
  await reaper.window.setDocked(false);
  if (firstOpen) {
    const ratio = window.devicePixelRatio || 1;
    await reaper.window.setSize(Math.round(460 * ratio), Math.round(400 * ratio));
  }
  await reaper.host.send({ type: 'editor-ready' });
}
start().catch(() => error('connectionLost'));
