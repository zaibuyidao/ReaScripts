--[[
 * ReaScript Name: Auto Expression Shape
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.1
 * Author: zaibuyidao, dangguidan
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-9-7)
  + Initial release
--]]

take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if take == nil then return end
tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)

local cc_num = reaper.GetExtState("InsertExpressionShape", "CC")
local val_01 = reaper.GetExtState("InsertExpressionShape", "Val1")
local val_02 = reaper.GetExtState("InsertExpressionShape", "Val2")
local bezier_in = reaper.GetExtState("InsertExpressionShape", "BezierIn")
local bezier_out = reaper.GetExtState("InsertExpressionShape", "BezierOut")

if (cc_num == "") then cc_num = "11" end
if (val_01 == "") then val_01 = "88" end
if (val_02 == "") then val_02 = "127" end
if (bezier_in == "") then bezier_in = "25" end
if (bezier_out == "") then bezier_out = "40" end

local user_ok, user_input_csv = reaper.GetUserInputs("Auto Expression Shape", 5, "CC number,Minimum value,Max value,Bezier in(-100 - 100),Bezier out(-100 - 100)", cc_num..','..val_01..','.. val_02..','..bezier_in..','.. bezier_out)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
cc_num, val_01, val_02, bezier_in, bezier_out = user_input_csv:match("(.*),(.*),(.*),(.*),(.*)")
if not tonumber(cc_num) or not tonumber(val_01) or not tonumber(val_02)  or not tonumber(bezier_in) or not tonumber(bezier_out) then return reaper.SN_FocusMIDIEditor() end
cc_num, val_01, val_02, bezier_in, bezier_out = tonumber(cc_num), tonumber(val_01), tonumber(val_02), tonumber(bezier_in), tonumber(bezier_out)

reaper.SetExtState("InsertExpressionShape", "CC", cc_num, false)
reaper.SetExtState("InsertExpressionShape", "Val1", val_01, false)
reaper.SetExtState("InsertExpressionShape", "Val2", val_02, false)
reaper.SetExtState("InsertExpressionShape", "BezierIn", bezier_in, false)
reaper.SetExtState("InsertExpressionShape", "BezierOut", bezier_out, false)

function StartInsert()
  reaper.MIDI_DisableSort(take)
  i = reaper.MIDI_EnumSelNotes(take, -1)
  while i ~= -1 do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    local len = endppqpos - startppqpos
    if len >= (tick / 2) and len < tick then -- 如果长度大于等于 240 并且 长度小于 480
      reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, val_01)
      reaper.MIDI_InsertCC(take, false, muted, startppqpos + (tick * 0.4), 0xB0, chan, cc_num, val_02)
    elseif len >= tick and len < tick * 2 then -- 如果长度大于等于 480 并且 长度小于 960
      reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, val_01)
      reaper.MIDI_InsertCC(take, false, muted, startppqpos + (tick * 0.75), 0xB0, chan, cc_num, val_02)
    elseif len == tick * 2 then -- 如果长度等于 960
      reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, val_01)
      reaper.MIDI_InsertCC(take, false, muted, startppqpos + tick, 0xB0, chan, cc_num, val_02)
    elseif len > tick * 2 then -- 如果长度大于 960
      reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, val_01)
      reaper.MIDI_InsertCC(take, false, muted, startppqpos + (tick * 1.5), 0xB0, chan, cc_num, val_02)
    elseif len > 0 and len < (tick / 2) then -- 如果长度大于0 并且小于 240
      reaper.MIDI_InsertCC(take, false, muted, startppqpos, 0xB0, chan, cc_num, val_02)
    end
    i = reaper.MIDI_EnumSelNotes(take, i)
  end

  j = reaper.MIDI_EnumSelCC(take, -1)
  while j ~= -1 do
    reaper.MIDI_SetCCShape(take, j, 5, bezier_in / 100, true)
    reaper.MIDI_SetCC(take, j, false, false, nil, nil, nil, nil, nil, true)
    j = reaper.MIDI_EnumSelCC(take, j)
  end

  reaper.MIDI_Sort(take)
end

function EndInsert()
  reaper.MIDI_DisableSort(take)
  i = reaper.MIDI_EnumSelNotes(take, -1)
  while i ~= -1 do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    local len = endppqpos - startppqpos
    local val_03
    if val_02 - val_01 > 10 then val_03 = val_01 + 10 else val_03 = val_01 end
    if len >= tick * 2 then -- 如果长度大于等于 960
      reaper.MIDI_InsertCC(take, true, muted, endppqpos - (tick * 0.75), 0xB0, chan, cc_num, val_02)
      reaper.MIDI_InsertCC(take, false, muted, endppqpos - (tick / 24), 0xB0, chan, cc_num, val_03)
    end
    i = reaper.MIDI_EnumSelNotes(take, i)
  end

  j = reaper.MIDI_EnumSelCC(take, -1)
  while j ~= -1 do
    reaper.MIDI_SetCCShape(take, j, 5, bezier_out / 100, true)
    reaper.MIDI_SetCC(take, j, false, false, nil, nil, nil, nil, nil, true)
    j = reaper.MIDI_EnumSelCC(take, j)
  end

  reaper.MIDI_Sort(take)
end

script_title = "Auto Expression Shape"
reaper.Undo_BeginBlock()

StartInsert()
EndInsert()

reaper.UpdateArrange()
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()