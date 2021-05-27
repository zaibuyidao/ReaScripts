--[[
 * ReaScript Name: Solo Selected Item Link Track (Play From First Item Position)
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
 * v1.0 (2021-5-28)
  + Initial release
--]]

local function Msg(str)
    reaper.ShowConsoleMsg(tostring(str).."\n")
end

function UnselectAllTracks()
    first_track = reaper.GetTrack(0, 0)
    reaper.SetOnlyTrackSelected(first_track)
    reaper.SetTrackSelected(first_track, false)
end

function table_max(t)
    local mn = nil
    for k, v in pairs(t) do
        if (mn == nil) then mn = v end
        if mn < v then mn = v end
    end
    return mn
end

function table_min(t)
    local mn = nil
    for k, v in pairs(t) do
        if (mn == nil) then mn = v end
        if mn > v then mn = v end
    end
    return mn
end

local function SaveSelectedTracks(table)
    for i = 0, reaper.CountSelectedTracks(0)-1 do
        table[i+1] = reaper.GetSelectedTrack(0, i)
    end
end

local function RestoreSelectedTracks(table)
    UnselectAllTracks()
    for _, track in ipairs(table) do
        reaper.SetTrackSelected(track, true)
    end
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

cur_pos = reaper.GetCursorPosition()
init_sel_tracks = {}
SaveSelectedTracks(init_sel_tracks)

local count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items < 0 then return end

isPlay = reaper.GetPlayState()

UnselectAllTracks()
for m = 0, count_sel_items - 1  do
    local item = reaper.GetSelectedMediaItem(0, m)
    local track = reaper.GetMediaItem_Track(item)
    reaper.SetTrackSelected(track, true)
end

count_sel_track = reaper.CountSelectedTracks(0)
if count_sel_track < 0 then return end

for i = 0, count_sel_track - 1 do
    track = reaper.GetSelectedTrack(0, i)
    count_track_items = reaper.CountTrackMediaItems(track)
    reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
end

local len_start = {}
local len_last = {}
local len_end = {}

if count_sel_items > 0 then
    for i = 1, count_sel_items do
        local item = reaper.GetSelectedMediaItem(0, i - 1)
        local len_last_item = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local len_pos_item = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local len_end_item = len_pos_item + len_last_item

        len_start[#len_start + 1] = len_pos_item
        len_last[#len_last + 1] = len_last_item
        len_end[#len_end + 1] = len_end_item
    end

    far_start_pos = table_max(len_start) -- 最遠的開始位置
    near_start_pos = table_min(len_start) -- 最近的開始位置
    far_end_pos = table_max(len_end) -- 最遠的結束位置

end
if near_start_pos ~= nil then
    reaper.SetEditCurPos(near_start_pos, 0, 0)
    reaper.Main_OnCommand(1007, 0)
end

if isPlay == 1 then
    reaper.Main_OnCommand(1016, 0)
    for i = 0, count_sel_track - 1 do
        track = reaper.GetSelectedTrack(0, i)
        count_track_items = reaper.CountTrackMediaItems(track)
        reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 0)
    end
end

reaper.SetEditCurPos(cur_pos, false, false)
reaper.Undo_EndBlock("Solo Selected Item Link Track (Play From First Item Position)", -1)
RestoreSelectedTracks(init_sel_tracks)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()