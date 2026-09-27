'use strict';
const gamepadSources=['a','b','x','y','back','guide','start','leftstick','rightstick','leftshoulder','rightshoulder','dpup','dpdown','dpleft','dpright','touchpad','leftup','leftdown','leftleft','leftright','rightup','rightdown','rightleft','rightright','lefttrigger','righttrigger'];
const gamepadTargets=['a','b','select','start','right','left','up','down','r','l','fast_forward'];
const gamepadActions=['a','b','a_turbo','b_turbo','select','start','up','down','left','right','l','r','fast_forward'];
function actionLabel(action){return action==='fast_forward'?t('holdFast'):action.endsWith('_turbo')?action[0].toUpperCase()+' '+t('gamepad_turbo'):labels[gamepadTargets.indexOf(action)];}
const actionBinding=action=>({target:action.replace(/_turbo$/,''),mode:action.endsWith('_turbo')?'turbo':'hold'});
function actionEntries(bindings,action){const binding=actionBinding(action);return Object.entries(bindings).filter(([,value])=>value.target===binding.target&&value.mode===binding.mode);}
const gamepadDefaultTargets=['a','b','none','none','select','none','start','none','none','l','r','up','down','left','right','none','up','down','left','right','none','none','none','none','none','none'];
function defaultGamepadBindings(){return Object.fromEntries(gamepadSources.map((source,i)=>[source,{target:gamepadDefaultTargets[i],mode:'hold'}]));}
let gamepadSaving=false,capture=null,captureTimer=null;
function sourceLabel(source){
 if(source.startsWith('button:'))return t('gamepadButton',{code:source.slice(7)});
 if(source.startsWith('axis:')){const [,code,direction]=source.split(':');return t('gamepadAxis',{code,direction});}
 if(source.startsWith('hat:')){const [,code,direction]=source.split(':');return t('gamepadHat',{code,direction:{1:'Up',2:'Right',4:'Down',8:'Left'}[direction]});}
 return t(`pad_${source}`);
}
function allBindings(){return {...defaultGamepadBindings(),...settings.gamepad_bindings};}
function renderGamepad(){
 const bindings=allBindings();$('gamepad-bindings').replaceChildren();
 for(const target of gamepadActions){
  const row=make('div','key-pair gamepad-action'),name=actionLabel(target),entries=actionEntries(bindings,target);
  const listening=capture?.target===target,caption=listening?t('pressKey'):entries.map(([source])=>sourceLabel(source)).join(' / ')||t('gamepadBind');
  const entry=make('div','gamepad-binding'),button=make('button','gamepad-source',caption);
  button.disabled=gamepadSaving||!!capture;button.dataset.target=target;button.setAttribute('aria-label',name+' · '+caption);button.onclick=run(()=>startCapture(target));
  button.classList.toggle('listening',listening);entry.append(button);
  row.append(make('span','gamepad-target',name),entry);$('gamepad-bindings').append(row);
 }
 $('reset-gamepad').disabled=gamepadSaving||!!capture;
 $('cancel-gamepad-capture').hidden=!capture;
}
async function saveGamepad(bindings){
 if(gamepadSaving)return;
 gamepadSaving=true;renderGamepad();
 try{
  await saveSettings({gamepad_bindings:bindings});
  if(!Object.entries(bindings).every(([source,binding])=>['target','mode'].every(field=>settings.gamepad_bindings?.[source]?.[field]===binding[field])))throw Error(t('gamepadSaveFailed'));
 }finally{gamepadSaving=false;renderGamepad();}
}
function cancelCapture(){clearTimeout(captureTimer);capture=null;$('gamepad-status').textContent='';renderGamepad();}
async function startCapture(target){
 cancelCapture();binding=-1;renderKeys();
 capture={target,instance:null,previous:new Set(),expires:Date.now()+15000};renderGamepad();
 await pollCapture(capture);
}
async function pollCapture(current){
 try{
  const input=await call('get_gamepad_input');
  if(capture!==current)return;
  if(Date.now()>current.expires){cancelCapture();toast(t('gamepadCaptureTimeout'));return;}
  if(!input.connected){current.instance=null;$('gamepad-status').textContent=t('gamepadDisconnected');}
  else{
   $('gamepad-status').textContent='';
   const held=new Set(input.inputs);
   if(current.instance===input.instance){
    const source=input.inputs.find(code=>!current.previous.has(code));
    if(source){
     const next=allBindings(),entries=actionEntries(next,current.target);
     for(const [previous] of entries)next[previous]={target:'none',mode:'hold'};
     for(const alias of input.aliases?.[source]||[])next[alias]={target:'none',mode:'hold'};
     next[source]=actionBinding(current.target);cancelCapture();await saveGamepad(next).catch(error=>toast(error.message,true));return;
    }
   }
   current.instance=input.instance;current.previous=held;
  }
  captureTimer=setTimeout(()=>pollCapture(current),50);
 }catch(error){if(capture!==current)return;cancelCapture();toast(error.message,true);}
}
function initGamepadBindings(){
 $('cancel-gamepad-capture').onclick=cancelCapture;
 document.addEventListener('keydown',event=>{if(event.key==='Escape'&&capture){event.preventDefault();cancelCapture();}});
 window.addEventListener('blur',()=>{if(capture)cancelCapture();});
 window.addEventListener('pagehide',()=>{capture=null;clearTimeout(captureTimer);});
 $('reset-gamepad').onclick=run(()=>saveGamepad(defaultGamepadBindings()));
}
