// SVG adapter for vu-meter-react 1.0.6 by Jun Murakami (MIT).
// Original: vendor/vu-meter-react/VUMeter.upstream.tsx. License shipped alongside it.
// Retain the supplied dial geometry and measured scale, without React/Web Audio:
// REAPER already supplies the post-DSP samples. One SVG coordinate space avoids
// the upstream CSS-needle / SVG-viewBox origin and aspect-ratio mismatch.
export const VU_MARKS=Object.freeze([
  [-25,-25],[-20,-23],[-10,-16],[-7,-12],[-5,-8],[-3,-3],
  [-2,0],[-1,3.5],[0,8],[1,13],[2,18],[3,25]
].map(Object.freeze));
export function meterAngle(db){
  if(!Number.isFinite(db))return db===Infinity?25:-25;
  if(db<=-25)return -25;
  if(db>=3)return 25;
  for(let i=1;i<VU_MARKS.length;i++){
    const [v,b]=VU_MARKS[i],[u,a]=VU_MARKS[i-1];
    if(db<=v)return a+(b-a)*(db-u)/(v-u);
  }
}
const polar=(r,a)=>{const t=a*Math.PI/180;return [100+Math.sin(t)*r,195-Math.cos(t)*r];};
const arc=(r,a,b,sweep=1)=>`M${polar(r,a)}A${r} ${r} 0 0 ${sweep} ${polar(r,b)}`;
export function meterDial(){
  const band=`${arc(132,8,25)}L${polar(124,25)}${arc(124,25,8,0).replace(/^M[^A]+/,'')}Z`;
  const ticks=VU_MARKS.map(([v,a])=>{
    const major=v===-25||v===0||v===3,p=polar(137,a),q=polar(137-(major?18:12),a);
    return `<line class="vu-tick" data-db="${v}" x1="${p[0]}" y1="${p[1]}" x2="${q[0]}" y2="${q[1]}" stroke="${v>0?'#b43e27':'#343025'}" stroke-width="${major?1.5:1}"/>`;
  }).join('');
  const labels=VU_MARKS.filter(([v])=>v!==-25).map(([v,a])=>{
    const p=polar(137,a);
    return `<text class="vu-label" data-db="${v}" x="${p[0]}" y="${p[1]-2}" fill="${v>0?'#b43e27':'#343025'}" font-size="${v===0?10:9}" text-anchor="middle">${Math.abs(v)}</text>`;
  }).join('');
  return `<svg id="meter-dial" data-source="vu-meter-react-1.0.6" x="15" y="15" width="198" height="104" viewBox="20 40 160 84" preserveAspectRatio="xMidYMid meet" overflow="hidden" aria-label="VU meter, minus 20 to plus 3">
    <g class="meter-print" font-family="Arial, sans-serif">
      <path d="${band}" fill="#bb442b" opacity=".8"/>
      <path class="vu-baseline" d="${arc(124,-25,25)}" fill="none" stroke="#343025" stroke-width="1.5"/>
      ${ticks}${labels}
      <text x="${polar(145,-28)[0]}" y="${polar(145,-28)[1]+10}" font-size="12" text-anchor="middle" fill="#343025">−</text>
      <text x="${polar(145,28)[0]}" y="${polar(145,28)[1]+10}" font-size="12" text-anchor="middle" fill="#b43e27">+</text>
      <text x="100" y="105" fill="#53452e" font-size="12" text-anchor="middle" letter-spacing="2">VU</text>
    </g>
    <g id="meter-pivot" transform="translate(100 195)" data-pivot-x="100" data-pivot-y="195">
      <g id="meter-needle" transform="rotate(8 0 0)"><path d="M-.6 0H.6L.4-137H-.4Z" fill="#292820"/></g>
      <circle class="needle-hub" r="3" fill="#292820"/>
    </g>
  </svg>`;
}

// Each native packet is an independently valid reading, calculated from every
// audio sample in JSFX. Dropped UI updates cannot erase RMS integration history.
export class MeterSignal {
  constructor(){this.reset();}
  reset(){this.power=0;this.grDb=0;this.sequence=null;this.valid=false;this.gap=false;this.frames=0;}
  accept(packet,sampleRate){
    const d=packet?.data;
    if(!(d instanceof Float32Array)||d.length!==3||!Number.isFinite(sampleRate)||sampleRate<8000||sampleRate>768000)return false;
    if(packet.sequence!=null&&this.sequence!=null&&packet.sequence<=this.sequence)return false;
    if(!Number.isFinite(d[0])||d[0]<0||d[0]>1.00001||!Number.isFinite(d[1])||!Number.isFinite(d[2])||d[1]<0||d[2]<0)return false;
    this.sequence=packet.sequence??this.sequence;
    this.power=(d[1]+d[2])*.5;
    this.grDb=20*Math.log10(Math.max(1e-12,d[0]));
    this.frames++;this.valid=true;return true;
  }
  get dbFS(){return this.power>0?10*Math.log10(this.power):-Infinity;}
}
