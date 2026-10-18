import {t} from './i18n.mjs';
/** Non-draggable shortcuts behind the unmodified Webamp windows. */
export function installDesktop(library, report) {
  const desktop = document.querySelector('#desktop-shortcuts');
  const icons = [...desktop.querySelectorAll('.desktop-icon')];
  const buttons = [...desktop.querySelectorAll('button')];
  const controller = new AbortController();
  let loading = false, disposed = false;
  for (const button of buttons) button.disabled = false;
  function select(icon) {
    for (const item of icons) {
      item.classList.toggle('selected', item === icon);
      if (item.tagName === 'BUTTON') item.setAttribute('aria-pressed', String(item === icon));
      else if (item === icon) item.setAttribute('aria-current', 'true');
      else item.removeAttribute('aria-current');
    }
  }
  select(null);
  document.addEventListener('pointerdown', event => {
    if (!desktop.contains(event.target)) select(null);
  }, {signal:controller.signal});
  desktop.addEventListener('focusin', event => select(event.target.closest('.desktop-icon')), {signal:controller.signal});
  desktop.addEventListener('keydown', event => {
    event.stopPropagation();
    const icon = event.target.closest('.desktop-icon');
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      event.preventDefault();
      icons[(icons.indexOf(icon) + (event.key === 'ArrowRight' ? 1 : -1) + icons.length) % icons.length]?.focus();
    }
    const button = event.target.closest('button');
    if (button && !event.repeat && (event.key === 'Enter' || event.key === ' ')) {
      event.preventDefault();
      void selectSkin(button);
    }
    const link = event.target.closest('#skin-museum');
    if (link && !event.repeat && event.key === 'Enter') {
      event.preventDefault();
      void openMuseum(link);
    }
  }, {signal:controller.signal});
  desktop.addEventListener('dragstart', event => event.preventDefault(), {signal:controller.signal});
  desktop.addEventListener('click', event => {
    select(event.target.closest('.desktop-icon'));
    const link = event.target.closest('#skin-museum');
    if (link) event.preventDefault();
  }, {signal:controller.signal});
  desktop.addEventListener('dblclick', event => {
    select(event.target.closest('.desktop-icon'));
    const link = event.target.closest('#skin-museum');
    if (link) { event.preventDefault(); void openMuseum(link); return; }
    void selectSkin(event.target.closest('button'));
  }, {signal:controller.signal});
  async function openMuseum(link) {
    try { await reaper.system.openExternal(link.href); } catch (error) { if (!disposed) report(error); }
  }
  async function selectSkin(button) {
    if (!button || loading || disposed) return;
    loading = true;
    for (const control of buttons) control.disabled = true;
    button.setAttribute('aria-busy', 'true');
    try {
      const filename = button.dataset.skin || 'base-2.91.wsz';
      const response = await fetch(new URL(`../assets/skins/${filename}`, import.meta.url), {signal:controller.signal});
      if (!response.ok) throw Error(t('skinReadError', {name:filename}));
      const blob = await response.blob();
      if (!disposed) await library.setSkin(new File([blob], filename));
    } catch (error) { if (!disposed) report(error); }
    finally {
      loading = false;
      button.removeAttribute('aria-busy');
      if (!disposed) for (const control of buttons) control.disabled = false;
    }
  }
  return () => { disposed = true; controller.abort(); };
}
