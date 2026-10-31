'use strict';
// Base palettes match the user's TrackAxis reference. Derived tokens cover the
// entire interface, including table states, dialogs and native form controls.
window.KeymapThemes=(()=>{
  const presets={
    modern:{background:'#181b20',panel:'#222830',text:'#e1e7ef',accent:'#89c7bd',line:'#3c4754'},
    retro:{background:'#efe5ce',panel:'#f7efdd',text:'#40362a',accent:'#83522b',line:'#c1ae87'},
    serious:{background:'#222326',panel:'#2c2e32',text:'#e4e4e7',accent:'#b8bec8',line:'#4a4e57'},
    cyber:{background:'#101321',panel:'#191d32',text:'#e1f5ff',accent:'#45e0dc',line:'#363c60'},
    warm:{background:'#f4e8de',panel:'#fff6ee',text:'#49392f',accent:'#a14d29',line:'#cbb6a6'},
    cold:{background:'#e8f1f6',panel:'#f5fafc',text:'#263f52',accent:'#226184',line:'#adc5d4'},
    anime:{background:'#211e35',panel:'#2d2846',text:'#f3eafa',accent:'#eda6d4',line:'#554b70'},
    forest:{background:'#18251f',panel:'#223129',text:'#e0eade',accent:'#a9c780',line:'#3e5747'},
    mono:{background:'#ececec',panel:'#fafafa',text:'#292929',accent:'#4b4b4b',line:'#bdbdbd'},
    midnight:{background:'#221f22',panel:'#221f22',text:'#eeeeee',accent:'#78dce6',line:'#19181a',control:'#2b2b2b',field:'#19181a'}
  };
  const options=[['reaper','跟随 REAPER 主题'],['modern','都市岩灰'],['retro','古典羊皮'],['serious','沉稳石墨'],['cyber','赛博霓虹'],['warm','暖阳琥珀'],['cold','冰川冷蓝'],['anime','樱花粉彩'],['forest','森野绿意'],['mono','极简黑白'],['midnight','深夜玄黑'],['custom','自定义配色']].map(([id,label])=>({id,label}));
  const fields=[['colorBackground','背景'],['colorPanel','面板'],['colorText','文字'],['colorAccent','强调色'],['colorBorder','边框']].map(([id,label])=>({id,label}));
  const defaults={theme:'midnight',colorBackground:'#221f22',colorPanel:'#221f22',colorText:'#eeeeee',colorAccent:'#78dce6',colorBorder:'#19181a'};
  const keys=Object.keys(defaults),validColor=value=>typeof value==='string'&&/^#[\da-f]{6}$/i.test(value);
  function normalize(raw={}){raw=raw&&typeof raw==='object'?raw:{};return Object.fromEntries(keys.map(key=>[key,key==='theme'?(options.some(option=>option.id===raw[key])?raw[key]:defaults[key]):(validColor(raw[key])?raw[key]:defaults[key])]));}
  const rgb=hex=>hex.slice(1).match(/../g).map(part=>parseInt(part,16));
  const mix=(a,b,amount)=>'#'+rgb(a).map((v,i)=>Math.round(v+(rgb(b)[i]-v)*amount).toString(16).padStart(2,'0')).join('');
  const light=color=>rgb(color).reduce((sum,value,i)=>sum+value*[.2126,.7152,.0722][i],0)>150;
  const luminance=color=>rgb(color).map(v=>v/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4).reduce((sum,v,i)=>sum+v*[.2126,.7152,.0722][i],0);
  const contrast=(a,b)=>(Math.max(luminance(a),luminance(b))+.05)/(Math.min(luminance(a),luminance(b))+.05);
  const readable=(color,bg)=>contrast(color,bg)>=4.5?color:(contrast('#eeeeee',bg)>contrast('#202020',bg)?'#eeeeee':'#202020');
  function palette(raw,native){
    const prefs=normalize(raw),custom={background:prefs.colorBackground,panel:prefs.colorPanel,text:prefs.colorText,accent:prefs.colorAccent,line:prefs.colorBorder};
    const base=prefs.theme==='custom'?custom:(presets[prefs.theme]||presets.midnight);
    const colors=prefs.theme==='reaper'&&native?.available?native.colors||{}:{};
    const get=(key,fallback)=>validColor(colors[key])?colors[key]:fallback;
    const following=prefs.theme==='reaper'&&native?.available,dark=following&&native.dark===true;
    // Dark-mode dialog overrides differ from the underlying .ReaperTheme colors.
    const background=dark?get('buttonface','#2b2b2b'):get('col_main_bg',base.background),panel=following?background:base.panel;
    const text=readable(dark?get('buttontext','#dddddd'):get('col_main_text',base.text),panel),accent=get('genlist_selbg',base.accent);
    const control=dark?panel:get('col_buttonbg',following?mix(panel,text,.06):(base.control||mix(panel,text,.06))),controlText=readable(text,control);
    const field=dark?get('window',mix(panel,'#000000',.15)):get('col_main_editbk',following?mix(panel,text,.035):(base.field||mix(background,text,.035)));
    const line=dark?get('buttonshadow',mix(panel,text,.18)):get('col_main_3dsh',following?mix(panel,text,.18):base.line);
    const toolbar=dark?control:get('col_main_bg2',panel);
    const selected=mix(panel,accent,.17),danger=light(panel)?'#a72b3d':'#f1a2ad',warning=light(panel)?'#83500d':'#e6bd81';
    return {background,panel,text,accent,line,field,'field-text':readable(text,field),control,'control-text':controlText,
      'on-accent':readable(get('genlist_selfg',light(accent)?'#101010':'#ffffff'),accent),
      'accent-text':readable(accent,panel),muted:mix(text,panel,.25),subtle:mix(text,panel,.36),
      hover:mix(panel,text,.07),selected,'selected-text':readable(text,selected),focus:mix(line,accent,.6),
      toolbar,'toolbar-text':readable(dark?text:get('col_main_text2',text),toolbar),
      gutter:mix(background,light(background)?'#ffffff':'#000000',.18),
      danger,'danger-bg':mix(panel,danger,.14),'danger-border':mix(line,danger,.4),
      warning,'warning-bg':mix(panel,warning,.13),'warning-border':mix(line,warning,.4),
      'scrollbar-track':mix(panel,text,.12),thumb:mix(panel,text,.32),'thumb-hover':mix(panel,text,.46),scheme:light(background)?'light':'dark'};
  }
  function apply(prefs,native){const tokens=palette(prefs,native);for(const [key,value] of Object.entries(tokens))if(key!=='scheme')document.documentElement.style.setProperty('--theme-'+key,value);document.documentElement.style.colorScheme=tokens.scheme;document.documentElement.dataset.theme=normalize(prefs).theme;}
  // Paint a saved/default palette before Vue mounts to avoid an old-color flash.
  let saved={};try{saved=JSON.parse(localStorage.getItem('reakeymap.colors')||'{}');}catch{}
  apply(saved);
  return {presets,options,fields,defaults,keys,normalize,palette,apply,contrast};
})();
