-- @noindex
local root = debug.getinfo(1, 'S').source:sub(2):match('^(.*[/\\])')
local required = {'ReaWeb_Open', 'ReaWeb_Send', 'ReaWeb_Receive', 'ReaWeb_IsOpen',
  'ReaWeb_IsReady', 'ReaWeb_Close', 'SectionFromUniqueID', 'kbd_enumerateActions',
  'CountActionShortcuts', 'GetActionShortcutDesc', 'DeleteActionShortcut', 'DoActionShortcutDialog'}

for _, name in ipairs(required) do
  if not reaper.APIExists(name) then
    reaper.MB('缺少 API：' .. name .. '\n请安装支持 Lua 消息桥的 ReaWebAPI，并更新 REAPER。', 'ReaKeymap 0.1.0', 0)
    return
  end
end

local JSON = assert(loadfile(root .. 'lua/json.lua'))()
local key = debug.getinfo(1, 'S').source
local id = reaper.ReaWeb_Open(root .. 'web/index.html', key)

if not id or id == 0 then
  reaper.MB(reaper.ReaWeb_GetLastError(), 'ReaKeymap', 0)

  return
end

if reaper.GetExtState('ReaKeymap.Backends', key) == tostring(id) then return end
reaper.SetExtState('ReaKeymap.Backends', key, tostring(id), false)

local engine, service

reaper.atexit(function()
  if service then service.cancel_native() end

  if engine then
    if engine.state.action_prompt_active and reaper.PromptForAction then pcall(reaper.PromptForAction, -1, 0, 0) end
    engine.save_settings()
  end

  reaper.ReaWeb_Close(id)
  if reaper.GetExtState('ReaKeymap.Backends', key) == tostring(id) then
    reaper.DeleteExtState('ReaKeymap.Backends', key, false)
  end
end)

local ok, err = xpcall(function()
  engine = assert(loadfile(root .. 'lua/engine.lua'))()(reaper, JSON)
  service = assert(loadfile(root .. 'lua/service.lua'))()(reaper, engine, JSON)
end, debug.traceback)

if not ok then reaper.MB(err, 'ReaKeymap 初始化失败', 0) return end

local queue, ready, next_poll = {}, false, 0

function enqueue_response(response)
  local encoded = JSON.encode(response, false)
  local chunk_bytes = 128 * 1024

  if #encoded <= chunk_bytes then queue[#queue+1] = encoded; return end

  local chunks, first = {}, 1

  while first <= #encoded do
    local last = math.min(first + chunk_bytes - 1, #encoded)
    while last < #encoded and encoded:byte(last+1) >= 128 and encoded:byte(last+1) < 192 do last = last - 1 end
    chunks[#chunks+1] = encoded:sub(first,last)
    first = last + 1
  end

  for part, data in ipairs(chunks) do
    queue[#queue+1] = JSON.encode({type='chunk',id=response.id,part=part,total=#chunks,data=data},false)
  end
end

function loop()
  if not reaper.ReaWeb_IsOpen(id) then return end
  local success, failure = xpcall(function()
    engine.tick()

    for _ = 1, 8 do
      local raw = reaper.ReaWeb_Receive(id)
      if not raw or raw == '' then break end

      if #raw <= 1048576 then
        local request = JSON.decode(raw)
        if type(request) == 'table' and type(request.id) == 'number' then
          ready = true
          local worked, result = pcall(service.dispatch, request.method, request.params or {})
          enqueue_response({type = 'response', id = request.id,
            ok = worked, result = worked and result or nil, error = not worked and tostring(result) or nil})
        end
      end
    end

    if reaper.ReaWeb_IsReady(id) then
      for _ = 1, 8 do
        if not queue[1] or not reaper.ReaWeb_Send(id, queue[1]) then break end
        table.remove(queue, 1)
      end

      local now = reaper.time_precise()

      if ready and now >= next_poll and #queue == 0 then
        local theme = service.theme_event()
        if theme then enqueue_response({type='theme',theme=theme}) end
        local event = service.event()
        if event then reaper.ReaWeb_Send(id, JSON.encode({type = 'changed'}, false)) end
        next_poll = now + 0.5
      end

    end
  end, debug.traceback)

  if not success then
    reaper.ShowConsoleMsg('[ReaKeymap] ' .. tostring(failure) .. '\n')
    reaper.MB('运行出错，详情已写入 REAPER 控制台。\n' .. tostring(failure), 'ReaKeymap', 0)
  
    return
  end

  reaper.defer(loop)
end

loop()
