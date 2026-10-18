import {t, setLanguage} from './i18n.mjs';
/** Outer application UI only. Existing action handlers and Webamp stay untouched. */
export function createShell() {
  const header = document.querySelector('.app-header');
  const triggers = [...header.querySelectorAll('.menu-trigger')];
  const dialog = document.querySelector('#import-dialog');
  const el = id => document.getElementById(id);
  const controller = new AbortController();
  const listen = (target, type, handler) => target.addEventListener(type, handler, { signal:controller.signal });
  let toastTimer;
  function dismissToast() { clearTimeout(toastTimer); el('error-toast').hidden = true; el('status').textContent = ''; }
  listen(el('dismiss-error'), 'click', dismissToast);
  listen(el('error-toast'), 'keydown', event => event.stopPropagation());
  listen(el('language'), 'change', async () => {
    try { await setLanguage(el('language').value); positionMenu(); }
    catch (error) { el('language').value = document.documentElement.lang; showMessage(error.message); }
  });
  let active = null, importKind = 'region', origin = null, errors = 0, submitting = false;

  function closeMenu(restoreFocus = false) {
    if (!active) return;
    const trigger = active;
    el(trigger.getAttribute('aria-controls')).hidden = true;
    trigger.setAttribute('aria-expanded', 'false');
    active = null;
    if (restoreFocus) trigger.focus();
  }
  function positionMenu() {
    if (!active) return;
    const panel = el(active.getAttribute('aria-controls'));
    const rect = active.getBoundingClientRect();
    panel.style.left = `${Math.max(6, Math.min(rect.left, innerWidth - panel.offsetWidth - 6))}px`;
    panel.style.top = `${rect.bottom}px`;
    panel.style.maxHeight = `${Math.max(0, innerHeight - rect.bottom - 10)}px`;
  }
  const focusable = panel => [...panel.querySelectorAll('button:enabled, select:enabled, input:enabled')];
  function openMenu(trigger, focusFirst = false) {
    closeMenu();
    active = trigger;
    const panel = el(trigger.getAttribute('aria-controls'));
    panel.hidden = false;
    trigger.setAttribute('aria-expanded', 'true');
    positionMenu();
    if (focusFirst) focusable(panel)[0]?.focus();
  }
  for (const trigger of triggers) {
    listen(trigger, 'click', () => active === trigger ? closeMenu() : openMenu(trigger));
    listen(trigger, 'pointerenter', event => {
      if (event.pointerType === 'mouse' && active && active !== trigger) openMenu(trigger);
    });
  }
  listen(header, 'click', event => {
    const button = event.target.closest('.menu-action');
    if (!button || button.disabled) return;
    const trigger = active;
    closeMenu(true);
    if (button.dataset.import) openImport(button.dataset.import, trigger);
  });
  listen(document, 'pointerdown', event => { if (!header.contains(event.target)) closeMenu(); });
  listen(document, 'focusin', event => { if (!header.contains(event.target)) closeMenu(); });
  listen(window, 'resize', positionMenu);
  listen(window, 'blur', () => closeMenu());
  listen(header, 'keydown', event => {
    event.stopPropagation(); // Menu keys must not also trigger Webamp hotkeys.
    const target = event.target;
    if (event.key === 'Escape') { event.preventDefault(); closeMenu(true); return; }
    if (target.matches('select, input')) return; // Preserve native field navigation.
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      event.preventDefault();
      const index = triggers.indexOf(active || target.closest('.menu-trigger'));
      const next = triggers[(index + (event.key === 'ArrowRight' ? 1 : -1) + triggers.length) % triggers.length];
      const wasOpen = !!active;
      next.focus();
      if (wasOpen) openMenu(next, true);
    } else if (['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) {
      event.preventDefault();
      if (!active) openMenu(target.closest('.menu-trigger') || triggers[0]);
      const items = focusable(el(active.getAttribute('aria-controls')));
      const index = items.indexOf(target);
      const next = event.key === 'Home' ? 0 : event.key === 'End' ? items.length - 1
        : event.key === 'ArrowDown' ? (index + 1) % items.length : (index <= 0 ? items.length : index) - 1;
      items[next]?.focus();
    }
  });

  function updateImportFields() {
    const preview = importKind === 'preview';
    el('preview-settings').hidden = !preview;
    el('tail-settings').hidden = !preview;
    el('region-settings').hidden = preview && el('preview-scope').value !== 'region';
    el('add-region').hidden = preview;
    el('render-preview').hidden = !preview;
  }
  function refreshRegions() {
    // Reuse the integration's existing request and retain a still-valid selection.
    const previous = el('region').value;
    Promise.resolve(el('refresh-regions').onclick?.()).then(() => {
      if ([...el('region').options].some(option => option.value === previous)) el('region').value = previous;
    });
  }
  function openImport(kind, trigger) {
    importKind = kind;
    origin = trigger;
    el('import-title').dataset.i18n = kind === 'preview' ? 'preview' : 'addRegion';
    el('import-hint').dataset.i18n = kind === 'preview' ? 'previewHint' : 'regionHint';
    el('import-title').textContent = t(el('import-title').dataset.i18n);
    el('import-hint').textContent = t(el('import-hint').dataset.i18n);
    el('import-feedback').hidden = true;
    updateImportFields();
    dialog.showModal();
    (kind === 'preview' ? el('preview-scope') : el('region')).focus();
    if (!el('region-settings').hidden) refreshRegions();
  }
  listen(el('preview-scope'), 'change', () => {
    updateImportFields();
    if (!el('region-settings').hidden) refreshRegions();
  });
  listen(dialog, 'close', () => origin?.focus());
  for (const modal of document.querySelectorAll('.shell-dialog')) {
    listen(modal, 'keydown', event => event.stopPropagation());
    for (const button of modal.querySelectorAll('[data-close]')) listen(button, 'click', () => modal.close());
  }
  function showMessage(message) {
    errors++;
    clearTimeout(toastTimer);
    el('status').textContent = message;
    el('error-toast').hidden = false;
    toastTimer = setTimeout(dismissToast, 6000);
    if (dialog.open) { el('import-feedback').textContent = message; el('import-feedback').hidden = false; }
  }
  return {
    ready(integrationAvailable) {
      for (const control of header.querySelectorAll('[data-player]')) control.disabled = false;
      for (const control of header.querySelectorAll('[data-integration]')) control.disabled = !integrationAvailable;
      if (integrationAvailable) for (const id of ['add-region', 'render-preview']) {
        const button = el(id), action = button.onclick;
        button.onclick = async event => {
          if (submitting) return;
          submitting = true;
          const before = errors, label = button.textContent;
          button.disabled = true;
          button.textContent = t(id === 'render-preview' ? 'rendering' : 'importing');
          el('import-feedback').hidden = true;
          try {
            await action.call(button, event);
            if (errors === before && dialog.open) dialog.close();
          } finally { submitting = false; button.disabled = false; button.textContent = label; }
        };
      }
    },
    report:showMessage,
    dispose() { closeMenu(); clearTimeout(toastTimer); controller.abort(); }
  };
}
