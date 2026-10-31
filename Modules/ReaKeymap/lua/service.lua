-- @noindex
return function(reaper, E, JSON)
local S = E.state

local native_theme={available=false,colors={}}
local native_theme_signature=''

function read_native_theme()
  local colors={}
  local function add(key,native)
    if type(native)~='number' or native==-1 or not reaper.ColorFromNative then return end
    local ok,red,green,blue=pcall(reaper.ColorFromNative,native & 0xffffff)
    if ok and type(red)=='number' and type(green)=='number' and type(blue)=='number' then colors[key]=string.format('#%02x%02x%02x',red&255,green&255,blue&255) end
  end
  if reaper.GetThemeColor then
    for _,key in ipairs({'col_main_bg','col_main_text','col_main_bg2','col_main_text2','col_main_editbk','col_buttonbg','col_main_3dsh','genlist_bg','genlist_fg','genlist_selbg','genlist_selfg'}) do
      local ok,value=pcall(reaper.GetThemeColor,key,0)
      if ok and not (key=='col_buttonbg' and value==0) then add(key,value) end
    end
  end
  if reaper.GSC_mainwnd then
    local okFace,face=pcall(reaper.GSC_mainwnd,15)
    local okText,text=pcall(reaper.GSC_mainwnd,18)
    if okFace and okText and type(face)=='number' and type(text)=='number' and (face&0xffffff)~=(text&0xffffff) then add('buttonface',face);add('buttontext',text) end
  end
  local dark=false
  if reaper.IsDarkMode then local ok,value=pcall(reaper.IsDarkMode);dark=ok and value==true end
  if reaper.GSC_mainwnd then
    for key,id in pairs({window=5,windowtext=8,buttonshadow=16}) do
      local ok,value=pcall(reaper.GSC_mainwnd,id);if ok then add(key,value) end
    end
  end
  local pieces={tostring(dark)};for key,value in pairs(colors) do pieces[#pieces+1]=key..value end;table.sort(pieces)
  local signature=table.concat(pieces,'|')
  if signature==native_theme_signature then return nil end
  native_theme_signature=signature;native_theme={available=next(colors)~=nil,colors=colors,dark=dark}
  return native_theme
end
read_native_theme()

local function check(value, message) if not value then error(message, 0) end return value end
local function native_actions_available()
  for _,name in ipairs({'PromptForAction','JS_Window_ListFind','JS_Window_HandleFromAddress','JS_Window_GetParent','JS_Window_FindChildByID','JS_Window_OnCommand','JS_ListView_ListAllSelItems','JS_ListView_GetItemText','JS_Window_Enable','JS_Window_IsWindow'}) do
    if type(reaper[name])~='function' then return false end
  end
  return true
end

function owned_action_window()
  local title=reaper.JS_Localize and reaper.JS_Localize('Actions','common') or 'Actions'
  local _,addresses=reaper.JS_Window_ListFind(title,true)
  for address in tostring(addresses or ''):gmatch('[^,]+') do
    local hex=address:match('^%s*0[xX](%x+)') or address:match('^%s*(%x+)')
    local candidate=hex and reaper.JS_Window_HandleFromAddress(tonumber(hex,16))
    local owner=candidate
    for _=1,24 do
      if not owner then break end
      owner=reaper.JS_Window_GetParent(owner)
      if owner==reaper.GetMainHwnd() then
        if reaper.JS_Window_FindChildByID(candidate,1323) and reaper.JS_Window_FindChildByID(candidate,1317) then return candidate end
        break
      end
      if not owner then break end
    end
  end
end

function cancel_native()
  local pending=S.native_pending
  S.native_pending=nil
  if pending and pending.window and reaper.JS_Window_IsWindow(pending.window) then reaper.JS_Window_Enable(pending.window,true) end
  if S.action_prompt_active then reaper.PromptForAction(-1,0,0);S.action_prompt_active=false end
end

function native_action(a,pending)
  local window=pending.window
  check(reaper.JS_Window_IsWindow(window) and owned_action_window()==window,'无法定位当前 REAPER 的操作列表窗口。')
  local list=reaper.JS_Window_FindChildByID(window,1323)
  local count,indices=reaper.JS_ListView_ListAllSelItems(list)
  local index=tonumber(indices)
  check(count==1 and index,'原生操作列表的所选命令不匹配，已停止操作。')
  -- PromptForAction selects the exact section/command ID. The dialog remains
  -- disabled from preparation through this check so the target cannot change
  -- while REAPER asynchronously populates the selection and its display text.
  check(reaper.JS_ListView_GetItemText(list,index,1)==a.name,'原生操作列表的所选命令不匹配，已停止操作。')
  cancel_native()
  -- REAPER 7 action-dialog resource 345: edit=5, delete=4, duplicate=7.
  check(reaper.JS_Window_OnCommand(window,pending.command)~=false,'无法执行原生操作列表命令。')
  return true
end

function all_ids()
  local ids = {}
  for _, section in ipairs(E.sections()) do if section.visible and section.handle then ids[#ids + 1] = section.id end end
  return ids
end

function refresh_ids(ids) for _, id in ipairs(ids) do E.refresh(id, true) end end

function action_for(key, fresh)
  check(type(key) == 'string', '缺少命令标识。')
  local id = tonumber(key:match('^(%-?%d+):'))
  check(id and E.section(id) and E.section(id).handle, '此操作区段不可用。')
  local cache = fresh and E.refresh(id, true) or E.cache(id)
  return check(cache and cache.by_key[key], '命令已经不存在，请刷新列表。')
end

function pack(a)
  return {key=a.key, name=a.name, section_id=a.section_id, section_name=a.section_name,
    id_text=a.id_text, type=a.type, shortcuts=a.shortcuts, note=a.note,
    script_path=a.script_path, script_directory=a.script_directory, conflict=a.has_conflict == true, managed=E.user_data.managed[a.key] == true}
end

function check_binding(a, expected)
  check(type(expected) == 'table' and JSON.encode(expected, false) == JSON.encode(a.shortcuts, false),
    '快捷键已被外部修改。请刷新详情后重试，避免操作错误的绑定。')
end

function plan_summary(p)
  local missing = {}
  for i, record in ipairs(p.unmatched) do if i <= 30 then missing[#missing+1] = record.command_name or record.named_command_id or tostring(record.command_id) end end
  return {matched=#p.matched, unmatched=#p.unmatched, missing=missing, additions=#p.additions,
    deletions=p.deletion_count, conflicts=p.conflict_count, sections=p.affected_section_ids,
    mode=p.mode, full=p.full_sections, total=p.shortcut_count}
end

function guide_info()
  local g = S.guide
  if not g then return nil end
  local step = g.plan.additions[g.index]
  local a = step and E.find(step.identity)
  local conflicts = {}
  if a then
    for _, candidate in ipairs(E.cache(a.section_id).actions) do
      if candidate.key ~= a.key and E.has_shortcut(candidate, step.shortcut) then conflicts[#conflicts+1] = candidate.name end
    end
  end
  return {label=g.label, index=g.index, total=#g.plan.additions, applied=g.applied, skipped=g.skipped,
    shortcut=step and step.shortcut, action=a and pack(a), error=g.last_error,
    backup=g.backup_path, plan=plan_summary(g.plan), conflicts=conflicts}
end


S.list_data_epoch = S.list_data_epoch or 0
local catalog_version, catalog_fingerprint = 0, ''
local managed_counts = setmetatable({}, {__mode='k'})

function catalog_revision()
  local parts={tostring(S.list_data_epoch),tostring(E.user_data.managed),tostring(E.user_data.notes)}
  for _,section in ipairs(E.sections()) do
    if section.visible then parts[#parts+1]=tostring(section.id)..':'..tostring(S.caches[section.id]) end
  end
  local current=table.concat(parts,'|')
  if current~=catalog_fingerprint then catalog_fingerprint=current;catalog_version=catalog_version+1 end
  return catalog_version
end

function meta()
  local sections, total, bound, managed, conflicts = {}, 0, 0, 0, 0
  for _, s in ipairs(E.sections()) do
    if s.visible then
    local c = S.caches[s.id]
    local managed_count = 0
    if c then
      local cached=managed_counts[c]
      if not cached or cached.epoch~=S.list_data_epoch or cached.source~=E.user_data.managed then
        for _,a in ipairs(c.actions) do if E.user_data.managed[a.key] then managed_count=managed_count+1 end end
        managed_counts[c]={epoch=S.list_data_epoch,source=E.user_data.managed,count=managed_count}
      else managed_count=cached.count end
    end
    managed = managed + managed_count
    sections[#sections+1] = {id=s.id,name=s.name,available=s.handle ~= nil,custom=s.custom,
      managed=managed_count,count=c and #c.actions or 0,bound=c and c.bound_count or 0,conflicts=c and c.conflict_count or 0}
    total = total + (c and #c.actions or 0)
    bound = bound + (c and c.bound_count or 0)
    conflicts = conflicts + (c and c.conflict_count or 0)
    end
  end
  return {catalog_revision=catalog_revision(),version='0.1.0',sections=sections,total=total,bound=bound,managed=managed,conflicts=conflicts,
    loading=not S.startup_capture_complete or S.overview_refresh_index ~= nil,
    status=S.status,status_kind=S.status_kind,undo=S.history_cursor>0,redo=S.history_cursor<#S.history,
    presets=S.presets,backups=S.backups,settings=E.settings,paths=E.paths,reaper_theme=native_theme,capabilities={native_actions=native_actions_available()},
    guide=guide_info(),result=S.guide_result}
end

local handlers = {}
function handlers.init() return true end

function handlers.catalog(p)
  local revision=catalog_revision()
  if p.revision~=nil and p.revision~=revision then return {reset=true,revision=revision} end
  local offset=tonumber(p.offset) or 0
  local limit=tonumber(p.limit) or 512
  check(offset>=0 and offset%1==0,'无效的命令读取位置。')
  check(limit>=1 and limit<=750 and limit%1==0,'命令读取批次必须为 1 至 750。')
  local rows,total,skip,bytes={},0,offset,0
  for _,section in ipairs(E.sections()) do
    if section.visible and section.handle then
      local cache=S.caches[section.id]
      local actions=cache and cache.actions or {}
      total=total+#actions
      if skip>=#actions then skip=skip-#actions
      else
        for i=skip+1,math.min(#actions,skip+limit-#rows) do
          if bytes>=192*1024 then break end
          local a=actions[i]
          rows[#rows+1]=pack(a)
          bytes=bytes+192+2*(#a.name+#a.id_text+#a.script_path+#a.note+#a.shortcut_text+#a.section_name)
        end
        skip=0
      end
    end
  end
  return {rows=rows,total=total,offset=offset,next_offset=offset+#rows,done=offset+#rows>=total,revision=revision}
end

function handlers.query(p)
  local result = {}
  local scope
  if p.section == nil and p.sections ~= nil then
    check(type(p.sections)=='table','显示区段格式无效。')
    scope={}
    for _,id in ipairs(p.sections) do
      check(type(id)=='number' and id%1==0,'显示区段 ID 无效。')
      scope[id]=true
    end
  end
  local terms = {}
  for term in tostring(p.search or ''):lower():gmatch('%S+') do terms[#terms+1]=term end
  local canonical = p.shortcut and E.canonical(p.shortcut)
  local selected = {}; for _, k in ipairs(p.selected or {}) do selected[k]=true end
  for _, section in ipairs(E.sections()) do
    if section.visible and section.handle and (p.section == nil or tonumber(p.section) == section.id) and (not scope or scope[section.id]) then
      local cache = S.caches[section.id]
      for _, a in ipairs(cache and cache.actions or {}) do
        local matches = (not p.type or p.type == 'all' or p.type == a.type)
        if p.view == 'managed' then matches = matches and E.user_data.managed[a.key] end
        if p.view == 'bound' then matches = matches and #a.shortcuts>0 end
        if p.view == 'unbound' then matches = matches and #a.shortcuts==0 end
        if p.view == 'conflicts' then matches = matches and a.has_conflict end
        if p.notes then matches = matches and a.note~='' end
        if p.selected_only then matches = matches and selected[a.key] end
        if matches and #terms>0 then
          local text=table.concat({a.name,a.id_text,a.script_path,a.note,a.shortcut_text,a.section_name}, '\n'):lower()
          for _,term in ipairs(terms) do if not text:find(term,1,true) then matches=false;break end end
        end
        if canonical then
          local found = false
          for _, shortcut in ipairs(a.shortcuts) do if E.canonical(shortcut)==canonical then found=true end end
          matches = matches and found
        end
        if matches then result[#result+1]=a end
      end
    end
  end
  local field = ({name='name',shortcut='shortcut_text',id='id_text',path='script_directory',note='note',section='section_name'})[p.sort] or 'name'
  table.sort(result,function(a,b)
    local order = E.compare(a[field], b[field])
    if order==0 then order=E.compare(a.key,b.key) end
    if p.desc then return order>0 end
    return order<0
  end)
  local rows = {}
  for _, action in ipairs(result) do rows[#rows+1]=pack(action) end
  return {rows=rows,total=#result}
end

function handlers.detail(p) return pack(action_for(p.key, true)) end
local native_token=0
local function prepare_native(a,command)
  check(native_actions_available(),'此功能需要 js_ReaScriptAPI 扩展。')
  if S.action_prompt_active then reaper.PromptForAction(-1,0,0) end
  reaper.PromptForAction(1,a.command_id,a.section_id);S.action_prompt_active=true
  native_token=native_token+1
  local window=owned_action_window()
  if not window then cancel_native();error('无法定位当前 REAPER 的操作列表窗口。',0) end
  S.native_pending={token=native_token,key=a.key,id=a.command_id,command=command,window=window,started=reaper.time_precise()}
  reaper.JS_Window_Enable(window,false)
  return {native_pending=native_token}
end

function handlers.run_action(p)
  local a=action_for(p.key,true)
  if a.section_id==0 or a.section_id==100 or a.section_id>=1 and a.section_id<=16 then
    check(reaper.Main_OnCommand,'当前 REAPER 不支持运行主区段命令。')(a.command_id,0)
  elseif a.section_id==32060 or a.section_id==32061 then
    check(reaper.MIDIEditor_LastFocused_OnCommand and reaper.MIDIEditor_LastFocused_OnCommand(a.command_id,a.section_id==32061),'请先打开对应的 MIDI 编辑器。')
  else
    return prepare_native(a,13)
  end
  return true
end

function handlers.action_operation(p)
  local a=action_for(p.key,true)
  local command=({edit=5,delete=4,duplicate=7})[p.operation]
  check(command,'不支持的命令操作。')
  check(a.type=='script' or a.type=='custom','只能编辑或删除自定义操作和 ReaScript。')
  check(p.operation~='duplicate' or a.type=='custom','只有自定义操作可以复制。')
  return prepare_native(a,command)
end

function handlers.native_continue(p)
  local pending=check(S.native_pending and S.native_pending.token==p.token and S.native_pending,'原生操作请求已失效。')
  local ok,result=pcall(function()
    local a=action_for(pending.key,true)
    check(a.command_id==pending.id,'原生操作列表的所选命令不匹配，已停止操作。')
    native_action(a,pending)
    local cache=E.refresh(a.section_id,true)
    E.refresh_all();E.reload_files()
    return {deleted=pending.command==4 and cache.by_key[a.key]==nil}
  end)
  cancel_native()
  if not ok then error(result,0) end
  return result
end

function handlers.refresh() E.refresh_all() E.reload_files() return true end

function handlers.note(p)
  local a=action_for(p.key,true)
  check(type(p.note)=='string' and #p.note<=65536,'备注过长。')
  check(a.note == p.expected, '备注已发生变化，请刷新详情后再保存。')
  local before=E.record(a,true)
  check(E.save_note(E.identity(a),p.note), S.status)
  if before.note~=a.note then E.history('编辑备注',{before},{E.record(a,true)},false) end
  return pack(a)
end

function handlers.manage(p)
  check(type(p.keys)=='table','缺少选择项。')
  local list={}; for _,key in ipairs(p.keys) do list[#list+1]=action_for(key) end
  local previous={}; for _,a in ipairs(list) do previous[a.key]=E.user_data.managed[a.key] or false; E.user_data.managed[a.key]=p.managed==true or nil end
  local ok,err=E.save_user_data()
  if not ok then for key,value in pairs(previous) do E.user_data.managed[key]=value or nil end end
  check(ok,'管理列表保存失败：'..tostring(err))
  E.status('管理列表已更新。','success') return true
end

function handlers.shortcut(p)
  local a=action_for(p.key,true); check_binding(a,p.expected)
  local index=tonumber(p.index)
  check(index and index%1==0 and index>=-1 and index<#a.shortcuts,'快捷键序号无效。')
  local backup,err=E.backup({a.section_id},'修改快捷键前备份'); check(backup,err)
  E.edit_shortcut(E.identity(a),index,index==-1 and '新增快捷键' or '修改快捷键')
  E.reload_files(); return pack(action_for(p.key))
end

function handlers.delete(p)
  local a=action_for(p.key,true); check_binding(a,p.expected)
  local indices={}
  for _,i in ipairs(p.indices or {}) do check(type(i)=='number' and i%1==0 and i>=0 and i<#a.shortcuts,'快捷键序号无效。'); indices[i]=true end
  check(next(indices),'请先选择快捷键。')
  local backup,err=E.backup({a.section_id},'删除快捷键前备份'); check(backup,err)
  E.delete_shortcuts(E.identity(a),indices); E.reload_files(); return pack(action_for(p.key))
end

function handlers.batch_delete(p)
  check(type(p.items)=='table' and #p.items>0,'请先选择命令。')
  local identities={}; local ids={}
  for _,item in ipairs(p.items) do local a=action_for(item.key,true); check_binding(a,item.expected); identities[#identities+1]=E.identity(a); ids[a.section_id]=true end
  E.batch_delete(identities); check(S.batch_delete==nil,S.status); E.reload_files(); return true
end

function handlers.delete_preset(p)
  local ok,err=E.delete_preset(p.path);check(ok,err)
  E.status('预设已删除。','success');return true
end

function handlers.export(p)
  local ids=p.scope=='current' and {check(tonumber(p.section),'请选择一个区段。')} or all_ids()
  refresh_ids(ids)
  S.selected={}; for _,key in ipairs(p.keys or {}) do S.selected[key]=true end
  check(p.scope~='selected' or next(S.selected),'没有选中的命令。')
  local records=E.collect(ids,p.unbound==true,p.notes~=false,p.scope=='selected')
  local name=tostring(p.name or ''):sub(1,180); check(name:find('%S'),'请填写预设名称。')
  local path=E.output_path(E.paths.presets,name)
  local doc=E.document(name,records,p.scope,p.scope~='selected' and ids or {})
  local ok,err=E.write_preset(path,doc); check(ok,err); E.reload_files()
  E.status('预设已保存：'..path,'success'); return {path=path,count=#records}
end

local function preview() local p=S.import_preview; return p and {name=p.document.preset_name,path=p.path,plan=plan_summary(p.plan)} end
function handlers.import(p)
  refresh_ids(all_ids())
  S.import_preview=nil
  if p.path then
    local allowed=false
    E.reload_files()
    for _,list in ipairs({S.presets,S.backups}) do for _,f in ipairs(list) do if f.path==p.path then allowed=true end end end
    check(allowed,'预设不在已加载的文件列表中。')
    check(E.prepare_import(p.path),S.status)
  else E.import_dialog() end
  return preview()
end

function handlers.import_options(p)
  check(S.import_preview,'没有待导入预设。')
  S.import_preview.mode=p.mode=='overwrite' and 'overwrite' or 'merge'
  S.import_preview.full_sections=p.full==true and p.mode=='overwrite'
  E.replan(); return preview()
end

function handlers.import_start()
  local p=check(S.import_preview,'没有待导入预设。')
  local previous=JSON.encode({scope=E.capture(p.plan),summary=plan_summary(p.plan)},false)
  refresh_ids(all_ids()); E.replan()
  check(JSON.encode({scope=E.capture(p.plan),summary=plan_summary(p.plan)},false)==previous,'快捷键状态已变化，请重新检查导入预览。')
  check(not p.plan.full_sections or #p.plan.unmatched==0,'完整区段覆盖包含无法匹配的命令，请先解决缺失命令或关闭完整区段覆盖。')
  check(E.start_guide(p.plan,'导入 '..(p.document.preset_name or '预设')),S.status)
  S.import_preview=nil; E.reload_files(); E.advance_guide(); return guide_info()
end

function handlers.guide_step(p)
  local g=check(S.guide,'没有正在进行的恢复任务。')
  local step=check(g.plan.additions[g.index],'新增阶段已经结束。')
  if p.skip then g.skipped=g.skipped+1; g.index=g.index+1; g.last_error=nil
  else
    local a=check(E.find(step.identity),'目标命令不存在。')
    reaper.DoActionShortcutDialog(reaper.GetMainHwnd(),E.section(a.section_id).handle,a.command_id,-1)
    E.refresh(a.section_id,true); E.sync_signature()
    if E.has_shortcut(E.find(step.identity),step.shortcut) then g.applied=g.applied+1; g.index=g.index+1; g.last_error=nil
    else g.last_error='未检测到预期快捷键，请重试或跳过。' end
  end
  E.advance_guide(); return guide_info()
end

function handlers.guide_finish()
  local g=check(S.guide,'没有正在进行的恢复任务。')
  check(g.index>#g.plan.additions,'仍有待处理的快捷键。')
  if g.plan.mode=='overwrite' then
    refresh_ids(g.plan.affected_section_ids)
    for _,desired in ipairs(g.plan.matched) do
      local a=E.find(desired.identity)
      check(a,'目标命令已失效，停止覆盖清理。')
      for _,shortcut in ipairs(desired.shortcut_list) do check(E.has_shortcut(a,shortcut),'存在未完成的快捷键，已阻止覆盖清理。请中止并从备份恢复，或重新导入。') end
    end
  end
  E.finish_guide(); E.reload_files(); return S.guide_result
end

function handlers.guide_abort()
  local g=check(S.guide,'没有正在进行的恢复任务。')
  -- An aborted history restore must invalidate redo; record its actual partial state.
  refresh_ids(g.plan.affected_section_ids)
  E.history('中止 '..g.label,g.before_records,E.collect(g.plan.affected_section_ids,true,true,false),true,g.plan.affected_section_ids)
  S.guide=nil; E.status('任务已中止。已完成的变更保留，可使用自动备份恢复。','warning'); return true
end

function handlers.history(p)
  refresh_ids(all_ids()); E.restore_history(p.redo==true); E.advance_guide(); E.reload_files(); return guide_info()
end

function handlers.restore_startup()
  check(S.startup_capture_complete,'启动快照尚未完成。')
  refresh_ids(all_ids())
  check(E.start_guide(E.plan(S.startup_snapshot,'overwrite',true,S.startup_section_ids),'恢复启动状态'),S.status)
  E.advance_guide(); E.reload_files(); return guide_info()
end

function handlers.settings(p)
  check(p.theme==nil or ({reaper=true,modern=true,retro=true,serious=true,cyber=true,warm=true,cold=true,anime=true,forest=true,mono=true,midnight=true,custom=true})[p.theme],'不支持的配色。')
  for _,key in ipairs({'colorBackground','colorPanel','colorText','colorAccent','colorBorder'}) do check(p[key]==nil or type(p[key])=='string' and p[key]:match('^#%x%x%x%x%x%x$'),'配色值无效。') end
  check(p.language==nil or ({en=true,['zh-CN']=true,['zh-TW']=true,ja=true,ko=true})[p.language], '不支持的界面语言。')
  local fields={'theme','colorBackground','colorPanel','colorText','colorAccent','colorBorder','language','auto_refresh','auto_refresh_interval','managed_init_from_bound','keep_detail_open','show_row_checkboxes','show_alt_recording','show_alt_sections'}
  local previous={}; for _,key in ipairs(fields) do previous[key]=E.settings[key] end
  for _,key in ipairs({'theme','colorBackground','colorPanel','colorText','colorAccent','colorBorder'}) do if p[key]~=nil then E.settings[key]=p[key] end end
  if p.language~=nil then E.settings.language=p.language end
  if p.auto_refresh~=nil then E.settings.auto_refresh=p.auto_refresh==true end
  if p.interval then E.settings.auto_refresh_interval=math.max(2,math.min(60,tonumber(p.interval) or 5)) end
  if p.initialize~=nil then E.settings.managed_init_from_bound=p.initialize==true end
  if p.show_row_checkboxes~=nil then E.settings.show_row_checkboxes=p.show_row_checkboxes==true end
  if p.keep_detail_open~=nil then E.settings.keep_detail_open=p.keep_detail_open==true end
  if p.show_alt_recording~=nil then E.settings.show_alt_recording=p.show_alt_recording==true end
  if p.show_alt_sections~=nil then E.settings.show_alt_sections=p.show_alt_sections==true end
  local ok=E.save_settings()
  if not ok then for _,key in ipairs(fields) do E.settings[key]=previous[key] end end
  check(ok,'设置保存失败。')
  if E.settings.show_alt_recording~=previous.show_alt_recording or E.settings.show_alt_sections~=previous.show_alt_sections then
    E.rebuild_sections()
  end
  return true
end

function handlers.custom_section(p)
  local id=tonumber(p.id); check(id and id%1==0 and id>=0,'区段 ID 必须是非负整数。')
  if p.remove then
    check(E.section(id) and E.section(id).custom,'只能移除自定义区段。')
    for i=#E.settings.custom_sections,1,-1 do if tonumber(E.settings.custom_sections[i].id)==id then table.remove(E.settings.custom_sections,i) end end
    S.caches[id]=nil
  else
    check(not E.section(id),'此区段已存在。'); check(reaper.SectionFromUniqueID(id),'REAPER 中不存在此区段。')
    E.settings.custom_sections[#E.settings.custom_sections+1]={id=id,name=tostring(p.name or ''):sub(1,120)}
  end
  E.rebuild_sections(); check(E.save_settings(),'设置保存失败。'); E.refresh_all(); return true
end

function handlers.rebuild_managed(p) return E.rebuild_managed(p.clear==true,p.bound~=false) end
function handlers.locate(p)
  local a=action_for(p.key)
  if reaper.PromptForAction then
    if S.action_prompt_active then reaper.PromptForAction(-1,0,0) end
    reaper.PromptForAction(1,a.command_id,a.section_id); S.action_prompt_active=true
  else reaper.ShowActionList(E.section(a.section_id).handle,reaper.GetMainHwnd()) end
  return true
end

function handlers.folder(p)
  local path=check(E.paths[p.kind],'未知目录。')
  if reaper.CF_ShellExecute then reaper.CF_ShellExecute(path)
  elseif reaper.GetOS():match('Win') then reaper.ExecProcess('explorer.exe "'..path:gsub('"','')..'"',-1)
  else error('请复制目录路径后在文件管理器中打开。',0) end
  return path
end

local readonly={init=true,catalog=true,query=true,detail=true,guide_step=true,guide_finish=true,guide_abort=true,folder=true}
local fingerprint=''
return {
  theme_event=read_native_theme,
  cancel_native=cancel_native,
  dispatch=function(method,p)
    check(type(method)=='string' and handlers[method],'未知请求。')
    check(type(p)=='table','请求参数必须是对象。')
    check(not S.native_pending or method=='native_continue' or method=='init' or method=='catalog' or method=='detail' or method=='query','原生操作正在处理中。')
    check(not S.guide or readonly[method],'请先完成或中止当前恢复任务。')
    check(S.startup_capture_complete or method=='init' or method=='catalog' or method=='query' or method=='detail','正在记录启动状态，请稍候。')
    local value=handlers[method](p)
    local visual_only=method=='settings'
    for key in pairs(p) do if not ({language=true,theme=true,colorBackground=true,colorPanel=true,colorText=true,colorAccent=true,colorBorder=true})[key] then visual_only=false end end
    if not ({init=true,catalog=true,query=true,detail=true,folder=true,delete_preset=true,run_action=true,action_operation=true,refresh=true})[method] and not visual_only then S.list_data_epoch=S.list_data_epoch+1 end
    return {value=value,meta=meta()}
  end,
  event=function()
    if S.native_pending and reaper.time_precise()-S.native_pending.started>5 then cancel_native() end
    local pieces={S.status,tostring(S.startup_capture_complete),tostring(S.overview_refresh_index)}
    for _,s in ipairs(E.sections()) do pieces[#pieces+1]=tostring(S.caches[s.id] and S.caches[s.id].scanned_at) end
    local current=table.concat(pieces,'|')
    if current~=fingerprint then fingerprint=current; return true end
    return false
  end,
}
end
