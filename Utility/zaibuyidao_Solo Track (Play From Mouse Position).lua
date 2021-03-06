--[[
 * ReaScript Name: Solo Track (Play From Mouse Position)
 * Version: 1.4
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.3 (2021-6-5)
  + 優化提速
 * v1.2 (2021-5-31)
  + 修復Snap錯誤
 * v1.1 (2021-5-30)
  + 支持無撤銷點
 * v1.0 (2021-5-28)
  + Initial release
--]]

local function Msg(str)
    reaper.ShowConsoleMsg(tostring(str).."\n")
end

local function UnselectAllTracks()
    local first_track = reaper.GetTrack(0, 0)
    if first_track ~= nil then
        reaper.SetOnlyTrackSelected(first_track)
        reaper.SetTrackSelected(first_track, false)
    end
end

local function SaveSelectedTracks(t)
    for i = 0, reaper.CountSelectedTracks(0)-1 do
        t[i+1] = reaper.GetSelectedTrack(0, i)
    end
end

local function RestoreSelectedTracks(t)
    UnselectAllTracks()
    for _, track in ipairs(t) do
        reaper.SetTrackSelected(track, true)
    end
end

function NoUndoPoint() end

reaper.PreventUIRefresh(1)
-- reaper.Undo_BeginBlock()

cur_pos = reaper.GetCursorPosition()
init_sel_tracks = {}
-- SaveSelectedTracks(init_sel_tracks)

local count_sel_items = reaper.CountSelectedMediaItems(0)
local count_sel_track = reaper.CountSelectedTracks(0)

isPlay = reaper.GetPlayState()

if isPlay == 0 then
    local item_ret, item_mouse_pos = reaper.BR_ItemAtMouseCursor()
    local track_ret, context, track_mouse_pos = reaper.BR_TrackAtMouseCursor()
    if count_sel_track <= 1 then
        if track_ret then
            UnselectAllTracks()
            reaper.Main_OnCommand(40340,0) -- Track: Unsolo all tracks
            reaper.SetEditCurPos(track_mouse_pos, 0, 0)
            reaper.Main_OnCommand(1007, 0) -- Transport: Play
            if count_sel_items == 0 then
                reaper.SetTrackSelected(track_ret, true)
                reaper.SetMediaTrackInfo_Value(track_ret, 'I_SOLO', 2)
            else
                for m = 0, count_sel_items-1  do
                    local item = reaper.GetSelectedMediaItem(0, m)
                    local track = reaper.GetMediaItem_Track(item)
                    reaper.SetTrackSelected(track, true)
                    reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
                end
            end
        end
    elseif count_sel_track > 1 then
        if track_ret then
            reaper.Main_OnCommand(40340,0) -- Track: Unsolo all tracks
            reaper.SetEditCurPos(track_mouse_pos, 0, 0)
            reaper.Main_OnCommand(1007, 0) -- Transport: Play
            for i = 0, count_sel_track-1 do
                if count_sel_items == 0 then
                    local track = reaper.GetSelectedTrack(0, i)
                    reaper.SetTrackSelected(track, true)
                    reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
                else
                    UnselectAllTracks()
                    for m = 0, count_sel_items-1  do
                        local item = reaper.GetSelectedMediaItem(0, m)
                        local track = reaper.GetMediaItem_Track(item)
                        reaper.SetTrackSelected(track, true)
                        reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
                    end
                end
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
                reaper.SetMediaTrackInfo_Value(track, "I_SOLO",solo)
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
-- reaper.Undo_EndBlock("Solo Track (Play From Mouse Position)", -1)
-- RestoreSelectedTracks(init_sel_tracks)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(NoUndoPoint)