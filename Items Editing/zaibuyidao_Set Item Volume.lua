--[[
 * ReaScript Name: Set Item Volume
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
 * v1.0 (2021-5-22)
  + Initial release
--]]

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
local count_sel_items = reaper.CountSelectedMediaItems(0)
local log10 = function(x) return math.log(x, 10) end
if count_sel_items > 0 then
    local retval, new_db = reaper.GetUserInputs("Set Item Volume", 1, "New dB:", "")
    if not retval or not tonumber(new_db) then return end
    if retval == true and new_db and tonumber(new_db) then
        for i = 0, count_sel_items-1 do
            local it = reaper.GetSelectedMediaItem(0, i)
            local it_vol = reaper.GetMediaItemInfo_Value(it, 'D_VOL')
            local it_db = 20*log10(it_vol)
            local delta_db = new_db - it_db
            reaper.SetMediaItemInfo_Value(it, 'D_VOL', it_vol*10^(0.05*delta_db))
            reaper.UpdateItemInProject(it)
        end
    end
end
reaper.Undo_EndBlock('Set Item Volume', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()