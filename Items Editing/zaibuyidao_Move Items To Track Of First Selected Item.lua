--[[
 * ReaScript Name: Move Items To Track Of First Selected Item
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2022-3-27)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end
count_sel_items = reaper.CountSelectedMediaItems(0)
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
if count_sel_items > 0 then
    for i = 0, count_sel_items - 1 do
        item = reaper.GetSelectedMediaItem(0, i)
        if i == 0 then 
          track = reaper.GetMediaItem_Track(item)
        end
        reaper.MoveMediaItemToTrack(item, track)
    end
end
reaper.Undo_EndBlock("Move Items To Track Of First Selected Item", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()