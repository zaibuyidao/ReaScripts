--[[
 * ReaScript Name: Play Stop From First Selected Item Position
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

local function TableMax(t)
    local mn = nil
    for k, v in pairs(t) do
        if (mn == nil) then mn = v end
        if mn < v then mn = v end
    end
    return mn
end

local function TableMin(t)
    local mn = nil
    for k, v in pairs(t) do
        if (mn == nil) then mn = v end
        if mn > v then mn = v end
    end
    return mn
end

reaper.PreventUIRefresh(1)
local cur_pos = reaper.GetCursorPosition()
local count_sel_items = reaper.CountSelectedMediaItems(0)
isPlay = reaper.GetPlayState()

if isPlay == 0 then
    local screen_x, screen_y = reaper.GetMousePosition()
    local item_ret, take = reaper.GetItemFromPoint(screen_x, screen_y, true)
    local track_ret, info_out = reaper.GetTrackFromPoint(screen_x, screen_y)

    snap_t = {}
    if count_sel_items > 0 then
        for i = 0, count_sel_items-1 do
            local item = reaper.GetSelectedMediaItem(0, i)
            local take = reaper.GetActiveTake(item)
            local take_start = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
            local item_snap = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
            local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local snap = item_pos + item_snap
            snap_t[#snap_t + 1] = snap
        end
        snap_pos = TableMin(snap_t)
    end

    if item_ret then
        item_snap = reaper.GetMediaItemInfo_Value(item_ret, "D_SNAPOFFSET")
        item_pos = reaper.GetMediaItemInfo_Value(item_ret, "D_POSITION")
        snap = item_pos + item_snap
    end

    if count_sel_items == 0 then -- 沒有item被選中
        if item_ret then
            reaper.SetEditCurPos(snap, 0, 0)
            reaper.Main_OnCommand(1007, 0) -- Transport: Play
        else
            reaper.Main_OnCommand(40514, 0) -- View: Move edit cursor to mouse cursor (no snapping)
            reaper.Main_OnCommand(1007, 0) -- Transport: Play
        end
    else
        reaper.SetEditCurPos(snap_pos, 0, 0)
        reaper.Main_OnCommand(1007, 0) -- Transport: Play
    end
end

if isPlay == 1 then
    reaper.Main_OnCommand(1016, 0) -- Transport: Stop
end

reaper.SetEditCurPos(cur_pos, 0, 0)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(function() end)