--[[
 * ReaScript Name: Show List Of Selected Items
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
 * v1.0 (2022-3-20)
  + Initial release
--]]

local function Msg(str)
  reaper.ShowConsoleMsg(tostring(str).."\n")
end
reaper.PreventUIRefresh(1)
count_sel_items = reaper.CountSelectedMediaItems(0)
reaper.ClearConsole()
for i = 0, count_sel_items - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  local take = reaper.GetActiveTake(item)
  if take then
    local name = reaper.GetTakeName(take)
    Msg(name)
  end
end
Msg("")
Msg("Total: "..count_sel_items)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(function() end)