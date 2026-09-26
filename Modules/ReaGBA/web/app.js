'use strict';
// ReaWebAPI owns the WebView and transport. ReaGBA owns the native core session.
(()=>{
 if(window.nativeRequest||!window.reaper?.host)return;
 const runtime=window.reaper,gba=runtime.host.service('reagba');
 let inputReady=false,docked=false,blocked=false,video=null,stream=null,stopStatus=null,stopInput=null;
 const pressed=new Set();
 const enrich=value=>value&&typeof value==='object'&&'loaded' in value?{...value,reaper:true,docked}:value;
 const report=error=>toast(error.message,true);
 const sendInput=value=>{if(inputReady)gba.send('input',value);};
 const focusGame=async()=>{await runtime.window.focus();document.getElementById('game-viewport').focus({preventScroll:true});};
 async function invoke(method,payload){
  const result=await gba.invoke(method,payload),large=result?.__reagbaResult;
  if(!large)return result;
  if(!Number.isSafeInteger(large.bytes)||large.bytes<1||large.bytes>8*1024*1024)throw Error('Invalid core result size');
  let text='',offset=0;
  while(offset<large.bytes){
   const part=await gba.invoke('readResult',{token:large.token,offset});
   if(part.offset!==offset||!Number.isSafeInteger(part.bytes)||part.bytes<1||offset+part.bytes>large.bytes||typeof part.text!=='string')throw Error('Invalid core result chunk');
   text+=part.text;offset+=part.bytes;
  }
  return JSON.parse(text);
 }
 const ready=(async()=>{
  await runtime.lifecycle.ready;
  await runtime.window.setIconVisible(false);
  await runtime.lifecycle.on('cleanup',cleanup);
  if(!runtime.stream)throw Error('ReaGBA requires ReaWebAPI v0.3.6.4 or later');
  docked=await runtime.window.isDocked();
  await runtime.events.on('windowstatechange',value=>{
   docked=value.docked;
   if(!value.focused)release();
   if(window.onNativeState)window.onNativeState(enrich(state));
  });
  await gba.invoke('getState');inputReady=true;
  stream=await runtime.stream.open('reagba.video');
  stream.on('data',frame=>{video??=createGameVideo();video.frame({width:stream.info.width,height:stream.info.height,data:frame.data});});
  stream.on('error',report);
  let updating=false;
  stopStatus=await runtime.system.schedule(async()=>{
   if(updating)return;updating=true;
   try{window.onNativeState?.(enrich(await gba.invoke('getState')));}catch(error){report(error);}finally{updating=false;}
  },{delay:250,interval:250});
 })();
 const request=async command=>{
  await ready;
  const {action,...payload}=command;
  try{return {ok:true,result:enrich(await invoke(action,payload))};}
  catch(error){return {ok:false,error:error.message};}
 };
 // Display preferences belong to the WebView. Import legacy values on first run
 // so existing language, shader and library layout choices survive migration.
 const displayDefaults={language:'en',library_view:'details',shader:'none',integer_scaling:true,filter:'nearest',vsync:true};
 const displayKeys=new Set([...Object.keys(displayDefaults),'library_split','library_expanded']);
 let displayPreferences=null,displayPath='',preferencesQueue=Promise.resolve();
 function validateDisplay(values){
  if('language' in values&&(typeof values.language!=='string'||! /^[A-Za-z0-9-]{1,64}$/.test(values.language)))throw Error('Invalid language identifier');
  if('library_view' in values&&!['details','grid','compact'].includes(values.library_view))throw Error('Unknown library view (expected details, grid or compact)');
  if('shader' in values&&!['none','lcd3x','lcd-grid-v2'].includes(values.shader))throw Error('Unknown shader preset (expected none, lcd3x or lcd-grid-v2)');
  if('library_split' in values&&values.library_split!==null&&(typeof values.library_split!=='number'||!Number.isFinite(values.library_split)||values.library_split<0||values.library_split>1))throw Error('Library split must be a ratio from 0 to 1, or null for automatic');
  for(const name of ['library_expanded','integer_scaling','vsync'])if(name in values&&typeof values[name]!=='boolean')throw Error('Invalid display preference: '+name);
  if('filter' in values&&!['nearest','linear'].includes(values.filter))throw Error('Invalid texture filter');
 }
 function preferences(command){
  const task=preferencesQueue.catch(()=>{}).then(async()=>{
   const display={},core={};
   for(const [key,value] of Object.entries(command.settings||{}))(displayKeys.has(key)?display:core)[key]=value;
   validateDisplay(display);
   const result=await request(Object.keys(core).length?{action:'set_settings',settings:core}:{action:'get_settings'});
   if(!result.ok)return result;
   if(!displayPreferences){
    displayPath=(await runtime.GetResourcePath())+'/Scripts/zaibuyidao Scripts/Modules/ReaGBA/config/ui.json';
    const loaded={...displayDefaults};
    for(const key of displayKeys)if(key in result.result)loaded[key]=result.result[key];
    if((await runtime.fs.stat(displayPath)).exists){
     const saved=JSON.parse(await runtime.fs.readFile(displayPath));
     if(!saved||typeof saved!=='object'||Array.isArray(saved))throw Error('Invalid UI preferences');
     validateDisplay(saved);for(const key of displayKeys)if(key in saved)loaded[key]=saved[key];
    }
    displayPreferences=loaded;
   }
   if(Object.keys(display).length){
    const next={...displayPreferences,...display};
    await runtime.fs.writeFile(displayPath,JSON.stringify(next),{overwrite:true});displayPreferences=next;
   }
   return {...result,result:{...result.result,...displayPreferences}};
  });
  preferencesQueue=task;return task;
 }

 window.nativeRequest=async command=>{
  await ready;
  const ok=result=>({ok:true,result});
  switch(command.action){
   case 'game_viewport':video?.draw();return ok(true);
   case 'keyboard_context':blocked=command.blocked;if(blocked)release();return ok(true);
   case 'focus_game':await focusGame();return ok(true);
   case 'toggle_dock':docked=await runtime.window.setDocked(!docked);window.onNativeState?.(enrich(state));return ok(true);
   case 'fullscreen':await document.getElementById('game-viewport').requestFullscreen();return ok(true);
   case 'open_rom':{
    release();
    const path=await runtime.dialog.openFile({title:command.dialog_title,initialPath:command.initial_path,filters:[{name:'GBA ROM',extensions:['gba']}]});
    if(!path)return ok(null);
    const result=await request({action:'load_rom',path});if(result.ok)await focusGame();return result;
   }
   case 'select_rom_directory':{
    release();
    const path=await runtime.dialog.selectFolder({title:command.dialog_title,initialPath:command.initial_path});
    return path?preferences({action:'set_settings',settings:{rom_directory:path,last_rom_directory:path}}):ok(null);
   }
  }
  const result=await (command.action==='get_settings'||command.action==='set_settings'?preferences(command):request(command));
  if(result.ok&&(command.action==='load_rom'||command.action==='start'))await focusGame();
  if(result.ok&&(command.action==='set_settings'||command.action==='get_settings')){
   // Draw after the existing caller installs the returned preferences.
   queueMicrotask(()=>requestAnimationFrame(()=>video?.draw()));
   release();
  }
  return result;
 };
 const keyName=code=>({ArrowUp:'Up',ArrowDown:'Down',ArrowLeft:'Left',ArrowRight:'Right',Enter:'Return',Space:'Space',Backspace:'Backspace',ShiftLeft:'Left Shift',ShiftRight:'Right Shift',ControlLeft:'Left Ctrl',ControlRight:'Right Ctrl',AltLeft:'Left Alt',AltRight:'Right Alt',Escape:'Escape',Tab:'Tab'}[code]||(/^Key[A-Z]$/.test(code)?code.slice(3):/^Digit[0-9]$/.test(code)?code.slice(5):code));
 function input(){
  const active=!blocked&&!editing()&&document.hasFocus()&&!document.hidden;
  let mask=0;const keys=settings.keys||defaultKeys;
  if(active)for(let i=0;i<10;i++)if(pressed.has(keys[i]))mask|=1<<i;
  const fast=active&&pressed.has(settings.fast_forward_key||'L');
  sendInput({mask,fast,active});
 }
 function release(){pressed.clear();sendInput({mask:0,fast:false,active:false});}
 document.addEventListener('keydown',event=>{
  if(blocked||editing())return;
  const key=keyName(event.code);
  if(!(settings.keys||defaultKeys).includes(key)&&key!==(settings.fast_forward_key||'L'))return;
  event.preventDefault();if(pressed.has(key))return;pressed.add(key);input();
 });
 document.addEventListener('keyup',event=>{const key=keyName(event.code);if(pressed.delete(key)){event.preventDefault();input();}});
 window.addEventListener('blur',release);
 document.addEventListener('visibilitychange',()=>{if(document.hidden)release();});
 ready.then(async()=>{stopInput=await runtime.system.schedule(input,{delay:200,interval:200});}).catch(report);
 let disposed=false;
 function cleanup(){
  if(disposed)return;disposed=true;release();
  return Promise.all([stopStatus?.(),stopInput?.(),stream?.close()]);
 }
 window.addEventListener('pagehide',()=>{if(!disposed){disposed=true;stopStatus?.();stopInput?.();stream?.close();}});
})();

