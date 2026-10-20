import {meterDial} from './vu-meter.js';
const text=(x,y,s,cls='face-ink',size=12)=>`<text x="${x}" y="${y}" class="ink ${cls}" font-size="${size}" text-anchor="middle">${s}</text>`;
const pt=(r,a)=>[Math.sin(a*Math.PI/180)*r,-Math.cos(a*Math.PI/180)*r];
const arc=(cx,cy,r,a,b)=>{const p=pt(r,a),q=pt(r,b);return `M${cx+p[0]} ${cy+p[1]} A${r} ${r} 0 0 1 ${cx+q[0]} ${cy+q[1]}`;};
function screw(x,y,a=0){return `<g class="rack-fastener" transform="translate(${x} ${y})">
  <circle r="11" fill="#090c0a" stroke="#282d27" stroke-width=".65"/>
  <circle r="9.8" fill="url(#rack-screw-edge)"/>
  <circle r="8.5" fill="url(#rack-screw-dome)"/>
  <path d="M-8.1 1.4A8.3 8.3 0 0 1 3.5-7.5" fill="none" stroke="#93988b" stroke-opacity=".38" stroke-width=".65"/>
  <path d="M8.1-1.4A8.3 8.3 0 0 1-3.5 7.5" fill="none" stroke="#070b07" stroke-opacity=".8" stroke-width=".85"/>
  <circle r="8.2" fill="#fff" filter="url(#material-grain)" opacity=".025"/>
  <g transform="rotate(${a})"><path d="M-5.2-1.5H-1.5V-5.2H1.5V-1.5H5.2V1.5H1.5V5.2H-1.5V1.5H-5.2Z" fill="#060906" stroke="#5c6455" stroke-opacity=".65" stroke-width=".5"/><path d="M-4.8-1H-1V-4.8M1.9-1H4.8M-1 1.9V4.8" fill="none" stroke="#020502" stroke-width=".65"/></g>
 </g>`;}

