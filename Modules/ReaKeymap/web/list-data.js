'use strict';
// Self-contained so the same index can run in a Blob worker or cooperatively
// on hosts that prohibit workers. No network or remote scripts are required.
function createKeymapListIndex() {
  let active=null, staging=null, queryGeneration=0;
  const shortcutNames=createKeymapShortcutNames();
  const pause=()=>new Promise(resolve=>setTimeout(resolve,0));
  const lower=value=>String(value??'').replace(/[A-Z]/g,c=>c.toLowerCase());
  const aliases={return:'enter',esc:'escape',spacebar:'space',leftarrow:'left',rightarrow:'right',uparrow:'up',downarrow:'down',pgup:'pageup',pgdn:'pagedown','num.':'keypaddecimal','num/':'keypaddivide','num*':'keypadmultiply','num-':'keypadsubtract','num+':'keypadadd',numenter:'keypadenter','num=':'keypadequal','keypad+':'keypadadd','keypad-':'keypadsubtract','keypad*':'keypadmultiply','keypad/':'keypaddivide'};
  for(let i=0;i<10;i++)aliases['num'+i]='keypad'+i;
  function canonical(value){
    let text=lower(shortcutNames.format(value,'en')).trim().replace(/\s*\+\s*/g,'+').replace(/⌘/g,'cmd+').replace(/⌥/g,'alt+').replace(/⇧/g,'shift+').replace(/⌃/g,'ctrl+').replace(/control\s*\+/g,'ctrl+').replace(/command\s*\+/g,'cmd+').replace(/(?:option|opt)\s*\+/g,'alt+').replace(/meta\s*\+/g,'cmd+');
    const prefix=(text.includes('ctrl+')?'C':'')+(text.includes('shift+')?'S':'')+(text.includes('alt+')?'A':'')+(/(?:cmd|win|super)\+/.test(text)?'M':'');
    text=text.replace(/(?:ctrl|shift|alt|cmd|win|super)\+/g,'').replace(/\s+/g,'');return prefix+':'+(aliases[text]||text);
  }
  function tokens(value){return (lower(value).match(/\d+|\D+/g)||[]).map(text=>/^\d/.test(text)?{text,number:text.replace(/^0+/,'')||'0'}:{text});}
  function compare(a,b){
    for(let i=0;i<Math.min(a.length,b.length);i++){
      const x=a[i],y=b[i];let result=0;
      if(x.number!==undefined&&y.number!==undefined)result=x.number.length-y.number.length||(x.number<y.number?-1:x.number>y.number?1:0)||x.text.length-y.text.length;
      else result=x.text<y.text?-1:x.text>y.text?1:0;
      if(result)return result;
    }
    return a.length-b.length;
  }
  async function ordered(data,field){
    if(data.orders.has(field))return data.orders.get(field);
    const promise=(async()=>{
      const n=data.rows.length,fields={name:'name',id:'id_text',note:'note',section:'section_name',path:'script_directory'};
      const values=new Array(n),keys=new Array(n);
      for(let i=0;i<n;i++){
        const row=data.rows[i];values[i]=tokens(field==='shortcut'?row.shortcuts.join(', '):row[fields[field]||'name']);keys[i]=tokens(row.key);
        if(i%2048===2047)await pause();
      }
      let from=Uint32Array.from({length:n},(_,i)=>i),to=new Uint32Array(n),deadline=performance.now()+6,operations=0;
      const less=(a,b)=>(compare(values[a],values[b])||compare(keys[a],keys[b]))<=0;
      // Bounded slices also keep the fallback responsive during a cold sort.
      for(let width=1;width<n;width*=2){
        for(let start=0;start<n;start+=2*width){
          let left=start,right=Math.min(start+width,n),endLeft=right,end=Math.min(start+2*width,n);
          for(let out=start;out<end;out++){
            to[out]=left<endLeft&&(right>=end||less(from[left],from[right]))?from[left++]:from[right++];
            if(++operations%1024===0&&performance.now()>deadline){await pause();deadline=performance.now()+6;}
          }
        }
        [from,to]=[to,from];
      }
      return from;
    })();data.orders.set(field,promise);return promise;
  }
  async function handle(message){
    if(message.type==='begin'){staging={revision:message.revision,rows:[],text:[],keys:[],orders:new Map(),queries:new Map()};return true;}
    if(message.type==='append'){
      if(!staging||staging.revision!==message.revision)throw Error('命令索引版本已改变。');
      for(const row of message.rows){staging.rows.push(row);staging.text.push(lower([row.name,row.id_text,row.script_path,row.note,row.shortcuts.join(', '),row.shortcuts.map(shortcutNames.searchText).join('\n'),row.section_name].join('\n')));staging.keys.push(row.shortcuts.map(canonical));}
      return true;
    }
    if(message.type==='commit'){
      const data=staging;if(!data||data.revision!==message.revision)throw Error('命令索引版本已改变。');
      await ordered(data,'name');active=data;staging=null;return true;
    }
    if(message.type==='query'){
      const generation=++queryGeneration,data=active,p=message.params;
      if(!data||message.revision!==data.revision)return {stale:true};
      const cacheKey=JSON.stringify(p);
      if(data.queries.has(cacheKey))return {indices:data.queries.get(cacheKey).slice(),revision:data.revision};
      const order=await ordered(data,p.sort),scope=new Set(p.sections||[]),selected=new Set(p.selected||[]),search=lower(p.search).match(/\S+/g)||[],key=p.shortcut?canonical(p.shortcut):null,result=[];
      let deadline=performance.now()+6;
      for(let i=0;i<order.length;i++){
        const index=order[p.desc?order.length-1-i:i],row=data.rows[index];
        if((p.section==null?scope.has(row.section_id):p.section===row.section_id)&&
          (p.view!=='bound'||row.shortcuts.length)&&(p.view!=='managed'||row.managed)&&(p.view!=='conflicts'||row.conflict)&&
          (!p.type||p.type==='all'||p.type===row.type)&&(!p.notes||row.note)&&(!p.selected_only||selected.has(row.key))&&
          search.every(term=>data.text[index].includes(term))&&(!key||data.keys[index].includes(key)))result.push(index);
        if(i%1024===1023&&performance.now()>deadline){await pause();deadline=performance.now()+6;if(generation!==queryGeneration)return {stale:true};}
      }
      if(generation!==queryGeneration)return {stale:true};
      const indices=Uint32Array.from(result);data.queries.set(cacheKey,indices);
      if(data.queries.size>24)data.queries.delete(data.queries.keys().next().value);
      return {indices:indices.slice(),revision:data.revision};
    }
    throw Error('未知列表索引请求。');
  }
  return {handle};
}

