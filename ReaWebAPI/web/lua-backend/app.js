'use strict';
(async () => {
  const name = document.querySelector('#name');
  const volume = document.querySelector('#volume');
  const value = document.querySelector('#value');
  const status = document.querySelector('#status');
  const report = error => { status.textContent = error.message; };
  try {
    if (!window.reaper?.host) throw new Error('Launch Open.lua with a ReaWebAPI version that supports host messages.');
    await reaper.events.on('message', text => {
      const data = JSON.parse(text);
      if (data.type !== 'state') return;
      name.textContent = data.track?.name || 'No track selected';
      volume.disabled = !data.track;
      volume.value = data.track?.volume ?? 0;
      value.textContent = data.track ? `${Math.round(data.track.volume * 100)}%` : '—';
      status.textContent = 'Connected to Lua';
    });
    volume.addEventListener('input', () => { value.textContent = `${Math.round(Number(volume.value) * 100)}%`; });
    volume.addEventListener('change', () => reaper.host.send(`volume ${volume.value}`).catch(report));
    await reaper.host.send('ready');
  } catch (error) { report(error); }
})();