const $=id=>document.getElementById(id);
const i18n=window.ReaGBAI18n,t=(key,values)=>i18n.t(key,values);
let games=[],filter='all',selected=null,state={loaded:false,running:false,speed:1},slot=1,slots=[],settings={},binding=-1;
let toastTimer;
function toast(message,error=false){$('toast').textContent=message;$('toast').className='visible'+(error?' error':'');clearTimeout(toastTimer);toastTimer=setTimeout(()=>$('toast').className='',3500);}
async function call(action,values={}){if(!window.nativeRequest)throw Error(t('openInReaper'));const result=await window.nativeRequest({action,...values});if(!result.ok)throw Error(result.error?i18n.error(result.error):t('failed'));return result.result;}
function run(fn){return async(...args)=>{try{await fn(...args);}catch(error){toast(error.message,true);}};}
function make(tag,cls,text){const e=document.createElement(tag);if(cls)e.className=cls;if(text!==undefined)e.textContent=text;return e;}
function parentDirectory(path){const cut=Math.max(path.lastIndexOf('/'),path.lastIndexOf('\\'));if(cut<0)return '';if(cut===0)return path[0];if(cut===2&&path[1]===':')return path.slice(0,3);return path.slice(0,cut);}
const coverCache=new Map();
let coversLoading=false,coverRevision=0;
function coverLetter(g){return Array.from((g.code||'').trim())[0]||Array.from(g.title||'')[0]||'G';}
function fillCover(cover,g){
 cover.replaceChildren();cover.classList.remove('has-image');
 cover.append(make('b','',coverLetter(g)),make('span','','ADVANCE'));
 cover.title=t('noCover',{code:g.code||t('unknown')});
 const source=coverCache.get(g.code)?.image;
 if(!source)return;
 const img=make('img');img.alt=t('coverAlt',{title:g.title});img.decoding='async';img.loading='lazy';
 img.onload=()=>{cover.classList.add('has-image');cover.title=t('coverSource',{title:g.title});};
 img.onerror=()=>{coverCache.set(g.code,{status:'error',retry:Date.now()+600000});img.remove();cover.classList.remove('has-image');cover.title=t('coverError',{code:g.code});renderCoverStatus();};
 img.src=source;cover.append(img);
}
function refreshCover(code){for(const cover of document.querySelectorAll('.cover'))if(cover.dataset.code===code){const g=games.find(g=>g.path===cover.dataset.path);if(g)fillCover(cover,g);}}
function renderCoverStatus(){
 const codes=[...new Set(games.map(g=>g.code))],count=status=>codes.filter(code=>coverCache.get(code)?.status===status).length;
 $('cover-status').textContent=(coversLoading?t('coversChecking'):'')+t('coversCached',{ready:i18n.number(count('ready')),total:i18n.number(codes.length)})+(count('missing')?t('coversMissing',{count:i18n.number(count('missing'))}):'')+(count('error')?t('coversError'):'');
}
async function loadCovers(){
 if(coversLoading)return;
 coversLoading=true;renderCoverStatus();
 try{
  for(;;){
   const g=games.find(g=>!coverCache.has(g.code)||(coverCache.get(g.code).retry||Infinity)<=Date.now());
   if(!g)break;
   const revision=coverRevision;let result;
   try{
    do{result=await call('get_cover',{code:g.code||''});if(result?.status==='pending'||result?.status==='busy')await new Promise(resolve=>setTimeout(resolve,150));}
    while(result?.status==='pending'||result?.status==='busy');
    if(!result||typeof result.status!=='string')result={status:'missing'};
   }catch{result={status:'error'};}
   if(revision!==coverRevision&&result.status!=='ready')continue;
   coverCache.set(g.code,{...result,retry:result.status==='error'?Date.now()+600000:result.status==='missing'?Date.now()+604800000:Infinity});
   refreshCover(g.code);renderCoverStatus();
  }
 }finally{coversLoading=false;renderCoverStatus();}
}
function renderLibrarySettings(){
 const view=['grid','compact'].includes(settings.library_view)?settings.library_view:'details';
 $('games').dataset.view=view;$('library-display').value=view;$('library-display-setting').value=view;
 $('auto-covers').checked=settings.auto_download_covers===true;
}
async function changeLibraryView(value){try{await saveSettings({library_view:value});}finally{renderLibrarySettings();scheduleViewport();}}
$('library-display').onchange=run(()=>changeLibraryView($('library-display').value));
$('library-display-setting').onchange=run(()=>changeLibraryView($('library-display-setting').value));
$('auto-covers').onchange=run(async()=>{
 $('auto-covers').disabled=true;
 try{await saveSettings({auto_download_covers:$('auto-covers').checked});++coverRevision;for(const [code,entry] of coverCache)if(entry.status!=='ready')coverCache.delete(code);void loadCovers();}
 finally{$('auto-covers').disabled=false;renderLibrarySettings();}
});
function renderGames(){
 const search=$('search').value.trim().toLocaleLowerCase(i18n.language);let rows=games.filter(g=>(filter!=='favorite'||g.favorite)&&(filter!=='recent'||g.last_played>0)&&g.title.toLocaleLowerCase(i18n.language).includes(search));
 const mode=$('sort').value;rows.sort((a,b)=>mode==='time'?(b.play_seconds-a.play_seconds):mode==='recent'||filter==='recent'?(b.last_played-a.last_played):a.title.localeCompare(b.title,i18n.language));
 $('count').textContent=i18n.number(games.length);$('empty').querySelector('h2').textContent=t(games.length?'noResults':'emptyTitle');$('empty').querySelector('p').textContent=t(games.length?'noResultsHint':'emptyHint');$('games').replaceChildren();$('empty').hidden=rows.length>0;$('games').hidden=rows.length===0;
 for(const g of rows){
  const card=make('article','game'+(selected?.path===g.path?' selected':''));card.tabIndex=0;card.setAttribute('aria-label',g.title);card.dataset.path=g.path;
  const cover=make('div','cover');cover.dataset.code=g.code||'';cover.dataset.path=g.path;fillCover(cover,g);
  const info=make('div','game-info'),title=make('h2','',g.title);title.title=g.title;
  info.append(title,make('span','tag','GBA'),make('div','game-meta',`${i18n.number(Math.round(g.size/1048576))} MB · ${g.play_seconds>=60?t('playTime',{count:i18n.number(Math.floor(g.play_seconds/60))}):t('noPlayTime')}`));
  const fav=make('button','favorite'+(g.favorite?' on':''),g.favorite?'★':'☆');fav.title=t(g.favorite?'unfavorite':'favorite');fav.setAttribute('aria-label',fav.title+' '+g.title);fav.setAttribute('aria-pressed',String(g.favorite));
  fav.onclick=run(async e=>{e.stopPropagation();await call('favorite',{path:g.path,value:!g.favorite});g.favorite=!g.favorite;renderGames();});
  const play=make('button','launch',t('play'));play.setAttribute('aria-label',t('playTitle',{title:g.title}));play.onclick=run(async e=>{e.stopPropagation();await playGame(g);});
  card.append(cover,info,fav,play);
  card.onclick=()=>{selected=g;document.querySelectorAll('.game').forEach(c=>c.classList.toggle('selected',c.dataset.path===g.path));if(!state.loaded)$('toggle').disabled=false;};
  card.ondblclick=run(e=>{if(!e.target.closest('button'))return playGame(g);});
  card.onkeydown=run(async e=>{if(e.key==='Enter'&&e.target===card){e.preventDefault();await playGame(g);}});
  $('games').append(card);
 }
}
async function scan(){games=await call('scan_roms');if(selected)selected=games.find(g=>g.path===selected.path)||null;if(!selected&&games.length)selected=games[0];renderGames();if(!state.loaded)$('toggle').disabled=!selected;void loadCovers();}
async function playGame(g){selected=g;const s=await call('load_rom',{path:g.path});onNativeState(s);await refreshSlots();await scan();scheduleViewport();showKeyHint();}
function renderState(s){if(s.app_version){$('about-version').textContent=s.app_version;$('footer-version').textContent='v'+s.app_version;}document.body.classList.toggle('playing',s.loaded);scheduleViewport();$('now-title').textContent=s.game?.title||selected?.title||t('chooseGame');$('now-subtitle').textContent=s.loaded?`${s.game.code} · 240 × 160 · ${s.core}`:'240 × 160 · Game Boy Advance';$('play-status').textContent=t(s.loaded?(s.running?'playing':'paused'):'ready');$('play-dot').className='dot'+(s.running?'':' idle');$('fps').textContent=s.running?`${i18n.number(s.fps,{minimumFractionDigits:1,maximumFractionDigits:1})} FPS`:'— FPS';$('speed').textContent=s.speed+'×';$('toggle').textContent=t(s.running?'pause':s.loaded?'resume':'start');$('toggle').disabled=!s.loaded&&!selected;for(const id of ['reset','shot','stop','save'])$(id).disabled=!s.loaded;$('load').disabled=!s.loaded||!slots.find(x=>x.slot===slot)?.exists;if('reaper' in s){$('dock-toggle').hidden=!s.reaper;$('dock-toggle').textContent=t(s.docked?'undock':'dock');$('fullscreen').hidden=!!s.reaper;}}
window.onNativeState=function(s){const changed=state.game?.hash!==s.game?.hash;state=s;if(s.game?.path)settings.last_rom_directory=parentDirectory(s.game.path);renderState(s);if(changed)run(refreshSlots)();if(s.error)toast(i18n.error(s.error),true);};
$('dock-toggle').onclick=run(()=>call('toggle_dock'));
async function refreshSlots(){slots=state.loaded?await call('get_save_states'):[];renderSlots();}
function renderSlots(){$('slots').replaceChildren();for(let n=1;n<=9;n++){const entry=slots.find(x=>x.slot===n);const b=make('button',(slot===n?'selected ':'')+(entry?.exists?'saved':''),n);b.title=entry?.metadata?i18n.date(new Date(entry.metadata.timestamp*1000)):t('emptySlot');b.onclick=()=>{slot=n;renderSlots();};b.setAttribute('aria-label',t('slotLabel',{slot:i18n.number(n),detail:b.title}));b.setAttribute('aria-pressed',String(slot===n));$('slots').append(b);}$('save-hint').textContent=t(slots.find(x=>x.slot===slot)?.exists?'slotSaved':'slotEmpty',{slot:i18n.number(slot)});$('load').disabled=!state.loaded||!slots.find(x=>x.slot===slot)?.exists;}
const defaultKeys=['J','K','Space','Return','D','A','W','S','Q','O'];const labels=['A','B','Select','Start','→','←','↑','↓','R','L','holdFast'];
function showKeyHint(){const keys=settings.keys||defaultKeys;toast(t('keyHint',{up:keys[6],down:keys[7],left:keys[5],right:keys[4],a:keys[0],b:keys[1],r:keys[8],l:keys[9],start:keys[3],select:keys[2],fast:settings.fast_forward_key||'L'}));}
function renderKeys(){$('keys').replaceChildren();[...(settings.keys||defaultKeys),settings.fast_forward_key||'L'].forEach((key,i)=>{const row=make('div','key-pair');const b=make('button','',binding===i?t('pressKey'):key);b.onclick=()=>{binding=i;renderKeys();};row.append(make('span','',i===10?t('holdFast'):labels[i]),b);$('keys').append(row);});}
async function saveSettings(values){settings=await call('set_settings',{settings:values});}
function renderShader(){const preset=settings.shader||'none';$('shader').value=preset;$('filter').disabled=preset!=='none';}
$('shader').onchange=run(async()=>{try{await saveSettings({shader:$('shader').value});}finally{renderShader();}});
document.addEventListener('keydown',run(async e=>{if(binding<0)return;e.preventDefault();e.stopPropagation();const map={ArrowUp:'Up',ArrowDown:'Down',ArrowLeft:'Left',ArrowRight:'Right',Enter:'Return',Space:'Space',Backspace:'Backspace',ShiftLeft:'Left Shift',ShiftRight:'Right Shift'};const key=map[e.code]||(/^Key[A-Z]$/.test(e.code)?e.code.slice(3):/^Digit[0-9]$/.test(e.code)?e.code.slice(5):null);if(e.key==='Escape'){binding=-1;renderKeys();return;}if(!key){toast(t('unsupportedKey'),true);return;}const index=binding;binding=-1;if(index===10)await saveSettings({fast_forward_key:key});else{const keys=[...(settings.keys||defaultKeys)];keys[index]=key;await saveSettings({keys});}renderKeys();}),true);
$('settings-toggle').onclick=()=>{const show=$('settings-view').hidden;$('settings-view').hidden=!show;$('library-view').hidden=show;$('settings-toggle').textContent=show?'×':'⚙';renderSettingsToggle();binding=-1;document.body.classList.toggle('settings-open',show);updateKeyboardContext();scheduleViewport();};
document.querySelectorAll('.tab').forEach(b=>b.onclick=()=>{filter=b.dataset.filter;document.querySelectorAll('.tab').forEach(x=>x.classList.toggle('active',x===b));renderGames();});
$('search').oninput=renderGames;$('sort').onchange=renderGames;$('refresh').onclick=run(scan);
$('open').onclick=run(async()=>{const s=await call('open_rom',{dialog_title:t('dialogROM'),initial_path:settings.last_rom_directory||settings.rom_directory||''});if(s){onNativeState(s);await scan();await refreshSlots();showKeyHint();}});
$('toggle').onclick=run(async()=>{if(!state.loaded&&selected)return playGame(selected);onNativeState(await call(state.running?'pause':'start'));});
for(const id of ['reset','stop'])$(id).onclick=run(async()=>onNativeState(await call(id)));
$('speed').onclick=run(async()=>onNativeState(await call('set_speed',{value:state.base_speed===1?2:state.base_speed===2?4:1})));
$('fullscreen').onclick=run(()=>call('fullscreen'));
$('shot').onclick=run(async()=>{await call('screenshot');toast(t('shotSaved'));});
$('save').onclick=run(async()=>{await call('save_state',{slot});await refreshSlots();toast(t('stateSaved',{slot:i18n.number(slot)}));});
$('load').onclick=run(async()=>{onNativeState(await call('load_state',{slot}));toast(t('stateLoaded',{slot:i18n.number(slot)}));});
$('volume').oninput=()=>$('volume-value').textContent=$('volume').value+'%';$('volume').onchange=run(()=>call('set_volume',{value:Number($('volume').value)/100}));
$('integer').onchange=run(()=>saveSettings({integer_scaling:$('integer').checked}));$('vsync').onchange=run(()=>saveSettings({vsync:$('vsync').checked}));$('filter').onchange=run(()=>saveSettings({filter:$('filter').value}));$('skip').onchange=run(()=>call('set_frame_skip',{value:Number($('skip').value)}));$('save-bios').onclick=run(async()=>{await saveSettings({bios:$('bios').value.trim()});toast(t('biosSaved'));});
$('choose-rom-directory').onclick=run(async()=>{const chosen=await call('select_rom_directory',{dialog_title:t('dialogFolder'),initial_path:settings.rom_directory||''});if(!chosen)return;settings=chosen;$('rom-directory').value=settings.rom_directory||'';await scan();toast(t('folderSaved'));});

