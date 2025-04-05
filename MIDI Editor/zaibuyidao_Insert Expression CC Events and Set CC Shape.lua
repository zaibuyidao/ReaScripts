-- @description Insert Expression CC Events and Set CC Shape
-- @version 1.0
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

take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if take == nil then return end
tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)

local cc_num = reaper.GetExtState("InsertExpressionCCEvents", "CC")
local val_01 = reaper.GetExtState("InsertExpressionCCEvents", "Val1")
local val_02 = reaper.GetExtState("InsertExpressionCCEvents", "Val2")
local val_03 = reaper.GetExtState("InsertExpressionCCEvents", "Val3")
if (cc_num == "") then cc_num = "11" end
if (val_01 == "") then val_01 = "90" end
if (val_02 == "") then val_02 = "127" end
if (val_03 == "") then val_03 = "95" end

local user_ok, user_input_csv = reaper.GetUserInputs("Insert Expression CC Events and Set CC Shape", 4, "CC number,Point 1,Point 2 and 3,Point 4", cc_num..','..val_01..','.. val_02..','.. val_03)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
cc_num, val_01, val_02, val_03 = user_input_csv:match("(.*),(.*),(.*),(.*)")
if not tonumber(cc_num) or not tonumber(val_01) or not tonumber(val_02) or not tonumber(val_03) then return reaper.SN_FocusMIDIEditor() end
cc_num, val_01, val_02, val_03 = tonumber(cc_num), tonumber(val_01), tonumber(val_02), tonumber(val_03)

reaper.SetExtState("InsertExpressionCCEvents", "CC", cc_num, false)
reaper.SetExtState("InsertExpressionCCEvents", "Val1", val_01, false)
reaper.SetExtState("InsertExpressionCCEvents", "Val2", val_02, false)
reaper.SetExtState("InsertExpressionCCEvents", "Val3", val_03, false)

function INST1() -- 音符开头插入
  for i = 0,  notecnt - 1 do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      local len = endppqpos - startppqpos
      if len > (tick / 4) and len <= ((tick / 4) + (tick / 2))  then -- 如果长度大于 120 并且 长度小于等于 360
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, chan, cc_num, val_01)
      elseif len > ((tick / 4) + (tick / 2)) and len <= tick then -- 如果长度大于 360 并且 长度小于等于 480
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, chan, cc_num, val_01)
      elseif len > tick and len <= tick * 2 then -- 如果长度大于 480 并且 长度小于等于 960
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, chan, cc_num, val_01)
      elseif len > tick * 2 then -- 如果长度大于 960
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, chan, cc_num, val_01)
      end
      reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 42083) -- Set CC shape to fast start
    end
    i=i+1
  end
  reaper.MIDIEditor_LastFocused_OnCommand(40671, 0) -- Unselect all CC events
end

function INST2() -- 音符开头插入
  for i = 0,  notecnt - 1 do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      local len = endppqpos - startppqpos
      if len > (tick / 4) and len <= ((tick / 4) + (tick / 2)) then -- 如果长度大于 120 并且 长度小于等于 360
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos + (tick / 16) * 3, 0xB0, chan, cc_num, val_02) -- 90
      elseif len > ((tick / 4) + (tick / 2)) and len <= tick then -- 如果长度大于 360 并且 长度小于等于 480
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos + (tick / 2), 0xB0, chan, cc_num, val_02) -- 240
      elseif len > tick and len <= (tick + tick / 2) then -- 如果长度大于 480 并且 长度小于等于 720
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos + (tick - tick / 4), 0xB0, chan, cc_num, val_02) -- 360
      elseif len > (tick + tick / 2) and len <= tick * 2 then -- 如果长度大于 720 并且 长度小于等于 960
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos + tick, 0xB0, chan, cc_num, val_02) -- 480
      elseif len > tick * 2 and len <= tick * 6 then -- 如果长度大于 960 并且 长度小于等于 2880
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos + tick, 0xB0, chan, cc_num, val_02) -- 480
      elseif len > tick * 6 then -- 如果长度大于 2880
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos + (tick + (tick / 2)), 0xB0, chan, cc_num, val_02) -- 720
      elseif len <= (tick / 4) then -- 如果长度小于等于 120
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, chan, cc_num, val_02)
      end
        reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 42081) -- Set CC shape to square
    end
    i=i+1
  end
  reaper.MIDIEditor_LastFocused_OnCommand(40671, 0) -- Unselect all CC events
end

function INST3() -- 音符结尾插入
  for i = 0,  notecnt - 1 do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      local len = endppqpos - startppqpos
      if len > tick and len <= tick * 2 then -- 如果长度大于 480 并且 长度小于等于 960
        reaper.MIDI_InsertCC(take, selected, muted, endppqpos - tick / 2, 0xB0, chan, cc_num, val_02) -- 240
      elseif len > tick * 2 and len <= tick * 6 then -- 如果长度大于 960 并且 长度小于等于 2880
        reaper.MIDI_InsertCC(take, selected, muted, endppqpos - tick, 0xB0, chan, cc_num, val_02) -- 480
      elseif len >  tick * 6 then -- 如果长度大于 2880
        reaper.MIDI_InsertCC(take, selected, muted, endppqpos - tick * 2, 0xB0, chan, cc_num, val_02) -- 960
      end
      reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 42084) -- Set CC shape to fast end
    end
    i=i+1
  end
  reaper.MIDIEditor_LastFocused_OnCommand(40671, 0) -- Unselect all CC events
end

function INST4() -- 音符结尾插入
  for i = 0,  notecnt - 1 do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      local len = endppqpos - startppqpos
      if len >= tick  + (tick / 2) and len <= tick * 2 then -- 如果长度大于等于 720 并且 长度小于等于 960
        reaper.MIDI_InsertCC(take, selected, muted, endppqpos - ((tick / 16) / 3), 0xB0, chan, cc_num, val_03) -- 10
      elseif len > tick * 2 then -- 如果长度大于 960
        reaper.MIDI_InsertCC(take, selected, muted, endppqpos - ((tick / 16) / 3), 0xB0, chan, cc_num, val_03) -- 10
      end
      reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 42081) -- Set CC shape to square
    end
    i=i+1
  end
  reaper.MIDIEditor_LastFocused_OnCommand(40671, 0) -- Unselect all CC events
end

script_title = "Insert Expression CC Events and Set CC Shape"
reaper.Undo_BeginBlock()
INST1()
INST2()
INST3()
INST4()
reaper.UpdateArrange()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()