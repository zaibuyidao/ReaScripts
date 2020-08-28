--[[
 * ReaScript Name: Insert Expression (Set CC Shape)
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Reference: https://forum.cockos.com/showthread.php?t=225108
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-1-1)
  + Initial release
--]]

take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if take == nil then return end
tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)

local cc_num = reaper.GetExtState("InsertExpressionShape", "CC")
local val_01 = reaper.GetExtState("InsertExpressionShape", "Val1")
local val_02 = reaper.GetExtState("InsertExpressionShape", "Val2")
local val_03 = reaper.GetExtState("InsertExpressionShape", "Val3")
if (cc_num == "") then cc_num = "11" end
if (val_01 == "") then val_01 = "90" end
if (val_02 == "") then val_02 = "127" end
if (val_03 == "") then val_03 = "95" end

local user_ok, user_input_csv = reaper.GetUserInputs("Insert Expression", 4, "CC number,Point 1,Point 2 and 3,Point 4", cc_num..','..val_01..','.. val_02..','.. val_03)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
cc_num, val_01, val_02, val_03 = user_input_csv:match("(.*),(.*),(.*),(.*)")
if not tonumber(cc_num) or not tonumber(val_01) or not tonumber(val_02) or not tonumber(val_03) then return reaper.SN_FocusMIDIEditor() end
cc_num, val_01, val_02, val_03 = tonumber(cc_num), tonumber(val_01), tonumber(val_02), tonumber(val_03)

reaper.SetExtState("InsertExpressionShape", "CC", cc_num, false)
reaper.SetExtState("InsertExpressionShape", "Val1", val_01, false)
reaper.SetExtState("InsertExpressionShape", "Val2", val_02, false)
reaper.SetExtState("InsertExpressionShape", "Val3", val_03, false)

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

script_title = "Insert Expression (Set CC Shape)"
reaper.Undo_BeginBlock()
INST1()
INST2()
INST3()
INST4()
reaper.UpdateArrange()
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()