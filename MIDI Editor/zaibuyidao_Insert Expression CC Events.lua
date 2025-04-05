-- @description Insert Expression CC Events
-- @version 1.0.1
-- @author zaibuyidao
-- @changelog
--   + New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

local ZBYDFuncPath = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Utility/zaibuyidao_Functions.lua'
if reaper.file_exists(ZBYDFuncPath) then
  dofile(ZBYDFuncPath)
  if not checkSWSExtension() or not checkJSAPIExtension() then return end
else
  local errorMsg = "Error - Missing Script (错误 - 缺失脚本)\n\n" ..
  "[English]\nThe required 'zaibuyidao Functions' script file was not found. Please ensure the file is correctly placed at:\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\nIf the file is missing, you can install it via ReaPack by searching for 'zaibuyidao Functions' in the ReaPack package browser.\n\n" ..
  "[中文]\n必需的 'zaibuyidao Functions' 脚本文件未找到。请确保文件正确放置在以下位置：\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\n如果文件缺失，您可以通过 ReaPack 包浏览器搜索并安装 'zaibuyidao Functions'。\n"

  reaper.MB(errorMsg, "Missing Script Error/脚本文件缺失错误", 0)

  if reaper.APIExists('ReaPack_BrowsePackages') then
    reaper.ReaPack_BrowsePackages('zaibuyidao Functions')
  else
    local reapackErrorMsg = "Error - ReaPack Not Found (错误 - 未找到 ReaPack)\n\n" ..
    "[English]\nThe ReaPack extension is not found. Please install ReaPack to manage and install REAPER scripts and extensions easily. Visit https://reapack.com for installation instructions.\n\n" ..
    "[中文]\n未找到 ReaPack 扩展。请安装 ReaPack 来便捷地管理和安装 REAPER 脚本及扩展。访问 https://reapack.com 获取安装指南。\n"

    reaper.MB(reapackErrorMsg, "ReaPack Not Found/未找到 ReaPack", 0)
  end
  return
end

local language = getSystemLanguage()

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not take then return end

local ticks_per_beat = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local _, note_count, _, _ = reaper.MIDI_CountEvts(take)

local cc_number      = reaper.GetExtState("InsertExpressionCCEvents", "CC")
local fast_start_val = reaper.GetExtState("InsertExpressionCCEvents", "Val1")
local square_val     = reaper.GetExtState("InsertExpressionCCEvents", "Val2")
local square_end_val = reaper.GetExtState("InsertExpressionCCEvents", "Val3")

if cc_number == "" then cc_number = "11" end
if fast_start_val == "" then fast_start_val = "90" end
if square_val == "" then square_val = "127" end
if square_end_val == "" then square_end_val = "95" end

if language == "简体中文" then
  scriptTitle = "插入表情CC事件"
  captionsCsv = "CC 编号,点 1,点 2 与 3,点 4"
elseif language == "繁體中文" then
  scriptTitle = "插入表情CC事件"
  captionsCsv = "CC 编號,點 1,點 2 與 3,點 4"
else
  scriptTitle = "Insert Expression CC Events"
  captionsCsv = "CC number,Point 1,Point 2 and 3,Point 4"
end

local uok, uinput = reaper.GetUserInputs(scriptTitle, 4, captionsCsv, cc_number .. "," .. fast_start_val .. "," .. square_val .. "," .. square_end_val)
if not uok then return reaper.SN_FocusMIDIEditor() end

cc_number, fast_start_val, square_val, square_end_val = uinput:match("([^,]+),([^,]+),([^,]+),([^,]+)")
if not (tonumber(cc_number) and tonumber(fast_start_val) and tonumber(square_val) and tonumber(square_end_val)) then return reaper.SN_FocusMIDIEditor() end

cc_number, fast_start_val, square_val, square_end_val = tonumber(cc_number), tonumber(fast_start_val), tonumber(square_val), tonumber(square_end_val)

reaper.SetExtState("InsertExpressionCCEvents", "CC", cc_number, false)
reaper.SetExtState("InsertExpressionCCEvents", "Val1", fast_start_val, false)
reaper.SetExtState("InsertExpressionCCEvents", "Val2", square_val, false)
reaper.SetExtState("InsertExpressionCCEvents", "Val3", square_end_val, false)

local function insertFastStartCC()
  for i = 0, note_count - 1 do
    local retval, selected, muted, startppqpos, endppqpos, channel, pitch, velocity = reaper.MIDI_GetNote(take, i)
    if selected then
      local note_length = endppqpos - startppqpos
      if note_length > (ticks_per_beat / 4) then -- 当音符长度大于 1/4 拍 (ticksPerBeat/4) 时插入 CC 事件
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, channel, cc_number, fast_start_val)
      end
      reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 42083) -- Set CC shape to fast start
    end
  end
  reaper.MIDIEditor_LastFocused_OnCommand(40671, 0) -- Unselect all CC events
end

