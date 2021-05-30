--[[
 * ReaScript Name: Solo Item (Play From First Item Position)
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.1 (2021-5-30)
  + 支持無撤銷點
 * v1.0 (2021-5-28)
  + Initial release
--]]

local function Msg(str)
    reaper.ShowConsoleMsg(tostring(str).."\n")
end

local function UnselAllTrack()
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

local function SaveSelectedItems(t)
    for i = 0, reaper.CountSelectedMediaItems(0)-1 do
        t[i+1] = reaper.GetSelectedMediaItem(0, i)
    end
end

local function RestoreSelectedItems(t)
    reaper.Main_OnCommand(40289, 0) -- Item: Unselect all items
    for _, item in ipairs(t) do
        reaper.SetMediaItemSelected(item, true)
    end
end

local function SaveSelectedTracks(t)
    for i = 0, reaper.CountSelectedTracks(0)-1 do
        t[i+1] = reaper.GetSelectedTrack(0, i)
    end
end

local function RestoreSelectedTracks(t)
    UnselAllTrack()
    for _, track in ipairs(t) do
        reaper.SetTrackSelected(track, true)
    end
end

function NoUndoPoint() end

reaper.PreventUIRefresh(1)
--reaper.Undo_BeginBlock()

cur_pos = reaper.GetCursorPosition()
init_sel_items = {}
init_sel_tracks = {}

SaveSelectedItems(init_sel_items)
--SaveSelectedTracks(init_sel_tracks)

local count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items < 0 then return end
count_sel_track = reaper.CountSelectedTracks(0)
if count_sel_track < 0 then return end

isPlay = reaper.GetPlayState()
snap_t = {}

if isPlay == 0 then
    if count_sel_items == 0 then -- Snap Offset
        local item_ret, position = reaper.BR_ItemAtMouseCursor()
        local track_ret, context, position = reaper.BR_TrackAtMouseCursor()
        if item_ret then
            UnselAllTrack()
            reaper.SelectAllMediaItems(0, false)
            reaper.SetMediaItemSelected(item_ret, true)
            local track = reaper.GetMediaItem_Track(item_ret)
            reaper.SetTrackSelected(track, true)
            local take = reaper.GetActiveTake(item_ret)
            local take_start = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
            local item_snap = reaper.GetMediaItemInfo_Value(item_ret, "D_SNAPOFFSET")
            local item_pos = reaper.GetMediaItemInfo_Value(item_ret, "D_POSITION")
            local snap = item_pos + take_start + item_snap
            reaper.SetEditCurPos(snap, 0, 0)
            reaper.Main_OnCommand(41558,0) -- Item properties: Solo exclusive
            reaper.Main_OnCommand(1007, 0) -- Transport: Play
        else
            if track_ret then
                UnselAllTrack()
                reaper.SetTrackSelected(track_ret, true)
                if context == 2 then
                    reaper.SetEditCurPos(position, 0, 0)
                    reaper.Main_OnCommand(1007, 0) -- Transport: Play
                end
            end
        end
    end
    if count_sel_items > 0 then -- Snap Offset
        UnselAllTrack()
        for m = 0, count_sel_items - 1  do
            local item = reaper.GetSelectedMediaItem(0, m)
            local track = reaper.GetMediaItem_Track(item)
            reaper.SetTrackSelected(track, true)
        end
        for i = 0, count_sel_items-1 do
            local item = reaper.GetSelectedMediaItem(0, i)
            local take = reaper.GetActiveTake(item)
            local take_start = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
            local item_snap = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
            local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local snap = item_pos + take_start + item_snap
            snap_t[#snap_t + 1] = snap
        end
        local snap_pos = TableMin(snap_t)
        reaper.SetEditCurPos(snap_pos, 0, 0)
        reaper.Main_OnCommand(41558,0) -- Item properties: Solo exclusive
        reaper.Main_OnCommand(1007, 0) -- Transport: Play
    end
end

if isPlay == 1 then
    reaper.Main_OnCommand(1016, 0) -- Transport: Stop
    reaper.Main_OnCommand(41185,0) -- Item properties: Unsolo all
end

reaper.SetEditCurPos(cur_pos, false, false)
--reaper.Undo_EndBlock("Solo Item (Play From First Item Position)", -1)
RestoreSelectedItems(init_sel_items)
--RestoreSelectedTracks(init_sel_tracks)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(NoUndoPoint)