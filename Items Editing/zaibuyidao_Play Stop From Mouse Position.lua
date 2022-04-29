--[[
 * ReaScript Name: Play Stop From Mouse Position
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0 or newer recommended
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2022-4-29)
  + Initial release
--]]

local function Msg(str)
    reaper.ShowConsoleMsg(tostring(str).."\n")
end

reaper.PreventUIRefresh(1)
local cur_pos = reaper.GetCursorPosition()
isPlay = reaper.GetPlayState()

if isPlay == 0 then
    reaper.Main_OnCommand(40514, 0) -- View: Move edit cursor to mouse cursor (no snapping)
    reaper.Main_OnCommand(1007, 0) -- Transport: Play
end

if isPlay == 1 then
    reaper.Main_OnCommand(1016, 0) -- Transport: Stop
end

reaper.SetEditCurPos(cur_pos, 0, 0)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(function() end)