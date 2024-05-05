-- @description Set Selected Items to Matching Region Colors
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

count_sel_items = reaper.CountSelectedMediaItems(0)

if count_sel_items > 0 then
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()
    for i = 0, count_sel_items - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local marker_idx, region_idx = reaper.GetLastMarkerAndCurRegion(0, item_pos)
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, region_idx)

        if retval > 0 then
            if take then
                reaper.SetMediaItemTakeInfo_Value(take, "I_CUSTOMCOLOR", color, true)
            else
                reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color, true)
            end
        end
    end
    reaper.Undo_EndBlock("Set Selected Items to Matching Region Colors", -1)
    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)
end
