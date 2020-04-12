--[[
 * ReaScript Name: Insert NRPN
 * Instructions: Open a MIDI take in MIDI Event List Editor. Select Event, Run.
 * Version: 2.3
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

function NonRegParm()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  local cur_pos = reaper.GetCursorPositionEx()
  local cur_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, cur_pos)
  local retval, input_csv = reaper.GetUserInputs("Insert NRPN", 2, "98-NRPN,6-Data Entry", "0,64")
  if not retval then return reaper.SN_FocusMIDIEditor() end
  local LSB, MSB = input_csv:match("(%d*),(%d*)")
  if not tonumber(LSB) or not tonumber(MSB) then return reaper.SN_FocusMIDIEditor() end
  reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40214) -- Edit: Unselect all
  reaper.MIDI_InsertCC(take, false, false, cur_ppq + 10, 0xB0, 0, 98, LSB)
  reaper.MIDI_InsertCC(take, true, false, cur_ppq + 20, 0xB0, 0, 6, MSB)
  reaper.SetEditCurPos(reaper.MIDI_GetProjTimeFromPPQPos(take, cur_ppq + 20), true, true)
end
reaper.Undo_BeginBlock()
NonRegParm()
reaper.Undo_EndBlock("Insert NRPN", 0)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()