window.KeymapListClient=class {
  constructor(onReset){
    this.pending=new Map();this.serial=0;this.fallback=null;
    try{
      const source=`const createKeymapShortcutNames=${createKeymapShortcutNames.toString()};const index=(${createKeymapListIndex.toString()})();onmessage=async({data})=>{try{const value=await index.handle(data);postMessage({id:data.id,value},value?.indices?[value.indices.buffer]:[]);}catch(error){postMessage({id:data.id,error:error.message});}};`;
      const url=URL.createObjectURL(new Blob([source],{type:'text/javascript'}));
      this.worker=new Worker(url);URL.revokeObjectURL(url);
      this.worker.onmessage=({data})=>{const pending=this.pending.get(data.id);if(!pending)return;this.pending.delete(data.id);data.error?pending.reject(Error(data.error)):pending.resolve(data.value);};
      this.worker.onerror=event=>{event.preventDefault();this.worker.terminate();this.worker=null;this.fallback=createKeymapListIndex();for(const pending of this.pending.values())pending.reject(Error('后台索引已切换为分帧模式，正在重新准备列表。'));this.pending.clear();setTimeout(()=>onReset?.(),0);};
    }catch{this.fallback=createKeymapListIndex();}
  }
  call(type,params={}){
    const message={type,...params,id:++this.serial};
    if(this.fallback)return this.fallback.handle(message);
    return new Promise((resolve,reject)=>{this.pending.set(message.id,{resolve,reject});this.worker.postMessage(message);});
  }
  dispose(){this.worker?.terminate();for(const p of this.pending.values())p.reject(Error('列表已关闭。'));this.pending.clear();}
};
