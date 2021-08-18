--[[
 * ReaScript Name: Solo Track
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
 * v1.0 (2021-8-18)
  + Initial release
--]]

local function Msg(str)
    reaper.ShowConsoleMsg(tostring(str).."\n")
end

local function unselect_all_tracks()
    local first_track = reaper.GetTrack(0, 0)
    if first_track ~= nil then
        reaper.SetOnlyTrackSelected(first_track)
        reaper.SetTrackSelected(first_track, false)
    end
end

function NoUndoPoint() end
reaper.PreventUIRefresh(1)
-- reaper.Undo_BeginBlock()

local track_ret, context, track_pos = reaper.BR_TrackAtMouseCursor()

if track_ret then
    if reaper.GetMediaTrackInfo_Value(track_ret, 'I_SOLO') == 2 then
        return
        reaper.SetMediaTrackInfo_Value(track_ret, 'I_SOLO', 0)
    end
    unselect_all_tracks()
    reaper.Main_OnCommand(40340,0) -- Track: Unsolo all tracks
    reaper.SetTrackSelected(track_ret, true)
    reaper.SetMediaTrackInfo_Value(track_ret, 'I_SOLO', 2)
end

-- reaper.Undo_EndBlock("Toggle Solo Track", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(NoUndoPoint)