// Bounded stereo resampler shared by the AudioWorklet and regression tests.
export class PCMBuffer {
  constructor(rate, outputRate, capacity = Math.ceil(rate * .2)) {
    if (!(rate > 0 && outputRate > 0)) throw Error('Invalid sample rate');
    this.rate=rate; this.outputRate=outputRate; this.capacity=capacity;
    this.data=new Float32Array(capacity*2); this.read=0; this.write=0; this.phase=0;
    this.dropped=0; this.underrun=0; this.target=Math.ceil(rate*.04);
  }
  reset(){this.read=this.write;this.phase=0;}
  push(data,channels){
    if(!Number.isInteger(channels)||channels<1||channels>32||data.length%channels)throw Error('Invalid PCM layout');
    const frames=data.length/channels;
    if(frames>this.capacity){this.dropped+=frames;this.reset();return;}
    if(this.write-this.read+frames>this.capacity){this.dropped+=this.write-this.read;this.reset();}
    for(let i=0;i<frames;i++)for(let ch=0;ch<2;ch++){
      const value=data[i*channels+Math.min(ch,channels-1)];
      this.data[((this.write+i)%this.capacity)*2+ch]=Number.isFinite(value)?value:0;
    }
    this.write+=frames;
  }
  render(left,right){
    const queued=this.write-this.read;
    if(queued>this.target*3){const discard=queued-this.target;this.read+=discard;this.dropped+=discard;}
    const step=this.rate/this.outputRate*(1+Math.max(-.005,Math.min(.005,(queued-this.target)/(this.rate*10))));
    for(let i=0;i<left.length;i++){
      if(this.write-this.read<2){left[i]=right[i]=0;this.underrun++;continue;}
      for(let ch=0;ch<2;ch++){
        const a=this.data[(this.read%this.capacity)*2+ch],b=this.data[((this.read+1)%this.capacity)*2+ch];
        (ch?right:left)[i]=a+(b-a)*this.phase;
      }
      this.phase+=step;const advance=Math.floor(this.phase);this.phase-=advance;this.read+=advance;
    }
  }
}