local function insertSquareStartCC()
  for j = 0, note_count - 1 do
    local retval, selected, muted, startppqpos, endppqpos, channel, pitch, velocity = reaper.MIDI_GetNote(take, j)
    if selected then
      local note_length = endppqpos - startppqpos
      local offset = nil

      if note_length <= (ticks_per_beat / 4) then -- 当音符长度小于等于 1/4 拍 (480/4 = 120), 直接在音符起始位置插入
        offset = 0
      elseif note_length <= ((ticks_per_beat / 4) + (ticks_per_beat / 2)) then -- 当音符长度介于 1/4 拍与 3/4 拍之间 (120 到 360)
        offset = (ticks_per_beat / 16) * 3 -- ticksPerBeat/16 = 480/16 = 30, 乘以 3 得到 90
      elseif note_length <= ticks_per_beat then -- 当音符长度介于 3/4 拍与 1 拍之间 (360 到 480), 偏移量设为 1/2 拍
        offset = ticks_per_beat / 2 -- ticksPerBeat/2 = 240
      elseif note_length <= (ticks_per_beat + (ticks_per_beat / 2)) then -- 当音符长度介于 1 拍与 1.5 拍之间 (480 到 720)
        offset = ticks_per_beat - (ticks_per_beat / 4) -- ticksPerBeat/4 = 120, 所以偏移量 = 480 - 120 = 360
      elseif note_length <= ticks_per_beat * 2 then -- 当音符长度介于 1.5 拍与 2 拍之间 (720 到 960 ticks)
        offset = ticks_per_beat -- 偏移量设为 1 拍 (480)
      elseif note_length <= ticks_per_beat * 6 then -- 当音符长度介于 2 拍与 6 拍之间 (960 到 2880), 同样设为 1 拍偏移
        offset = ticks_per_beat
      elseif note_length > ticks_per_beat * 6 then -- 当音符长度大于 6 拍 ( > 2880), 偏移量设为 1 拍半
        offset = ticks_per_beat + (ticks_per_beat / 2) -- 480 + 240 = 720
      end

      if offset then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos + offset, 0xB0, channel, cc_number, square_val)
      end

      reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 42081) -- Set CC shape to square
    end
  end
  reaper.MIDIEditor_LastFocused_OnCommand(40671, 0) -- Unselect all CC events
end

local function insertFastEndCC()
  for m = 0, note_count - 1 do
    local retval, selected, muted, startppqpos, endppqpos, channel, pitch, velocity = reaper.MIDI_GetNote(take, m)
    if selected then
      local note_length = endppqpos - startppqpos
      local insert_point = nil

      if note_length > ticks_per_beat and note_length <= ticks_per_beat * 2 then -- 当音符长度介于 1 拍与 2 拍之间 (480 到 960)
        insert_point = endppqpos - (ticks_per_beat / 2) -- 音符结束位置减去半拍 (ticksPerBeat/2), 480/2 = 240
      elseif note_length > ticks_per_beat * 2 and note_length <= ticks_per_beat * 6 then -- 当音符长度介于 2 拍与 6 拍之间 (960 到 2880)
        insert_point = endppqpos - ticks_per_beat -- 音符结束位置减去 1 拍 (480)
      elseif note_length > ticks_per_beat * 6 then -- 当音符长度大于 6 拍 (> 2880)
        insert_point = endppqpos - (ticks_per_beat * 2) -- 音符结束位置减去 2 拍 (480*2 = 960)
      end

      if insert_point then
        reaper.MIDI_InsertCC(take, selected, muted, insert_point, 0xB0, channel, cc_number, square_val)
      end

      reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 42084) -- Set CC shape to fast end
    end
  end
  reaper.MIDIEditor_LastFocused_OnCommand(40671, 0) -- Unselect all CC events
end

local function insertSquareEndCC()
  for n = 0, note_count - 1 do
    local retval, selected, muted, startppqpos, endppqpos, channel, pitch, velocity = reaper.MIDI_GetNote(take, n)
    if selected then
      local note_length = endppqpos - startppqpos
      local insert_point = nil
      
      if note_length >= (ticks_per_beat + (ticks_per_beat / 2)) then -- 当音符长度大于等于 1 拍半时 (ticksPerBeat + ticksPerBeat/2, 即480+240=720)
        insert_point = endppqpos - ((ticks_per_beat / 16) / 3) -- ticksPerBeat/16 = 480/16 = 30, 再除以 3 得到 10
      end

      if insert_point then
        reaper.MIDI_InsertCC(take, selected, muted, insert_point, 0xB0, channel, cc_number, square_end_val)
      end

      reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 42081) -- Set CC shape to square
    end
  end
  reaper.MIDIEditor_LastFocused_OnCommand(40671, 0) -- Unselect all CC events
end

reaper.Undo_BeginBlock()
insertFastStartCC()
insertSquareStartCC()
insertFastEndCC()
insertSquareEndCC()
reaper.UpdateArrange()
reaper.Undo_EndBlock(scriptTitle, -1)
reaper.SN_FocusMIDIEditor()
