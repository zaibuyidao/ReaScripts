--[[
 * ReaScript Name: Set Project Grid
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
 * v1.0 (2020-4-25)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
function main()
    reaper.Undo_BeginBlock()
    midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
    grid_tick = reaper.GetExtState("SetProjectGrid", "Tick")
    if (grid_tick == "") then grid_tick = "480" end
    user_ok, grid_tick = reaper.GetUserInputs("Set Project Grid", 1, "Enter A Tick", grid_tick)
    if not user_ok then return end
    reaper.SetExtState("SetProjectGrid", "Tick", grid_tick, false)
    grid_division = grid_tick / (midi_tick * 4)
    reaper.SetProjectGrid(0, grid_division)
    reaper.Undo_EndBlock("Set Project Grid", 0)
end
reaper.PreventUIRefresh(1)
main()
reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)