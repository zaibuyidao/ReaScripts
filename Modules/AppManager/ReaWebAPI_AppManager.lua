-- @noindex
local r = reaper
for _, name in ipairs({'ReaWeb_Open','ReaWeb_Close','ReaWeb_IsOpen','ReaWeb_IsReady','ReaWeb_Send','ReaWeb_Receive'}) do
  if not r.APIExists(name) then
    r.MB('Requires ReaWebAPI v0.3.9.28 or later. Install the extension separately.', 'ReaWebAPI_AppManager', 0)
    return
  end
end
local source = debug.getinfo(1, 'S').source
local directory = source:sub(2):match('^(.*[/\\])')
local json = dofile(directory .. 'lua/json.lua')
local folders = dofile(directory .. 'lua/folders.lua')
local association = dofile(directory .. 'lua/association.lua')
local Registry = dofile(directory .. 'lua/registry.lua')
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
local registry, scanning, scan_notice
local outbox = {}
local function send(value) outbox[#outbox + 1] = json.encode(value) end
local function problem(key, diagnostic) send({type='error', key=key, diagnostic=diagnostic}) end
local function refresh(notice)
  registry = Registry.new(r, json, association.new(r,json))
  registry.begin()
  scanning, scan_notice, outbox = true, notice, {}
  send({type='loading'})
end
local function handle(message)
  if #message > 8192 then error('invalidRequest',0) end
  local req = json.decode(message)
  if type(req) ~= 'table' then error('invalidRequest',0) end
  if req.language and not set_language(req.language) then error('invalidRequest',0) end
  if req.action == 'language' then send({type='notice',key='saved'}); return end
  if req.action == 'ready' or req.action == 'refresh' then refresh(); return end
  if scanning then error('busy',0) end
  if not registry then error('stale',0) end
  local row, err = registry.validate(req.appId,req.token)
  if not row then error(err,0) end
  if req.action == 'remove' then
    if not row.removable then error('invalidBinding',0) end
    local warning = t('remove') .. '\n\nApp ID: ' .. row.appId .. '\nRoot: ' .. row.root
      .. '\n\n' .. t('removeFile') .. ':\n' .. row.registrationPath
      .. '\n\n' .. t('preserve') .. '\n\n' .. t('closeBeforeRemove') .. '\n\n' .. t('confirmQuestion')
    if r.MB(warning, 'ReaWebAPI — ' .. t('remove'), 4) ~= 6 then
      send({type='cancelled'}); return
    end
    local ok, failure = registry.remove(req.appId,req.token)
    if not ok then error(failure,0) end
    refresh('removed')
  elseif req.action == 'reveal' then
    local path, failure = registry.folder(req.appId,req.token,req.folder)
    if not path then error(failure,0) end
    if not folders.open(r,path) then error('folderOpenFailed',0) end
    send({type='notice',key='revealRequested'})
  else error('invalidRequest',0) end
end
local loop
local function step()
  if not r.ReaWeb_IsOpen(id) then return end
  -- One incoming command, one directory page and one outgoing message per defer.
  local message = r.ReaWeb_Receive(id)
  if message ~= '' then
    local ok, err = pcall(handle,message)
    if not ok then
      if locales.strings[err] then problem(err) else problem('invalidRequest',tostring(err)) end
    end
  end
  if #outbox == 0 and scanning then
    local ok, page, complete = pcall(registry.page)
    if not ok then scanning = false; problem('hostError',tostring(page))
    else
      send({type='page',data=page})
      scanning = not complete
      if complete and scan_notice then send({type='notice',key=scan_notice}); scan_notice = nil end
    end
  end
  if #outbox > 0 and r.ReaWeb_IsReady(id) and r.ReaWeb_Send(id,outbox[1]) then table.remove(outbox,1) end
  r.defer(loop)
end
loop = function()
  local ok, err = pcall(step)
  if not ok then r.MB(tostring(err), 'ReaWebAPI_AppManager', 0) end
end
loop()
