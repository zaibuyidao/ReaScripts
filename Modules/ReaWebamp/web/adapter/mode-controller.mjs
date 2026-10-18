import {t} from './i18n.mjs';
import {openMonitor} from './reaper-monitor.mjs';
// Isolated integration with Webamp 2.3.1's IMedia and analyser graph.
export function createModes(player,backend,report,changed){
 const media=player.media,analyser=media.getAnalyser();
 if(!media._balance || analyser!==media._analyser || !media._context || !media._source?._audio)throw Error('Unsupported Webamp media graph');
 const names=['play','pause','stop','seekToTime','seekToPercentComplete','loadFromUrl','duration','timeElapsed'];
 const original=Object.fromEntries(names.map(name=>[name,media[name].bind(media)]));
 let mode='player',follow=false,monitor=null,snapshot=null,syncing=false,busy=false,restoring=false,project=null,length=0,position=0,state=0,offTransport,offProject;
 let transitions=Promise.resolve();
 const enqueue=fn=>{const next=transitions.then(fn);transitions=next.catch(()=>{});return next};
 const notify=()=>changed({mode,follow,state,position,length,diagnostics:monitor?.diagnostics});
 const control=async(action,value=0)=>{
  if(syncing || restoring)return;
  if(!follow){report(Error(t('transportOff')));return}
  try{await backend.request('transport',project.token,action,value)}catch(e){report(e)}
 };
 media.play=()=>mode==='monitor'?control('play'):original.play();
 media.pause=()=>mode==='monitor'?control('pause'):original.pause();
 media.stop=()=>mode==='monitor'?control('stop'):original.stop();
 media.seekToTime=value=>mode==='monitor'?control('seek',value):original.seekToTime(value);
 media.seekToPercentComplete=value=>mode==='monitor'?control('seek',length*value/100):original.seekToPercentComplete(value);
 media.loadFromUrl=(url,auto)=>mode==='monitor'?Promise.resolve():original.loadFromUrl(url,restoring?false:auto);
 media.duration=()=>mode==='monitor'?length:original.duration();media.timeElapsed=()=>mode==='monitor'?position:original.timeElapsed();
 const sync=event=>{
  if(mode!=='monitor'||!event?.available)return;
  state=event.state;position=(state&1)?event.position:event.cursor;
  syncing=true;
  try{player.store.dispatch({type:(state&1)?'IS_PLAYING':(state&2)?'PAUSE':'IS_STOPPED'});player.store.dispatch({type:'UPDATE_TIME_ELAPSED',elapsed:position})}finally{syncing=false}
  if(!(state&1))monitor?.reset();notify();
 };
 async function leave(){
  follow=false;await offTransport?.();await offProject?.();offTransport=offProject=null;
  await monitor?.close();monitor=null;
  if(mode==='monitor'){
   media._balance.connect(analyser);mode='player';restoring=true;
   try{player.setTracksToPlay(snapshot||[]);original.stop()}finally{restoring=false;snapshot=null}
  }
  notify();
 }
 let playlistExit=false;
 const offPlaylist=player.store.subscribe(()=>{
  if(mode!=='monitor'||busy||restoring||playlistExit)return;
  const tracks=player.getPlaylistTracks();if(tracks.length===1&&String(tracks[0].url)==='reaweb-monitor:timeline')return;
  playlistExit=true;
  void enqueue(async()=>{
   try{if(mode==='monitor'){const current=player.getPlaylistTracks();const additions=current.filter(t=>String(t.url)!=='reaweb-monitor:timeline');snapshot=current.some(t=>String(t.url)==='reaweb-monitor:timeline')?[...(snapshot||[]),...additions]:additions;await leave()}}
   finally{playlistExit=false}
  });
 });
 return {
  get preserveTracks(){return mode==='monitor'||restoring||busy},get mode(){return mode},get follow(){return follow},get diagnostics(){return monitor?.diagnostics},get monitor(){return monitor},
  enterMonitor(){return enqueue(async()=>{
   if(busy||mode==='monitor')return;busy=true;
   try{
    if(!player.store.getState().windows.milkdropEnabled)throw Error(t('monitorUnsupported'));
    project=await backend.request('state');length=project.length;state=project.state;position=project.position;
    snapshot=player.getPlaylistTracks();original.stop();
    media._balance.disconnect(analyser);mode='monitor';
    monitor=await openMonitor(media._context,analyser,error=>{report(error);void enqueue(leave)});
    player.setTracksToPlay([{url:'reaweb-monitor:timeline',defaultName:'REAPER hardware output',duration:length,metaData:{title:'REAPER Timeline'}}]);
    offTransport=await reaper.events.on('transportchange',sync);
    let epoch=null;
    offProject=await reaper.events.on('projectchange',event=>{if(epoch===null){epoch=event?.projectEpoch;return}if(event?.projectEpoch!==epoch){report(Error(t('projectSwitched')));void enqueue(leave)}});
    sync({available:true,state,position,cursor:project.cursor});notify();
   }catch(e){await leave();throw e}finally{busy=false}
  })},
  setFollow(value){if(mode!=='monitor')throw Error(t('monitorOnly'));follow=!!value;notify()},
  leave:()=>enqueue(leave),
  async dispose(){offPlaylist();await enqueue(leave);for(const name of names)media[name]=original[name]}
 };
}
