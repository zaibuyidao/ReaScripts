'use strict';
window.KeymapI18n=(()=>{
  const patterns=Object.keys(window.KEYMAP_LOCALES.en.strings).filter(key=>/\{\w+\}/.test(key)).map(key=>{
    const names=[];let cursor=0,pattern='^';
    const escape=text=>text.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
    for(const match of key.matchAll(/\{(\w+)\}/g)){pattern+=escape(key.slice(cursor,match.index))+'([\\s\\S]*?)';names.push(match[1]);cursor=match.index+match[0].length;}
    return {key,names,regex:new RegExp(pattern+escape(key.slice(cursor))+'$')};
  });
  function translate(locale,source,params){
    if(source==null)return '';
    source=String(source);
    const strings=(window.KEYMAP_LOCALES[locale]||window.KEYMAP_LOCALES.en).strings;
    let template=strings[source];
    // Legacy backend status messages carry interpolated strings. Match only known
    // complete templates, never individual words within names, paths or notes.
    if(template===undefined&&!params){
      for(const entry of patterns){const match=entry.regex.exec(source);if(match){template=strings[entry.key];params=Object.fromEntries(entry.names.map((name,index)=>[name,match[index+1]]));break;}}
    }
    return (template??source).replace(/\{(\w+)\}/g,(match,key)=>params&&Object.hasOwn(params,key)?String(params[key]):match);
  }
  return {translate};
})();
