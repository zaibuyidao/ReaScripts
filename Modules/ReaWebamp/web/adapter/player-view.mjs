import {preferences, savePreferences} from './preferences.mjs';
import {SETTINGS_KEY} from './upstream-state.mjs';

/** Host defaults apply once; subsequent native geometry belongs to the user. */
export async function initializeWindow() {
  if (preferences.initialized) return;
  if (!localStorage.getItem(SETTINGS_KEY) && !(await reaper.window.isDocked())) await reaper.window.setSize(700, 700);
  savePreferences({initialized:true});
}

export function installPlayerView(player) {
  const viewport = document.querySelector('#viewport');
  const container = document.querySelector('#player');
  let disposed = false;
  function updateExtents() {
    const origin = container.getBoundingClientRect();
    const windows = [...container.querySelectorAll('.window')].map(node => node.getBoundingClientRect()).filter(rect => rect.width && rect.height);
    for (const [property, value] of [
      ['minWidth', Math.max(0,...windows.map(rect => rect.right-origin.left))],
      ['minHeight', Math.max(0,...windows.map(rect => rect.bottom-origin.top))],
    ]) {
      const pixels = `${Math.round(value * 1000) / 1000}px`;
      if (container.style[property] !== pixels) container.style[property] = pixels;
    }
  }
  const observer = new MutationObserver(updateExtents);
  observer.observe(container, {subtree:true, childList:true, attributes:true, attributeFilter:['style','class']});
  updateExtents();
  function center() {
      const windows = [...container.querySelectorAll('.window')].map(node => node.getBoundingClientRect()).filter(rect => rect.width && rect.height);
      if (!windows.length) return;
      const left = Math.min(...windows.map(rect => rect.left)), top = Math.min(...windows.map(rect => rect.top));
      const width = Math.max(...windows.map(rect => rect.right)) - left, height = Math.max(...windows.map(rect => rect.bottom)) - top;
      const area = viewport.getBoundingClientRect();
      const dx = area.left + Math.max(0,(viewport.clientWidth-width)/2) - left;
      const dy = area.top + Math.max(0,(viewport.clientHeight-height)/2) - top;
      const positions = Object.fromEntries(Object.entries(player.store.getState().windows.genWindows).map(([id,w]) => [id,{x:Math.max(0,Math.round(w.position.x+dx)),y:Math.max(0,Math.round(w.position.y+dy))}]));
      player.store.dispatch({type:'UPDATE_WINDOW_POSITIONS',absolute:true,positions});
  }
  return {
    center,
    async resetLayout() {
      // Restore the initial two-column arrangement while retaining window sizes,
      // visibility and shade mode.
      viewport.scrollTo(0,0);
      const dimensions = Object.fromEntries(['main','equalizer','playlist'].map(id => {
        const rect = container.querySelector(`#${id}-window, #${id}-window-shade`)?.getBoundingClientRect();
        return [id,{width:rect?.width || 0, height:rect?.height || 0}];
      }));
      player.store.dispatch({type:'UPDATE_WINDOW_POSITIONS',absolute:true,positions:{
        main:{x:0,y:0}, equalizer:{x:0,y:dimensions.main.height},
        playlist:{x:0,y:dimensions.main.height+dimensions.equalizer.height},
        milkdrop:{x:Math.max(dimensions.main.width,dimensions.equalizer.width,dimensions.playlist.width),y:0},
      }});
      // Wait for React and the extent observer, then remove any obsolete scrollbars
      // before the final center calculation.
      for (let pass=0; pass<2; pass++) {
        await new Promise(requestAnimationFrame);
        if (disposed) return;
        updateExtents();
        viewport.scrollTo(0,0);
        center();
      }
    },
    dispose() { disposed = true; observer.disconnect(); },
  };
}
