// Identify this hosted view by a unique native title on Windows and SWELL.
// REAPER owns the outer FX window; ordinary window.setSize() is unavailable.
export async function connectWindowZoom(reaper) {
  if(!await reaper.APIExists('JS_Window_Resize'))throw Error('Window scaling requires the js_ReaScriptAPI extension.');
  const root=await reaper.app.getRootPath();
  const action=await reaper.AddRemoveReaScript(true,0,root+'/resize-window.lua',false);
  if(!action)throw Error('Could not load the FX window resize action.');
  const section='ReaWeb1175WindowSize',identity=crypto.randomUUID();
  await reaper.window.setTitle('1175 ReaWeb UI [zoom-'+identity+']');
  const mac=/OSX|macOS/i.test(await reaper.GetOS());
  let queue=Promise.resolve();
  const resize=(zoom,mode='change',current=()=>true)=>{
    const next=queue.catch(()=>{}).then(async()=>{
      for(let attempt=0;attempt<6;attempt++){
        if(!current())return null;
        const token=crypto.randomUUID();
        // Cocoa/SWELL geometry is in points, including Retina displays.
        const units=mac?1:devicePixelRatio;
        const request=[token,identity,zoom,units,mode].join('|');
        await reaper.SetExtState(section,'request',request,false);
        if(!current()){
          if(await reaper.GetExtState(section,'request')===request)await reaper.DeleteExtState(section,'request',false);
          return null;
        }
        await reaper.Main_OnCommand(action,0);
        const result=await reaper.GetExtState(section,'reply-'+token);
        await reaper.DeleteExtState(section,'reply-'+token,false);
        if(result==='skip')return null;
        if(result.startsWith('ok|')){
          const [,effective,kind]=result.split('|');
          resize.kind=kind;
          return Number(effective);
        }
        // Retry only while attaching or when a genuine size change is pending.
        // The manifest requests the minimum supported (50%) content size, so
        // switching an existing chain never forces a return to 100%.
        if(result&&!result.startsWith('retry|'))throw Error(result.slice(6));
        if(attempt<5)await new Promise(r=>setTimeout(r,80*2**attempt));
      }
      if(current())throw Error('FX window is still changing. Please select the scale again.');
      return null;
    });
    queue=next;return next;
  };
  return resize;
}

