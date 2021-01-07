--[[
 * ReaScript Name: Random Take Pan
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

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
count_sel_items = reaper.CountSelectedMediaItems(0)
reaper.Undo_BeginBlock() -- 撤消塊開始
if count_sel_items > 0 then
    for i = 0, count_sel_items - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        local rand = math.random() * 2 - 1
        reaper.SetMediaItemTakeInfo_Value(take, 'D_PAN', rand)
        reaper.UpdateItemInProject(item)
    end
end
reaper.Undo_EndBlock("Random Take Pan", -1) -- 撤消塊結束