--[[
 * ReaScript Name: Select All Note In Take
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-9-5)
  + Initial release
--]]

function Main()
    reaper.PreventUIRefresh(1)
    local editor = reaper.MIDIEditor_GetActive()
    local take = reaper.MIDIEditor_GetTake(editor)
    if (take == nil) then return end
    reaper.Undo_BeginBlock()
    reaper.MIDIEditor_OnCommand(editor, 40214) -- Edit: Unselect all
    reaper.MIDI_SelectAll(take, true)
    reaper.Undo_EndBlock("Select All Note In Take", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

Main()