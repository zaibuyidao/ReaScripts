--[[
 * ReaScript Name: Reposition Items
 * Version: 1.4
 * Author: zaibuyidao & acendan
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0 or newer recommended
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.4 (2023-04-28)
  + Support h:m:s:f intervals
 * v1.3.1 (2022-3-26)
  + 優化時間模式
 * v1.0 (2020-11-6)
  + Initial release
--]]

function Msg(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items < 0 then return end

function get_item_pos()
    local t = {}
    for i = 1, reaper.CountSelectedMediaItems(0) do
        t[i] = {}
        local item = reaper.GetSelectedMediaItem(0, i-1)
        track = reaper.GetMediaItem_Track(item)
        take = reaper.GetActiveTake(item)

        if item ~= nil then
          t[i].item = item
          t[i].pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
          t[i].len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
          t[i].pitch = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
          t[i].takename = reaper.GetTakeName(take)
        end
    end
    return t
end

sort_func = function(a,b)
    if (a.pos == b.pos) then
        return a.pitch < b.pitch
    end
    if (a.pos < b.pos) then
        return true
    end
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local interval = reaper.GetExtState("RepositionItems", "Interval")
local toggle = reaper.GetExtState("RepositionItems", "Toggle")
local mode = reaper.GetExtState("RepositionItems", "Mode")
if (interval == "") then interval = "0" end
if (toggle == "") then toggle = "1" end
if (mode == "") then mode = "2" end

local retval, retvals_csv = reaper.GetUserInputs("Reposition Items", 3, "Time Interval (s, h:m:s:f),0=Start 1=End,0=Track 1=Wrap 2=Timeline", interval .. ',' .. toggle .. ',' .. mode)
if not retval then return end
interval, toggle, mode = retvals_csv:match("(.*),(.*),(.*)")

-- parse toggle/mode
if not tonumber(toggle) or not tonumber(mode) then return end
reaper.SetExtState("RepositionItems", "Toggle", toggle, false)
reaper.SetExtState("RepositionItems", "Mode", mode, false)

-- parse interval, check h:m:s.f
if interval:find(":") > 0 then 
  local interval_to_sec = reaper.parse_timestr_len(interval, 0, 5)
  if interval_to_sec == 0.0 then reaper.ShowMessageBox("Failed to parse interval as h:s:m:f!", "Reposition Items", 0); return end
  reaper.SetExtState("RepositionItems", "Interval", interval, false)
  interval = interval_to_sec
else
  if not tonumber(interval) then return end
  reaper.SetExtState("RepositionItems", "Interval", interval, false)
end

if mode == '0' then
    for i = 0, count_sel_items - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local track = reaper.GetMediaItem_Track(item)
        local count_track_items = reaper.CountTrackMediaItems(track)
        sel_item_track = {}
        item_num_new = {}
        item_num_order = 1 
      
        for j = 0, count_track_items - 1 do
            local item = reaper.GetTrackMediaItem(track, j)
            if reaper.IsMediaItemSelected(item) == true then
                sel_item_track[item_num_order] = item
                item_num_new[item_num_order] = reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
                item_num_order = item_num_order + 1
            end
        end
  
        for k = 1, item_num_order - 1 do
            local item_next_start = reaper.GetMediaItemInfo_Value(sel_item_track[k], "D_POSITION")
            local item_next_end = reaper.GetMediaItemInfo_Value(sel_item_track[k], "D_LENGTH") + item_next_start

            if k < item_num_order - 1 then
                if toggle == "1" then
                    reaper.SetMediaItemInfo_Value(sel_item_track[k + 1], "D_POSITION", item_next_end + interval)
                elseif toggle == "0" then
                    reaper.SetMediaItemInfo_Value(sel_item_track[k + 1], "D_POSITION", item_next_start + interval)
                end
            end
        end
    end
elseif mode == '1' then
    local item_list = {}
    
    for i = 0, count_sel_items - 1 do
        item = reaper.GetSelectedMediaItem(0, i)
        table.insert(item_list, item)
    end
    
    for k, item in ipairs(item_list) do
        local item_next_start = reaper.GetMediaItemInfo_Value(item_list[k], "D_POSITION")
        local item_next_end = reaper.GetMediaItemInfo_Value(item_list[k], "D_LENGTH") + item_next_start

        if k < count_sel_items then
            if toggle == "1" then
                reaper.SetMediaItemInfo_Value(item_list[k + 1], "D_POSITION", item_next_end + interval)
            elseif toggle == "0" then
                reaper.SetMediaItemInfo_Value(item_list[k + 1], "D_POSITION", item_next_start + interval)
            end
        end
    end
elseif mode == '2' then
    local data = get_item_pos()
    table.sort(data, sort_func)

    for i = 1, #data do
        local item_next_start = reaper.GetMediaItemInfo_Value(data[i].item, "D_POSITION")
        local item_next_end = reaper.GetMediaItemInfo_Value(data[i].item, "D_LENGTH") + item_next_start

        if i < #data then
            if toggle == "1" then
                reaper.SetMediaItemInfo_Value(data[i+1].item, "D_POSITION", item_next_end + interval)
            elseif toggle == "0" then
                reaper.SetMediaItemInfo_Value(data[i+1].item, "D_POSITION", item_next_start + interval)
            end
        end
    end
end

reaper.Undo_EndBlock("Reposition Items", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
