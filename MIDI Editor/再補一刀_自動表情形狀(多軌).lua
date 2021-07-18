--[[
 * ReaScript Name: 自動表情形狀(多軌)
 * Version: 1.2.1
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-9-10)
  + Initial release
--]]

local cc_num = reaper.GetExtState("InsertExpressionShape", "CC")
local val_01 = reaper.GetExtState("InsertExpressionShape", "Val1")
local val_02 = reaper.GetExtState("InsertExpressionShape", "Val2")
local speed = reaper.GetExtState("InsertExpressionShape", "Speed")
local bezier_in = reaper.GetExtState("InsertExpressionShape", "BezierIn")
local bezier_out = reaper.GetExtState("InsertExpressionShape", "BezierOut")
local flag = 0

if (cc_num == "") then cc_num = "11" end
if (val_01 == "") then val_01 = "88" end
if (val_02 == "") then val_02 = "127" end
if (speed == "") then speed = "0" end
if (bezier_in == "") then bezier_in = "-20" end
if (bezier_out == "") then bezier_out = "40" end

local user_ok, user_input_csv = reaper.GetUserInputs("自動表情形狀(多軌)", 6, "CC編號,最小值,最大值,速度(0=慢 1=快),開始弧度(-100至100),結束弧度(-100至100),extrawidth=5", cc_num..','..val_01..','.. val_02..','.. speed..','..bezier_in..','.. bezier_out)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
cc_num, val_01, val_02, speed, bezier_in, bezier_out = user_input_csv:match("(.*),(.*),(.*),(.*),(.*),(.*)")
if not tonumber(cc_num) or not tonumber(val_01) or not tonumber(val_02)  or not tonumber(speed) or not tonumber(bezier_in) or not tonumber(bezier_out) then return reaper.SN_FocusMIDIEditor() end
cc_num, val_01, val_02, speed, bezier_in, bezier_out = tonumber(cc_num), tonumber(val_01), tonumber(val_02), tonumber(speed), tonumber(bezier_in), tonumber(bezier_out)

reaper.SetExtState("InsertExpressionShape", "CC", cc_num, false)
reaper.SetExtState("InsertExpressionShape", "Val1", val_01, false)
reaper.SetExtState("InsertExpressionShape", "Val2", val_02, false)
reaper.SetExtState("InsertExpressionShape", "Speed", speed, false)
reaper.SetExtState("InsertExpressionShape", "BezierIn", bezier_in, false)
reaper.SetExtState("InsertExpressionShape", "BezierOut", bezier_out, false)

function StartInsert()
  reaper.MIDI_DisableSort(take)
  i = reaper.MIDI_EnumSelNotes(take, -1)
  while i ~= -1 do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    local len = endppqpos - startppqpos
    if speed == 0 then
      if len >= (tick / 2) and len < tick then -- 如果长度大于等于 240 并且 长度小于 480
        reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, val_01)
        reaper.MIDI_InsertCC(take, false, muted, startppqpos + (tick * 0.4), 0xB0, chan, cc_num, val_02)
      end
    end
    if len >= tick and len < tick * 2 then -- 如果长度大于等于 480 并且 长度小于 960
      reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, val_01)
      reaper.MIDI_InsertCC(take, false, muted, startppqpos + (tick * 0.75), 0xB0, chan, cc_num, val_02)
    end
    if len == tick * 2 then -- 如果长度等于 960
      reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, val_01)
      reaper.MIDI_InsertCC(take, false, muted, startppqpos + tick, 0xB0, chan, cc_num, val_02)
    end
    if len > tick * 2 then -- 如果长度大于 960
      reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, val_01)
      reaper.MIDI_InsertCC(take, false, muted, startppqpos + (tick * 1.5), 0xB0, chan, cc_num, val_02)
    end
    if speed == 0 then speed_note = (tick / 2) else speed_note = tick end
    if len > 0 and len < speed_note then -- 如果长度大于0 并且小于 240
      if flag == 0 then
        reaper.MIDI_InsertCC(take, false, muted, startppqpos, 0xB0, chan, cc_num, val_02)
        flag = 1
      end
    else
      flag = 0
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
    local val_03 = math.modf(((val_02-val_01)/val_02)*65) + val_01
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

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items > 0 then
    for i = 1, count_sel_items do
        item = reaper.GetSelectedMediaItem(0, i - 1)
        take = reaper.GetTake(item, 0)
        if not take or not reaper.TakeIsMIDI(take) then return end
        StartInsert()
        EndInsert()
    end
else
    take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end
    StartInsert()
    EndInsert()
end
reaper.Undo_EndBlock("自動表情形狀(多軌)", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()