// The library takes surplus height; the game rectangle always stays 3:2.
let libraryPreference=null,splitDrag=null,paneBounds=null,splitSaveTimer;
const splitKey=()=>'library_split';
const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));
function setPixels(element,property,value){const next=Math.max(0,value)+'px';if(element.style[property]!==next)element.style[property]=next;}
function sizePanes(){
 const divider=$('library-splitter');
 if(!$('settings-view').hidden){divider.hidden=true;return;}
 const main=document.querySelector('main'),library=$('library-view'),body=$('library-body'),player=$('player');
 const style=getComputedStyle(main),available=main.clientHeight-parseFloat(style.paddingTop)-parseFloat(style.paddingBottom);
 const outerHeight=e=>{const s=getComputedStyle(e);return e.getBoundingClientRect().height+parseFloat(s.marginTop)+parseFloat(s.marginBottom);};
 // Measure intrinsic controls, never the stretched height of the controls column.
 document.body.classList.remove('library-collapsed');body.hidden=false;
 const libraryChrome=library.querySelector('.heading').getBoundingClientRect().height+outerHeight(body.querySelector('nav'))+outerHeight(body.querySelector('.search-row'));
 const firstCard=$('games').firstElementChild;
 const rowHeight=settings.library_view==='grid'&&firstCard?Math.ceil(firstCard.getBoundingClientRect().height)+4:106;
 const minLibrary=libraryChrome+Math.max(96,Math.min(rowHeight,400));
 const controls=document.querySelector('.player-controls'),workspace=document.querySelector('.play-workspace'),stage=document.querySelector('.game-stage');
 const controlsHeight=outerHeight(document.querySelector('.play-actions'))+outerHeight(document.querySelector('.save-heading'))+outerHeight($('slots'))+outerHeight(document.querySelector('.save-actions'))+parseFloat(getComputedStyle(controls).gap);
 const headingHeight=outerHeight(document.querySelector('.player-heading'))+parseFloat(getComputedStyle(player).gap);
 const chrome=headingHeight+controlsHeight+parseFloat(getComputedStyle(workspace).rowGap);
 const minPlayer=chrome+64,maxPlayer=chrome+stage.clientWidth/1.5;
 const expanded=libraryPreference??(available>=minLibrary+chrome+160+20);
 body.hidden=!expanded;divider.hidden=!expanded;
 document.body.classList.toggle('library-collapsed',!expanded);
 $('library-toggle').textContent=t(expanded?'collapseLibrary':'expandLibrary');$('library-toggle').setAttribute('aria-expanded',String(expanded));
 if(expanded){
   const total=Math.max(available-20,minLibrary+minPlayer);
   const min=Math.max(minLibrary,total-maxPlayer),max=total-minPlayer;
   const ratio=settings[splitKey()];
   const libraryHeight=clamp(typeof ratio==='number'&&Number.isFinite(ratio)?ratio*total:min,min,max);
   setPixels(library,'height',libraryHeight);setPixels(player,'height',total-libraryHeight);
   paneBounds={min,max,total,height:libraryHeight};
   for(const [name,value] of [['min',min],['max',max],['now',libraryHeight]])divider.setAttribute('aria-value'+name,Math.round(value/total*100));
   divider.setAttribute('aria-valuetext',t('splitValue',{library:i18n.number(Math.round(libraryHeight/total*100)),game:i18n.number(Math.round((total-libraryHeight)/total*100))}));
 }else{
   library.style.height='auto';paneBounds=null;
   setPixels(player,'height',Math.max(minPlayer,Math.min(maxPlayer,available-outerHeight(library))));
 }
 const bounds=stage.getBoundingClientRect(),width=Math.max(0,Math.min(bounds.width,bounds.height*1.5));
 setPixels($('game-viewport'),'width',width);setPixels($('game-viewport'),'height',width/1.5);
}
function changeSplit(height){if(!paneBounds)return;settings[splitKey()]=clamp(height,paneBounds.min,paneBounds.max)/paneBounds.total;scheduleViewport();}
function persistSplit(){clearTimeout(splitSaveTimer);const key=splitKey(),value=settings[key];return saveSettings({[key]:value});}
$('library-splitter').addEventListener('pointerdown',e=>{
 if(e.button!==0||!paneBounds)return;e.preventDefault();clearTimeout(splitSaveTimer);
 const divider=$('library-splitter');divider.focus();divider.setPointerCapture(e.pointerId);
 splitDrag={id:e.pointerId,y:e.clientY,height:paneBounds.height,key:splitKey(),original:settings[splitKey()]??null};
 document.body.classList.add('resizing-library');updateKeyboardContext();
});
$('library-splitter').addEventListener('pointermove',e=>{if(splitDrag?.id===e.pointerId)changeSplit(splitDrag.height+e.clientY-splitDrag.y);});
function endSplit(cancel=false){
 if(!splitDrag)return;const drag=splitDrag;splitDrag=null;
 if(cancel){settings[drag.key]=drag.original;scheduleViewport();}else if(settings[drag.key]!==undefined)run(()=>saveSettings({[drag.key]:settings[drag.key]}))();
 document.body.classList.remove('resizing-library');
 if($('library-splitter').hasPointerCapture(drag.id))$('library-splitter').releasePointerCapture(drag.id);
 updateKeyboardContext();
}
$('library-splitter').addEventListener('pointerup',()=>endSplit());
$('library-splitter').addEventListener('pointercancel',()=>endSplit(true));
$('library-splitter').addEventListener('lostpointercapture',()=>endSplit(true));
window.addEventListener('blur',()=>endSplit(true));
$('library-splitter').ondblclick=run(async()=>{settings[splitKey()]=null;scheduleViewport();await persistSplit();toast(t('splitReset'));});
$('library-splitter').addEventListener('keydown',e=>{
 if(e.key==='Escape'&&splitDrag){e.preventDefault();endSplit(true);return;}
 if(!paneBounds||!['ArrowUp','ArrowDown','Home','End'].includes(e.key))return;
 e.preventDefault();const step=e.shiftKey?40:12;
 changeSplit(e.key==='Home'?paneBounds.min:e.key==='End'?paneBounds.max:paneBounds.height+(e.key==='ArrowDown'?step:-step));
 clearTimeout(splitSaveTimer);splitSaveTimer=setTimeout(run(persistSplit),200);
});
function setLibraryExpanded(expanded){libraryPreference=expanded;scheduleViewport();run(()=>saveSettings({library_expanded:expanded}))();}
$('library-toggle').onclick=()=>setLibraryExpanded($('library-body').hidden);
$('reset-keys').onclick=run(async()=>{binding=-1;await saveSettings({keys:defaultKeys,fast_forward_key:'L'});renderKeys();toast(t('keysReset'));});
function editing(){const e=document.activeElement;return !$('settings-view').hidden||binding>=0||!!splitDrag||!!e?.matches('input,textarea,select,[role="separator"],[contenteditable="true"]');}
let keyboardContext=null;
function updateKeyboardContext(){const blocked=editing();if(blocked!==keyboardContext){keyboardContext=blocked;call('keyboard_context',{blocked}).catch(error=>toast(error.message,true));}}
document.addEventListener('focusin',updateKeyboardContext,true);
document.addEventListener('focusout',()=>queueMicrotask(updateKeyboardContext),true);
$('game-viewport').onclick=run(()=>call('focus_game'));
// Keep the original layout; the ReaWebAPI adapter redraws the WebView canvas.
let viewportQueued=false,lastViewport='';
function layoutMetrics(){const box=id=>{const r=$(id).getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height,bottom:r.bottom,right:r.right};};return {mode:'vertical',window:{width:innerWidth,height:innerHeight},game:box('game-viewport'),save:box('save'),load:box('load'),player:box('player'),library:box('library-view'),splitter:box('library-splitter'),libraryExpanded:!$('library-body').hidden,mainBottom:document.querySelector('main').getBoundingClientRect().bottom,scrollHeight:document.querySelector('main').scrollHeight,clientHeight:document.querySelector('main').clientHeight};}
function scheduleViewport(){if(viewportQueued)return;viewportQueued=true;requestAnimationFrame(()=>{viewportQueued=false;sizePanes();const r=$('game-viewport').getBoundingClientRect(),m=document.querySelector('main').getBoundingClientRect();const rect={x:r.x,y:r.y,width:r.width,height:r.height,clipTop:m.top,clipBottom:m.bottom,clientWidth:innerWidth,visible:state.loaded&&r.width>0&&r.bottom>m.top&&r.top<m.bottom};const serialized=JSON.stringify(rect);if(serialized!==lastViewport){lastViewport=serialized;call('game_viewport',{rect,layout:layoutMetrics()}).catch(error=>toast(error.message,true));}});}
document.querySelector('main').addEventListener('scroll',scheduleViewport,{passive:true});
window.addEventListener('resize',()=>{endSplit(true);scheduleViewport();});
new ResizeObserver(scheduleViewport).observe(document.querySelector('main'));
new ResizeObserver(scheduleViewport).observe($('player'));
new ResizeObserver(scheduleViewport).observe($('game-viewport'));
new ResizeObserver(scheduleViewport).observe($('library-view'));
new ResizeObserver(scheduleViewport).observe(document.querySelector('.player-controls'));
document.fonts.ready.then(scheduleViewport);

