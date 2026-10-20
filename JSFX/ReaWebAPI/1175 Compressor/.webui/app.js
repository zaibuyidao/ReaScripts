import {connectJSFX} from './jsfx-webui.mjs';
import {buildPanel,paintTheme} from './panel.js';
import {meterAngle,MeterSignal} from './vu-meter.js';
import {openJSFXEditor} from './edit-jsfx.js';

const $=id=>document.getElementById(id);
const spec=[{min:-60,max:0,step:.1,def:0,invert:true,unit:'dB'},{min:0,max:9,step:1,def:5,unit:''},{min:-20,max:20,step:.1,def:0,unit:'dB'},{min:20,max:2000,step:10,def:20,invert:true,unit:'µs'},{min:20,max:1000,step:1,def:250,invert:true,unit:'ms'},{min:0,max:100,step:.1,def:100,unit:'%'}];
const values=spec.map(s=>s.def);
const ratioValues=[4,8,12,20];
let ratioButtons=new Set([4]),ratioPending=0,lastSingleRatio=0;
let jsfx=null,gesture=null,queue=Promise.resolve(),meterMode='gr',stream=null,opening=false,active=true;
let lastPacket=0,grDb=0,outPower=0,needle=meterAngle(0),frame=0,lastFrame=0,wheelTimer=0,disposed=false;
const meterSignal=new MeterSignal();
let meterSampleRate=0,meterGapUntil=0;
let nativeSizing=false,zoomRequest=0;
const pendingParameters=Array(6).fill(0);
let pointer=null,hostVisible=true,meterEpoch=0,meterClosing=Promise.resolve();
let bypassIndex=null,bypassed=false,bypassPending=0,transportQueue=Promise.resolve();
let recovering=null;
const limit=(v,a,b)=>Math.max(a,Math.min(b,v));
const norm=(i,v)=>(v-spec[i].min)/(spec[i].max-spec[i].min);
const real=(i,n)=>{const s=spec[i];return Number(limit(s.min+Math.round(n*(s.max-s.min)/s.step)*s.step,s.min,s.max).toFixed(4));};
const position=i=>spec[i].invert?1-norm(i,values[i]):norm(i,values[i]);
const fromPosition=(i,p)=>real(i,spec[i].invert?1-p:p);
const fmt=i=>[0,2,5].includes(i)?values[i].toFixed(1):String(Math.round(values[i]));
function report(e){
  if(jsfx&&!disposed&&(e?.code==='STALE_SESSION'||!jsfx.params.snapshot)){recoverSession();return;}
  $('message').hidden=false;$('message').textContent=`Connection: ${e?.message||e}`;
}
function recoverSession(){
  if(recovering)return recovering;
  recovering=(async()=>{
    // Starting transport can reinitialize the JSFX telemetry session. Refresh
    // the authoritative state; never replay a write against an obsolete session.
    for(let attempt=0;attempt<3&&!disposed;attempt++){
      await new Promise(resolve=>setTimeout(resolve,150*(attempt+1)));
      try{await jsfx.getCapabilities();hostState(await jsfx.params.getState());openMeter();return;}
      catch(e){if(attempt===2){$('message').hidden=false;$('message').textContent=`Connection: ${e.message}`;}}
    }
  })().finally(()=>recovering=null);
  return recovering;
}
async function readyParameters(){
  if(!jsfx.params.snapshot)await recoverSession();
  if(!jsfx.params.snapshot)throw Error('Parameters are reconnecting. Please try again.');
}
function remember(key,value){try{localStorage.setItem('1175.'+key,value);}catch{}}
function recall(key,fallback){try{return localStorage.getItem('1175.'+key)||fallback;}catch{return fallback;}}
function paintZoom(value){
  const zoom=[.5,.75,1,1.5,2,2.5,3].includes(Number(value))?Number(value):1;
  const viewport=$('surface-scroll'),previous=Number($('ui-zoom').dataset.current||1),factor=zoom/previous;
  $('app').style.setProperty('--ui-scale',nativeSizing?1:zoom);
  $('app').style.setProperty('--window-scale',zoom);$('ui-zoom').value=String(zoom);$('ui-zoom').dataset.current=zoom;
  viewport.scrollLeft*=factor;viewport.scrollTop*=factor;
  return zoom;
}
function setZoom(value){
  const zoom=paintZoom(value);remember('zoom',zoom);
  if(nativeSizing&&active&&!disposed){
    const request=++zoomRequest;$('ui-zoom').dataset.resizing='true';
    jsfx.editor.setSize(Math.round(1380*zoom),Math.ceil((30+1380*258/1400+34)*zoom))
      .catch(e=>{if(request===zoomRequest&&active)report(e);})
      .finally(()=>{if(request===zoomRequest)$('ui-zoom').dataset.resizing='false';});
  }
}
function editorSize(size){
  if(size?.customized){const zoom=size.width/1380;paintZoom(zoom);remember('zoom',zoom);}
}
function render(){
  for(const i of [0,2,3,4,5]){
    const angle=-135+270*position(i);
    $('rotor-'+i).setAttribute('transform',`rotate(${i===5?angle-135:angle})`);
    const k=$('knob-'+i),s=spec[i];
    if(k.dataset.angle!==String(angle)){
      k.dataset.angle=angle;
      const collar=k.querySelector('.collar-flutes');collar?.setAttribute('transform',`rotate(${angle})`);
      // The collar rotates mechanically; its lighting remains at eleven o'clock.
      for(const rib of collar?.children||[]){
        const light=Math.max(0,Math.cos((Number(rib.dataset.angle)+angle+30)*Math.PI/180));
        const tone=Math.round(20+light*48),edge=Math.round(28+light*63);
        rib.querySelectorAll('.rib-tone').forEach(s=>s.setAttribute('stop-color',`rgb(${tone},${tone+2},${tone-1})`));
        rib.querySelector('.rib-ridge').setAttribute('stop-color',`rgb(${edge},${edge+2},${edge-1})`);
        rib.querySelector('.flute-highlight').setAttribute('stroke',`rgb(${edge},${edge+2},${edge-1})`);
      }
    }
    k.setAttribute('aria-valuemin',s.min);k.setAttribute('aria-valuemax',s.max);k.setAttribute('aria-valuenow',values[i]);k.setAttribute('aria-valuetext',`${fmt(i)} ${s.unit}`);
    if(document.activeElement!==$('value-'+i))$('value-'+i).value=fmt(i);
  }
  const r=Math.round(values[1])%5,legacy=values[1]<5;
  if(r!==4){ratioButtons=new Set([ratioValues[r]]);lastSingleRatio=r;}
  else if(ratioButtons.size<2)ratioButtons=new Set(ratioValues);
  document.querySelectorAll('[data-ratio]').forEach(b=>b.setAttribute('aria-pressed',String(ratioButtons.has(Number(b.dataset.ratio)))));
  $('all').setAttribute('aria-pressed',String(ratioButtons.size===4));$('legacy').setAttribute('aria-pressed',String(legacy));
  $('legacy').querySelector('b').textContent=legacy?'LEGACY':'NORMAL';
  $('cap-switch').setAttribute('aria-pressed',String(legacy));$('cap-slot').setAttribute('transform',`rotate(${legacy?90:0})`);
}
function hostState(s){
  if(!s)return;
  const bypass=s.parameters.find(p=>/:bypass$/.test(p.ident||''));
  if(bypass){bypassIndex=bypass.index;if(!bypassPending)bypassed=bypass.normalized>=.5;}
  renderPower();
  for(const p of s.parameters){if(p.index>=6||pendingParameters[p.index]||(p.index===1&&ratioPending))continue;values[p.index]=real(p.index,p.normalized);}
  render();
}
function renderPower(){
  $('power').disabled=!!jsfx&&bypassIndex===null;
  $('power').setAttribute('aria-pressed',String(!bypassed));
  $('power').setAttribute('aria-label',bypassed?'Effect bypassed: enable':'Effect enabled: bypass');
}
function togglePower(){
  if(jsfx&&bypassIndex===null)return;
  finish();const target=!bypassed;bypassed=target;bypassPending++;renderPower();
  queue=queue.then(async()=>{
    try{if(jsfx){await readyParameters();await jsfx.params.set(bypassIndex,target?1:0);}}
    finally{bypassPending--;if(jsfx)hostState(jsfx.params.snapshot);else renderPower();}
  }).catch(report);
}
function isTransportSpace(e){return (e.code==='Space'||e.key===' ')&&!e.ctrlKey&&!e.altKey&&!e.metaKey;}
function transportSpace(e){
  if(!isTransportSpace(e))return;
  e.preventDefault();e.stopImmediatePropagation();if(e.repeat)return;
  // Commit a typed value or pending knob edit before returning Space to transport.
  if(document.activeElement instanceof HTMLInputElement)document.activeElement.blur();
  pointer=null;clearTimeout(wheelTimer);const editsDone=finish();
  const r=globalThis.reaper;if(!r?.GetPlayState)return;
  transportQueue=transportQueue.then(async()=>{
    await editsDone;
    const state=await r.GetPlayState();
    if(state&5)await r.OnStopButton();else await r.OnPlayButton();
  }).catch(report);
}
function setLocal(i,value){values[i]=limit(value,spec[i].min,spec[i].max);render();}
function begin(i,kind){
  if(gesture)finish(gesture);
  const previous=queue;
  let release;
  queue=new Promise(r=>release=r);
  const g={index:i,kind,value:values[i],closed:false,started:false,release};gesture=g;
  pendingParameters[i]++;
  g.ready=previous.then(async()=>{if(jsfx){await readyParameters();g.session=jsfx.params.snapshot.sessionId;await jsfx.params.beginEdit(i);g.started=true;}});
  // Observe rejection immediately even if the user is still holding the pointer.
  g.ready.catch(report);
  return g;
}
function move(g,value){
  if(g.closed)return;
  g.value=value;setLocal(g.index,value);
  if(g.started&&jsfx&&jsfx.params.snapshot&&g.session===jsfx.params.snapshot.sessionId)jsfx.params.set(g.index,norm(g.index,value)).catch(report);
}
function finish(g=gesture){
  if(!g||g.closed)return queue;
  g.closed=true;
  // Keep this index protected from stale host notifications until endEdit's snapshot.
  const work=(async()=>{
    try{
      await g.ready;
      if(g.started){try{
        if(jsfx.params.snapshot&&g.session===jsfx.params.snapshot.sessionId)await jsfx.params.set(g.index,norm(g.index,g.value));
      }finally{await jsfx.params.endEdit();}}
    }catch(e){report(e);}finally{
      pendingParameters[g.index]--;
      if(gesture===g)gesture=null;
      if(jsfx)hostState(jsfx.params.snapshot);else render();
      g.release();
    }
  })();
  return work;
}
function discrete(i,value){
  pendingParameters[i]++;
  const isRatio=i===1;if(isRatio)ratioPending++;
  finish();
  setLocal(i,value);
  queue=queue.then(async()=>{
    try{if(jsfx){await readyParameters();await jsfx.params.set(i,norm(i,value));}}
    finally{pendingParameters[i]--;if(isRatio)ratioPending--;if(jsfx)hostState(jsfx.params.snapshot);}
  }).catch(report);
  return queue;
}
function chooseRatio(r){return discrete(1,(values[1]<5?0:5)+r);}
function toggleRatio(value){
  // All multi-button combinations use the original JSFX All enumeration.
  // The selection is visual state; no new ratios or audio algorithms are added.
  if(ratioButtons.has(value)){
    if(ratioButtons.size===1)return;
    ratioButtons.delete(value);
  }else ratioButtons.add(value);
  return chooseRatio(ratioButtons.size>1?4:ratioValues.indexOf([...ratioButtons][0]));
}
function toggleAll(){
  // Restore the last single ratio when leaving ALL IN (4:1 if none is known).
  if(ratioButtons.size===ratioValues.length)return chooseRatio(lastSingleRatio);
  ratioButtons=new Set(ratioValues);return chooseRatio(4);
}
function toggleLegacy(){return discrete(1,(Math.round(values[1])+5)%10);}
function bindKnob(i){
  const k=$('knob-'+i);
  k.addEventListener('pointerdown',e=>{
    if(e.button!==0)return;e.preventDefault();finish();k.focus({preventScroll:true});k.setPointerCapture(e.pointerId);
    pointer={index:i,id:e.pointerId,startY:e.clientY,previousY:e.clientY,position:position(i),gesture:null};
  });
  k.addEventListener('pointermove',e=>{
    const p=pointer;if(!p||p.index!==i||p.id!==e.pointerId)return;
    if(!p.gesture){if(Math.abs(e.clientY-p.startY)<2)return;p.gesture=begin(i,'pointer');}
    p.position=limit(p.position+(p.previousY-e.clientY)/(e.shiftKey?2400:240),0,1);p.previousY=e.clientY;
    move(p.gesture,fromPosition(i,p.position));
  });
  const release=e=>{if(pointer?.index===i&&pointer.id===e.pointerId){const p=pointer;pointer=null;if(p.gesture)finish(p.gesture);}};
  k.addEventListener('pointerup',release);k.addEventListener('pointercancel',release);k.addEventListener('lostpointercapture',release);
  k.addEventListener('dblclick',e=>{e.preventDefault();discrete(i,spec[i].def);});
  k.addEventListener('wheel',e=>{
    e.preventDefault();if(!e.deltaY)return;
    const g=gesture?.kind==='wheel'&&gesture.index===i&&!gesture.closed?gesture:begin(i,'wheel');
    const step=e.shiftKey?spec[i].step/(spec[i].max-spec[i].min):.01;
    move(g,fromPosition(i,limit(position(i)-Math.sign(e.deltaY)*step,0,1)));
    clearTimeout(wheelTimer);wheelTimer=setTimeout(()=>finish(g),180);
  },{passive:false});
  k.addEventListener('keydown',e=>{
    if(!['ArrowUp','ArrowDown','ArrowLeft','ArrowRight','PageUp','PageDown','Home','End','Escape'].includes(e.key))return;
    e.preventDefault();if(e.key==='Escape'){finish();return;}
    const g=gesture?.kind==='key'&&gesture.index===i&&!gesture.closed?gesture:begin(i,'key');
    const d=e.shiftKey?spec[i].step/(spec[i].max-spec[i].min):e.key.startsWith('Page')?.1:.01;
    const p=e.key==='Home'?0:e.key==='End'?1:position(i)+(['ArrowUp','ArrowRight','PageUp'].includes(e.key)?d:-d);
    move(g,fromPosition(i,limit(p,0,1)));
  });
  k.addEventListener('keyup',()=>{if(gesture?.kind==='key'&&gesture.index===i)finish();});
  k.addEventListener('blur',()=>{if(gesture?.index===i)finish();});
  const input=$('value-'+i);
  input.addEventListener('change',()=>{
    if(input.value.trim()===''||!Number.isFinite(input.valueAsNumber)){input.value=fmt(i);return;}
    const v=real(i,norm(i,input.valueAsNumber));input.value=String(v);discrete(i,v);
  });
  input.addEventListener('keydown',e=>{if(e.key==='Enter')input.blur();if(e.key==='Escape'){input.value=fmt(i);input.blur();}});
}
function setMeter(mode){
  meterMode=mode;document.body.dataset.meter=mode;remember('meter',mode);
  document.querySelectorAll('[data-meter]').forEach(b=>{if(b.classList.contains('hardware-button'))b.setAttribute('aria-pressed',String(b.dataset.meter===mode));});
}
function acceptPacket(packet){
  if(!active||disposed)return;
  if(packet.data?.length!==3){report(Error('Reload this FX to update the meter data format'));return;}
  if(!meterSignal.accept(packet,meterSampleRate))return;
  outPower=meterSignal.power;grDb=meterSignal.grDb;lastPacket=performance.now();
  if(meterSignal.gap)meterGapUntil=lastPacket+500;
}
async function openMeter(){
  if(disposed||opening||!jsfx||!active||stream&&!stream.closed)return;
  opening=true;
  const epoch=meterEpoch;
  try{
    await meterClosing;
    if(!active||disposed||epoch!==meterEpoch)return;
    const caps=await jsfx.getCapabilities();if(caps.status!=='ready')return;
    const s=await jsfx.streams.open('meter',{updateRate:30});
    if(!active||disposed||epoch!==meterEpoch){await s.close();return;}
    meterSampleRate=Number(s.info?.sampleRate);
    if(!Number.isFinite(meterSampleRate)||meterSampleRate<8000){await s.close();throw Error('Meter sample rate is unavailable');}
    if(s.info?.source!=='gainReduction/postDSP/energy-v2'){await s.close();throw Error('Reload this FX to update the meter data format');}
    meterSignal.reset();lastPacket=0;outPower=0;grDb=0;
    stream=s;s.on('data',p=>{
      if(stream!==s||epoch!==meterEpoch)return;
      // The data callback and queue may expose the same packet. Sequence IDs
      // prevent double counting. Process (do not discard) any queued samples.
      if(s.info?.kind==='audio')for(let n=0;n<Math.min(s.info.capacity||1,256);n++){
        const queued=s.read();if(!queued)break;acceptPacket(queued);
      }
      acceptPacket(p);
    });
    s.on('close',()=>{if(stream===s)stream=null;});
    s.on('error',e=>{if(stream===s){stream=null;s.close().catch(()=>{});if(active)report(e);}});
  }catch(e){if(active&&epoch===meterEpoch)report(e);}finally{opening=false;}
}
function animate(now){
  if(!active||disposed){frame=0;return;}
  const dt=lastFrame?Math.min(.1,(now-lastFrame)/1000):.016;lastFrame=now;
  const stale=now-lastPacket>500;
  if(stale){outPower*=Math.exp(-dt/.18);grDb*=Math.exp(-dt/.18);}
  const outDb=10*Math.log10(Math.max(1e-12,outPower));
  let target=meterAngle(-Infinity);
  if(meterMode==='gr')target=meterAngle(Math.min(0,grDb));
  else if(meterMode!=='off')target=meterAngle(outDb+(meterMode==='4'?18:14));
  needle+=(target-needle)*(1-Math.exp(-dt/.085));
  $('meter-needle').setAttribute('transform',`rotate(${needle.toFixed(3)} 0 0)`);
  const readout=meterMode==='off'?'METER OFF':globalThis.reaper&&stale?'NO DATA':now<meterGapUntil?'METER SYNC':meterMode==='gr'?`GR <b>${Math.abs(grDb).toFixed(1)}</b> dB`:`OUT <b>${outDb<=-100?'−∞':outDb.toFixed(1)}</b> dBFS`;
  if($('meter-readout').innerHTML!==readout)$('meter-readout').innerHTML=readout;
  frame=requestAnimationFrame(animate);
}
function visibility(){
  // A visible meter must continue even when the editor does not own keyboard focus.
  const visible=hostVisible&&!document.hidden&&!disposed;
  if(active===visible)return;
  active=visible;meterEpoch++;
  if(!visible){
    zoomRequest++;$('ui-zoom').dataset.resizing='false';
    pointer=null;finish();clearTimeout(wheelTimer);
    const previous=stream;stream=null;
    meterClosing=Promise.allSettled([meterClosing,previous?.close()]);
    cancelAnimationFrame(frame);frame=0;
  }else{lastFrame=0;lastPacket=0;if(!frame)frame=requestAnimationFrame(animate);openMeter();}
}

