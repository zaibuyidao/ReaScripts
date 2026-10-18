import {t} from './i18n.mjs';
import {connectHost} from './host-client.mjs';
import {createModes} from './mode-controller.mjs';
export async function createIntegration(player,library,urls,report){
 const backend=await connectHost();
 const el=id=>document.getElementById(id);
 const changed=state=>{
  el('mode').value=state.mode;el('follow').checked=state.follow;el('follow').disabled=state.mode!=='monitor';
  el('source').textContent=t(state.mode==='monitor'?'monitorMode':'playerMode');
 };
 const modes=createModes(player,backend,report,changed);
 const run=fn=>async()=>{try{await fn()}catch(e){report(e)}};
 async function selection(scope,replace=false){
  await modes.leave();
  const result=await backend.request('selection',scope,el('region').value||-1);
  if(!result.items.length)throw Error(t('noItems'));
  const errors=result.items.filter(row=>row.error);if(errors.length)report(Error(errors.map(row=>row.error).join('\n')));
  const valid=result.items.filter(row=>!row.error);if(!valid.length)return;
  if(replace){player.setTracksToPlay([]);await library.releaseAll()}
  const tracks=await library.openPaths(valid);player.appendTracks(tracks);
  el('source').textContent=t('regionHint');
 }
 el('mode').onchange=run(()=>el('mode').value==='monitor'?modes.enterMonitor():modes.leave());
 el('follow').onchange=run(()=>modes.setFollow(el('follow').checked));
 el('add-items').onclick=run(()=>selection('item'));
 el('replace-items').onclick=run(()=>selection('item',true));
 el('add-tracks').onclick=run(()=>selection('track'));
 el('add-region').onclick=run(()=>selection('region'));
 el('refresh-regions').onclick=run(async()=>{const regions=await backend.request('regions');el('region').replaceChildren(...regions.map(row=>{const option=document.createElement('option');option.value=row.id;option.textContent=`${row.id}: ${row.name||t('region')} (${row.start.toFixed(2)}–${row.finish.toFixed(2)} s)`;return option}))});
 el('open-local').onclick=run(async()=>{
  await modes.leave();const path=await reaper.dialog.openFile({title:t('openAudio')});if(!path)return;
  player.appendTracks(await library.openPaths([{path}]));
 });
 el('open-skin').onclick=run(async()=>{const path=await reaper.dialog.openFile({title:t('chooseSkin'),filters:[{name:t('classicSkin'),extensions:['wsz','zip']}]});if(!path)return;await library.setSkin(new File([await reaper.fs.readBinary(path)],path.split(/[\\/]/).pop()))});
 el('render-preview').onclick=run(async()=>{
  await modes.leave();el('render-preview').disabled=true;
  try{const row=await backend.request('preview',el('preview-scope').value,el('region').value||-1,+el('tail').value);player.appendTracks(await library.openPaths([row]));el('source').textContent=t('preview')}
  finally{el('render-preview').disabled=false}
 });
 el('clear-cache').onclick=run(async()=>{await modes.leave();player.setTracksToPlay([]);await library.releaseAll();const count=await backend.request('clearCache');el('source').textContent=t('cacheCleared',{count})});
 // Keep upstream browser File drops, including EQF and Milkdrop preset targets.
 const rememberSkin=event=>{const files=event.dataTransfer?.files||event.target?.files;if(files?.length===1&&/\.(wsz|zip)$/i.test(files[0].name)){const file=files[0],previous=player.store.getState().skin;setTimeout(()=>{void player.skinIsLoaded().then(()=>{if(player.store.getState().skin!==previous)return library.rememberSkin(file)}).catch(report)},0)}};
 // Webamp's native pickers use detached inputs, whose change events do not bubble to document.
 const prototype=HTMLInputElement.prototype,clickDescriptor=Object.getOwnPropertyDescriptor(prototype,'click'),originalClick=prototype.click;
 const observed=new WeakSet();
 const inputClick=function(...args){if(this.type==='file'&&!observed.has(this)){observed.add(this);this.addEventListener('change',rememberSkin)}return originalClick.apply(this,args)};
 prototype.click=inputClick;
 document.addEventListener('drop',rememberSkin,true);document.addEventListener('change',rememberSkin,true);
 const offProject=await reaper.events.on('projectchange',event=>{
  for(const row of library.records.values())if(row.projectGuid&&row.revision!==event?.changeCount){row.stale=true;el('source').textContent=t('projectMediaChanged');break}
 });
 changed({mode:'player',follow:false,state:0});
 return {modes,backend,selection,async dispose(){if(prototype.click===inputClick){if(clickDescriptor)Object.defineProperty(prototype,'click',clickDescriptor);else delete prototype.click}document.removeEventListener('drop',rememberSkin,true);document.removeEventListener('change',rememberSkin,true);await offProject();await modes.dispose();await backend.dispose()}};
}
