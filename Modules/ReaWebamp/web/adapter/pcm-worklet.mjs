import {PCMBuffer} from './pcm-buffer.mjs';
class ReaWebampPCM extends AudioWorkletProcessor {
 constructor(options){
  super();this.buffer=new PCMBuffer(options.processorOptions.sampleRate,sampleRate);this.ticks=0;
  this.port.onmessage=({data})=>{
   if(data.reset)this.buffer.reset();
   if(data.pcm){this.buffer.push(data.pcm,data.channels);this.port.postMessage({ack:true});}
  };
 }
 process(_,outputs){
  this.buffer.render(outputs[0][0],outputs[0][1]);
  if(++this.ticks%375===0)this.port.postMessage({queued:this.buffer.write-this.buffer.read,dropped:this.buffer.dropped,underrun:this.buffer.underrun});
  return true;
 }
}
registerProcessor('reawebamp-pcm',ReaWebampPCM);
