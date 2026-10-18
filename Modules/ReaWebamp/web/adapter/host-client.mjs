import {t} from './i18n.mjs';
export async function connectHost(host=globalThis.reaper){
 let sequence=0,closed=false;const pending=new Map();
 const off=await host.events.on('message',raw=>{
  let reply;try{reply=JSON.parse(raw)}catch{return}
  if(reply.type!=='reawebamp')return;
  const item=pending.get(reply.id);if(!item)return;
  pending.delete(reply.id);clearTimeout(item.timer);reply.error?item.reject(Error(reply.error)):item.resolve(reply.result);
 });
 return {
  async request(op,...args){
   if(closed)throw Error('ReaWebamp backend is closed');
   const id=++sequence;
   const result=new Promise((resolve,reject)=>{const timer=setTimeout(()=>{pending.delete(id);reject(Error(t('backendTimeout')))},op==='preview'?180000:15000);pending.set(id,{resolve,reject,timer})});
   try{await host.host.send(`RW2 ${id} ${op} ${args.map(value=>encodeURIComponent(String(value))).join(' ')}`)}catch(e){const item=pending.get(id);pending.delete(id);clearTimeout(item?.timer);item?.reject(e)}
   return result;
  },
  async dispose(){closed=true;await off();for(const item of pending.values()){clearTimeout(item.timer);item.reject(Error('ReaWebamp closed'))}pending.clear()}
 };
}
