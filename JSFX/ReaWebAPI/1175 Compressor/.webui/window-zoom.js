// Resize the REAPER-owned editor via a packaged one-shot Lua action. The Runtime
// correctly rejects ordinary window.setSize() for hosted JSFX editors.
export async function connectWindowZoom(reaper) {
  if(!await reaper.APIExists('JS_Window_Resize'))throw Error('Window scaling requires the js_ReaScriptAPI extension.');
  const root=await reaper.app.getRootPath();
  const action=await reaper.AddRemoveReaScript(true,0,root+'/resize-window.lua',false);
  if(!action)throw Error('Could not load the FX window resize action.');
  const section='ReaWeb1175WindowSize';
  let queue=Promise.resolve();
  return zoom=>{
    const next=queue.catch(()=>{}).then(async()=>{
      for(let attempt=0;attempt<3;attempt++){
        const [size,pos]=await Promise.all([reaper.window.getSize(),reaper.window.getPosition()]);
        const token=crypto.randomUUID();
        const width=Math.round(1380*zoom*devicePixelRatio),height=Math.ceil((30+1380*258/1400+34)*zoom*devicePixelRatio);
        const request=[token,pos.x,pos.y,size.width,size.height,width,height].join('|');
        await reaper.SetExtState(section,'request',request,false);
        await reaper.Main_OnCommand(action,0);
        const result=await reaper.GetExtState(section,'reply-'+token);
        await reaper.DeleteExtState(section,'reply-'+token,false);
        // Another open 1175 page can consume a simultaneous request; retry only
        // when this request has no reply, never apply another page's dimensions.
        if(!result)continue;
        if(!result.startsWith('ok|')){
          // REAPER may still be positioning a newly shown editor. Re-read its
          // bounds before retrying; never choose an ambiguous window by index.
          if(attempt<2&&result.includes('could not be identified uniquely')){await new Promise(r=>setTimeout(r,100));continue;}
          throw Error(result.slice(6));
        }
        return result;
      }
      throw Error('FX window is resizing. Please select the scale again.');
    });
    queue=next;return next;
  };
}