buildPanel();
document.addEventListener('selectstart',e=>{if(!(e.target instanceof HTMLInputElement))e.preventDefault();});
document.addEventListener('dragstart',e=>e.preventDefault());
$('power').onclick=togglePower;renderPower();
$('edit-jsfx').disabled=!globalThis.reaper;
$('edit-jsfx').onclick=async()=>{
  const button=$('edit-jsfx');if(button.disabled)return;
  button.disabled=true;finish();
  try{await queue;await openJSFXEditor(globalThis.reaper);}
  catch(e){report(e);}
  finally{button.disabled=false;}
};
document.addEventListener('keydown',transportSpace,true);
document.addEventListener('keyup',e=>{if(isTransportSpace(e)){e.preventDefault();e.stopImmediatePropagation();}},true);
paintZoom(recall('zoom','1'));$('ui-zoom').addEventListener('change',e=>setZoom(e.target.value));
const savedTheme=recall('theme','ae');paintTheme(['ae','silver','black'].includes(savedTheme)?savedTheme:'ae');
const savedMeter=recall('meter','gr');setMeter(['gr','8','4','off'].includes(savedMeter)?savedMeter:'gr');
for(const i of [0,2,3,4,5])bindKnob(i);
document.querySelectorAll('.styles button').forEach(b=>b.onclick=()=>{paintTheme(b.dataset.theme);remember('theme',b.dataset.theme);});
document.querySelectorAll('[data-ratio]').forEach(b=>b.onclick=()=>toggleRatio(Number(b.dataset.ratio)));
document.querySelectorAll('.hardware-button[data-meter]').forEach(b=>b.onclick=()=>setMeter(b.dataset.meter));
document.querySelectorAll('svg [role=button]').forEach(b=>b.addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();b.dispatchEvent(new MouseEvent('click'));}}));
$('all').onclick=toggleAll;$('legacy').onclick=toggleLegacy;$('cap-switch').onclick=toggleLegacy;
window.addEventListener('blur',()=>{pointer=null;finish();clearTimeout(wheelTimer);});
window.addEventListener('focus',()=>{visibility();openMeter();});
document.addEventListener('visibilitychange',visibility);
window.addEventListener('pagehide',()=>{disposed=true;finish();clearInterval(retryTimer);clearTimeout(wheelTimer);cancelAnimationFrame(frame);jsfx?.dispose().catch(()=>{});});
render();frame=requestAnimationFrame(animate);visibility();
const retryTimer=setInterval(openMeter,1200);
if(globalThis.reaper){
  try{
    jsfx=await connectJSFX(globalThis.reaper,report);hostState(jsfx.params.snapshot);
    if(!jsfx.editor.size)throw Error('Window scaling requires ReaWebAPI v0.3.8.31 or later.');
    nativeSizing=true;document.body.classList.add('native-window');
    if(jsfx.editor.size.customized)editorSize(jsfx.editor.size);
    else {
      const zoom=paintZoom($('ui-zoom').value);
      await jsfx.editor.setSize(Math.round(1380*zoom),Math.ceil((30+1380*258/1400+34)*zoom));
    }
    await jsfx.editor.onSizeChange(editorSize);
    await jsfx.params.onChange(hostState);await jsfx.onVisibilityChange(v=>{hostVisible=v;visibility();});await jsfx.onCapabilitiesChange(openMeter);
    $('connection').textContent='REAPER';$('connection').className='live';hostVisible=jsfx.active;visibility();openMeter();
  }catch(e){$('connection').textContent='Disconnected';report(e);}
}else{$('connection').textContent='Preview';$('connection').title='Preview only. Connect to REAPER to process audio.';}
