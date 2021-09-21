--[[
 * ReaScript Name: Toggle Solo Track (Auto Solo)
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Reference: Script: me2beats_Auto solo for selected tracks (defer).lua
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2021-6-28)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

function main()
  local change_count = reaper.GetProjectStateChangeCount()
  if not last_count or last_count ~= change_count then
    reaper.PreventUIRefresh(1)
    count_track = reaper.CountTracks()
    for i = 0, count_track-1 do
      local get_track = reaper.GetTrack(0, i)
      local sel_track = reaper.IsTrackSelected(get_track)
      local solo = reaper.GetMediaTrackInfo_Value(get_track, 'I_SOLO')
      if sel_track then
        if solo == 0 then reaper.SetMediaTrackInfo_Value(get_track, 'I_SOLO', 2) end
      elseif solo ~= 0 then
        reaper.SetMediaTrackInfo_Value(get_track, 'I_SOLO', 0)
      end
    end
    reaper.PreventUIRefresh(-1)
  end
  last_count = change_count
  reaper.defer(main)
end

(function()
  local _, _, sectionId, cmdId = reaper.get_action_context()
  if sectionId ~= -1 then
    reaper.SetToggleCommandState(sectionId, cmdId, 1)
    reaper.RefreshToolbar2(sectionId, cmdId)
    main()
    reaper.atexit(function()
      reaper.SoloAllTracks(0)
      reaper.SetToggleCommandState(sectionId, cmdId, 0)
      reaper.RefreshToolbar2(sectionId, cmdId)
    end)
  end
end)()
