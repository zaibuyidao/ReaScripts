--[[
 * ReaScript Name: Solo Track Play From Edit Cursor Position
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
 * v1.0 (2021-9-20)
  + Initial release
--]]

function print(string) reaper.ShowConsoleMsg(tostring(string)..'\n') end

local function UnSelectAllTracks() -- 反選所有軌道
    local first_track = reaper.GetTrack(0, 0)
    if first_track ~= nil then
        reaper.SetOnlyTrackSelected(first_track)
        reaper.SetTrackSelected(first_track, false)
    end
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

function NoUndoPoint() end

count_sel_items = reaper.CountSelectedMediaItems(0)
count_sel_track = reaper.CountSelectedTracks(0)

cur_pos = reaper.GetCursorPosition()
isPlay = reaper.GetPlayState()
snap_t = {}

reaper.PreventUIRefresh(1)

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

if isPlay == 0 then
    local item_ret, item_mouse_pos = reaper.BR_ItemAtMouseCursor()
    if item_ret then
        take = reaper.GetActiveTake(item_ret)
        take_tarck = reaper.GetMediaItemTake_Track(take)
        check_track = reaper.GetMediaTrackInfo_Value(take_tarck, 'I_SELECTED')
        take_start = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
        item_snap = reaper.GetMediaItemInfo_Value(item_ret, "D_SNAPOFFSET")
        item_pos = reaper.GetMediaItemInfo_Value(item_ret, "D_POSITION")
        snap = item_pos + item_snap
    end
    local track_ret, context, track_mouse_pos = reaper.BR_TrackAtMouseCursor()

    if count_sel_track <= 1 then
        UnSelectAllTracks()
        reaper.Main_OnCommand(40340,0) -- Track: Unsolo all tracks
        reaper.SetEditCurPos(cur_pos, 0, 0)
        reaper.Main_OnCommand(1007, 0) -- Transport: Play
        if count_sel_track == 0 then
            if count_sel_items == 0 then
                reaper.SetTrackSelected(track_ret, true) -- 將軌道設置為選中
                reaper.SetMediaTrackInfo_Value(track_ret, 'I_SOLO', 2)
            else
                local selected_track = {} -- 选中的轨道
                for m = 0, count_sel_items - 1  do
                    local item = reaper.GetSelectedMediaItem(0, m)
                    local track = reaper.GetMediaItem_Track(item)
                    if (not selected_track[track]) then
                        selected_track[track] = true
                    end
                end
    
                for track, _ in pairs(selected_track) do
                    reaper.SetTrackSelected(track, true) -- 將軌道設置為選中
                    reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
                end
            end
        else
            reaper.SetTrackSelected(track_ret, true) -- 將軌道設置為選中
            reaper.SetMediaTrackInfo_Value(track_ret, 'I_SOLO', 2)
        end
    elseif count_sel_track > 1 then
        if track_ret then
            reaper.Main_OnCommand(40340,0) -- Track: Unsolo all tracks
            reaper.SetEditCurPos(cur_pos, 0, 0)
            reaper.Main_OnCommand(1007, 0) -- Transport: Play
            for i = 0, count_sel_track-1 do
                local track = reaper.GetSelectedTrack(0, i)
                reaper.SetTrackSelected(track, true)
                reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
            end
        end
    end
end

if isPlay == 1 then
    reaper.Main_OnCommand(1016, 0) -- Transport: Stop
    if count_sel_items == 0  then
        for i = 0, reaper.CountTracks(0) - 1 do
            local track = reaper.GetSelectedTrack(0, i)
            if track ~= nil then
                local solo = reaper.GetMediaTrackInfo_Value(track, "I_SOLO")
                if solo == 2 then solo = 0 end
                reaper.SetMediaTrackInfo_Value(track, "I_SOLO", solo)
            end
        end
    else
        for i = 0, count_sel_track-1 do
            track = reaper.GetSelectedTrack(0, i)
            reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 0)
        end
    end
end

reaper.SetEditCurPos(cur_pos, false, false)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(NoUndoPoint)