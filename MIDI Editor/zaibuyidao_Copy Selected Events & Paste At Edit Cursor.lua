--[[
 * ReaScript Name: Copy Selected Events & Paste At Edit Cursor
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes or CC Events. Run.
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-2-22)
  + Initial release
--]]

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if take == nil then return end
function SaveCursorPos()
    init_cursor_pos = reaper.GetCursorPosition()
end
function RestoreCursorPos()
    reaper.SetEditCurPos(init_cursor_pos, false, false)
end
function main()
    reaper.MIDIEditor_LastFocused_OnCommand(40010, 0)
    reaper.MIDIEditor_LastFocused_OnCommand(40011, 0)
    reaper.MIDIEditor_LastFocused_OnCommand(40440, 0)
end
reaper.Undo_BeginBlock()
SaveCursorPos()
main()
RestoreCursorPos()
reaper.Undo_EndBlock("Copy Selected Events & Paste At Edit Cursor", 0)
reaper.UpdateArrange()