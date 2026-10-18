import {t} from './i18n.mjs';
import {chooseFiles,resolvePlaylist} from './local-tracks.mjs';
import {saveBlob} from './browser-files.mjs';
const DB='reawebamp.library.v2';
const key=file=>`${file.name}:${file.size}:${file.lastModified}`;
export function parseList(text,path){
 if(text.length>1024*1024)throw Error(t('listLarge'));
 const base=path.replace(/[^/\\]*$/,'');
 let paths;
 if(/^\s*\[playlist\]/i.test(text))paths=[...text.matchAll(/^File(\d+)=(.+)$/gmi)].sort((a,b)=>+a[1]-+b[1]).map(m=>m[2].trim());
 else paths=text.replace(/^\uFEFF/,'').split(/\r?\n/).map(s=>s.trim()).filter(s=>s&&!s.startsWith('#'));
 if(paths.length>32)throw Error(t('listLimit'));
 return paths.map(value=>{if(/^[a-z][\w+.-]*:\/\//i.test(value)||value.includes('\0'))throw Error(t('localOnly'));return /^(?:[a-z]:[\\/]|\/|\\\\)/i.test(value)?value:base+value});
}
export async function createLibrary(player,urls,report,isMonitor){
 const db=await new Promise((resolve,reject)=>{const request=indexedDB.open(DB,1);request.onupgradeneeded=()=>request.result.createObjectStore('files');request.onerror=()=>reject(request.error);request.onsuccess=()=>resolve(request.result)});
 const storage=(operation,key,value)=>new Promise((resolve,reject)=>{const transaction=db.transaction('files',operation==='get'?'readonly':'readwrite');const store=transaction.objectStore('files');const request=operation==='get'?store.get(key):store.put(value,key);transaction.oncomplete=()=>resolve(request.result);transaction.onerror=()=>reject(transaction.error)});
 const records=new Map(),handles=new Map(),attached=new Set();let applyingMetadata=false,lastList='',timer,closed=false,saving=Promise.resolve(),restoring=false;
 async function openPaths(rows){
  if(rows.length+handles.size>32)throw Error(t('mediaLimit'));
  const tracks=[],opened=[];
  try{
   for(const row of rows){
    const media=await reaper.fs.openMedia(row.path);opened.push(media);
    const info=await reaper.audio.getFileInfo(row.path);
    const name=row.name||row.path.split(/[\\/]/).pop();
    records.set(media.url,{...row,name,size:media.size,duration:info.duration,audioInfo:info});handles.set(media.url,media);
    tracks.push({url:media.url,defaultName:name,duration:info.duration,metaData:{title:name}});
   }
   return tracks;
  }catch(error){for(const media of opened){handles.delete(media.url);records.delete(media.url);await media.close()}throw error}
 }
 async function snapshot(){
  if(closed||restoring||isMonitor())return;
  const list=[];let bytes=0;
  for(const track of player.getPlaylistTracks()){
   if(records.has(track.url)){const row=records.get(track.url);if(!row.blobKey){list.push(row);continue}}
   const file=urls.blobs.get(track.url);
   if(file instanceof File){
    if(file.size>256*1024*1024)throw Error(t('fileLarge'));
    bytes+=file.size;if(bytes>256*1024*1024)throw Error(t('copiesLarge'));
    const id=key(file);await storage('put',id,file);const row={blobKey:id,name:file.name,duration:track.duration};records.set(track.url,row);list.push(row);
   }
  }
  await storage('put','playlist',list);
  await new Promise((resolve,reject)=>{const tx=db.transaction('files','readwrite'),keep=new Set(['playlist','skin',...list.map(row=>row.blobKey).filter(Boolean)]);const request=tx.objectStore('files').openCursor();request.onsuccess=()=>{const cursor=request.result;if(cursor){if(!keep.has(cursor.key))cursor.delete();cursor.continue()}};tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error)});
 }
 async function restoreRows(rows){
  if(!Array.isArray(rows)||rows.length>10000)throw Error(t('invalidLargeList'));
  const tracks=[],errors=[];
  for(const row of rows){
   try{
    if(typeof row.path==='string'){tracks.push(...await openPaths([row]));continue}
    if(typeof row.blobKey==='string'){const file=await storage('get',row.blobKey);if(!file)throw Error(t('missingCopy'));tracks.push({blob:file,defaultName:row.name,duration:row.duration});continue}
    throw Error(t('invalidReference'));
   }catch(e){errors.push(`${row.name||row.path}: ${e.message}`)}
  }
  if(errors.length)report(Error(t('restoreFiles',{files:errors.join('\n')})));
  return tracks;
 }
 const off=player.store.subscribe(()=>{
  if(restoring||isMonitor()||closed)return;
  if(!applyingMetadata){applyingMetadata=true;try{for(const track of Object.values(player.store.getState().tracks)){const row=records.get(track.url),info=row?.audioInfo;if(info&&track.sampleRate!==info.sampleRate)player.store.dispatch({type:'SET_MEDIA_TAGS',id:track.id,title:row.name,artist:'',sampleRate:info.sampleRate,bitrate:info.duration>0?Math.round(row.size*8/info.duration):0,numberOfChannels:info.channels})}}finally{applyingMetadata=false}}
  const tracks=player.getPlaylistTracks();const identity=JSON.stringify(tracks.map(t=>t.url));
  if(identity!==lastList){lastList=identity;clearTimeout(timer);timer=setTimeout(()=>{saving=saving.then(snapshot).catch(report)},400)}
  const current=new Set(tracks.map(t=>t.url));
  for(const url of current)if(handles.has(url))attached.add(url);
  for(const [url,handle]of handles)if(attached.has(url)&&!current.has(url)){attached.delete(url);handles.delete(url);records.delete(url);void handle.close().catch(report)}
 });
 return {
  records,openPaths,
  rememberSkin:file=>storage('put','skin',file),
  async restore(){restoring=true;try{const list=await storage('get','playlist');if(list){const tracks=await restoreRows(list);player.appendTracks(tracks)}const skin=await storage('get','skin');if(skin){const url=URL.createObjectURL(skin);player.setSkinFromUrl(url);await player.skinIsLoaded();URL.revokeObjectURL(url)}}finally{restoring=false}},
  async setSkin(file){const url=URL.createObjectURL(file);try{player.setSkinFromUrl(url);await player.skinIsLoaded();await storage('put','skin',file)}finally{URL.revokeObjectURL(url)}},
  async saveList(tracks){
   await snapshot();
   const list=tracks.map(t=>records.get(String(t.url)));
   if(list.some(row=>!row))throw Error(t('unsavedFiles'));
   const native=list.every(row=>row.path);
   const content=native?'#EXTM3U\n'+list.map(row=>`#EXTINF:${row.duration||-1},${row.name.replace(/[\r\n]/g,' ')}\n${row.path}`).join('\n')+'\n':JSON.stringify({format:'reawebamp-playlist',version:2,tracks:list},null,2);
   await saveBlob(new Blob([content],{type:native?'audio/x-mpegurl':'application/json'}),native?'ReaWebamp.m3u8':'ReaWebamp.playlist.json');return null;
  },
  async loadList(){
   const path=await reaper.dialog.openFile({title:t('openPlaylist'),filters:[{name:'Playlist',extensions:['m3u','m3u8','pls','json']}]});if(!path)return null;
   const text=await reaper.fs.readText(path);
   if(text.length>1024*1024)throw Error(t('listLarge'));
   if(/\.json$/i.test(path)){const list=JSON.parse(text);if(list.format!=='reawebamp-playlist')throw Error(t('invalidPlaylist'));if(list.version===1){if(!list.tracks?.length)return resolvePlaylist(list,[]);const files=await chooseFiles(t('oldPlaylist'),{multiple:true});return files.length?resolvePlaylist(list,files):null}if(list.version!==2)throw Error(t('listVersion'));return restoreRows(list.tracks)}
   return openPaths(parseList(text,path).map(path=>({path})));
  },
  async releaseAll(){for(const h of handles.values())await h.close();handles.clear();records.clear()},
  async dispose(){clearTimeout(timer);off();await saving;await snapshot();closed=true;for(const h of handles.values())await h.close().catch(()=>{});handles.clear();db.close()}
 };
}
