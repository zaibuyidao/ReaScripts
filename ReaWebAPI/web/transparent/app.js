'use strict';
const status = document.querySelector('#status');
const report = error => { status.textContent = `${error.code || 'ERROR'}: ${error.message}`; };
const showState = state => {
  status.textContent = `transparent: ${state.transparent}\ntransparentActive: ${state.transparentActive}\nframelessActive: ${state.framelessActive}`;
};
document.querySelector('#opacity').addEventListener('input', event => {
  document.documentElement.style.setProperty('--panel-alpha', event.target.value);
});
document.querySelector('#close').onclick = () => reaper.window.close().catch(report);
document.querySelector('#reload').onclick = () => reaper.window.reload().catch(report);
document.querySelector('#dock').onclick = () => reaper.window.setDocked(true).catch(report);
(async () => {
  await reaper.lifecycle.ready;
  await reaper.events.on('windowstatechange', showState);
  showState(await reaper.window.getState());
})().catch(report);
