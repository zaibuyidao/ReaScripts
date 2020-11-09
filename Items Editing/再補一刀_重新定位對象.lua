--[[
 * ReaScript Name: 重新定位對象
 * Version: 1.1
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-11-6)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end

count_sel_items = reaper.CountSelectedMediaItems(0)

if count_sel_items > 0 then
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock() -- 撤消塊開始

    local interval = reaper.GetExtState("RepositionItems", "Interval")
    local toggle = reaper.GetExtState("RepositionItems", "Toggle")
    if (interval == "") then interval = "1" end
    if (toggle == "") then toggle = "1" end

    local user_ok, user_input_csv = reaper.GetUserInputs("重新定位對象", 2, "時間間隔(秒),0=對象開始 1=對象結束", interval ..','.. toggle)
    if not user_ok or not tonumber(interval) then return end
    interval, toggle = user_input_csv:match("(.*),(.*)")
    if not tonumber(interval) or not tonumber(toggle) then return end

    reaper.SetExtState("RepositionItems", "Interval", interval, false)
    reaper.SetExtState("RepositionItems", "Toggle", toggle, false)

    local item_list = {} -- 收集所有選定item

    for i = 0, count_sel_items - 1 do
        item = reaper.GetSelectedMediaItem(0, i)
        table.insert(item_list, item)
    end

    for k, item in ipairs(item_list) do
        item_next_start = reaper.GetMediaItemInfo_Value(item_list[k], "D_POSITION")
        item_next_end = reaper.GetMediaItemInfo_Value(item_list[k], "D_LENGTH") + item_next_start
        
        if k < count_sel_items then
            if toggle == "1" then
                reaper.SetMediaItemInfo_Value(item_list[k + 1], "D_POSITION", item_next_end + interval)
            elseif toggle == "0" then
                reaper.SetMediaItemInfo_Value(item_list[k + 1], "D_POSITION", item_next_start + interval)
            end
        end
    end

    reaper.Undo_EndBlock("重新定位對象", -1) -- 撤消塊結束
    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)
end
