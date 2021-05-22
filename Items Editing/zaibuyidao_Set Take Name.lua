--[[
 * ReaScript Name: Set Take Name
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
if count_sel_items > 0 then
    local retval, retvals_csv = reaper.GetUserInputs('Set Take Name', 1, 'New Name,extrawidth=150', '')
    if not retval or not (tonumber(retvals_csv) or tostring(retvals_csv)) then return end
    for i = 0, count_sel_items - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        local take_name = reaper.GetTakeName(take)
        reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', retvals_csv, true)
    end
end
reaper.Undo_EndBlock('Set Take Name', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()