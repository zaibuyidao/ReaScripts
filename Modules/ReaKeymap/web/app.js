'use strict';
const {createApp, ref, shallowRef, reactive, computed, watch, onMounted, onUnmounted, nextTick} = Vue;
const iconPaths = {
  trash:'M3 6h18 M9 6V3h6v3 M5 6l1 15h12l1-15 M10 10v7 M14 10v7',
  piano:'M3 4h18v16H3z M8 4v16 M16 4v16 M6 4h4v8H6z M14 4h4v8h-4z',
  waveform:'M3 10v4 M7 6v12 M11 3v18 M15 7v10 M19 5v14 M23 10v4',
  list:'M4 6h1 M4 12h1 M4 18h1 M9 6h11 M9 12h11 M9 18h11',
  crossfade:'M3 5h3l12 14h3 M3 19h3L18 5h3',
  keyboard:'M4 5h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Z M6 9h.01 M10 9h.01 M14 9h.01 M18 9h.01 M6 13h.01 M10 13h.01 M14 13h.01 M18 13h.01 M7 16h10',
  grid:'M3 3h7v7H3z M14 3h7v7h-7z M3 14h7v7H3z M14 14h7v7h-7z',
  command:'M9 7V5a2 2 0 1 0-2 2h10a2 2 0 1 0-2-2v14a2 2 0 1 0 2-2H7a2 2 0 1 0 2 2V7',
  layers:'m12 3 10 5-10 5L2 8l10-5Z M2 12l10 5 10-5 M2 16l10 5 10-5',
  search:'M21 21l-5-5 M18 10a8 8 0 1 1-16 0 8 8 0 0 1 16 0',
  plus:'M12 5v14 M5 12h14', close:'m6 6 12 12 M6 18 18 6',
  file:'M14 2H5a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V9l-7-7Z M14 2v7h7 M7 13h10 M7 17h7',
  history:'M3 12a9 9 0 1 0 3-6.7L3 8 M3 3v5h5 M12 7v5l3 2',
  settings:'m9 3 .5-1h5l.5 3 2 1.2 2.8-1 2.5 4.3-2.3 2v2.3l2.3 2-2.5 4.3-2.8-1L15 20l-.5 2h-5L9 20l-2-1.2-2.8 1-2.5-4.3 2.3-2v-2.3l-2.3-2 2.5-4.3 2.8 1L9 5V3Z M16 12a4 4 0 1 1-8 0 4 4 0 0 1 8 0',
  import:'M12 3v12 m-4-4 4 4 4-4 M4 16v4h16v-4',
  export:'M12 15V3 m-4 4 4-4 4 4 M4 16v4h16v-4',
  undo:'M3 10h11a7 7 0 0 1 0 14 M3 10l5-5 M3 10l5 5',
  redo:'M21 10H10a7 7 0 0 0 0 14 M21 10l-5-5 M21 10l-5 5',
  refresh:'M20 7a9 9 0 0 0-15-2L2 8 M2 2v6h6 M4 17a9 9 0 0 0 15 2l3-3 M22 22v-6h-6',
  code:'m8 5-7 7 7 7 M16 5l7 7-7 7 M14 3l-4 18',
  down:'m6 9 6 6 6-6', up:'m6 15 6-6 6 6', left:'m15 6-6 6 6 6', right:'m9 6 6 6-6 6',
  copy:'M9 9h12v12H9z M15 5V3H3v12h2', external:'M14 3h7v7 M21 3 10 14 M10 3H3v18h18v-7',
  check:'m5 12 4 4L19 6', info:'M12 8h.01 M12 11v5 M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0'
};
const Icon = {props:{name:String,size:{default:18}},computed:{path(){return iconPaths[this.name]||iconPaths.command;}},template:'<svg :width="size" :height="size" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path :d="path"/></svg>'};
const Keycap = {props:{value:String,locale:{default:'en'}},computed:{label(){return KeymapShortcutNames.format(this.value,this.locale);},parts(){const parts=this.label.split('+'); if(parts.at(-1)===''){parts.pop();parts[parts.length-1]+='+';} return parts.filter(Boolean);}},template:'<span class="keycap" :aria-label="label"><template v-for="(part,i) in parts" :key="i"><span v-if="i" class="key-plus" aria-hidden="true">+</span><kbd>{{part}}</kbd></template></span>'};

