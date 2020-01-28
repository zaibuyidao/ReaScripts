--[[
 * ReaScript Name: Move Edit Cursor +10
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

local tick = 10

script_title = "Move Edit Cursor +10"
reaper.Undo_BeginBlock()
local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local pos = reaper.GetCursorPositionEx()
local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
reaper.SetEditCurPos(reaper.MIDI_GetProjTimeFromPPQPos(take, ppq+tick), true, true)
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()