'use strict';
// ReaWebAPI owns the WebView and transport. ReaGBA owns the native core session.
function initReaGBABridge(){
 if(window.nativeRequest||!window.reaper?.host)return;
 const runtime=window.reaper,gba=runtime.host.service('reagba');
 let inputReady=false,docked=false,blocked=false,video=null,stream=null,stopStatus=null,stopInput=null,lastFrame=null;
 const pressed=new Set();
 const enrich=value=>value&&typeof value==='object'&&'loaded' in value?{...value,reaper:true,docked}:value;
 const report=error=>toast(error.message,true);
 const ownsGame=()=>!window.ReaGBAPopout||window.ReaGBAPopout.ownsGame();
 const sendInput=value=>{if(inputReady&&ownsGame())gba.send('input',value);};
 const focusGame=async()=>{if(!ownsGame())return;await runtime.window.focus();document.getElementById('game-viewport').focus({preventScroll:true});};
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
  const capabilities=await runtime.lifecycle.ready;
  await runtime.window.setIconVisible(false);
  await runtime.lifecycle.on('cleanup',cleanup);
  if(!runtime.stream)throw Error('ReaGBA requires ReaWebAPI v0.3.6.4 or later');
  docked=await runtime.window.isDocked();
  await runtime.events.on('windowstatechange',value=>{
   docked=value.docked;
   if(!value.focused)release();
   if(window.onNativeState)window.onNativeState(enrich(state));
  });
  await window.ReaGBAPopout?.init(runtime,capabilities.windowId);
  await gba.invoke('getState');inputReady=true;
  stream=await runtime.stream.open('reagba.video');
  stream.on('data',frame=>{lastFrame=frame;if(!ownsGame())return;video??=createGameVideo();video.frame({width:stream.info.width,height:stream.info.height,data:frame.data});});
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
   case 'popout':release();await window.ReaGBAPopout.toggle();return ok(true);
   case 'game_viewport':if(ownsGame()&&lastFrame){video??=createGameVideo();video.frame({width:stream.info.width,height:stream.info.height,data:lastFrame.data});}return ok(true);
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
 ready.then(async()=>{stopInput=await runtime.system.schedule(input,{delay:200,interval:200});}).catch(error=>{report(error);window.ReaGBAPopout?.failed();});
 let disposed=false;
 function cleanup(){
  if(disposed)return;disposed=true;release();window.ReaGBAPopout?.dispose();
  return Promise.all([stopStatus?.(),stopInput?.(),stream?.close()]);
 }
 window.addEventListener('pagehide',()=>{if(!disposed){release();window.ReaGBAPopout?.dispose();disposed=true;stopStatus?.();stopInput?.();stream?.close();}});
}