// Explicit read-only preview fixtures. Never fall back to these after a live error.
function scriptDirectory(path){if(!path)return '';const normalized=path.replace(/\\/g,'/').replace(/^Scripts\//i,'');const slash=normalized.lastIndexOf('/');return slash<0?'(脚本)':normalized.slice(0,slash)||'/';}
function previewData() {
  const entries = [
    ['播放 / 停止','40044',['Space'],'试听与编辑时最常用的播放控制。'],
    ['录音','1013',['Ctrl+R'],'开始录制当前已准备轨道。'],
    ['保存工程','40026',['Ctrl+S'],'保持随手保存的习惯。'],
    ['撤销上一步操作','40029',['Ctrl+Z'],''],
    ['重做上一步操作','40030',['Ctrl+Shift+Z'],''],
    ['在编辑光标处分割媒体对象','40757',['S'],'精确剪辑，先对齐编辑光标。'],
    ['插入新轨道','40001',['Ctrl+T'],''],
    ['切换节拍器','40364',['C'],'录音前检查节拍器设置。'],
    ['切换循环播放','1068',['R'],''],
    ['打开混音器','40078',['Ctrl+M'],''],
    ['Script: 将选中对象移动到编辑光标','_RS_preview_01',['Alt+A'],'自定义剪辑工作流。','script'],
    ['Custom: 整理选中媒体对象','_preview_custom',['Alt+A'],'与脚本绑定重复，建议检查。','custom'],
    ['渲染工程到文件','40015',['Ctrl+Alt+R'],''],
    ['插入标记','40157',['M'],'用标记记录片段位置。'],
    ['将所选音符升高一个半音','40177',['Up'],'','native',32060],
    ['将所选音符降低一个半音','40178',['Down'],'','native',32060],
    ['切换 MIDI 网格吸附','1014',['Alt+S'],'','native',32060],
    ['打开媒体资源管理器','50124',[],''],
    ['Script: 批量重命名媒体对象','_RS_preview_02',[],'待分配快捷键。','script'],
    ['SWS: 保存当前轨道选择','_SWS_SAVESEL',['Shift+F1'],'','extension']
  ];
  return entries.map(([name,id,shortcuts,note,type='native',section_id=0])=>({key:`${section_id}:${id}`,name,id_text:id,shortcuts,note,type,section_id,section_name:section_id===0?'Main':'MIDI Editor',managed:shortcuts.length>0,conflict:shortcuts.includes('Alt+A'),script_path:type==='script'?'Scripts/zaibuyidao Scripts/Various/example.lua':''}));
}
const demoRows = previewData();
const demoSections = [{id:0,name:'Main'},{id:32063,name:'Media Explorer'},{id:32060,name:'MIDI Editor'},{id:32061,name:'MIDI Event List Editor'},{id:32062,name:'MIDI Inline Editor'},{id:32065,name:'Crossfade Editor'}].map(s=>({...s,available:true,count:demoRows.filter(a=>a.section_id===s.id).length,bound:demoRows.filter(a=>a.section_id===s.id&&a.shortcuts.length).length,managed:demoRows.filter(a=>a.section_id===s.id&&a.managed).length,conflicts:s.id===0?1:0}));
createApp({components:{Icon,Keycap},setup(){
  const languages=Object.values(window.KEYMAP_LOCALES).sort((a,b)=>a.order-b.order);
  const validLocale=value=>languages.some(language=>language.locale===value)?value:'en';
  let savedLanguage='en';try{savedLanguage=validLocale(localStorage.getItem('reakeymap.language'));}catch{}
  const locale=ref(savedLanguage);
  const t=(source,params)=>KeymapI18n.translate(locale.value,source,params);
  const shortcutLabel=value=>KeymapShortcutNames.format(value,locale.value);
  function applyLanguage(value){locale.value=validLocale(value);try{localStorage.setItem('reakeymap.language',locale.value);}catch{}}
  function changeLanguage(value){if(!busy.value){settingsDraft.language=validLocale(value);locale.value=settingsDraft.language;}}
  watch(locale,(value,previous)=>{document.documentElement.lang=value;finderValue.value=KeymapShortcutNames.format(finderValue.value,value);if(exportForm.name===KeymapI18n.translate(previous,'我的快捷键预设'))exportForm.name=t('我的快捷键预设');});
  document.documentElement.lang=locale.value;
  const themeOptions=KeymapThemes.options,themeColorFields=KeymapThemes.fields;
  let savedColors={};try{savedColors=JSON.parse(localStorage.getItem('reakeymap.colors')||'{}');}catch{}
  const savedTheme=ref(KeymapThemes.normalize(savedColors)),nativeTheme=shallowRef({available:false,colors:{}});
  let nativeThemeSignature='';
  function updateNativeTheme(value){const signature=JSON.stringify(value);if(signature!==nativeThemeSignature){nativeThemeSignature=signature;nativeTheme.value=value;}}
  function saveTheme(value){savedTheme.value=KeymapThemes.normalize(value);try{localStorage.setItem('reakeymap.colors',JSON.stringify(savedTheme.value));}catch{}}
  const connected=ref(false), busy=ref(false), meta=ref({sections:[],presets:[],backups:[],settings:{},paths:{},total:0,bound:0,conflicts:0,loading:true});
  const statusText=computed(()=>busy.value?'等待 REAPER 完成操作':catalogLoading.value?'正在更新命令索引':meta.value.loading?'正在扫描操作区段':meta.value.status||'所有更改已同步');
  const section=ref(null), view=ref('all'), search=ref(''), type=ref('all'), notesOnly=ref(false), selectedOnly=ref(false), shortcut=ref('');
  const defaultOverviewSections=[0,32060,32063];
  let savedOverviewSections=defaultOverviewSections;
  try{const saved=JSON.parse(localStorage.getItem('reakeymap.overview-sections'));if(Array.isArray(saved))savedOverviewSections=saved.filter(Number.isInteger);}catch{}
  const overviewSections=ref([...new Set(savedOverviewSections)]),overviewDraft=ref([]);
  const overviewAvailable=computed(()=>meta.value.sections.filter(s=>s.available&&overviewSections.value.includes(s.id)));
  const overviewStats=computed(()=>overviewAvailable.value.reduce((sum,s)=>({count:sum.count+(s.count||0),bound:sum.bound+(s.bound||0),managed:sum.managed+(s.managed||0),conflicts:sum.conflicts+(s.conflicts||0)}),{count:0,bound:0,managed:0,conflicts:0}));
  function openOverviewSections(){guardNotes(()=>{setDetail(null);overviewDraft.value=[...overviewSections.value];modal.value='sections';});}
  function applyOverviewSections(){overviewSections.value=[...overviewDraft.value];clearSelection();setDetail(null);modal.value='';try{localStorage.setItem('reakeymap.overview-sections',JSON.stringify(overviewSections.value));}catch{notify('显示区段已更新，但无法保存到本地。','error');}}
  const rows=shallowRef([]), total=ref(0), sort=ref('name'), desc=ref(false);
  const actionMenu=ref(null),actionMenuElement=ref(null);
  let actionMenuTrigger;
  const actionMenuOptions=computed(()=>{
    const row=actionMenu.value?.row,locked=!connected.value||busy.value||meta.value.loading;
    const editable=['script','custom'].includes(row?.type),native=meta.value.capabilities?.native_actions===true;
    const reason=connected.value&&!native?t('此功能需要 js_ReaScriptAPI 扩展。'):'';
    return [
      {id:'shortcut',label:'为操作添加快捷键',disabled:locked},
      {id:'edit',label:'编辑所选自定义操作/ReaScript',disabled:locked||!editable||!native,reason},
      {id:'delete',label:'删除所选自定义操作/ReaScript',disabled:locked||!editable||!native,reason},
      {id:'duplicate',label:'复制自定义操作',disabled:locked||row?.type!=='custom'||!native,reason},
      {id:'copy_id',label:'复制所选操作命令 ID'},
      {id:'copy_text',label:'复制所选操作文本'}
    ];
  });
  async function openActionMenu(event,row){
    if(modal.value||busy.value)return;
    closeColumnMenu();actionMenuTrigger=event.currentTarget;
    const rect=event.currentTarget.getBoundingClientRect();
    actionMenu.value={row,x:event.clientX||rect.left+12,y:event.clientY||rect.bottom};
    await nextTick();if(!actionMenu.value||!actionMenuElement.value)return;
    const menu=actionMenuElement.value.getBoundingClientRect();
    actionMenu.value={...actionMenu.value,x:Math.max(5,Math.min(actionMenu.value.x,innerWidth-menu.width-5)),y:Math.max(5,Math.min(actionMenu.value.y,innerHeight-menu.height-5))};
    actionMenuElement.value.querySelector('button:not(:disabled)')?.focus({preventScroll:true});
  }
  function closeActionMenu(restore=false){actionMenu.value=null;if(restore&&actionMenuTrigger?.isConnected)actionMenuTrigger.focus({preventScroll:true});}
  async function actionMenuCommand(command){
    const row=actionMenu.value?.row,option=actionMenuOptions.value.find(o=>o.id===command);
    if(!row||!option||option.disabled)return;
    closeActionMenu(true);
    if(command==='copy_id')return copy(row.id_text);
    if(command==='copy_text')return copy(row.name);
    if(command==='shortcut')return run('shortcut',{key:row.key,index:-1,expected:row.shortcuts},value=>{if(detail.value?.key===row.key){detail.value=value;shortcutSelection.value=[];}});
    const execute=()=>run('action_operation',{key:row.key,operation:command},value=>{if(value?.deleted){if(detail.value?.key===row.key){++detailSerial;setDetail(null);}const next=new Set(selected.value);next.delete(row.key);selected.value=next;selectedRows.delete(row.key);}});
    if(command==='delete')guardNotes(execute);
    else execute();
  }
  function actionMenuKey(event){
    if(event.key==='Escape'){event.preventDefault();closeActionMenu(true);}
    else if(event.key==='Tab')closeActionMenu(true);
    else if(['ArrowDown','ArrowUp','Home','End'].includes(event.key)){
      event.preventDefault();const buttons=[...actionMenuElement.value.querySelectorAll('button:not(:disabled)')],index=buttons.indexOf(document.activeElement);
      const next=event.key==='Home'?0:event.key==='End'?buttons.length-1:(index+(event.key==='ArrowDown'?1:-1)+buttons.length)%buttons.length;buttons[next]?.focus();
    }
  }
  const columnMenu=ref(null),columnMenuElement=ref(null);
  let columnMenuTrigger;
  async function openColumnMenu(event){
    if(modal.value)return;
    closeActionMenu();
    const header=event.target.closest('th')||event.currentTarget.querySelector('th');
    columnMenuTrigger=header?.querySelector('button,input')||document.activeElement;
    const rect=header?.getBoundingClientRect();
    columnMenu.value={x:event.clientX||rect?.left||8,y:event.clientY||rect?.bottom||8};
    await nextTick();if(!columnMenu.value||!columnMenuElement.value)return;
    const menu=columnMenuElement.value.getBoundingClientRect();
    columnMenu.value={x:Math.max(8,Math.min(columnMenu.value.x,innerWidth-menu.width-8)),y:Math.max(8,Math.min(columnMenu.value.y,innerHeight-menu.height-8))};
    (columnMenuElement.value.querySelector('[aria-checked="true"]')||columnMenuElement.value.querySelector('button'))?.focus({preventScroll:true});
  }
  function closeColumnMenu(restore=false){columnMenu.value=null;if(restore)(columnMenuTrigger?.isConnected?columnMenuTrigger:tableScroll.value?.querySelector('.column-sort'))?.focus({preventScroll:true});}
  function toggleColumn(id){
    hiddenColumns.value=hiddenColumns.value.includes(id)?hiddenColumns.value.filter(value=>value!==id):[...hiddenColumns.value,id];
    saveColumns();
  }
  function resetColumnsFromMenu(){resetColumns();closeColumnMenu(true);}
  function dismissColumnMenu(event){if(actionMenu.value&&(event.type==='resize'||!actionMenuElement.value?.contains(event.target)))closeActionMenu();if(columnMenu.value&&(event.type==='resize'||!columnMenuElement.value?.contains(event.target)))closeColumnMenu();}
  function columnMenuKey(event){
    const buttons=[...columnMenuElement.value.querySelectorAll('button')],index=buttons.indexOf(document.activeElement);
    if(event.key==='Escape'){event.preventDefault();closeColumnMenu(true);}
    else if(event.key==='Tab')closeColumnMenu(true);
    else if(['ArrowDown','ArrowUp','Home','End'].includes(event.key)){
      event.preventDefault();const next=event.key==='Home'?0:event.key==='End'?buttons.length-1:(index+(event.key==='ArrowDown'?1:-1)+buttons.length)%buttons.length;buttons[next].focus();
    }
  }
  const selected=shallowRef(new Set()), selectedRows=new Map(), detail=ref(null), noteDraft=ref(''), shortcutSelection=ref([]);
  const keepDetailOpen=computed(()=>meta.value.settings.keep_detail_open!==false);
  const showRowCheckboxes=computed(()=>meta.value.settings.show_row_checkboxes===true);
  const selectionColumnWidth=computed(()=>showRowCheckboxes.value?32:0);
  const showDetailPanel=computed(()=>keepDetailOpen.value||!!detail.value);
  const finderManual=ref(false), modal=ref(''), toast=ref(null), confirmData=ref({}), finderValue=ref(''), exportForm=reactive({name:t('我的快捷键预设'),scope:'all',notes:true,unbound:false});
  const settingsFields=[...KeymapThemes.keys,'language','show_row_checkboxes','keep_detail_open','show_alt_recording','show_alt_sections','auto_refresh','auto_refresh_interval','managed_init_from_bound'];
  const settingsDraft=reactive({}),settingsBaseline=ref({});
  function resetSettingsDraft(){
    const current={...meta.value.settings,...savedTheme.value,language:locale.value};
    settingsBaseline.value=Object.fromEntries(settingsFields.map(key=>[key,current[key]]));
    Object.assign(settingsDraft,settingsBaseline.value);
  }
  watch(()=>[modal.value==='settings'?KeymapThemes.normalize(settingsDraft):savedTheme.value,nativeTheme.value],([colors,native])=>KeymapThemes.apply(colors,native),{deep:true,immediate:true});
  const settingsDirty=computed(()=>settingsFields.some(key=>settingsDraft[key]!==settingsBaseline.value[key]));
  async function applySettings(close=false){
    if(busy.value)return;
    const params={};
    for(const key of settingsFields)if(settingsDraft[key]!==settingsBaseline.value[key])params[key==='auto_refresh_interval'?'interval':key==='managed_init_from_bound'?'initialize':key]=settingsDraft[key];
    if(!Object.keys(params).length){if(close)modal.value='';return;}
    busy.value=true;
    try{
      if(connected.value)await api('settings',params);
      else meta.value={...meta.value,settings:{...meta.value.settings,...settingsDraft}};
      applyLanguage(settingsDraft.language);saveTheme(settingsDraft);resetSettingsDraft();
      if(section.value!==null&&!meta.value.sections.some(item=>item.id===section.value))chooseSection(null);
      if(close)modal.value='';
      notify('设置已保存。');
      if(connected.value&&Object.keys(params).some(key=>key!=='language'&&!KeymapThemes.keys.includes(key)))await rebuildCatalog();
    }catch(error){notify(error.message,'error');}
    finally{busy.value=false;}
  }
  const importPreview=ref(null), importMode=ref('merge'), importFull=ref(false), guideResult=ref(null);
  const searchInput=ref(null), tableScroll=ref(null), modalElement=ref(null);
  const scrollTop=ref(0),viewportHeight=ref(600),headerHeight=ref(26),rowHeight=24,overscan=16;
  const virtualStart=computed(()=>Math.max(0,Math.min(Math.floor(Math.max(0,scrollTop.value-headerHeight.value)/rowHeight)-overscan,Math.max(0,rows.value.length-1))));
  const virtualEnd=computed(()=>Math.min(rows.value.length,virtualStart.value+Math.ceil(viewportHeight.value/rowHeight)+overscan*2+2));
  const renderedRows=computed(()=>rows.value.slice(virtualStart.value,virtualEnd.value));
  const topSpace=computed(()=>virtualStart.value*rowHeight);
  const bottomSpace=computed(()=>Math.max(0,rows.value.length-virtualEnd.value)*rowHeight);
  const tableColumnCount=computed(()=>visibleColumns.value.length+(showRowCheckboxes.value?1:0));
  function onTableScroll(){if(!tableScroll.value)return;if(draggingColumn.value&&tableScroll.value.scrollTop!==dragScrollTop)tableScroll.value.scrollTop=dragScrollTop;scrollTop.value=tableScroll.value.scrollTop;}
  function resetTableScroll(){scrollTop.value=0;if(tableScroll.value)tableScroll.value.scrollTop=0;}
  const panelWindowWidth=ref(window.innerWidth),panelWidths=ref({left:null,right:null}),resizingPanel=ref('');
  try{const saved=JSON.parse(localStorage.getItem('reakeymap.panels')||'null');if(saved?.version===1)for(const side of ['left','right'])if(Number.isFinite(saved[side])&&saved[side]>0)panelWidths.value[side]=saved[side];}catch{}
  const clampPanel=(value,min,max)=>Math.max(min,Math.min(value,max));
  const panelLayout=computed(()=>{
    const width=panelWindowWidth.value,overlay=width<=980&&!keepDetailOpen.value;
    const defaults={left:width<=700?62:width<=1200?188:width>=1600?235:218,right:width<=700?Math.min(330,width):width<=980?320:width<=1200?280:width>=1600?340:310};
    const leftMin=width<=700?62:188;
    const middleMin=width<=980?Math.min(320,Math.max(160,width-leftMin-240)):420;
    const leftMax=Math.max(leftMin,width-(overlay?320:middleMin)-(showDetailPanel.value&&!overlay?240:0));
    const left=clampPanel(panelWidths.value.left??defaults.left,leftMin,leftMax);
    const rightMax=Math.max(240,overlay?width-48:width-left-middleMin);
    const right=clampPanel(panelWidths.value.right??defaults.right,Math.min(240,rightMax),rightMax);
    return {left,right,overlay,leftMin,leftMax:Math.max(leftMin,width-(overlay?320:middleMin)-(showDetailPanel.value&&!overlay?right:0)),rightMin:Math.min(240,rightMax),rightMax};
  });
  let finishPanelResize;
  function savePanelWidths(){try{localStorage.setItem('reakeymap.panels',JSON.stringify({version:1,...panelWidths.value}));}catch{notify('侧栏宽度已调整，但无法保存到本地。','error');}}
  function setPanelWidth(side,width){const layout=panelLayout.value;panelWidths.value={...panelWidths.value,[side]:Math.round(clampPanel(width,layout[side+'Min'],layout[side+'Max']))};}
  function resizePanelBy(side,delta){setPanelWidth(side,panelLayout.value[side]+delta);savePanelWidths();}
  function resetPanelWidth(side){finishPanelResize?.();panelWidths.value={...panelWidths.value,[side]:null};savePanelWidths();}
  function startPanelResize(event,side){
    if(event.button!==0||resizingColumn.value)return;
    event.preventDefault();finishPanelResize?.();closeColumnMenu();
    const handle=event.currentTarget,startX=event.clientX,startWidth=panelLayout.value[side];
    handle.focus({preventScroll:true});handle.setPointerCapture(event.pointerId);resizingPanel.value=side;
    document.body.classList.add('resizing-panels');
    const move=e=>setPanelWidth(side,startWidth+(e.clientX-startX)*(side==='left'?1:-1));
    const finish=()=>{
      handle.removeEventListener('pointermove',move);handle.removeEventListener('pointerup',finish);handle.removeEventListener('pointercancel',finish);handle.removeEventListener('lostpointercapture',finish);
      if(handle.hasPointerCapture(event.pointerId))handle.releasePointerCapture(event.pointerId);
      resizingPanel.value='';document.body.classList.remove('resizing-panels');finishPanelResize=undefined;savePanelWidths();
    };
    finishPanelResize=finish;
    handle.addEventListener('pointermove',move);handle.addEventListener('pointerup',finish);handle.addEventListener('pointercancel',finish);handle.addEventListener('lostpointercapture',finish);
  }
  function updatePanelViewport(){finishPanelResize?.();panelWindowWidth.value=window.innerWidth;}
  watch(showDetailPanel,value=>{if(!value&&resizingPanel.value==='right')finishPanelResize?.();});
  const columnDefinitions=[
    {id:'shortcut',label:'快捷键',width:240,min:10},
    {id:'name',label:'命令名称',width:390,min:10},
    {id:'id',label:'命令 ID',width:140,min:10},
    {id:'section',label:'操作区段',width:170,min:10},
    {id:'path',label:'ReaScript 路径',width:260,min:10},
    {id:'note',label:'备注',width:220,min:10}
  ];
  const hiddenColumns=ref([]);
  const columnVisibilityOptions=columnDefinitions.map(c=>({id:c.id,label:c.label.replace(/ /g,'')}));
  const columnOrder=ref(columnDefinitions.map(c=>c.id));
  const columnWidths=ref(Object.fromEntries(columnDefinitions.map(c=>[c.id,c.width])));
  const draggingColumn=ref(''),dropColumn=ref(''),dropAfter=ref(false),resizingColumn=ref('');
  const visibleColumns=computed(()=>columnOrder.value.filter(id=>!hiddenColumns.value.includes(id)).map(id=>columnDefinitions.find(c=>c.id===id)));
  const viewportWidth=ref(0);
  let tableObserver,tableMeasureFrame=0,lastScrollbarWidth=-1;
  const fittedWidths=computed(()=>{
    const columns=visibleColumns.value;
    const minimum=columns.reduce((sum,c)=>sum+c.min,0);
    const space=Math.max(minimum,viewportWidth.value-selectionColumnWidth.value);
    const weights=columns.map(c=>Math.max(0,columnWidths.value[c.id]-c.min));
    const total=weights.reduce((sum,w)=>sum+w,0);
    return Object.fromEntries(columns.map((c,i)=>[c.id,c.min+(space-minimum)*(total?weights[i]/total:1/columns.length)]));
  });
  const tableWidth=computed(()=>visibleColumns.value.length?selectionColumnWidth.value+visibleColumns.value.reduce((sum,c)=>sum+fittedWidths.value[c.id],0):viewportWidth.value);
  const tableStyles=computed(()=>({width:tableWidth.value+'px',...Object.fromEntries(visibleColumns.value.map(column=>['--width-'+column.id,fittedWidths.value[column.id]+'px']))}));
  function measureTable(){
    tableMeasureFrame=0;
    const scroller=tableScroll.value;
    if(!scroller||!scroller.isConnected)return;
    viewportHeight.value=scroller.clientHeight;
    headerHeight.value=scroller.querySelector('thead')?.offsetHeight||32;
    const width=scroller.clientWidth;
    if(width<=0)return;
    const scrollbarWidth=scroller.offsetWidth-width;
    if(viewportWidth.value!==width)viewportWidth.value=width;
    if(lastScrollbarWidth!==scrollbarWidth){
      lastScrollbarWidth=scrollbarWidth;
      scroller.closest('.library').style.setProperty('--table-scrollbar',scrollbarWidth+'px');
    }
  }
  function scheduleTableMeasure(){
    // Layout writes must run outside ResizeObserver's delivery cycle.
    // Coalesce repeated notifications and skip unchanged measurements.
    if(!tableMeasureFrame)tableMeasureFrame=requestAnimationFrame(measureTable);
  }
  function resizedWidths(id,delta,base){
    const index=visibleColumns.value.findIndex(c=>c.id===id),column=visibleColumns.value[index],next=visibleColumns.value[index+1];
    if(!next)return {...base};
    const movement=Math.max(column.min-base[id],Math.min(base[next.id]-next.min,delta));
    return {...base,[id]:base[id]+movement,[next.id]:base[next.id]-movement};
  }
  let ignoreSortUntil=0;
  function saveColumns(){try{localStorage.setItem('reakeymap.columns',JSON.stringify({version:4,order:columnOrder.value,widths:columnWidths.value,hidden:hiddenColumns.value}));}catch{}}
  function loadColumns(){
    try{
      const saved=JSON.parse(localStorage.getItem('reakeymap.columns')||'null');
      if(!saved)return;
      const ids=columnDefinitions.map(c=>c.id);
      if(Array.isArray(saved.hidden))hiddenColumns.value=[...new Set(saved.hidden.filter(id=>ids.includes(id)))];
      if(Array.isArray(saved.order))columnOrder.value=[...new Set(saved.order.filter(id=>ids.includes(id))),...ids.filter(id=>!saved.order.includes(id))];
      if((saved.version||0)<3&&['name,shortcut,id,note,section,path','shortcut,name,id,note,section,path'].includes(columnOrder.value.join(',')))columnOrder.value=columnDefinitions.map(c=>c.id);
      for(const c of columnDefinitions){const w=saved.widths?.[c.id];if(Number.isFinite(w))columnWidths.value[c.id]=Math.round(Math.max(c.min,Math.min(1800,w)));}
      saveColumns();return true;
    }catch{}
  }
  function resetColumns(){hiddenColumns.value=[];columnOrder.value=columnDefinitions.map(c=>c.id);columnWidths.value=Object.fromEntries(columnDefinitions.map(c=>[c.id,c.width]));saveColumns();}
  let finishColumnDrag,dragScrollTop=0;
  function endColumnDrag(){draggingColumn.value='';dropColumn.value='';document.body.classList.remove('reordering-columns');}
  function startColumnDrag(event,id){
    if(event.button!==0||resizingColumn.value||Date.now()<ignoreSortUntil||event.target.closest('.column-resize'))return;
    finishColumnDrag?.();
    const handle=event.target.closest('.column-sort')||event.currentTarget,startX=event.clientX,startY=event.clientY;
    dragScrollTop=tableScroll.value.scrollTop;
    let moved=false;
    handle.setPointerCapture(event.pointerId);
    const stopWheel=e=>{if(moved)e.preventDefault();};
    const move=e=>{
      if(!moved&&Math.hypot(e.clientX-startX,e.clientY-startY)<5)return;
      if(!moved){moved=true;draggingColumn.value=id;document.body.classList.add('reordering-columns');closeColumnMenu();closeActionMenu();}
      e.preventDefault();tableScroll.value.scrollTop=dragScrollTop;
      const headers=[...tableScroll.value.querySelectorAll('th[data-column]')];
      const target=headers.find(header=>{const rect=header.getBoundingClientRect();return e.clientX>=rect.left&&e.clientX<=rect.right;});
      if(target){const rect=target.getBoundingClientRect();dropColumn.value=target.dataset.column;dropAfter.value=e.clientX>rect.left+rect.width/2;}
      else dropColumn.value='';
    };
    const finish=e=>{
      handle.removeEventListener('pointermove',move);handle.removeEventListener('pointerup',finish);handle.removeEventListener('pointercancel',finish);handle.removeEventListener('lostpointercapture',finish);
      tableScroll.value?.removeEventListener('wheel',stopWheel);
      if(handle.hasPointerCapture(event.pointerId))handle.releasePointerCapture(event.pointerId);
      if(moved){
        if(e?.type==='pointerup'&&dropColumn.value&&dropColumn.value!==id){
          const order=columnOrder.value.filter(c=>c!==id);order.splice(order.indexOf(dropColumn.value)+(dropAfter.value?1:0),0,id);columnOrder.value=order;saveColumns();
        }
        ignoreSortUntil=Date.now()+250;
        tableScroll.value.scrollTop=dragScrollTop;
      }
      finishColumnDrag=null;endColumnDrag();
    };
    finishColumnDrag=finish;
    handle.addEventListener('pointermove',move);handle.addEventListener('pointerup',finish);handle.addEventListener('pointercancel',finish);handle.addEventListener('lostpointercapture',finish);
    tableScroll.value.addEventListener('wheel',stopWheel,{passive:false});
  }
  function moveColumn(id,step){
    const visible=visibleColumns.value.map(c=>c.id),index=visible.indexOf(id),target=visible[index+step];
    if(!target)return;
    const order=[...columnOrder.value],a=order.indexOf(id),b=order.indexOf(target);[order[a],order[b]]=[order[b],order[a]];columnOrder.value=order;saveColumns();
  }
  function resizeColumnBy(id,delta){columnWidths.value=resizedWidths(id,delta,{...columnWidths.value,...fittedWidths.value});saveColumns();}
  function startColumnResize(event,id){
    if(event.button!==0||visibleColumns.value.at(-1).id===id)return;
    event.preventDefault();event.stopPropagation();
    const measured={...columnWidths.value,...fittedWidths.value};
    columnWidths.value=measured;
    const handle=event.currentTarget,startX=event.clientX;
    resizingColumn.value=id;handle.setPointerCapture(event.pointerId);
    document.body.classList.add('resizing-columns');
    const move=e=>{columnWidths.value=resizedWidths(id,e.clientX-startX,measured);};
    const finish=()=>{handle.removeEventListener('pointermove',move);handle.removeEventListener('pointerup',finish);handle.removeEventListener('pointercancel',finish);handle.removeEventListener('lostpointercapture',finish);if(handle.hasPointerCapture(event.pointerId))handle.releasePointerCapture(event.pointerId);resizingColumn.value='';document.body.classList.remove('resizing-columns');ignoreSortUntil=Date.now()+250;saveColumns();};
    handle.addEventListener('pointermove',move);handle.addEventListener('pointerup',finish);handle.addEventListener('pointercancel',finish);handle.addEventListener('lostpointercapture',finish);
  }
  const tabs=[{id:'all',label:'全部命令',icon:'command',hint:'查看当前范围的全部命令'},{id:'bound',label:'已绑定命令',icon:'keyboard',tone:'green',hint:'查看已配置快捷键的命令'},{id:'managed',label:'管理列表',icon:'list',tone:'green',hint:'查看已加入管理列表的命令'},{id:'conflicts',label:'快捷键冲突',icon:'layers',tone:'amber',hint:'查看存在快捷键冲突的命令'}];
  const noteDirty=computed(()=>detail.value&&noteDraft.value!==detail.value.note);
  const activeSection=computed(()=>meta.value.sections.find(s=>s.id===section.value));
  const sectionTitle=computed(()=>section.value===null?'全部区段':sectionLabel(activeSection.value));
  const scopeTotal=computed(()=>section.value===null?overviewStats.value.count:activeSection.value?.count||0);
  const scopeBound=computed(()=>section.value===null?overviewStats.value.bound:activeSection.value?.bound||0);
  const scopeConflicts=computed(()=>section.value===null?overviewStats.value.conflicts:activeSection.value?.conflicts||0);
  const scopeManaged=computed(()=>section.value===null?overviewStats.value.managed:activeSection.value?.managed||0);
  const viewCounts=computed(()=>({all:scopeTotal.value,bound:scopeBound.value,managed:scopeManaged.value,conflicts:scopeConflicts.value}));
  const allRowsSelected=computed(()=>rows.value.length>0&&selected.value.size>=rows.value.length&&rows.value.every(row=>selected.value.has(row.key)));
  const modalTitle=computed(()=>({sections:'显示区段',export:'导出快捷键预设',finder:'查找快捷键',confirm:confirmData.value.title||'确认操作',import:'导入预设',guide:'引导应用',result:'校验结果',backups:'备份与恢复',settings:'偏好设置'})[modal.value]||'');
  let querySerial=0, detailSerial=0, toastTimer, anchor=-1, restoreFocus;
  const catalogLoading=ref(false),listPending=ref(false);
  const listLoading=computed(()=>meta.value.loading||catalogLoading.value||listPending.value);
  const listClient=new KeymapListClient(()=>{catalogRevision=null;if(!disposed)loadRows();});
  let catalogRows=[],catalogRevision=null,catalogPromise=null,disposed=false,changePending=false,catalogRetryTimer=null,catalogRetryDelay=250;
  function scheduleCatalogRetry(){
    if(disposed||catalogRetryTimer!==null)return;
    catalogLoading.value=true;
    catalogRetryTimer=setTimeout(()=>{catalogRetryTimer=null;if(disposed)return;if(busy.value){scheduleCatalogRetry();return;}syncCatalog();},catalogRetryDelay);
    catalogRetryDelay=Math.min(catalogRetryDelay*2,2000);
  }
  const bridge=new KeymapBridge(()=>{changePending=true;if(connected.value&&!busy.value)syncCatalog();},updateNativeTheme);
  async function syncCatalog(){
    changePending=false;
    try{await api('init');if(!meta.value.loading)await rebuildCatalog();else scheduleCatalogRetry();}
    catch(error){catalogLoading.value=false;if(!disposed)notify(error.message,'error');}
  }
  async function rebuildCatalog(){
    if(catalogPromise)return catalogPromise;
    if(catalogRevision!==null&&(!connected.value||catalogRevision===meta.value.catalog_revision)&&!meta.value.loading){clearTimeout(catalogRetryTimer);catalogRetryTimer=null;catalogLoading.value=false;catalogRetryDelay=250;return;}
    if(catalogRetryTimer!==null)return;
    if(connected.value&&meta.value.loading){scheduleCatalogRetry();return;}
    catalogLoading.value=true;
    catalogPromise=(async()=>{
      for(let attempt=0;attempt<2&&!disposed;attempt++){
        const revision=connected.value?meta.value.catalog_revision:'preview',nextRows=[];
        await listClient.call('begin',{revision});let offset=0,restart=false;
        do{
          const batch=connected.value?await api('catalog',{offset,limit:512,revision}):{rows:demoRows,done:true};
          if(connected.value&&meta.value.loading)return;
          if(batch.reset){restart=true;break;}
          const batchRows=batch.rows.map(row=>({...row,script_directory:row.script_directory??scriptDirectory(row.script_path)}));
          nextRows.push(...batchRows);await listClient.call('append',{revision,rows:batchRows});
          offset+=batchRows.length;if(batch.done)break;
          if(!batchRows.length)throw Error('命令读取未完成，请刷新列表重试。');
        }while(!disposed);
        if(restart)continue;
        if(disposed)return;
        await listClient.call('commit',{revision});catalogRows=nextRows;catalogRevision=revision;
        clearTimeout(catalogRetryTimer);catalogRetryTimer=null;catalogRetryDelay=250;
        // Update selected records too: bulk writes must use fresh expected bindings.
        const liveSelected=new Set();let updatedDetail;
        for(const row of nextRows){
          if(selected.value.has(row.key)){liveSelected.add(row.key);selectedRows.set(row.key,row);}
          if(detail.value?.key===row.key)updatedDetail=row;
        }
        for(const key of selected.value)if(!liveSelected.has(key))selectedRows.delete(key);
        if(liveSelected.size!==selected.value.size)selected.value=liveSelected;
        if(detail.value&&!noteDirty.value){detail.value=updatedDetail||null;noteDraft.value=updatedDetail?.note||'';shortcutSelection.value=[];}
        return;
      }
    })();
    try{await catalogPromise;}finally{catalogPromise=null;catalogLoading.value=false;}
    if(!disposed){
      if(connected.value&&(meta.value.loading||catalogRevision!==meta.value.catalog_revision))scheduleCatalogRetry();
      if(catalogRevision!==null)await loadRows(true);
    }
  }
  function number(n){return Number(n||0).toLocaleString(locale.value);}
  function typeLabel(type){return t({native:'原生命令',script:'脚本',custom:'自定义动作',extension:'扩展命令'}[type]||type);}
  function sectionIcon(s){return ({0:'command',100:'keyboard',32060:'piano',32061:'list',32062:'code',32063:'waveform',32065:'crossfade'})[s.id]||(s.id>=1&&s.id<=16?'keyboard':'layers');}
  function sectionLabel(s){
    if(!s)return t('操作区段');
    if(s.id===100)return t('主区段（备用录音）');
    if(s.id>=1&&s.id<=16)return t('主区段（备用 {number}）',{number:s.id});
    return t(({0:'主区段',32063:'媒体资源管理器',32060:'MIDI 编辑器',32061:'MIDI 事件列表编辑器',32062:'MIDI 内联编辑器',32065:'交叉淡化编辑器'})[s.id]||s.name);
  }
  function scriptPathLabel(row){const path=row.script_directory??scriptDirectory(row.script_path);return path==='(脚本)'?t('(脚本)'):path;}
  function notify(text,kind='success'){toast.value={text,kind};clearTimeout(toastTimer);toastTimer=setTimeout(()=>toast.value=null,kind==='error'?12000:5500);}
  async function api(method,params={}){const response=await bridge.call(method,params);meta.value=response.meta;if(response.meta.reaper_theme)updateNativeTheme(response.meta.reaper_theme);if(response.meta.guide)modal.value='guide';return response.value;}
  async function run(method,params={},after){
    if(!connected.value){notify('此处是只读预览，请通过 REAPER 运行 ReaKeymap.lua。','error');return;}
    if(busy.value)return;
    busy.value=true;
    try{let value=await api(method,params);if(value?.native_pending){await new Promise(resolve=>setTimeout(resolve,80));value=await api('native_continue',{token:value.native_pending});}if(after)await after(value);return value;}
    catch(error){notify(error.message,'error');}
    finally{busy.value=false;if(changePending)await syncCatalog();else await rebuildCatalog();await loadRows();}
  }
  function queryParams(){return {sections:section.value===null?[...overviewSections.value]:undefined,section:section.value,view:view.value,search:search.value,type:type.value,notes:notesOnly.value,selected_only:selectedOnly.value,selected:selectedOnly.value?[...selected.value]:[],shortcut:shortcut.value||undefined,sort:sort.value,desc:desc.value};}
  async function loadRows(preservePosition=false){
    const serial=++querySerial,p=queryParams();listPending.value=true;
    try{
      if(catalogRevision===null){await rebuildCatalog();if(serial!==querySerial||catalogRevision===null)return;}
      const snapshot=catalogRows,revision=catalogRevision;
      const result=await listClient.call('query',{revision,params:p});
      if(serial!==querySerial||disposed)return;
      if(result.stale||revision!==catalogRevision){queueMicrotask(loadRows);return;}
      const oldTop=tableScroll.value?.scrollTop||0,oldIndex=Math.floor(oldTop/rowHeight);
      const anchorKey=preservePosition?rows.value[oldIndex]?.key:null;
      rows.value=Array.from(result.indices,index=>snapshot[index]);total.value=rows.value.length;
      if(anchorKey){const newIndex=rows.value.findIndex(row=>row.key===anchorKey);if(newIndex>=0){const top=newIndex*rowHeight+oldTop%rowHeight;scrollTop.value=top;await nextTick();tableScroll.value.scrollTop=top;}}
      await nextTick();onTableScroll();
    }catch(error){if(serial===querySerial&&!disposed)notify(error.message,'error');}
    finally{if(serial===querySerial)listPending.value=false;}
  }
  function setDetail(a){detail.value=a;noteDraft.value=a?.note||'';shortcutSelection.value=[];}
  function ask(title,text,action,label='确认',danger=false){confirmData.value={title,text,action,label,danger};modal.value='confirm';}
  function guardNotes(action){if(noteDirty.value){ask('备注尚未保存','继续将放弃当前未保存的备注。',action,'放弃并继续');}else action();}
  async function openDetail(row){guardNotes(async()=>{const serial=++detailSerial;try{const a=connected.value?await api('detail',{key:row.key}):row;if(serial===detailSerial)setDetail(a);}catch(error){notify(error.message,'error');}});}
  function closeDetail(){guardNotes(()=>{++detailSerial;setDetail(null);});}
  function chooseSection(id){guardNotes(()=>{section.value=id;resetFilters(false,false);clearSelection();setDetail(null);resetTableScroll();});}
  function toggleSelection(row){const next=new Set(selected.value);if(next.has(row.key)){next.delete(row.key);selectedRows.delete(row.key);}else{next.add(row.key);selectedRows.set(row.key,row);}selected.value=next;}
  function clearSelection(){selected.value=new Set();selectedRows.clear();anchor=-1;}
  function selectAllRows(){const next=new Set(selected.value);const remove=allRowsSelected.value;for(const row of rows.value){if(remove){next.delete(row.key);selectedRows.delete(row.key);}else{next.add(row.key);selectedRows.set(row.key,row);}}selected.value=next;}
  function selectRow(row,index,event){if(event.shiftKey&&anchor>=0){const next=new Set(selected.value);for(let i=Math.min(index,anchor);i<=Math.max(index,anchor);i++){const a=rows.value[i];if(a){next.add(a.key);selectedRows.set(a.key,a);}}selected.value=next;}else if(event.ctrlKey||event.metaKey){toggleSelection(row);anchor=index;}else{selected.value=new Set([row.key]);selectedRows.clear();selectedRows.set(row.key,row);anchor=index;openDetail(row);}}
  function sortBy(field){if(Date.now()<ignoreSortUntil||resizingColumn.value||draggingColumn.value)return;if(sort.value===field)desc.value=!desc.value;else{sort.value=field;desc.value=false;}}
  function resetFilters(resetView=true,resetType=true){if(resetView)view.value='all';search.value='';if(resetType)type.value='all';notesOnly.value=false;selectedOnly.value=false;shortcut.value='';}
  async function refresh(){if(connected.value)await run('refresh');else await loadRows();if(detail.value&&!noteDirty.value){const row=detail.value;await openDetail(row);}}
  async function saveNote(){if(!detail.value)return;const current=detail.value;const draft=noteDraft.value;await run('note',{key:current.key,note:draft,expected:current.note},a=>{if(detail.value?.key===a.key){detail.value=a;if(noteDraft.value===draft)noteDraft.value=a.note;}notify('备注已保存。');});}
  async function editShortcut(index){const a=detail.value;if(!a)return;await run('shortcut',{key:a.key,index,expected:a.shortcuts},value=>{detail.value=value;shortcutSelection.value=[];notify(meta.value.status);});}
  function deleteShortcut(){const a=detail.value;const indices=[...shortcutSelection.value];ask('删除选中的快捷键',t('将从“{name}”删除 {count} 个绑定。执行前会自动备份当前区段。',{name:a.name,count:indices.length}),()=>run('delete',{key:a.key,indices,expected:a.shortcuts},value=>{detail.value=value;shortcutSelection.value=[];notify(meta.value.status);}), '备份并删除',true);}
  function batchDelete(){const items=[...selectedRows.values()].map(a=>({key:a.key,expected:a.shortcuts}));ask('批量删除快捷键',t('将删除 {count} 条所选命令的全部快捷键。每个受影响区段都会先保存完整备份。',{count:items.length}),()=>run('batch_delete',{items},()=>{setDetail(null);notify(meta.value.status);}), '备份并删除',true);}
  async function manage(value){await run('manage',{keys:[...selected.value],managed:value},()=>{if(detail.value&&selected.value.has(detail.value.key))detail.value={...detail.value,managed:value};notify(value?'已加入管理列表。':'已移出管理列表，快捷键绑定保留。');});}
  async function manageDetail(){const a=detail.value;await run('manage',{keys:[a.key],managed:!a.managed},()=>{detail.value={...a,managed:!a.managed};notify('管理列表已更新。');});}
  async function copy(text){try{await navigator.clipboard.writeText(text);notify('已复制。');}catch{const el=document.createElement('textarea');el.value=text;el.style.position='fixed';el.style.opacity='0';document.body.append(el);el.select();const ok=document.execCommand('copy');el.remove();notify(ok?'已复制。':'复制失败，请手动选择文本。',ok?'success':'error');}}
  function openExport(){exportForm.scope=section.value===null?'all':'current';modal.value='export';}
  function exportPreset(){return run('export',{...exportForm,section:section.value,keys:[...selected.value]},value=>{modal.value='';notify(t('已导出 {count} 条命令。文件：{path}',{count:value.count,path:value.path}));});}
  function openFinder(){finderValue.value=shortcutLabel(shortcut.value);modal.value='finder';}
  function captureKey(event){if(finderManual.value)return;if(['Control','Shift','Alt','Meta'].includes(event.key)||event.isComposing)return;if(event.key==='Tab')return;if(event.key==='Escape'){event.stopPropagation();}if((event.ctrlKey||event.metaKey)&&event.key.toLowerCase()==='v')return;event.preventDefault();const names={Space:'Space',ArrowUp:'Up',ArrowDown:'Down',ArrowLeft:'Left',ArrowRight:'Right',Escape:'Esc',BracketLeft:'[',BracketRight:']',Minus:'-',Equal:'=',Comma:',',Period:'.',Slash:'/',Backslash:'\\',Semicolon:';',Quote:"'",Backquote:'`',NumpadDecimal:'Num .',NumpadAdd:'Num +',NumpadSubtract:'Num -',NumpadMultiply:'Num *',NumpadDivide:'Num /',NumpadEnter:'Num Enter'};let key=names[event.code]||event.key;if(event.code.startsWith('Key'))key=event.code.slice(3);if(event.code.startsWith('Digit'))key=event.code.slice(5);if(/^Numpad\d$/.test(event.code))key='Num '+event.code.slice(-1);finderValue.value=shortcutLabel([event.ctrlKey?'Ctrl':'',event.shiftKey?'Shift':'',event.altKey?'Alt':'',event.metaKey?'Win':'',key].filter(Boolean).join('+'));}
  function applyFinder(){shortcut.value=finderValue.value.trim();view.value='all';search.value='';type.value='all';notesOnly.value=false;selectedOnly.value=false;modal.value='';}
  function deletePreset(preset){
    ask('删除预设',t('确定删除“{name}”？预设文件将被永久删除，当前快捷键和自动备份不会改变。',{name:preset.name}),()=>run('delete_preset',{path:preset.path},()=>notify('预设已删除。')),'删除预设',true);
  }
  async function importPreset(path){await run('import',path?{path}:{},value=>{if(value){importPreview.value=value;importMode.value='merge';importFull.value=false;modal.value='import';}});}
  async function updateImport(){await run('import_options',{mode:importMode.value,full:importFull.value},value=>{importPreview.value=value;});}
  async function setImportMode(mode){if(busy.value)return;importMode.value=mode;importFull.value=false;await updateImport();}
  async function startImport(){await run('import_start',{},value=>{if(value)modal.value='guide';});}
  async function guideStep(skip){await run('guide_step',{skip});}
  async function finishGuide(){await run('guide_finish',{},value=>{guideResult.value=value;modal.value='result';});}
  async function abortGuide(){await run('guide_abort',{},()=>{modal.value='';notify('任务已中止，可通过自动备份恢复。');});}
  async function history(redo){guardNotes(()=>run('history',{redo},value=>{if(value){setDetail(null);modal.value='guide';}}));}
  function openBackups(){modal.value='backups';}
  function restoreStartup(){ask('恢复启动状态','将创建当前配置备份，并引导恢复本次启动时记录的所有可用区段。',()=>run('restore_startup',{},()=>{modal.value='guide';}),'备份并开始');}
  function rebuildManaged(clear){const action=()=>run('rebuild_managed',{clear,bound:true},()=>notify('管理列表已更新。'));if(clear)ask('重建管理列表','将用当前所有已绑定命令替换管理列表，不改变任何快捷键。',action,'重建列表');else action();}
  async function confirmAction(){const action=confirmData.value.action;modal.value='';await action?.();}
  function closeModal(){if(busy.value||modal.value==='guide')return;modal.value='';}
  watch([overviewSections,section,view,search,type,notesOnly,selectedOnly,shortcut,sort,desc],()=>{anchor=-1;resetTableScroll();loadRows();});
  watch([section,view,type],()=>{try{localStorage.setItem('reakeymap.ui',JSON.stringify({section:section.value,view:view.value,type:type.value}));}catch{}});
  watch(selected,()=>{if(selectedOnly.value)loadRows();});
  watch(modal,async(value,old)=>{if(old==='settings'&&value!=='settings')locale.value=settingsBaseline.value.language;if(value==='settings'&&old!=='settings')resetSettingsDraft();if(value&&!old)restoreFocus=document.activeElement;await nextTick();if(value){modalElement.value?.focus();if(value==='finder')modalElement.value?.querySelector('input')?.focus();}else restoreFocus?.focus();});
  function keyboard(event){
    if(finishColumnDrag&&event.key==='Escape'){event.preventDefault();finishColumnDrag();return;}
    if(resizingPanel.value&&event.key==='Escape'){event.preventDefault();finishPanelResize?.();return;}
    if(modal.value){if(event.key==='Escape'&&modal.value!=='finder'){event.preventDefault();closeModal();}if(event.key==='Tab'){const els=[...modalElement.value.querySelectorAll('button:not(:disabled),input:not(:disabled),select:not(:disabled),textarea:not(:disabled),[tabindex="0"]')].filter(e=>e.offsetParent!==null);if(!els.length){event.preventDefault();return;}const first=els[0],last=els.at(-1);if(event.shiftKey&&(document.activeElement===first||document.activeElement===modalElement.value)){event.preventDefault();last.focus();}else if(!event.shiftKey&&(document.activeElement===last||document.activeElement===modalElement.value)){event.preventDefault();first.focus();}}return;}
    if((event.ctrlKey||event.metaKey)&&!event.altKey&&event.key.toLowerCase()==='z'){
      const target=event.target;
      if(target?.closest?.('input,textarea,select')||target?.isContentEditable)return;
      event.preventDefault();
      const redo=event.shiftKey;
      if(!event.repeat&&connected.value&&!busy.value&&!meta.value.loading&&(redo?meta.value.redo:meta.value.undo))history(redo);
      return;
    }
    if((event.ctrlKey||event.metaKey)&&event.key.toLowerCase()==='k'){event.preventDefault();searchInput.value?.focus();searchInput.value?.select();}
    if((event.ctrlKey||event.metaKey)&&event.key.toLowerCase()==='s'&&document.activeElement?.tagName==='TEXTAREA'){event.preventDefault();saveNote();}
    if(event.key==='Escape')closeDetail();
  }
  onUnmounted(()=>{disposed=true;clearTimeout(catalogRetryTimer);finishColumnDrag?.();listClient.dispose();finishPanelResize?.();window.removeEventListener('resize',updatePanelViewport);tableObserver?.disconnect();if(tableMeasureFrame)cancelAnimationFrame(tableMeasureFrame);tableMeasureFrame=0;document.removeEventListener('keydown',keyboard);document.removeEventListener('pointerdown',dismissColumnMenu,true);document.removeEventListener('scroll',dismissColumnMenu,true);window.removeEventListener('resize',dismissColumnMenu);});
  onMounted(async()=>{
    if(window.reaper?.window?.setIconVisible){
      try{await window.reaper.lifecycle?.ready;await window.reaper.window.setIconVisible(false);}
      catch(error){console.warn('[ReaKeymap] 无法隐藏窗口标题栏图标：',error);}
    }
    window.addEventListener('resize',updatePanelViewport);updatePanelViewport();
    loadColumns();
    tableObserver=new ResizeObserver(scheduleTableMeasure);tableObserver.observe(tableScroll.value);scheduleTableMeasure();
    document.addEventListener('keydown',keyboard);document.addEventListener('pointerdown',dismissColumnMenu,true);document.addEventListener('scroll',dismissColumnMenu,true);window.addEventListener('resize',dismissColumnMenu);
    window.addEventListener('beforeunload',event=>{if(noteDirty.value){event.preventDefault();event.returnValue='';}});
    try{
      connected.value=await bridge.start();
      if(connected.value){await api('init');applyLanguage(meta.value.settings.language);saveTheme(meta.value.settings);}
      else meta.value={version:'0.1.0',sections:demoSections,total:demoRows.length,bound:demoRows.filter(a=>a.shortcuts.length).length,conflicts:1,presets:[],backups:[],undo:false,redo:false,settings:{auto_refresh:true,auto_refresh_interval:5,managed_init_from_bound:true,keep_detail_open:true,show_row_checkboxes:false,show_alt_recording:false,show_alt_sections:false},paths:{data:'REAPER/Data/ReaKeymap',presets:'REAPER/Data/ReaKeymap/Presets',backups:'REAPER/Data/ReaKeymap/Backups'},loading:false,status:'只读预览：显示示例数据'};
      try {
        const prefs=JSON.parse(localStorage.getItem('reakeymap.ui')||'null');
        if(prefs){
          if(prefs.section===null||meta.value.sections.some(s=>s.id===prefs.section&&s.available))section.value=prefs.section;
          if(tabs.some(t=>t.id===prefs.view))view.value=prefs.view;
          if(['all','native','script','custom','extension'].includes(prefs.type))type.value=prefs.type;
        }
      }catch{}
      await loadRows();
    }catch(error){notify(error.message,'error');}
  });
  return {listLoading,shortcutLabel,actionMenu,actionMenuElement,actionMenuOptions,openActionMenu,actionMenuCommand,actionMenuKey,tableStyles,themeOptions,themeColorFields,nativeTheme,settingsDraft,settingsDirty,applySettings,locale,languages,t,changeLanguage,scriptPathLabel,renderedRows,virtualStart,topSpace,bottomSpace,tableColumnCount,onTableScroll,catalogLoading,listPending,showRowCheckboxes,keepDetailOpen,showDetailPanel,statusText,panelLayout,resizingPanel,startPanelResize,resizePanelBy,resetPanelWidth,columnMenu,columnMenuElement,columnVisibilityOptions,hiddenColumns,openColumnMenu,closeColumnMenu,toggleColumn,resetColumnsFromMenu,columnMenuKey,defaultOverviewSections,overviewSections,overviewDraft,overviewAvailable,overviewStats,openOverviewSections,applyOverviewSections,scriptDirectory,visibleColumns,columnWidths,fittedWidths,tableWidth,draggingColumn,dropColumn,dropAfter,resizingColumn,startColumnDrag,endColumnDrag,startColumnResize,resizeColumnBy,moveColumn,resetColumns,connected,busy,meta,section,view,search,type,notesOnly,selectedOnly,shortcut,rows,total,sort,desc,selected,detail,noteDraft,shortcutSelection,modal,toast,confirmData,finderManual,finderValue,exportForm,importPreview,importMode,importFull,guideResult,searchInput,tableScroll,modalElement,tabs,noteDirty,sectionTitle,scopeTotal,scopeBound,scopeManaged,scopeConflicts,viewCounts,allRowsSelected,modalTitle,number,typeLabel,sectionLabel,sectionIcon,run,chooseSection,selectRow,toggleSelection,selectAllRows,clearSelection,openDetail,closeDetail,sortBy,resetFilters,refresh,saveNote,editShortcut,deleteShortcut,batchDelete,manage,manageDetail,copy,openExport,exportPreset,openFinder,captureKey,applyFinder,deletePreset,importPreset,updateImport,setImportMode,startImport,guideStep,finishGuide,abortGuide,history,openBackups,restoreStartup,rebuildManaged,confirmAction,closeModal};
}}).mount('#app');
