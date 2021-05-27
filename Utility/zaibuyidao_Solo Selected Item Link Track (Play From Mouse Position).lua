--[[
 * ReaScript Name: Solo Selected Item Link Track (Play From Mouse Position)
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

if count_sel_items > 0 then
	reaper.BR_ItemAtMouseCursor()
    retval, context, position = reaper.BR_TrackAtMouseCursor()
	if context == 2 then
        reaper.SetEditCurPos(position, 0, 0)
        reaper.Main_OnCommand(1007, 0)
    end
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