const element = id => document.getElementById(id);
const run = action => Promise.resolve().then(action).catch(error => { element('error').textContent = `${error.code || 'ERROR'}: ${error.message}`; });
let state, count = 0;
const render = value => {
  state = value;
  element('state').textContent = JSON.stringify(value, null, 2);
  element('dock').textContent = value.docked ? 'Undock / 浮动' : 'Dock / 停靠';
};
element('count').onclick = () => { element('count').textContent = `Count / 计数: ${++count}`; };
element('close').onclick = () => run(() => reaper.window.close());
element('dock').onclick = () => run(() => reaper.window.setDocked(!state.docked));
element('size').onclick = () => run(() => reaper.window.setSize(640, 420));
element('devtools').onclick = () => run(() => reaper.debug.openDevTools());
run(async () => {
  await reaper.lifecycle.ready;
  render(await reaper.window.getState());
  await reaper.events.on('windowstatechange', render);
});
