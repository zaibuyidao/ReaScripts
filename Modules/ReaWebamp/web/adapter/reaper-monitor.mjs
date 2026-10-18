import {t} from './i18n.mjs';
export async function openMonitor(context,analyser,onError,host=globalThis.reaper){
 if(!context.audioWorklet || typeof AudioWorkletNode!=='function')throw Error(t('workletUnsupported'));
 const stream=await host.audio.openStream('audio',{source:'master'});
 let node,silent,disposed=false,inflight=0,sequence=null,lastArrival=0;
 const diagnostics={source:'REAPER hardware output (post-processing)',sampleRate:stream.info.sampleRate,channels:stream.info.channels,dropped:0,underrun:0,queued:0,packetGaps:0,portDropped:0,packets:0,peak:0};
 const disposers=[];
 async function close(){
  if(disposed)return;disposed=true;
  for(const off of disposers)off();
  node?.port.close();node?.disconnect();silent?.disconnect();await stream.close();
 }
 try{
  if(!(stream.info.sampleRate>0) || !(stream.info.channels>0))throw Error('Native Stream descriptor has no audio format');
  await context.audioWorklet.addModule(new URL('./pcm-worklet.mjs',import.meta.url));
  node=new AudioWorkletNode(context,'reawebamp-pcm',{numberOfInputs:0,numberOfOutputs:1,outputChannelCount:[2],processorOptions:{sampleRate:stream.info.sampleRate}});
  silent=context.createGain();silent.gain.value=0;
  node.connect(analyser);node.connect(silent);silent.connect(context.destination);
  node.port.onmessage=({data})=>{if(data.ack)inflight=Math.max(0,inflight-1);else Object.assign(diagnostics,data)};
  const consume=()=>{
   let packet;
   while((packet=stream.read())){
    const now=performance.now();
    if(sequence!==null && (packet.sequence!==sequence+1n || now-lastArrival>250)){diagnostics.packetGaps++;node.port.postMessage({reset:true});}
    sequence=packet.sequence;lastArrival=now;
    if(inflight>=2){diagnostics.portDropped++;continue;}
    const pcm=new Float32Array(packet.data);let peak=0;for(const n of pcm)peak=Math.max(peak,Math.abs(n));
    diagnostics.peak=peak;diagnostics.packets++;inflight++;
    node.port.postMessage({pcm,channels:stream.info.channels},[pcm.buffer]);
   }
  };
  disposers.push(stream.on('data',consume),stream.on('close',error=>{if(!disposed){void close();onError(error)}}));
  const state=()=>{node.port.postMessage({reset:true});};context.addEventListener('statechange',state);
  disposers.push(()=>context.removeEventListener('statechange',state));
  await context.resume();consume();
  return {diagnostics,stream,node,silent,reset:()=>node.port.postMessage({reset:true}),close};
 }catch(error){await close();throw error}
}
