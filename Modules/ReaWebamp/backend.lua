-- @noindex
local M = {}

function encode(value)
  local kind = type(value)
  if kind == 'nil' then return 'null' end
  if kind == 'boolean' then return value and 'true' or 'false' end
  
  if kind == 'number' then
    assert(value == value and math.abs(value) < math.huge, 'Invalid number')
    return string.format('%.17g', value):gsub(',', '.')
  end

  if kind == 'string' then
    return '"' .. value:gsub('.', function(c)
      local n = c:byte()
  
      if c == '"' or n == 92 then
        return string.char(92) .. c
      end
  
      if n < 32 then
        return string.char(92) .. string.format('u%04x', n)
      end
  
      return c
    end) .. '"'
  end

  local out = {}

  if getmetatable(value) == M.array or #value>0 then
    for _, v in ipairs(value) do
      out[#out+1] = encode(v)
    end

    return '[' .. table.concat(out, ',') .. ']'
  end

  for k, v in pairs(value) do
    out[#out+1] = encode(k) .. ':' .. encode(v)
  end

  return '{'..table.concat(out,',')..'}'
end

M.array = {}

function array()
  return setmetatable({}, M.array)
end

local projectTokens=setmetatable({}, {__mode="k"})

function project()
  local p, path = reaper.EnumProjects(-1, '')
  projectTokens[p] = projectTokens[p] or reaper.genGuid()

  return p, {
    token = projectTokens[p],
    guid = reaper.GetTrackGUID(reaper.GetMasterTrack(p)),
    path = path,
    length = reaper.GetProjectLength(p),
    state = reaper.GetPlayStateEx(p),
    position = reaper.GetPlayPositionEx(p),
    cursor = reaper.GetCursorPositionEx(p),
    revision = reaper.GetProjectStateChangeCount(p)
  }
end

function guard(guid, stopped)
  local p, state = project()
  assert(state.token==guid, '工程已切换，请刷新后重试。')
  assert(state.state&4==0, '录音中，已拒绝控制或渲染操作。')
  assert(not reaper.GetCurrentProjectInLoadSave(), '工程正在加载、保存或渲染。')

  if stopped then
    assert(state.state == 0,'请先停止 REAPER 播放再生成预览。')
  end

  return p, state
end

function collect(scope,regionId)
  local p, state=project()
  local rows = array()
  local items = {}
  local range

  if scope == 'item' then
    for i = 0, reaper.CountSelectedMediaItems(p) - 1 do
      items[#items+1] = reaper.GetSelectedMediaItem(p, i)
    end
  elseif scope == 'track' then
    for i = 0, reaper.CountSelectedTracks(p) - 1 do
      local t = reaper.GetSelectedTrack(p, i)
      for j = 0, reaper.CountTrackMediaItems(t) - 1 do
        items[#items+1] = reaper.GetTrackMediaItem(t, j)
      end
    end
  elseif scope == 'region' then
    local i = 0

    while true do
      local ok, isrgn, a, b, name, id = reaper.EnumProjectMarkers3(p, i)

      if ok == 0 then
        break
      end

      if isrgn and id == tonumber(regionId) then
        range = {
          start = a,
          finish = b,
          name = name,
          id = id
        }
        break
      end

      i = i + 1
    end

    assert(range, '区域不存在，请刷新。')

    for i = 0, reaper.CountMediaItems(p) - 1 do
      local item = reaper.GetMediaItem(p, i)
      local a = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
      local b = a + reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')

      if a < range.finish and b > range.start then
        items[#items + 1] = item
      end
    end

  else
    error('Unknown selection scope')
  end

  assert(#items <= 256, '一次最多收集 256 个 Item。')

  for _, item in ipairs(items) do
    local _, guid = reaper.GetSetMediaItemInfo_String(item, 'GUID', '', false)
    local take = reaper.GetActiveTake(item)

    local row = {
      itemGuid = guid,
      projectGuid = state.guid,
      projectPath = state.path,
      revision = state.revision,
      position = reaper.GetMediaItemInfo_Value(item, 'D_POSITION'),
      length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    }

    local track = reaper.GetMediaItem_Track(item)
    row.trackGuid = reaper.GetTrackGUID(track)
    row.trackNumber = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')

    if not take then
      row.error = 'Item 没有活动 Take'
    elseif reaper.TakeIsMIDI(take) then
      row.error = 'MIDI Take 需要渲染预览'
    else
      local _, takeGuid = reaper.GetSetMediaItemTakeInfo_String(take, 'GUID', '', false)
      row.takeGuid = takeGuid
      row.name = reaper.GetTakeName(take)

      local source = reaper.GetMediaItemTake_Source(take)
      local depth = 0

      while source and depth < 16 do
        local parent = reaper.GetMediaSourceParent(source)

        if not parent then
          break
        end

        source = parent
        depth = depth + 1
      end

      row.path = source and reaper.GetMediaSourceFileName(source, '') or ''

      if row.path == '' then
        row.error = '媒体来源不是可访问的音频文件'
      end
    end

    rows[#rows + 1] = row
  end

  table.sort(rows, function(a, b)
    if a.position ~= b.position then
      return a.position < b.position
    end

    if a.trackNumber ~= b.trackNumber then
      return a.trackNumber < b.trackNumber
    end

    return a.itemGuid < b.itemGuid
  end)

  return {
    project = state,
    items = rows,
    range = range
  }
end

function M.attach(id,directory)
  local instance = 'ReaWebamp.Backend.' .. tostring(id)

  if reaper.GetExtState('ReaWebamp', instance) == 'running' then
    return
  end

  reaper.SetExtState('ReaWebamp', instance, 'running', false)

  local dataRoot = reaper.GetResourcePath() .. '/ReaWebAPI/Apps/reawebamp/Data/previews'
  reaper.RecursiveCreateDirectory(dataRoot, 0)

  local function cacheFiles()
    local rows = {}
    local i = 0

    while true do
      local name = reaper.EnumerateFiles(dataRoot, i)

      if not name then
        break
      end

      i = i + 1

      local stem, extension = name:match('^(%x+)%.(.+)$')

      if stem and #stem == 32 and ({
        wav = true,
        rpp = true,
        ['rpp-bak'] = true,
        ['wav.reapeaks'] = true
      })[extension:lower()] then
        rows[#rows + 1] = dataRoot .. '/' .. name
      end
    end

    return rows
  end

  local managed={}

  function preview(scope, regionId, tail)
    local _, state = project()
    local p = guard(state.token, true)

    if scope == 'track' then
      assert(
        reaper.CountSelectedTracks(p) == 1,
        '轨道预览请只选择一条轨道，多轨混音请使用 Region 预览。'
      )
    end

    local selection = collect(scope, regionId)
    assert(#selection.items > 0 or selection.range, '没有可渲染的选择。')

    tail = tonumber(tail) or 0
    assert(tail >= 0 and tail <= 30, '尾音必须在 0–30 秒之间。')

    local start, finish = math.huge, 0

    for _, item in ipairs(selection.items) do
      start = math.min(start, item.position)
      finish = math.max(finish, item.position + item.length)
    end

    if selection.range then
      start = selection.range.start
      finish = selection.range.finish
    end

    assert(finish > start, '渲染范围为空。')
    assert(finish - start + tail <= 3600, '单次预览最长 1 小时。')

    local total = 0

    for _, path in ipairs(cacheFiles()) do
      local f = io.open(path, 'rb')

      if f then
        total = total + (f:seek('end') or 0)
        f:close()
      end
    end

    assert(
      total + (finish - start + tail) * 48000 * 8 < 2 * 1024 * 1024 * 1024,
      '预览缓存将超过 2 GiB，请先清理缓存。'
    )

    local key = reaper.genGuid():gsub('[^%w]', '')
    local snapshot = dataRoot .. '/' .. key .. '.rpp'
    local output = dataRoot .. '/' .. key .. '.wav'

    local dirty = reaper.IsProjectDirty(p)
    local clone

    reaper.Main_SaveProjectEx(p, snapshot, 0)

    managed[#managed + 1] = snapshot
    managed[#managed + 1] = output

    if dirty ~= 0 and reaper.IsProjectDirty(p) == 0 then
      reaper.MarkProjectDirty(p)
    end

    local success, result = xpcall(function()
      reaper.Main_OnCommand(40859, 0)

      clone = reaper.EnumProjects(-1, '')
      assert(clone ~= p, 'Cannot create a temporary render project')

      reaper.Main_openProject('noprompt:' .. snapshot)

      clone = reaper.EnumProjects(-1, '')
      assert(clone ~= p, 'Refusing to render into the source project')

      local settings = scope == 'item' and (64 | 262144) or scope == 'track' and 128 or 0

      local values = {
        RENDER_SETTINGS = settings,
        RENDER_BOUNDSFLAG = 0,
        RENDER_STARTPOS = start,
        RENDER_ENDPOS = finish,
        RENDER_CHANNELS = 2,
        RENDER_SRATE = 48000,
        RENDER_TAILFLAG = 1,
        RENDER_TAILMS = tail * 1000,
        RENDER_ADDTOPROJ = 0,
        RENDER_NORMALIZE = 0,
        RENDER_DITHER = 0
      }

      for k, v in pairs(values) do
        reaper.GetSetProjectInfo(clone, k, v, true)
      end

      reaper.GetSetProjectInfo_String(clone, 'RENDER_FILE', dataRoot, true)
      reaper.GetSetProjectInfo_String(clone, 'RENDER_PATTERN', key, true)
      reaper.GetSetProjectInfo_String(clone, 'RENDER_FORMAT', 'ZXZhdyAAAA==', true)
      reaper.GetSetProjectInfo_String(clone, 'RENDER_FORMAT2', '', true)

      reaper.Main_OnCommand(42230, 0)

      local f = io.open(output, 'rb')
      assert(f, '渲染已取消或没有生成预期文件。')

      local size = f:seek('end')
      f:close()

      assert(size > 44, '渲染文件为空。')

      local source = reaper.PCM_Source_CreateFromFile(output)
      assert(source, '渲染输出无法解码。')

      local duration = reaper.GetMediaSourceLength(source)
      reaper.PCM_Source_Destroy(source)

      assert(duration >= finish - start + tail - 0.05, '渲染被取消或输出不完整。')

      return {
        path = output,
        name = (selection.range and selection.range.name ~= '' and selection.range.name or scope) .. ' preview',
        projectGuid = state.guid,
        projectPath = state.path,
        revision = state.revision,
        render = {
          scope = scope,
          start = start,
          finish = finish,
          tail = tail,
          sampleRate = 48000,
          channels = 2,
          format = 'WAV float32',
          route = scope == 'region' and 'project master mix'
            or scope == 'track' and 'selected tracks via master'
            or 'selected items via master'
        }
      }
    end, debug.traceback)

    local cleanupOK, cleanupError = pcall(function()
      if clone and clone ~= p and reaper.ValidatePtr(clone, 'ReaProject*') then
        reaper.SelectProjectInstance(clone)
        reaper.Main_SaveProjectEx(clone, snapshot, 8)
        reaper.Main_OnCommand(40860, 0)
      end
    end)

    if reaper.ValidatePtr(p, 'ReaProject*') then
      reaper.SelectProjectInstance(p)
    end

    assert(cleanupOK, '预览工程未能自动关闭：' .. tostring(cleanupError))

    if not success then
      error(result)
    end

    return result
  end

  local function execute(op, args)
    if op == 'state' then
      local _, state = project()
      return state
    end

    if op == 'transport' then
      local p = guard(args[1], false)
      local action = args[2]

      if action == 'play' then
        reaper.OnPlayButtonEx(p)
      elseif action == 'pause' then
        reaper.OnPauseButtonEx(p)
      elseif action == 'stop' then
        reaper.OnStopButtonEx(p)
      elseif action == 'seek' then
        local time = tonumber(args[3])
        assert(time and time >= 0 and time <= reaper.GetProjectLength(p), '无效的工程时间')
        reaper.SetEditCurPos2(p, time, false, true)
      else
        error('Unknown transport action')
      end

      return true
    end

    if op == 'selection' then
      return collect(args[1], args[2])
    end

    if op == 'regions' then
      local p = project()
      local rows = array()
      local i = 0

      while true do
        local ok, isrgn, a, b, name, index = reaper.EnumProjectMarkers3(p, i)

        if ok == 0 then
          break
        end

        if isrgn then
          rows[#rows + 1] = {
            id = index,
            name = name,
            start = a,
            finish = b
          }
        end

        i = i + 1
      end

      return rows
    end

    if op == 'preview' then
      return preview(args[1], args[2], args[3])
    end

    if op == 'clearCache' then
      local count = 0

      for _, path in ipairs(cacheFiles()) do
        if os.remove(path) then
          count = count + 1
        end
      end

      managed = {}
      return count
    end

    error('Unknown ReaWebamp command')
  end

  local function handle(message)
    local request, op, rest = message:match('^RW2 (%d+) ([%a]+)%s*(.*)$')

    if not request then
      return false
    end

    local args = {}

    for word in rest:gmatch('%S+') do
      args[#args + 1] = word:gsub('%%(%x%x)', function(hex)
        return string.char(tonumber(hex, 16))
      end)
    end

    local ok, result = pcall(execute, op, args)

    reaper.ReaWeb_Send(id, encode({
      type = 'reawebamp',
      id = tonumber(request),
      result = ok and result or nil,
      error = not ok and tostring(result) or nil
    }))

    return true
  end

  local function loop()
    if not reaper.ReaWeb_IsOpen(id) then
      reaper.DeleteExtState('ReaWebamp', instance, false)
      return
    end

    for _ = 1, 16 do
      local message = reaper.ReaWeb_Receive(id)

      if message == '' then
        break
      end

      handle(message)
    end

    reaper.defer(loop)
  end

  reaper.atexit(function()
    reaper.DeleteExtState('ReaWebamp', instance, false)
  end)

  return {
    step = loop,
    handle = handle
  }

end

return M
