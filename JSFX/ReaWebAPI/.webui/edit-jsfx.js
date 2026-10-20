// Open the bound native JSFX source editor without changing the FX or its source.
export async function openJSFXEditor(reaper){
  if(!reaper?.window?.getSize||!reaper?.app?.getRootPath)throw Error('Open this UI inside REAPER to edit its JSFX source.');
  if(!await reaper.APIExists('JS_WindowMessage_Post'))throw Error('EDIT JSFX requires js_ReaScriptAPI.');
  const root=await reaper.app.getRootPath();
  const action=await reaper.AddRemoveReaScript(true,0,root+'/edit-jsfx.lua',false);
  if(!action)throw Error('Could not load the JSFX editor action.');
  const section='ReaWeb1175SourceEditor';
  for(let attempt=0;attempt<2;attempt++){
    const [pos,size]=await Promise.all([reaper.window.getPosition(),reaper.window.getSize()]);
    const token=crypto.randomUUID();
    await reaper.SetExtState(section,'request',[token,pos.x,pos.y,size.width,size.height].join('|'),false);
    await reaper.Main_OnCommand(action,0);
    const result=await reaper.GetExtState(section,'reply-'+token);
    await reaper.DeleteExtState(section,'reply-'+token,false);
    if(result==='ok')return;
    if(result)throw Error(result.replace(/^error\|/,''));
  }
  throw Error('The FX window changed. Please click EDIT JSFX again.');
}