function renderSettingsToggle(){const text=t($('settings-view').hidden?'settings':'closeSettings');$('settings-toggle').title=text;$('settings-toggle').setAttribute('aria-label',text);}
function applyLanguage(value){
 i18n.set(value);document.documentElement.lang=i18n.language;i18n.apply();$('language').value=i18n.language;
 renderSettingsToggle();renderGames();renderCoverStatus();renderKeys();renderSlots();renderState(state);scheduleViewport();
}
for(const [code,catalog] of Object.entries(i18n.catalogs)){const option=make('option','',catalog.name);option.value=code;option.lang=code;$('language').append(option);}
$('language').onchange=run(async()=>{
 const previous=i18n.language,next=$('language').value;binding=-1;$('language').disabled=true;clearTimeout(toastTimer);$('toast').className='';
 applyLanguage(next);
 try{await saveSettings({language:next});if(settings.language!==next)throw Error(t('languageSaveFailed'));}
 catch(error){applyLanguage(previous);throw error;}
 finally{$('language').disabled=false;}
});
i18n.apply();
renderSlots();run(async()=>{settings=await call('get_settings');applyLanguage(settings.language);$('language').disabled=false;libraryPreference=typeof settings.library_expanded==='boolean'?settings.library_expanded:null;renderLibrarySettings();scheduleViewport();$('rom-directory').value=settings.rom_directory||'';$('integer').checked=settings.integer_scaling!==false;$('vsync').checked=settings.vsync!==false;$('filter').value=settings.filter||'nearest';renderShader();$('bios').value=settings.bios||'';renderKeys();await scan();const s=await call('get_emulator_state');$('volume').value=Math.round(s.volume*100);$('volume-value').textContent=$('volume').value+'%';onNativeState(s);})();// PCM remains in the GBA core extension.

