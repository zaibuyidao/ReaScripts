--[[
 * ReaScript Name: Insert NRPN
 * Instructions: Open a MIDI take in MIDI Event List Editor. Select Event, Run.
 * Version: 2.2
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v2.2 (2020-2-16)
  + Version update
 * v1.0 (2019-12-12)
  + Initial release
--]]

muted = false
selected = true

local retval, userInputsCSV = reaper.GetUserInputs("Insert NRPN", 2, "98-NRPN,6-Data Entry", "0,64")
if not retval then return reaper.SN_FocusMIDIEditor() end
local LSB, MSB = userInputsCSV:match("(%d*),(%d*)")
if not LSB:match('[%d%.]+') or not MSB:match('[%d%.]+') then return reaper.SN_FocusMIDIEditor() end
LSB, MSB = tonumber(LSB), tonumber(MSB)

function NonRegParm()
  reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40214)
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  local pos = reaper.GetCursorPositionEx()
  local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
  reaper.MIDI_InsertCC(take, false, muted, ppq + 10, 0xB0, 0, 98, LSB)
  reaper.MIDI_InsertCC(take, selected, muted, ppq + 20, 0xB0, 0, 6, MSB)
  reaper.SetEditCurPos(reaper.MIDI_GetProjTimeFromPPQPos(take, ppq + 20), true, true)
end

reaper.Undo_BeginBlock()
NonRegParm()
reaper.UpdateArrange()
reaper.Undo_EndBlock("Insert NRPN", 0)
reaper.SN_FocusMIDIEditor()