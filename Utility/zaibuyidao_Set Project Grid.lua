--[[
 * ReaScript Name: Set Project Grid
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
 * v1.0 (2020-4-25)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local _, cur_grid = reaper.GetSetProjectGrid(0, 0)
cur_grid = math.floor(cur_grid * (midi_tick * 4))
local user_ok, new_grid = reaper.GetUserInputs("Set Project Grid", 1, "Enter A Tick", cur_grid)
if not user_ok then return end
grid_division = new_grid / (midi_tick * 4)
reaper.SetProjectGrid(0, grid_division)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Set Project Grid", 0)