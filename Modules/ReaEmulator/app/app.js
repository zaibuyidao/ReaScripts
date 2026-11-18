import { currentView, reloadView, setPlayerView } from './shared/navigation.js';

async function mountPlayer(view, signal) {
    // Use the original player markup and runtime in the top-level document so the
    // injected ReaWebAPI bridge, isolation and Lua reader keep the same window.
    const response = await fetch('./app/player/player.html');
    if (!response.ok) throw new Error(`player.html: ${response.status}`);
    const player = new DOMParser().parseFromString(await response.text(), 'text/html');
    signal?.throwIfAborted();
    player.querySelectorAll('script').forEach(script => script.remove());
    if (view) {
      setPlayerView(view);
      window.dispatchEvent(new Event('reaemulator-player-mount'));
    }
    document.querySelector('link[data-romm-style]')?.remove();
    for (const style of player.head.querySelectorAll('style, link[rel="stylesheet"]')) document.head.append(style.cloneNode(true));
    document.body.replaceChildren(...[...player.body.childNodes].map(node => node.cloneNode(true)));
    const boot = currentView();
    if (boot?.gameId) {
      const loading = document.getElementById('player-loading');
      if (boot.backgroundColor) loading.style.setProperty('--player-boot-color', boot.backgroundColor);
      loading.hidden = false;
    }
    await new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = './app/player/player-runtime.js';
      script.addEventListener('load', resolve, { once: true });
      script.addEventListener('error', () => reject(new Error('无法加载模拟器入口，请检查 player-runtime.js 是否完整安装。')), { once: true });
      document.body.append(script);
    });
    await import('./player/player.js');
}

window.reaEmulatorOpenPlayer = async (view, signal) => {
  try { await mountPlayer(view, signal); }
  catch (error) {
    if (!currentView()) throw error;
    showFailure(error);
  }
};

try {
  if (currentView()) {
    await mountPlayer();
  } else {
    const style = document.createElement('link');
    style.rel = 'stylesheet'; style.href = './vendor/romm/ui/library.css'; style.dataset.rommStyle = '';
    document.head.append(style);
    await import('../vendor/romm/ui/library.js');
  }
} catch (error) { showFailure(error); }

function showFailure(error) {
  console.error(error);
  const message = document.createElement('p');
  message.textContent = `无法打开游戏：${error.message || error}`;
  const back = document.createElement('button');
  back.textContent = '返回游戏库';
  back.addEventListener('click', () => reloadView(null).catch(failure => { message.textContent = failure.message; }));
  document.body.replaceChildren(message, back);
}
