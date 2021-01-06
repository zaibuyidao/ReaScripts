--[[
 * ReaScript Name: Unselect All Events
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2021-1-7)
  + Initial release
--]]

function Main()
    local editor = reaper.MIDIEditor_GetActive()
    local take = reaper.MIDIEditor_GetTake(editor)
    if take == nil then return end
    reaper.Undo_BeginBlock()
    reaper.MIDI_SelectAll(take, false)
    reaper.Undo_EndBlock("Unselect All Events", -1)
    reaper.UpdateArrange()
end

Main()