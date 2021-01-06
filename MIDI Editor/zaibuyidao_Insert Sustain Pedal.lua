--[[
 * ReaScript Name: Insert Sustain Pedal
 * Version: 1.6
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local cishu = reaper.GetExtState("InsertSustainPedal", "Cishu")
if (cishu == "") then cishu = "99" end

local retval, user_input_csv = reaper.GetUserInputs("Insert Sustain Pedal", 1, "Repetition", cishu)
if not retval then return reaper.SN_FocusMIDIEditor() end
cishu = user_input_csv:match("(.*)")
cishu = tonumber(cishu)
reaper.SetExtState("InsertSustainPedal", "Cishu", cishu, false)

function HoldPedalOn()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  for i = 1, cishu do
    local cur_pos = reaper.GetCursorPositionEx()
    local cur_pos_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, cur_pos)
    local cur_pos_qn = reaper.MIDI_GetProjQNFromPPQPos(take, cur_pos_ppq)
    local Meas, Bar_Start_QN, Bar_End_QN = reaper.TimeMap_QNToMeasures(0, cur_pos_qn)
    local new_Start_QN = reaper.MIDI_GetPPQPosFromProjQN(take, Bar_Start_QN)
    local new_End_QN = reaper.MIDI_GetPPQPosFromProjQN(take, Bar_End_QN)
    reaper.MIDI_InsertCC(take, selected, false, new_Start_QN+110, 0xB0, 0, 64, 127) --踩下
    reaper.MIDI_InsertCC(take, selected, false, new_End_QN-10, 0xB0, 0, 64, 0) --釋放
    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40451) --Navigate: Move edit cursor to start of next measure
  end
end

reaper.Undo_BeginBlock()
selected = true
HoldPedalOn()
reaper.UpdateArrange()
reaper.Undo_EndBlock("Insert Sustain Pedal", 0)
reaper.SN_FocusMIDIEditor()