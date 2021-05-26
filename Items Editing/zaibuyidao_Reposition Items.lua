--[[
 * ReaScript Name: Reposition Items
 * Version: 1.2
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.2 (2021-5-26)
  + 增加軌道定位
 * v1.0 (2020-11-6)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end

count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items < 0 then return end

function UnselectAllTracks()
    first_track = reaper.GetTrack(0, 0)
    reaper.SetOnlyTrackSelected(first_track)
    reaper.SetTrackSelected(first_track, false)
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock() -- 撤消塊開始

local interval = reaper.GetExtState("RepositionItems", "Interval")
local toggle = reaper.GetExtState("RepositionItems", "Toggle")
local mode = reaper.GetExtState("RepositionItems", "Mode")
if (interval == "") then interval = "0" end
if (toggle == "") then toggle = "1" end
if (mode == "") then mode = "0" end

local user_ok, user_input_csv = reaper.GetUserInputs("Reposition Items", 3, "Time interval (s),0=Item start 1=Item end,0=Track 1=Time", interval .. ',' .. toggle .. ',' .. mode)
if not user_ok or not tonumber(interval) or not tonumber(toggle) or not tonumber(mode) then return end
interval, toggle, mode = user_input_csv:match("(.*),(.*),(.*)")
if not tonumber(interval) or not tonumber(toggle) or not tonumber(mode) then return end

reaper.SetExtState("RepositionItems", "Interval", interval, false)
reaper.SetExtState("RepositionItems", "Toggle", toggle, false)
reaper.SetExtState("RepositionItems", "Mode", mode, false)

if mode == '1' then
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
elseif mode == '0' then

    UnselectAllTracks()
    for m = 0, count_sel_items - 1  do
        local item = reaper.GetSelectedMediaItem(0, m)
        local track = reaper.GetMediaItem_Track(item)
        reaper.SetTrackSelected(track, true)
    end
    
    count_sel_track = reaper.CountSelectedTracks(0)
    for i = 0, count_sel_track - 1 do
        track = reaper.GetSelectedTrack(0, i)
        count_track_items = reaper.CountTrackMediaItems(track)
        sel_item_track = {}
        item_num_new = {}
        item_num_order = 1 
        
        for j = 0, count_track_items - 1  do
            item = reaper.GetTrackMediaItem(track, j)
            if reaper.IsMediaItemSelected(item) == true then
                sel_item_track[item_num_order] = item
                item_num_new[item_num_order] = reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
                item_num_order = item_num_order + 1
            end
        end
        
        for k = 1, item_num_order - 1 do
            item2_next_start = reaper.GetMediaItemInfo_Value(sel_item_track[k], "D_POSITION")
            item2_next_end = reaper.GetMediaItemInfo_Value(sel_item_track[k], "D_LENGTH") + item2_next_start
    
            if k < item_num_order - 1 then
                if toggle == "1" then
                    reaper.SetMediaItemInfo_Value(sel_item_track[k + 1], "D_POSITION", item2_next_end + interval)
                elseif toggle == "0" then
                    reaper.SetMediaItemInfo_Value(sel_item_track[k + 1], "D_POSITION", item2_next_start + interval)
                end
            end
        end
    end
end

reaper.Undo_EndBlock("Reposition Items", -1) -- 撤消塊結束
reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)