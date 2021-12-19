--[[
 * ReaScript Name: Toggle Solo Track
 * Version: 1.0.1
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

local count_sel_track = reaper.CountSelectedTracks(0)
local screen_x, screen_y = reaper.GetMousePosition()
local track_ret, info_out = reaper.GetTrackFromPoint(screen_x, screen_y)

if count_sel_track <= 1 then
    if track_ret then
        if reaper.GetMediaTrackInfo_Value(track_ret, 'I_SOLO') == 2 then
            return
            reaper.Main_OnCommand(40340,0) -- Track: Unsolo all tracks
        end
        unselect_all_tracks()
        reaper.Main_OnCommand(40340,0) -- Track: Unsolo all tracks
        reaper.SetTrackSelected(track_ret, true)
        reaper.SetMediaTrackInfo_Value(track_ret, 'I_SOLO', 2)
    end
else
    for i = 0, count_sel_track-1 do
        local track = reaper.GetSelectedTrack(0, i)
        if reaper.GetMediaTrackInfo_Value(track, 'I_SOLO') == 2 then return reaper.Main_OnCommand(40340,0) end
    end
    
    reaper.Main_OnCommand(40340, 0) -- Track: Unsolo all tracks
    
    for i = 0, count_sel_track-1 do
        local track = reaper.GetSelectedTrack(0, i)
        reaper.SetTrackSelected(track, true)
        reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
    end
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(NoUndoPoint)