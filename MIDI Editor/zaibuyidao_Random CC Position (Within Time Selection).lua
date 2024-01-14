-- @description Random CC Position (Within Time Selection)
-- @version 3.0
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

-- USER AREA
-- Settings that the user can customize.

local gridEnabled = true -- Set to true to enable grid-based randomization

-- End of USER AREA

function print(...)
  for _, v in ipairs({...}) do
    reaper.ShowConsoleMsg(tostring(v) .. " ")
  end
  reaper.ShowConsoleMsg("\n")
end

function getSystemLanguage()
  local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))
  local os = reaper.GetOS()
  local lang

  if os == "Win32" or os == "Win64" then -- Windows
      if locale == 936 then -- Simplified Chinese
          lang = "简体中文"
      elseif locale == 950 then -- Traditional Chinese
          lang = "繁體中文"
      else -- English
          lang = "English"
      end
  elseif os == "OSX32" or os == "OSX64" then -- macOS
      local handle = io.popen("/usr/bin/defaults read -g AppleLocale")
      local result = handle:read("*a")
      handle:close()
      lang = result:gsub("_", "-"):match("[a-z]+%-[A-Z]+")
      if lang == "zh-CN" then -- 简体中文
          lang = "简体中文"
      elseif lang == "zh-TW" then -- 繁体中文
          lang = "繁體中文"
      else -- English
          lang = "English"
      end
  elseif os == "Linux" then -- Linux
      local handle = io.popen("echo $LANG")
      local result = handle:read("*a")
      handle:close()
      lang = result:gsub("%\n", ""):match("[a-z]+%-[A-Z]+")
      if lang == "zh_CN" then -- 简体中文
          lang = "简体中文"
      elseif lang == "zh_TW" then -- 繁體中文
          lang = "繁體中文"
      else -- English
          lang = "English"
      end
  end

  return lang
end

local language = getSystemLanguage()

if language == "简体中文" then
  title = "随机CC位置"
elseif language == "繁体中文" then
  title = "隨機CC位置"
else
  title = "Random CC Position"
end

function isCCOverlap(take, ppqpos, index, currentIndex)
  for j = 1, #index do
    if j ~= currentIndex then
      local _, _, _, other_ppqpos = reaper.MIDI_GetCC(take, index[j])
      if ppqpos == other_ppqpos then
        return true
      end
    end
  end
  return false
end

function getGrid(take)
  local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
  local grid_qn = reaper.MIDI_GetGrid(take)
  return math.floor(midi_tick * grid_qn)
end

function Main(gridEnabled)
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end

  local grid = gridEnabled and getGrid(take) or 1
  local time_start, time_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, 0)
  local loop_start, loop_end

  local index = {}
  local min_ppq, max_ppq
  local val = reaper.MIDI_EnumSelCC(take, -1)
  while val ~= -1 do
    local _, _, _, ppqpos = reaper.MIDI_GetCC(take, val)
    min_ppq = (min_ppq == nil) and ppqpos or math.min(min_ppq, ppqpos)
    max_ppq = (max_ppq == nil) and ppqpos or math.max(max_ppq, ppqpos)
    table.insert(index, val)
    val = reaper.MIDI_EnumSelCC(take, val)
  end

  if #index == 0 then return end  -- 如果没有选中的 CC 事件，直接返回

  if time_start == time_end then
    -- 没有时间选区，根据选中的CC事件创建时间选区
    time_start = reaper.MIDI_GetProjTimeFromPPQPos(take, min_ppq)
    time_end = reaper.MIDI_GetProjTimeFromPPQPos(take, max_ppq)
    reaper.GetSet_LoopTimeRange2(0, true, false, time_start, time_end, false)
  end

  loop_start = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_start))
  loop_end = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_end))
  local loop_len = loop_end - loop_start

  -- 计算基于网格的时间选区的开始和结束位置
  if gridEnabled then
    -- 当时间选区的开始或结束正好在网格上时，保持它们不变
    if loop_start % grid ~= 0 then
      loop_start = loop_start + grid - (loop_start % grid)
    end
    if loop_end % grid ~= 0 then
      loop_end = loop_end - (loop_end % grid)
    end
    if loop_start >= loop_end then return end -- 确保时间选区在网格范围内
  end

  reaper.MIDI_DisableSort(take)
  for i, idx in ipairs(index) do
    local retval, sel, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, idx)
    local rand_pos
    local retry_count = 0
    local max_retries = 50

    repeat
      if gridEnabled then
        -- 确保随机位置包括时间选区的起始位置
        local grid_count = math.floor((loop_end - loop_start) / grid)
        local rand_grid = math.random(0, grid_count) * grid
        rand_pos = loop_start + rand_grid

        -- 防止随机位置超出时间选区
        if rand_pos >= loop_end then
          rand_pos = loop_end - grid
        end
      else
        -- 非网格随机时确保随机位置不超出时间选区
        rand_pos = math.random(loop_start, loop_end - 1)
      end

      retry_count = retry_count + 1
      if retry_count > max_retries then
        break
      end
    until not isCCOverlap(take, rand_pos, index, i)

    if retry_count <= max_retries then
      reaper.MIDI_SetCC(take, idx, sel, muted, rand_pos, chanmsg, chan, msg2, msg3, false)
    end
  end
  
  reaper.MIDI_Sort(take)
  reaper.UpdateArrange()
end

reaper.Undo_BeginBlock()
reaper.MIDIEditor_LastFocused_OnCommand(40747, 0) -- Edit: Select all CC events in time selection (in last clicked CC lane)
Main(gridEnabled)
reaper.Undo_EndBlock(title, -1)