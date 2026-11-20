// WebView2 can deliver caption presses to the document after an inner pane scrolls.
export function installCaptionDrag(host) {
  if (!(navigator.userAgentData?.platform || navigator.platform).startsWith('Win')) return () => {};
  const controls = '[data-reaweb-no-drag],a,button,input,textarea,select,summary,[role="button"],[contenteditable]:not([contenteditable="false"]),[tabindex]';
  let active, pending;
  let writing = false;
  let disposed = false;

  async function flush() {
    if (writing) return;
    writing = true;
    try {
      while (pending) {
        const drag = pending;
        pending = null;
        const geometry = await drag.geometry;
        if (!geometry || disposed || drag.cancelled || document.documentElement.matches('.is-framed,.is-docked')) continue;
        const {origin, scale} = geometry;
        await host.window.setPosition(Math.round(origin.x + (drag.x - drag.startX) * scale),
          Math.round(origin.y + (drag.y - drag.startY) * scale));
      }
    } catch {
      // The window may have closed or docked during the gesture.
    } finally {
      writing = false;
      if (pending) void flush();
    }
  }
  function down(event) {
    if (active || !event.isTrusted || event.button !== 0 || event.pointerType !== 'mouse' ||
        document.documentElement.matches('.is-framed,.is-docked')) return;
    const region = event.target.closest?.('.notes-nav[data-reaweb-drag], .note-page [data-reaweb-drag]');
    if (!region || event.target.closest(controls)) return;
    const geometry = Promise.all([host.window.getPosition(), host.window.getSize()])
      .then(([origin, size]) => ({origin, scale:size.width / innerWidth}), () => null);
    active = {id:event.pointerId, region, geometry, startX:event.screenX, startY:event.screenY};
    region.setPointerCapture(event.pointerId);
    event.preventDefault();
  }
  function move(event) {
    if (!active || active.id !== event.pointerId) return;
    active.x = event.screenX;
    active.y = event.screenY;
    if (!active.moved && Math.hypot(active.x - active.startX, active.y - active.startY) < 3) return;
    active.moved = true;
    pending = active;
    void flush();
  }
  function end(event) {
    if (!active || (event.pointerId != null && event.pointerId !== active.id)) return;
    if (event.type === 'pointerup') move(event);
    else active.cancelled = true;
    const {region, id} = active;
    active = null;
    if (region.hasPointerCapture(id)) region.releasePointerCapture(id);
  }
  const listeners = {pointerdown:down, pointermove:move, pointerup:end, pointercancel:end, lostpointercapture:end};
  for (const [type, fn] of Object.entries(listeners)) document.addEventListener(type, fn, true);
  window.addEventListener('blur', end);
  return () => {
    disposed = true;
    end({type:'cleanup'});
    for (const [type, fn] of Object.entries(listeners)) document.removeEventListener(type, fn, true);
    window.removeEventListener('blur', end);
  };
}
