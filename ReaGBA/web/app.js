'use strict';
// REAPER extension transport. The optional standalone test host supplies its own binding.
(()=>{
 if(window.nativeRequest)return;
 const web=window.chrome?.webview,kit=window.webkit?.messageHandlers?.reagba;
 if(!web&&!kit)return;
 let next=0;const pending=new Map();
 window.ReaGBAReceive=message=>{
   if(message.type==='state'){window.onNativeState?.(message.result);return;}
   const entry=pending.get(message.id);if(!entry)return;
   pending.delete(message.id);clearTimeout(entry.timer);entry.resolve(message);
 };
 web?.addEventListener('message',event=>window.ReaGBAReceive(event.data));
 window.nativeRequest=command=>new Promise((resolve,reject)=>{
   const id=++next;
   const timer=setTimeout(()=>{pending.delete(id);reject(Error(window.ReaGBAI18n?.t('timeout')||'The native extension did not respond. Reopen ReaGBA.'));},30000);
   pending.set(id,{resolve,timer});
   try{(web||kit).postMessage({...command,id});}catch(error){clearTimeout(timer);pending.delete(id);reject(error);}
 });
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

// The library takes surplus height; the native game rectangle always stays 3:2.
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
// Only a rectangle crosses the bridge; every game pixel stays in the native GPU view.
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
renderSlots();run(async()=>{settings=await call('get_settings');applyLanguage(settings.language);$('language').disabled=false;libraryPreference=typeof settings.library_expanded==='boolean'?settings.library_expanded:null;renderLibrarySettings();scheduleViewport();$('rom-directory').value=settings.rom_directory||'';$('integer').checked=settings.integer_scaling!==false;$('vsync').checked=settings.vsync!==false;$('filter').value=settings.filter||'nearest';renderShader();$('bios').value=settings.bios||'';renderKeys();await scan();const s=await call('get_emulator_state');$('volume').value=Math.round(s.volume*100);$('volume-value').textContent=$('volume').value+'%';onNativeState(s);})();// The game framebuffer and PCM never enter this script.