// GBA pixels are presented inside the WebView. PCM stays in the core extension.
// LCD3X: Gigaherz's public-domain sinusoidal mask (libretro/glsl-shaders).
// lcd-grid-v2: cgwg's integrated LCD subpixel model, preserving ReaGBA's equations.
function createGameVideo(){
 const holder=document.getElementById('game-viewport'),canvas=document.createElement('canvas');
 canvas.id='game-frame';canvas.setAttribute('aria-hidden','true');holder.append(canvas);
 const gl=canvas.getContext('webgl2',{alpha:false,antialias:false,depth:false,stencil:false,preserveDrawingBuffer:true});
 let pixels=null,queued=false,program,texture,ctx,source,sourceContext;
 if(gl){
  const compile=(type,text)=>{const shader=gl.createShader(type);gl.shaderSource(shader,text);gl.compileShader(shader);if(!gl.getShaderParameter(shader,gl.COMPILE_STATUS))throw Error(gl.getShaderInfoLog(shader));return shader;};
  program=gl.createProgram();
  gl.attachShader(program,compile(gl.VERTEX_SHADER,`#version 300 es
precision highp float;
out vec2 uv;
void main(){uv=vec2((gl_VertexID<<1)&2,gl_VertexID&2);gl_Position=vec4(uv*vec2(2,-2)+vec2(-1,1),0,1);}`));
  gl.attachShader(program,compile(gl.FRAGMENT_SHADER,`#version 300 es
precision highp float;
precision highp int;
in vec2 uv;
uniform sampler2D frame;
uniform vec2 sourceSize;
uniform vec2 outputSize;
uniform int shaderPreset;
out vec4 color;
vec3 sampleFrame(vec2 coordinate){return texture(frame,coordinate).rgb;}
vec3 fetchFrame(ivec2 texel){return texelFetch(frame,clamp(texel,ivec2(0),ivec2(sourceSize)-1),0).rgb;}

vec3 lcd3x(vec2 uv) {
    const float pi = 3.141592654;
    vec2 phase = uv * sourceSize * (2.0 * pi);
    vec3 mask = (4.0 + sin(phase.x + pi * vec3(0.5, -1.0/6.0, -5.0/6.0))) / 5.0;
    return sampleFrame(uv) * mask * ((16.0 + sin(phase.y)) / 17.0);
}

// Antiderivatives of the squared horizontal and vertical subpixel profiles:
// (1-z^2-z^4+z^6)^2 and (1-2z^4+z^6)^2, supported on [-1,1].
vec3 profileIntegral(vec3 z, bool horizontal) {
    vec3 q = z*z;
    if (horizontal)
        return z*(1.0+q*(-2.0/3.0+q*(-1.0/5.0+q*(4.0/7.0+q*(-1.0/9.0+q*(-2.0/11.0+q/13.0))))));
    return z*(1.0+q*q*(-4.0/5.0+q*(2.0/7.0+q*(4.0/9.0+q*(-4.0/11.0+q/13.0)))));
}
vec3 coverage(vec3 distance, float footprint, float radius, bool horizontal) {
    vec3 lo = clamp((distance - footprint*0.5) / radius, -1.0, 1.0);
    vec3 hi = clamp((distance + footprint*0.5) / radius, -1.0, 1.0);
    return max((profileIntegral(hi, horizontal) - profileIntegral(lo, horizontal)) * (radius/footprint),
               vec3(0.0, 0.0, 0.0));
}
vec3 lcdLight(ivec2 texel) {
    vec3 value = fetchFrame(texel) + 0.05;
    return value * value * value;
}
vec3 lcdGrid(vec2 uv) {
    vec2 position = uv*sourceSize - 0.4999;
    ivec2 origin = ivec2(floor(position));
    vec2 fraction = position - vec2(origin);
    // Physical output pixels, not the WebView's CSS size (important on HiDPI).
    vec2 footprint = sourceSize / max(outputSize, vec2(1.0, 1.0));
    vec3 leftMask = coverage(fraction.x*3.0 + vec3(1.0, 0.0, -1.0), footprint.x*3.0, 1.5, true);
    vec3 rightMask = coverage(fraction.x*3.0 + vec3(-2.0, -3.0, -4.0), footprint.x*3.0, 1.5, true);
    vec3 rows = coverage(vec3(fraction.y, fraction.y-1.0, 0.0), footprint.y, 0.63, false);
    vec3 upper = lcdLight(origin)*leftMask + lcdLight(origin+ivec2(1,0))*rightMask;
    vec3 lower = lcdLight(origin+ivec2(0,1))*leftMask + lcdLight(origin+ivec2(1,1))*rightMask;
    return pow(max(upper*rows.x + lower*rows.y, vec3(0.0,0.0,0.0)), vec3(1.0/2.2,1.0/2.2,1.0/2.2));
}
vec3 shadeFrame(vec2 uv) {
    if (shaderPreset == 1) return lcd3x(uv);
    if (shaderPreset == 2) return lcdGrid(uv);
    return sampleFrame(uv);
}

void main(){color=vec4(shadeFrame(uv),1.0);}`));
  gl.linkProgram(program);if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw Error(gl.getProgramInfoLog(program));
  gl.useProgram(program);texture=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,texture);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
  gl.uniform1i(gl.getUniformLocation(program,'frame'),0);gl.uniform2f(gl.getUniformLocation(program,'sourceSize'),240,160);
  gl.disable(gl.DITHER);
 }else{
  ctx=canvas.getContext('2d',{alpha:false});source=document.createElement('canvas');source.width=240;source.height=160;sourceContext=source.getContext('2d');
 }
 // CPU fallback uses the same subpixel equations when WebGL2 is unavailable.
 function softwareShader(width,height,preset){
  const image=ctx.createImageData(width,height),out=image.data;
  const sample=(x,y,c)=>pixels[(Math.max(0,Math.min(159,y))*240+Math.max(0,Math.min(239,x)))*4+c]/255;
  const integral=(z,h)=>{const q=z*z;return h?z*(1+q*(-2/3+q*(-1/5+q*(4/7+q*(-1/9+q*(-2/11+q/13)))))):z*(1+q*q*(-4/5+q*(2/7+q*(4/9+q*(-4/11+q/13)))));};
  const coverage=(distance,footprint,radius,h)=>{
   const lo=Math.max(-1,Math.min(1,(distance-footprint*.5)/radius)),hi=Math.max(-1,Math.min(1,(distance+footprint*.5)/radius));
   return Math.max(0,(integral(hi,h)-integral(lo,h))*radius/footprint);
  };
  const columns=Array.from({length:width},(_,x)=>{
   const u=(x+.5)*240/width,position=u-.4999,origin=Math.floor(position),fraction=position-origin;
   return {u,origin,left:[1,0,-1].map(n=>coverage(fraction*3+n,240/width*3,1.5,true)),right:[-2,-3,-4].map(n=>coverage(fraction*3+n,240/width*3,1.5,true))};
  });
  for(let y=0;y<height;y++){
   const v=(y+.5)*160/height,position=v-.4999,origin=Math.floor(position),fraction=position-origin;
   const upper=coverage(fraction,160/height,.63,false),lower=coverage(fraction-1,160/height,.63,false);
   for(let x=0;x<width;x++){
    const column=columns[x],offset=(y*width+x)*4;
    for(let c=0;c<3;c++){
     let value;
     if(preset==='lcd3x')value=sample(Math.floor(column.u),Math.floor(v),c)*(4+Math.sin(column.u*2*Math.PI+Math.PI*[.5,-1/6,-5/6][c]))/5*(16+Math.sin(v*2*Math.PI))/17;
     else{
      const light=(sx,sy)=>Math.pow(sample(sx,sy,c)+.05,3);
      const top=light(column.origin,origin)*column.left[c]+light(column.origin+1,origin)*column.right[c];
      const bottom=light(column.origin,origin+1)*column.left[c]+light(column.origin+1,origin+1)*column.right[c];
      value=Math.pow(Math.max(0,top*upper+bottom*lower),1/2.2);
     }
     out[offset+c]=Math.max(0,Math.min(255,Math.round(value*255)));
    }
    out[offset+3]=255;
   }
  }
  return image;
 }

 function drawNow(){
  queued=false;if(!pixels)return;
  const ratio=window.devicePixelRatio||1,w=Math.max(1,Math.round(holder.clientWidth*ratio)),h=Math.max(1,Math.round(holder.clientHeight*ratio));
  if(canvas.width!==w)canvas.width=w;if(canvas.height!==h)canvas.height=h;
  let scale=Math.min(w/240,h/160);if(settings.integer_scaling!==false&&scale>=1)scale=Math.floor(scale);
  const width=Math.max(1,Math.floor(240*scale)),height=Math.max(1,Math.floor(160*scale));
  const x=Math.floor((w-width)/2),y=Math.floor((h-height)/2);
  if(gl){
   gl.viewport(0,0,w,h);gl.clearColor(0,0,0,1);gl.clear(gl.COLOR_BUFFER_BIT);gl.viewport(x,y,width,height);
   const preset=settings.shader==='lcd3x'?1:settings.shader==='lcd-grid-v2'?2:0;
   const filter=!preset&&settings.filter==='linear'?gl.LINEAR:gl.NEAREST;
   gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,filter);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,filter);
   gl.uniform2f(gl.getUniformLocation(program,'outputSize'),width,height);gl.uniform1i(gl.getUniformLocation(program,'shaderPreset'),preset);
   gl.drawArrays(gl.TRIANGLES,0,3);
  }else{
   ctx.fillStyle='#000';ctx.fillRect(0,0,w,h);
   if(settings.shader==='lcd3x'||settings.shader==='lcd-grid-v2')ctx.putImageData(softwareShader(width,height,settings.shader),x,y);
   else{ctx.imageSmoothingEnabled=settings.filter==='linear';ctx.drawImage(source,x,y,width,height);}
  }
 }
 function draw(){if(settings.vsync===false)drawNow();else if(!queued){queued=true;requestAnimationFrame(drawNow);}}
 canvas.addEventListener('webglcontextlost',event=>{event.preventDefault();toast('Graphics context lost. Reopen ReaGBA.',true);});
 return {draw,frame(message){
  if(message.width!==240||message.height!==160||!(message.data instanceof Uint8Array)||message.data.byteLength!==240*160*4)throw Error('Invalid GBA frame');
  pixels=message.data;
  if(gl)gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA8,240,160,0,gl.RGBA,gl.UNSIGNED_BYTE,pixels);
  else sourceContext.putImageData(new ImageData(new Uint8ClampedArray(pixels.buffer),240,160),0,0);
  draw();
 }};
}
