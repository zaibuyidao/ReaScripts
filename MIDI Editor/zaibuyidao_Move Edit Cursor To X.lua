--[[
 * ReaScript Name: Move Edit Cursor To X
 * Instructions: Open a MIDI take in MIDI Editor. Run.
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
  userOK, get_input = reaper.GetUserInputs("Move Edit Cursor", 1, "Tick", "10")
  if not userOK then return reaper.SN_FocusMIDIEditor() end
  tick = get_input:match("(.*)")
  if not tick:match('[%d%.]+') then return reaper.SN_FocusMIDIEditor() end
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  local pos = reaper.GetCursorPositionEx()
  local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
  reaper.SetEditCurPos(reaper.MIDI_GetProjTimeFromPPQPos(take, ppq+tick), true, true)
end

script_title = "Move Edit Cursor To X"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()