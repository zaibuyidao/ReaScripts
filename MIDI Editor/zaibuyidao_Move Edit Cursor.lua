--[[
 * ReaScript Name: Move Edit Cursor
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
 * provides: [main=midi_editor,midi_eventlisteditor] .
--]]

--[[
 * Changelog:
 * v1.0 (2020-1-27)
  + Initial release
--]]

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  local pos = reaper.GetCursorPositionEx()
  local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
  local tick = reaper.GetExtState("MoveEditCursor", "Tick")
  if (tick == "") then tick = "10" end
  user_ok, get_input_csv = reaper.GetUserInputs("Move Edit Cursor", 1, "Enter A Tick", tick)
  if not user_ok then return reaper.SN_FocusMIDIEditor() end
  tick = get_input_csv:match("(.*)")
  if not tonumber(tick) then return reaper.SN_FocusMIDIEditor() end
  reaper.SetExtState("MoveEditCursor", "Tick", tick, false)
  reaper.SetEditCurPos(reaper.MIDI_GetProjTimeFromPPQPos(take, ppq+tick), true, true)
end
script_title = "Move Edit Cursor"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()