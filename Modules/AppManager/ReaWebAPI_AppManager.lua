-- @noindex
local r = reaper
if not r.APIExists('ReaWeb_AppManager') then
  r.MB('This manager requires a ReaWebAPI build with the ReaWeb_AppManager Lua interface.\nInstall the accompanying Runtime update, then restart REAPER.', 'ReaWebAPI_AppManager', 0)
  return
end
local source = debug.getinfo(1, 'S').source
local directory = source:sub(2):match('^(.*[/\\])')
local json = dofile(directory .. 'lua/json.lua')
local folders = dofile(directory .. 'lua/folders.lua')
local association = dofile(directory .. 'lua/association.lua')
local locale_file = assert(io.open(directory .. 'locales.json', 'rb'))
local locales = json.decode(locale_file:read('*a')); locale_file:close()
local language_index = 1
local function set_language(code)
  for index, item in ipairs(locales.languages) do
    if item.code == code then language_index = index; return true end
  end
  return false
end
local function t(key) return (locales.strings[key] or {})[language_index] or (locales.strings[key] or {})[1] or key end
local id = r.ReaWeb_Open(directory .. 'index.html', source)
if id == 0 then r.MB(r.ReaWeb_GetLastError(), 'ReaWebAPI_AppManager', 0); return end
local section = 'ReaWebAPI.AppManager'
if tonumber(r.GetExtState(section, source)) == id then return end
r.SetExtState(section, source, tostring(id), false)
r.atexit(function()
  r.ReaWeb_Close(id)
  if r.GetExtState(section, source) == tostring(id) then r.DeleteExtState(section, source, false) end
end)
local rows, scan, pending, outbox, scan_notice = {}, nil, nil, {}, nil
local classify
local function send(value) outbox[#outbox + 1] = json.encode(value) end
local function native(request) return json.decode(r.ReaWeb_AppManager(json.encode(request))) end
local function problem(key, diagnostic) send({ type='error', key=key, diagnostic=diagnostic }) end
local function failure(result)
  local err = result.error
  local code = type(err) == 'table' and err.code or nil
  local known = { APP_ID_CONFLICT=true, APP_REGISTRATION_CHANGED=true, PATH_UNAVAILABLE=true, BUSY=true, INVALID_ARGUMENT=true }
  send({type='error', key='hostError', code=code, diagnostic=not known[code] and (type(err)=='table' and err.message or tostring(err)) or nil})
end
local function refresh(notice)
  classify = association.new(r, json)
  rows = {}; outbox = {}; scan = { action='list', offset=0 }
  scan_notice = notice
  send({ type='loading' })
end
local function handle(message)
  if #message > 8192 then error('invalidRequest',0) end
  local req = json.decode(message)
  if type(req) ~= 'table' then error('invalidRequest',0) end
  if req.language and not set_language(req.language) then error('invalidRequest',0) end
  if req.action == 'language' then send({type='notice',key='saved'}); return end
  if req.action == 'ready' or req.action == 'refresh' then
    if pending then error('busy',0) end
    refresh(); return
  end
  if scan or pending then error('busy',0) end
  local row = rows[req.appId]
  if not row or row.token ~= req.token then error('stale',0) end
  if req.action == 'remove' then
    if not row.removable or row.activeWindowCount ~= 0 then error('closeWindows',0) end
    local warning = t('remove') .. '\n\nApp ID: ' .. row.appId .. '\nRoot: ' .. row.root
      .. '\n\n' .. t('removeFile') .. ':\n' .. row.registrationPath
      .. '\n\n' .. t('preserve') .. '\n\n' .. t('confirmQuestion')
    if r.MB(warning, 'ReaWebAPI — ' .. t('remove'), 4) ~= 6 then send({type='cancelled'}); return end
    local result = native({action='remove', appId=row.appId, token=row.token})
    if not result.ok then failure(result); return end
    refresh('removed')
  elseif req.action == 'reveal' then
    if req.folder ~= 'root' and req.folder ~= 'data' then error('invalidRequest',0) end
    local result = native({action='reveal', appId=row.appId, token=row.token, folder=req.folder})
    if not result.ok then
      if folders.open_legacy(r, result, row, req.folder) then send({type='notice',key='revealed'})
      else failure(result) end
      return
    end
    pending = r.time_precise()
  else error('invalidRequest',0) end
end
local loop
local function step()
  if not r.ReaWeb_IsOpen(id) then return end
  -- Bound work per defer: one input, one metadata page, and one output message.
  local message = r.ReaWeb_Receive(id)
  if message ~= '' then local ok, err = pcall(handle, message); if not ok then
    if locales.strings[err] then problem(err) else problem('invalidRequest',tostring(err)) end
  end end
  if #outbox == 0 and scan then
    local result = native(scan)
    if not result.ok then scan = nil; failure(result)
    else
      for _, row in ipairs(result.apps) do
        classify(row)
        if row.appId ~= json.null then rows[row.appId] = row end
      end
      send({type='page', data=result})
      scan = result.nextOffset ~= json.null and {action='list', offset=result.nextOffset, scanId=result.scanId} or nil
      if not scan and scan_notice then send({type='notice',key=scan_notice}); scan_notice = nil end
    end
  elseif #outbox == 0 and pending then
    local result = native({action='poll'})
    if not result.ok then pending = nil; failure(result)
    elseif not result.pending then pending = nil; send({type='notice',key='revealed'})
    elseif r.time_precise() - pending > 15 then pending = nil; problem('folderTimeout') end
  end
  if #outbox > 0 and r.ReaWeb_IsReady(id) then
    if r.ReaWeb_Send(id, outbox[1]) then table.remove(outbox, 1) end
  end
  r.defer(loop)
end
loop = function()
  local ok, err = pcall(step)
  if not ok then r.MB(tostring(err), 'ReaWebAPI_AppManager', 0) end
end
loop()