function scale(x,y,r,labels,labelRadius=r+12){
  let s=`<g class="scale" transform="translate(${x} ${y})">`;
  const count=r<50?12:32;
  for(let i=0;i<=count;i++){const a=-135+i*270/count,p=pt(r,a);s+=`<circle cx="${p[0]}" cy="${p[1]}" r="${r<50?(i%2?.75:1.1):(i%4===0?1.65:1.05)}" stroke-width="0"/>`;}
  labels.forEach((l,i)=>{const p=pt(labelRadius,-135+270*i/(labels.length-1));s+=`<text x="${p[0]}" y="${p[1]+4}" text-anchor="middle">${l}</text>`;});return s+'</g>';
}
function knob(id,x,y,r,label,compact=false){
  // Machined circular surfaces are rotationally symmetric. Keep their geometry
  // and illumination stationary; rotate the indicator and fluted collar.
  // Short contact shadows stay beneath the circular seat. No displaced solid
  // sidewall discs: those produced a second silhouette and looked off-center.
  const cap=r*(compact?.8:r<30?.65:.53);
  const grip=compact?r:cap+r*.14,teethCount=r>=40?32:r>=20?18:10;
  const markerInner=compact?cap+r*.02:grip;
  const flutes=Array.from({length:teethCount},(_,i)=>{
    // Broad, rounded axial grip ribs on the cap sidewall. The continuous seat
    // remains under them; there are no flat gear teeth or cut-out notches.
    const a=i*360/teethCount,w=360/teethCount*.43,inner=cap+r*.018,outer=grip-r*.006;
    const p=pt(inner,a-w*.72),q=pt(outer-r*.025,a-w),s=pt(outer-r*.025,a+w),t=pt(inner,a+w*.72);
    const left=pt(outer,a-w*.65),crest=pt(outer,a),right=pt(outer,a+w*.65);
    const body=`M${p}Q${q} ${left}Q${crest} ${right}Q${s} ${t}Z`;
    const ridgeStart=pt(inner+r*.025,a-w*.28),ridgeEnd=pt(outer-r*.035,a-w*.28);
    const gl=pt((inner+outer)/2,a-w),gr=pt((inner+outer)/2,a+w),gradient=`grip-rib-${id}-${i}`;
    const light=Math.max(0,Math.cos((a+30)*Math.PI/180)),tone=Math.round(20+light*48),edge=Math.round(28+light*63);
    return `<g class="collar-rib" data-angle="${a}"><linearGradient id="${gradient}" gradientUnits="userSpaceOnUse" x1="${gl[0]}" y1="${gl[1]}" x2="${gr[0]}" y2="${gr[1]}"><stop stop-color="#13190f"/><stop class="rib-tone" offset=".24" stop-color="rgb(${tone},${tone+2},${tone-1})"/><stop class="rib-ridge" offset=".44" stop-color="rgb(${edge},${edge+2},${edge-1})"/><stop class="rib-tone" offset=".72" stop-color="rgb(${tone},${tone+2},${tone-1})"/><stop offset="1" stop-color="#11170f"/></linearGradient><path class="collar-flute" d="${body}" fill="url(#${gradient})"/><path class="flute-highlight" d="M${ridgeStart}Q${pt((inner+outer)/2,a-w*.32)} ${ridgeEnd}" fill="none" stroke="rgb(${edge},${edge+2},${edge-1})" stroke-opacity=".2" stroke-linecap="round" stroke-width="${r<30?.3:.45}"/></g>`;
  }).join('');
  const machining=Array.from({length:28},(_,i)=>`<circle r="${cap*(.12+i*.031)}" fill="none" stroke="${i%3?'#ffffff':'#252a29'}" stroke-opacity="${i%3?.115:.08}" stroke-width="${i%3?.12:.095}"/>`).join('');
  return `<g id="knob-${id}" class="knob${compact?' knob-compact':''}" role="slider" tabindex="0" aria-label="${label}" transform="translate(${x} ${y})">
    <g class="knob-fixed" data-center="0 0">
      ${compact?`<circle class="knob-cast-shadow" cx=".45" cy=".8" r="${r-.3}" fill="#000" opacity=".24" filter="url(#knob-shadow-soft)"/>`:''}
      <circle cx="0" cy="0" r="${r+(compact?.65:1)}" fill="#101612"/>
      ${compact?`<circle class="knob-outer knob-grip" cx="0" cy="0" r="${r}" fill="url(#cap-seat)"/>`:`
      <circle class="knob-outer" cx="0" cy="0" r="${r}" fill="url(#knob-edge)"/>
      <circle cx="0" cy="0" r="${r*.97}" fill="url(#knob-body)"/>
      <circle cx="0" cy="0" r="${r*.96}" fill="#fff" filter="url(#material-grain)" opacity=".045"/>
      <circle class="knob-cast-shadow" cx=".6" cy="1" r="${grip-.4}" fill="#000" opacity=".26" filter="url(#knob-shadow-soft)"/>
      <circle class="knob-grip" cx="0" cy="0" r="${grip}" fill="url(#cap-seat)"/>`}
      <g class="collar-flutes" data-teeth="${teethCount}">${flutes}</g>
      <circle class="cap-rim" cx="0" cy="0" r="${cap+r*.02}" fill="url(#cap-bevel)"/>
      <circle class="knob-inner" cx="0" cy="0" r="${cap}" fill="url(#aluminum)"/>
      <foreignObject class="cap-reflection" x="${-cap+.3}" y="${-cap+.3}" width="${cap*2-.6}" height="${cap*2-.6}" pointer-events="none"><div xmlns="http://www.w3.org/1999/xhtml" style="width:100%;height:100%;border-radius:50%;background:linear-gradient(150deg,#ffffff30,#00000003),conic-gradient(from -30deg,#ffffff 0deg,#f4f5f4 38deg,#b5bab8 82deg,#d6dad8 118deg,#ffffff 160deg,#f2f4f2 207deg,#a6adaa 264deg,#e6e9e7 308deg,#ffffff 332deg,#ffffff 360deg)"></div></foreignObject>
      <g class="cap-machining" pointer-events="none">${machining}</g>
      <circle cx="0" cy="0" r="${cap*.98}" fill="none" stroke="#e6e8db" stroke-opacity=".23" stroke-width=".35"/>
    </g>
    <g class="rotor" id="rotor-${id}">
      ${compact?`<circle class="position-dot" cx="0" cy="${-(cap-r*.112)}" r="${r*.076}" fill="#bcc1b4" stroke="#111610" stroke-width="${r*.035}"/>`:`<path class="position-mark" d="M0 ${-r}V${-markerInner}" stroke="#e3e3d4" stroke-width="2.05"/>`}
    </g>
    <circle r="${r+9}" fill="transparent"/>
  </g>`;
}
function brushedMetal(){
  // Non-repeating horizontal hairlines across the whole faceplate, rather than
  // a small visibly tiled stripe. Seeded so all three finishes share one tooling.
  let seed=1175;
  const rand=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  return Array.from({length:960},(_,i)=>{
    const x=rand()*1400,y=rand()*258,len=12+rand()*420;
    return `<path d="M${x.toFixed(2)} ${y.toFixed(2)}h${Math.min(len,1400-x).toFixed(2)}" stroke="${i%3?'#f4f3e7':'#090c0d'}" stroke-opacity="${(.025+rand()*.13).toFixed(3)}" stroke-width="${(.15+rand()*.35).toFixed(2)}"/>`;
  }).join('');
}
function patina(){
  let seed=19276;
  const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  let result='';
  // Sparse finish wear, concentrated at the mounting edges, not a grunge overlay.
  for(let i=0;i<130;i++){
    const x=random()*1392+4,y=i<75?(i%2?251-random()*7:4+random()*7):random()*250+4;
    const length=.5+random()*(i<75?9:2.5);
    result+=`<path d="M${x.toFixed(2)} ${y.toFixed(2)}l${length.toFixed(2)} ${((random()-.5)*1.1).toFixed(2)}" stroke="${i%3?'#d2d1bc':'#141812'}" stroke-width="${(.2+random()*.45).toFixed(2)}" stroke-opacity="${(.06+random()*.16).toFixed(2)}"/>`;
  }
  return result;
}
function brand(){
  // Extended geometric lettering, drawn as a worn screen-printed hardware mark.
  const letters={
    R:['M0 20V0H11Q19 0 19 6Q19 11 13 12L20 20H14L8 12H4V20ZM4 4V8H10Q14 8 14 6Q14 4 10 4Z',20],
    E:['M0 0H17V4H4V8H15V12H4V16H17V20H0Z',17],
    A:['M0 20 8 0H14L22 20H17L15.5 16H6.5L5 20ZM8 12H14L11 4Z',22],
    W:['M0 0H5L9 14 13 0H18L22 14 26 0H31L25 20H20L15.5 6 11 20H6Z',31],
    B:['M0 20V0H11Q19 0 19 5Q19 8 16 10Q20 11 20 15Q20 20 12 20ZM4 4V8H10Q14 8 14 6Q14 4 10 4ZM4 12V16H11Q15 16 15 14Q15 12 11 12Z',20],
    U:['M0 0H4V13Q4 16 10 16Q16 16 16 13V0H20V13Q20 20 10 20Q0 20 0 13Z',20],
    I:['M0 0H4V20H0Z',4]
  };
  let x=0;const glyphs=[...'REAWEB UI'].map(letter=>{if(letter===' '){x+=10;return '';}const [d,w]=letters[letter],s=`<path transform="translate(${x} 0)" d="${d}"/>`;x+=w+3.3;return s;}).join('');
  return `<g class="brand-print blue-ink" role="img" aria-label="REAWEB UI" transform="translate(${1058-(x-3.3)*1.12/2} 222) scale(1.12 .85)" fill-rule="evenodd">${glyphs}</g>`;
}
function mountingSlot(x,y,index){
  let seed=1175+index*9283;
  const rand=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  const point=(a,r)=>[Math.sign(Math.cos(a))*5.5+Math.cos(a)*r,Math.sin(a)*r];
  const edge=Array.from({length:64},(_,i)=>{
    const a=i*Math.PI/32,r=8.35+rand()*.42+(i%17===index?rand()*.85:0);return point(a,r);
  });
  let wear='';
  for(let i=0;i<7;i++){
    const a=rand()*Math.PI*2,l=.09+rand()*.23,p=point(a,9.2),q=point(a+l,9.1+rand()*.65),m=point(a+l*.55,8.5);
    wear+=`<path d="M${p}L${q}L${m}Z" fill="${i%3?'#8b8e85':'#c4c4b4'}" opacity="${.2+rand()*.35}"/>`;
  }
  return `<g class="mount-hole" data-corner="${index}" transform="translate(${x} ${y}) scale(1.2)"><rect x="-15.2" y="-9.6" width="30.4" height="19.2" rx="9.4" fill="#343a36"/><path class="hole-aperture" d="M${edge.join('L')}Z" fill="#020404" stroke="#5f655d" stroke-opacity=".48" stroke-width=".7"/>${wear}</g>`;
}
function key(id,x,y,label,kind){return `<g id="${kind}-${id}" class="hardware-button" data-${kind}="${id}" role="button" tabindex="0" aria-label="${kind==='ratio'?'Ratio '+id+':1':'Meter '+label}" aria-pressed="false" transform="translate(${x} ${y})">
  <rect x="1" y="-2" width="23" height="42" fill="#090d0a" stroke="#565c51" stroke-opacity=".3" stroke-width=".6"/>
  <rect class="key-shadow" x="7" y="6" width="20" height="38" rx=".5" fill="#020402" filter="url(#key-shadow-soft)"/>
  <path class="key-side" d="M22 0L25.5 6V44H6.5L3 38H22Z" fill="url(#key-sidewall)"/>
  <g class="key-cap" data-axis="perpendicular-to-panel">
    <rect class="key-bevel" x="3" width="19" height="38" rx=".6" fill="url(#key-bevel)"/>
    <rect class="key-face" x="4.35" y="1.5" width="16.3" height="35" rx=".3" fill="url(#key)"/>
    <rect x="4.35" y="1.5" width="16.3" height="35" fill="#fff" filter="url(#material-grain)" opacity=".035"/>
    <path class="key-toplight" d="M3.6 37.2V.6H21.4" fill="none" stroke="#899080" stroke-width=".7"/>
    <rect class="key-rim" x="3.3" y=".3" width="18.4" height="37.4" rx=".5" fill="none" stroke="#a9afa0" stroke-width=".4"/>
  </g>
  <rect class="key-outline" x="-3" y="-4" width="32" height="46" rx="2"/>
  ${text(kind==='ratio'?-19:48,24,label,'face-ink',12)}
  <rect x="-10" y="-2" width="50" height="42" fill="transparent"/>
  </g>`;}

