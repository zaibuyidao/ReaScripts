--[[
 * ReaScript Name: Solo Track (Play From Play State)
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
 * v1.0 (2021-5-31)
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

function NoUndoPoint() end

reaper.PreventUIRefresh(1)
-- reaper.Undo_BeginBlock()

local count_sel_items = reaper.CountSelectedMediaItems(0)
local count_sel_track = reaper.CountSelectedTracks(0)
local item_ret, item_pos = reaper.BR_ItemAtMouseCursor()
local track_ret, context, track_pos = reaper.BR_TrackAtMouseCursor()

if count_sel_track <= 1 then
    if count_sel_items == 0 then -- 優先級最高
        if item_ret then
            UnselectAllTracks()
            reaper.Main_OnCommand(40340,0) -- Track: Unsolo all tracks
            local track = reaper.GetMediaItem_Track(item_ret)
            reaper.SetTrackSelected(track, true)
            reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
        else
            if track_ret then
                UnselectAllTracks()
                reaper.Main_OnCommand(40340,0) -- Track: Unsolo all tracks
                reaper.SetTrackSelected(track_ret, true)
                reaper.SetMediaTrackInfo_Value(track_ret, 'I_SOLO', 2)
            end
        end
    else
        UnselectAllTracks()
        reaper.Main_OnCommand(40340,0) -- Track: Unsolo all tracks
        for m = 0, count_sel_items-1  do
            local item = reaper.GetSelectedMediaItem(0, m)
            local track = reaper.GetMediaItem_Track(item)
            reaper.SetTrackSelected(track, true)
            reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
        end
    end
elseif count_sel_track > 1 then
    reaper.Main_OnCommand(40340,0) -- Track: Unsolo all tracks
    for i = 0, count_sel_track-1 do
        if count_sel_items == 0 then
            local track = reaper.GetSelectedTrack(0, i)
            reaper.SetTrackSelected(track, true)
            reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
        else
            for m = 0, count_sel_items-1  do
                local item = reaper.GetSelectedMediaItem(0, m)
                local track = reaper.GetMediaItem_Track(item)
                reaper.SetTrackSelected(track, true)
                reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
            end
        end
    end
end

-- reaper.Undo_EndBlock("Toggle Solo Track (Play From Play State)", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(NoUndoPoint)