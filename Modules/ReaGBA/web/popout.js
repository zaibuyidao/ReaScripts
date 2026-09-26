'use strict';
// Separate per-window leases avoid lost updates between WebView processes.
window.ReaGBAPopout=(()=>{
 const child=document.body.classList.contains('game-window'),prefix='reagba:popout:';
 let runtime,id,parentId=null,childId=null,opened=0,seen=false,closing=false,stop=null,busy=false;
 const key=(role,value)=>prefix+role+':'+value;
 const read=(role,value)=>{const text=localStorage.getItem(key(role,value));return text?JSON.parse(text):null;};
 const write=(role,value,data)=>localStorage.setItem(key(role,value),JSON.stringify(data));
 const fresh=value=>value&&Date.now()-value.time<5000;
 function ownsGame(){
  if(closing)return false;
  if(!child)return childId===null;
  const owner=parentId===null?null:read('parent',parentId);
  return fresh(owner)&&owner.child===id;
 }
 function render(){
  document.body.classList.toggle('game-detached',childId!==null);
  if(!child){const button=document.getElementById('popout');button.textContent=childId===null?'↗':'↙';button.title=t(childId===null?'popout':'restoreGame');button.setAttribute('aria-label',button.title);scheduleViewport();}
 }
 function restore(){
  localStorage.removeItem(key('parent',id));
  if(childId!==null)localStorage.removeItem(key('child',childId));
  childId=null;seen=false;render();
 }
 function dispose(){
  if(closing)return;closing=true;stop?.();
  if(child){
   if(parentId===null||read('parent',parentId)?.child===id)write('child',id,{closed:true,time:Date.now()});
   else localStorage.removeItem(key('child',id));
  }
  else localStorage.removeItem(key('parent',id));
 }
 function close(){
  // Release input while this page still owns the game.
  if(ownsGame())runtime.host.service('reagba').send('input',{mask:0,fast:false,active:false});
  dispose();runtime.window.close().catch(()=>{});
 }
 function tick(){
  if(closing)return;
  if(child){
   if(parentId===null){
    for(let n=0;n<localStorage.length;n++){
     const name=localStorage.key(n);
     if(!name.startsWith(prefix+'parent:'))continue;
     const owner=JSON.parse(localStorage.getItem(name));
     if(owner?.child===id&&fresh(owner)){
      parentId=Number(name.slice((prefix+'parent:').length));
      window.nativeRequest?.({action:'game_viewport'}).catch(error=>toast(error.message,true));
      break;
     }
    }
    if(parentId===null){if(Date.now()-opened>15000)close();return;}
   }
   const owner=read('parent',parentId);
   if(!fresh(owner)||owner.child!==id){close();return;}
   window.applyGamePreferences?.(owner.settings);
   write('child',id,{time:Date.now()});
  }else if(childId!==null){
   const childState=read('child',childId);
   if(childState?.closed){restore();return;}
   if(fresh(childState))seen=true;
   else if(seen||Date.now()-opened>15000){restore();return;}
   write('parent',id,{child:childId,time:Date.now(),settings});
  }
 }
 async function init(host,windowId){
  runtime=host;id=windowId;opened=Date.now();
  if(child){localStorage.removeItem(key('child',id));await runtime.window.setDocked(false);tick();}
  else localStorage.removeItem(key('parent',id));
  stop=await runtime.system.schedule(()=>{try{tick();}catch(error){if(child)close();else{restore();toast(error.message,true);}}},{delay:200,interval:200});
 }
 async function toggle(){
  if(busy)return;
  if(childId!==null){restore();return;}
  busy=true;
  try{
   // Verify shared storage before opening a native window.
   write('parent',id,{child:null,time:Date.now()});
   const openedId=await runtime.window.open('game.html');
   if(!Number.isInteger(openedId)||openedId<=0)throw Error(t('popoutFailed'));
   childId=openedId;opened=Date.now();seen=false;
   tick();render();
  }catch(error){restore();throw error;}finally{busy=false;}
 }
 return {init,toggle,ownsGame,dispose,render,failed:()=>{if(child)close();}};
})();