function meterWear(){
  let seed=8275;
  const rand=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  return Array.from({length:42},(_,i)=>{
    const horizontal=i<28,x=horizontal?4+rand()*219:(i%2?225:2.6),y=horizontal?(i%3?2.8:131.2):5+rand()*122;
    const length=.35+rand()*3.3;
    return `<path d="M${x} ${y}l${horizontal?length:(rand()-.5)*.45} ${horizontal?(rand()-.5)*.45:length}" stroke="${i%4?'#92948b':'#d0d0c2'}" stroke-opacity="${.12+rand()*.22}" stroke-width="${.22+rand()*.36}"/>`;
  }).join('');
}
function meter(){
  return `<svg id="vu-meter" x="944" y="49" width="228" height="134" viewBox="0 0 228 134" overflow="visible">
    <rect id="meter-cast-shadow" x="1" y="1.8" width="228" height="134" fill="#000" opacity=".24" filter="url(#meter-shadow-soft)"/>
    <rect id="meter-frame" width="228" height="134" rx="1.7" fill="url(#meter-shoulder)"/>
    <rect class="meter-casing-face" x="3.2" y="3.2" width="221.6" height="127.6" rx=".8" fill="url(#meter-bezel)"/>
    <g id="meter-frame-finish">
      <rect x="0" y="0" width="228" height="134" fill="#fff" filter="url(#material-grain)" opacity=".018"/>
    </g>
    <g id="meter-edge-wear" pointer-events="none">${meterWear()}</g>
    <rect id="meter-inner-frame" x="10" y="10" width="208" height="114" fill="url(#meter-recess)"/>
    <g clip-path="url(#meter-clip)" id="meter-face">
      <rect x="15" y="15" width="198" height="104" fill="url(#paper)"/>
      <rect id="meter-light" x="15" y="15" width="198" height="104" fill="url(#meter-glow)"/>
      ${meterDial()}
    </g>
    <!-- The library uses an off-face pivot, clipped behind the lower housing. -->
    <g id="meter-baffle" clip-path="url(#meter-clip)">
      <rect id="meter-movement-cover" x="15" y="101" width="198" height="33" fill="url(#meter-lip)"/>
      <rect x="15" y="101" width="198" height="18" fill="#fff" filter="url(#material-grain)" opacity=".025"/>
      <path d="M15 101.35H213" stroke="#727060" stroke-opacity=".3" stroke-width=".6"/>
      <g id="meter-cover-screw" transform="translate(114 110)">
        <circle r="6.4" fill="#10140f"/>
        <circle r="5.65" fill="url(#meter-screw)" stroke="#666858" stroke-width=".45"/>
        <circle r="4.7" fill="none" stroke="#1b2118" stroke-width=".45"/>
        <path class="screw-cross" transform="rotate(12)" d="M-3.7 -.85H-.85V-3.7H.85V-.85H3.7V.85H.85V3.7H-.85V.85H-3.7Z" fill="#0d130d" stroke="#606352" stroke-width=".35"/>
      </g>
    </g>
    <path id="meter-glass" d="M15 15H213V54L15 35Z" fill="url(#glass)"/>
  </svg>`;
}
export function buildPanel(){
document.getElementById('faceplate').innerHTML=`
  <defs>
    <linearGradient id="panel-fill" gradientUnits="userSpaceOnUse" x1="520" y1="-190" x2="880" y2="450"><stop stop-color="#33373b"/><stop offset=".4" stop-color="#292c2f"/><stop offset="1" stop-color="#202326"/></linearGradient>
    <linearGradient id="blue-fill" x1=".25" y1=".067" x2=".75" y2=".933"><stop stop-color="#186681"/><stop offset=".5" stop-color="#11617c"/><stop offset="1" stop-color="#104e64"/></linearGradient>
    <filter id="grain" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency=".8 .85" numOctaves="3" seed="1175"/><feColorMatrix type="saturate" values="0"/></filter>
    <filter id="brushed-grain" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency=".009 .72" numOctaves="2" seed="23"/><feColorMatrix type="saturate" values="0"/><feComponentTransfer><feFuncR type="linear" slope="1.5" intercept="-.25"/><feFuncG type="linear" slope="1.5" intercept="-.25"/><feFuncB type="linear" slope="1.5" intercept="-.25"/></feComponentTransfer></filter>
    <filter id="material-grain" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency=".85" numOctaves="2" seed="8"/><feColorMatrix type="saturate" values="0"/><feComposite in2="SourceGraphic" operator="in"/></filter>
    <filter id="printed-ink" x="-3%" y="-6%" width="106%" height="112%"><feTurbulence type="fractalNoise" baseFrequency="1.3 .9" numOctaves="2" seed="51"/><feColorMatrix type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  .65 0 0 0 .52"/><feComposite in="SourceGraphic" operator="in"/><feGaussianBlur stdDeviation=".09"/></filter>
    <linearGradient id="surface-light" gradientUnits="userSpaceOnUse" x1="520" y1="-190" x2="880" y2="450"><stop stop-color="#f6f4df" stop-opacity=".1"/><stop offset=".45" stop-color="#e0e7cf" stop-opacity=".015"/><stop offset="1" stop-color="#0a100c" stop-opacity=".14"/></linearGradient>
    <linearGradient id="edge-light" x2="0" y2="1"><stop stop-color="#e6e7db" stop-opacity=".21"/><stop offset=".018" stop-color="#e6e7db" stop-opacity="0"/><stop offset=".975" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".5"/></linearGradient>
    <linearGradient id="rack-screw-edge" x1=".25" y1=".067" x2=".75" y2=".933"><stop stop-color="#777e70"/><stop offset=".2" stop-color="#4d5547"/><stop offset=".55" stop-color="#22291e"/><stop offset="1" stop-color="#090e08"/></linearGradient>
    <radialGradient id="rack-screw-dome" cx=".28" cy=".18" r=".88"><stop stop-color="#4c5444"/><stop offset=".35" stop-color="#343c2e"/><stop offset=".72" stop-color="#1b2317"/><stop offset="1" stop-color="#0b1109"/></radialGradient>
    <linearGradient id="screw" x1=".25" y1=".067" x2=".75" y2=".933"><stop stop-color="#9ca296"/><stop offset=".35" stop-color="#52594e"/><stop offset="1" stop-color="#1d251c"/></linearGradient>
    <linearGradient id="knob-edge" x1=".25" y1=".067" x2=".75" y2=".933"><stop stop-color="#50534f"/><stop offset=".28" stop-color="#303330"/><stop offset=".7" stop-color="#252825"/><stop offset="1" stop-color="#111412"/></linearGradient>
    <linearGradient id="knob-body" x1=".25" y1=".067" x2=".75" y2=".933"><stop stop-color="#3c3f3b"/><stop offset=".26" stop-color="#282b28"/><stop offset=".65" stop-color="#1a1d1b"/><stop offset="1" stop-color="#141715"/></linearGradient>
    <linearGradient id="cap-seat" x1=".25" y1=".067" x2=".75" y2=".933"><stop stop-color="#454941"/><stop offset=".25" stop-color="#20251d"/><stop offset="1" stop-color="#11160e"/></linearGradient>
    <linearGradient id="cap-bevel" x1=".25" y1=".067" x2=".75" y2=".933"><stop stop-color="#fafcf8"/><stop offset=".4" stop-color="#d3d7d2"/><stop offset="1" stop-color="#858d83"/></linearGradient>
    <linearGradient id="aluminum" x1=".25" y1=".067" x2=".75" y2=".933"><stop stop-color="#f8faf7"/><stop offset="1" stop-color="#bfc6bf"/></linearGradient>
    <linearGradient id="pivot-metal" x1=".25" y1=".067" x2=".75" y2=".933"><stop stop-color="#aaa78b"/><stop offset="1" stop-color="#424a34"/></linearGradient>
    <path id="badge-upper" d="M-33.6 0 A33.6 33.6 0 0 1 33.6 0"/>
    <path id="badge-lower" d="M-38.2 0 A38.2 38.2 0 0 0 38.2 0"/>
    <filter id="knob-shadow-soft" x="-30%" y="-30%" width="160%" height="170%"><feGaussianBlur stdDeviation="1.25"/></filter>
    <filter id="meter-shadow-soft" x="-15%" y="-20%" width="135%" height="150%"><feGaussianBlur stdDeviation="1.4"/></filter>
    <linearGradient id="key-sidewall" x1="0" y1="0" x2="1" y2=".3"><stop stop-color="#1b221b"/><stop offset=".7" stop-color="#343c30"/><stop offset="1" stop-color="#171e16"/></linearGradient>
    <g id="rw-emblem" fill="none" stroke="currentColor" stroke-linejoin="round" stroke-linecap="round">
      <path d="M-31 0 0-19 31 0 0 19Z" stroke-width="1.4"/>
      <path d="M-14 7V-7H-8Q-3-7-3-3Q-3 1-8 1H-14M-9 1-3 7M-1.5-7 2 7 7-3 12 7 15.5-7" stroke-width="1.8"/>
    </g>
    <filter id="key-shadow-soft" x="-20%" y="-15%" width="145%" height="140%"><feGaussianBlur stdDeviation=".65"/></filter>
    <linearGradient id="key" x1=".25" y1=".067" x2=".75" y2=".933"><stop stop-color="#292c29"/><stop offset=".55" stop-color="#202320"/><stop offset="1" stop-color="#181b18"/></linearGradient>
    <linearGradient id="key-bevel" x1=".25" y1=".067" x2=".75" y2=".933"><stop stop-color="#484e44"/><stop offset=".48" stop-color="#2a3026"/><stop offset="1" stop-color="#10160e"/></linearGradient>
    <linearGradient id="key-pressed" x1=".25" y1=".067" x2=".75" y2=".933"><stop stop-color="#1f231d"/><stop offset="1" stop-color="#141912"/></linearGradient>
    <linearGradient id="key-inset" x1=".25" y1=".067" x2=".75" y2=".933"><stop stop-color="#0f140d"/><stop offset="1" stop-color="#2b3325"/></linearGradient>
    <linearGradient id="meter-shoulder" x1=".15" y1="0" x2=".85" y2="1"><stop stop-color="#4b4f48"/><stop offset=".09" stop-color="#343831"/><stop offset=".52" stop-color="#1b201b"/><stop offset="1" stop-color="#080c09"/></linearGradient>
    <linearGradient id="meter-recess" x1=".15" y1="0" x2=".85" y2="1"><stop stop-color="#070a08"/><stop offset=".55" stop-color="#10150f"/><stop offset="1" stop-color="#292f25"/></linearGradient>
    <linearGradient id="meter-bezel" x1=".25" y1=".067" x2=".75" y2=".933"><stop stop-color="#323532"/><stop offset=".4" stop-color="#222522"/><stop offset="1" stop-color="#151815"/></linearGradient>
    <radialGradient id="paper" cx=".48" cy=".35" r=".75"><stop stop-color="#fff1ab"/><stop offset=".55" stop-color="#ebc779"/><stop offset="1" stop-color="#a67d3e"/></radialGradient>
    <radialGradient id="meter-glow" cx=".5" cy=".5" r=".65"><stop stop-color="#ffde6c" stop-opacity=".4"/><stop offset=".75" stop-color="#ffb52f" stop-opacity=".1"/><stop offset="1" stop-color="#a04900" stop-opacity=".3"/></radialGradient>
    <linearGradient id="glass" x2=".1" y2="1"><stop stop-color="#fff" stop-opacity=".23"/><stop offset="1" stop-color="#fff" stop-opacity=".01"/></linearGradient>
    <linearGradient id="meter-lip" x1=".25" y1=".067" x2=".75" y2=".933"><stop stop-color="#35362e"/><stop offset=".5" stop-color="#282c24"/><stop offset="1" stop-color="#191e18"/></linearGradient>
    <linearGradient id="meter-screw" x1=".25" y1=".067" x2=".75" y2=".933"><stop stop-color="#66675a"/><stop offset=".4" stop-color="#3d4234"/><stop offset="1" stop-color="#20271b"/></linearGradient>
    <radialGradient id="lamp" cx=".35" cy=".28"><stop stop-color="#ffead6"/><stop offset=".25" stop-color="#ff5c3c"/><stop offset=".6" stop-color="#dc1e0d"/><stop offset="1" stop-color="#6c0c03"/></radialGradient>
    <clipPath id="meter-clip"><rect x="15" y="15" width="198" height="104"/></clipPath>
  </defs>
  <rect width="1400" height="258" fill="url(#panel-fill)"/>
  <rect id="blue-stripe" x="927" width="261" height="258" fill="url(#blue-fill)"/>
  <rect id="panel-directional" x="1" y="1" width="1398" height="256" filter="url(#brushed-grain)"/>
  <g id="panel-brush">${brushedMetal()}</g>
  <rect id="panel-grain" x="1" y="1" width="1398" height="256" filter="url(#grain)"/>
  <rect id="panel-light" width="1400" height="258" fill="url(#surface-light)"/>
  <g id="finish-wear">${patina()}</g>
  ${[[22,18],[22,240],[1378,18],[1378,240]].map(([x,y],i)=>mountingSlot(x,y,i)).join('')}
  ${screw(92,51,22)}${screw(92,206,-18)}${screw(1306,51,-15)}${screw(1306,206,28)}
  ${scale(198,130,65.5,['∞','48','36','30','24','18','12','6','0'],79.5)}
  ${knob(0,198,130,60,'INPUT threshold')}
  ${text(198,233,'INPUT','face-ink label')}
  ${scale(477,130,65.5,['−20','−15','−10','−5','0','+5','+10','+15','+20'],79.5)}
  ${knob(2,477,130,60,'OUTPUT gain')}
  ${text(477,233,'OUTPUT','face-ink label')}
  ${text(340,55,'CAP','face-ink small')}
  <g id="cap-switch" class="trim-switch" role="button" tabindex="0" aria-label="Toggle Blown Capacitor compatibility" aria-pressed="false" transform="translate(340 72)"><circle r="10" fill="#080d0f" stroke="#747b7c"/><circle r="7.5" fill="url(#screw)"/><path id="cap-slot" d="M-5 0H5" stroke="#101719" stroke-width="2.6"/><circle r="15" fill="transparent"/></g>
  ${text(320,76,'N','face-ink small')}${text(360,76,'L','face-ink small')}
  ${text(340,165,'MIX','face-ink small')}<g id="knob-5" class="knob mix-trim" role="slider" tabindex="0" aria-label="MIX dry/wet" transform="translate(340 188)"><circle r="10" fill="#080d0f" stroke="#747b7c"/><circle r="7.5" fill="url(#screw)"/><g id="rotor-5" class="rotor"><path d="M-5 0H5" stroke="#101719" stroke-width="2.6"/></g><circle r="15" fill="transparent"/></g>
  ${text(318,192,'−','face-ink')}${text(362,192,'+','face-ink')}
  ${text(702,20,'ATTACK','face-ink label')}
  ${scale(702,70,32.2,['1','','3','','5','','7'],43.2)}${knob(3,702,70,28,'ATTACK microseconds',true)}
  <g id="attack-speed-labels">${text(702+pt(43.2,-135)[0],118,'SLOW','face-ink small')}${text(702+pt(43.2,135)[0],118,'FAST','face-ink small')}</g>
  ${scale(702,184,32.2,['1','','3','','5','','7'],43.2)}${knob(4,702,184,28,'RELEASE milliseconds',true)}
  ${text(702,233,'RELEASE','face-ink label')}
  ${text(884,28,'RATIO','face-ink label')}
  ${[20,12,8,4].map((v,i)=>key(v,872,42+i*44,v,'ratio')).join('')}
  ${text(884,232,'ALL','face-ink small')}
  <g class="diamond-mark" transform="translate(1058 25)" style="color:#e5e8df" role="img" aria-label="RW"><path d="M-31 0 0-19 31 0 0 19Z" fill="#111d24"/><use href="#rw-emblem"/></g>
  <g class="silver-lamp" transform="translate(1058 24)"><circle r="14" fill="#181e21"/><circle r="12.1" fill="#a6aaa0"/><circle id="meter-lamp" r="10" fill="url(#lamp)" stroke="#610900" stroke-width="1.4"/></g>
  ${meter()}
  ${text(1058,213,'1175 LIMITING AMPLIFIER','blue-ink label')}
  ${brand()}
  ${text(1236,28,'METER','face-ink label')}
  ${[['gr','GR'],['8','+8'],['4','+4'],['off','OFF']].map(([v,l],i)=>key(v,1224,42+i*44,l,'meter')).join('')}
  <g class="badge" transform="translate(1342 130) scale(1.12)" aria-label="AE · Anniversary Edition · ReaWeb Limiting Amplifier">
    <circle r="43" fill="#25282a" fill-opacity=".32" stroke="#c7c9bb" stroke-width=".85"/>
    <circle r="41.1" fill="none" stroke="#bfc3b6" stroke-width=".35"/>
    <circle r="30.7" fill="none" stroke="#c7c9bb" stroke-width=".65"/>
    <circle r="28.8" fill="none" stroke="#a5ac9f" stroke-width=".3"/>
    <text class="badge-legend"><textPath href="#badge-upper" startOffset="50%" text-anchor="middle">ANNIVERSARY EDITION</textPath></text>
    <text class="badge-legend badge-lower"><textPath href="#badge-lower" startOffset="50%" text-anchor="middle">REAWEB · LIMITING AMPLIFIER</textPath></text>
    <circle cx="-36" cy="0" r="1" fill="#d8d9cc"/><circle cx="36" cy="0" r="1" fill="#d8d9cc"/>
    <text class="badge-ae" x="0" y="11.5" text-anchor="middle">AE</text>
  </g>
`;
}
export function paintTheme(theme){
  document.body.dataset.theme=theme;
  const colors={ae:['#1c1c1e','#1a1a1c','#1d1d1f'],silver:['#d5d7d3','#bfc4c0','#dcdfd8'],black:['#423a40','#302c32','#393138']}[theme];
  document.querySelectorAll('#panel-fill stop').forEach((s,i)=>s.setAttribute('stop-color',colors[i]));
  document.getElementById('blue-stripe').style.display=theme==='black'?'none':'';
  document.querySelectorAll('.styles button').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.theme===theme)));
}
