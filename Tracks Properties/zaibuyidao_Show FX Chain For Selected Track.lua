--[[
 * ReaScript Name: Show FX Chain For Selected Track
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
 * v1.0 (2021-10-16)
  + Initial release
--]]

track_keep = false

function Msg(string) reaper.ShowConsoleMsg(tostring(string) .. '\n') end

function updateTracksFx()
  local track_count = reaper.CountTracks(0)
  for track_idx = 0, track_count - 1 do
    value = reaper.CF_EnumSelectedFX(reaper.CF_GetTrackFXChain(reaper.GetTrack(0, track_idx)), -1)
    if value >= 0 then
      tracks_fx[track_idx] = value
    end
  end
end

function hasTrackFxOpen(track)
  local cnt = reaper.TrackFX_GetCount(track)
  for i = 0, cnt - 1 do
    if reaper.TrackFX_GetOpen(track, i) then
      return true
    end
  end
  return false
end

tracks_fx = {}

function main()
  
  updateTracksFx()

  -- 標記某個track的fx窗口是否已生效(被打開), 如果已生效後續操作將關閉所有track的fx窗口
  local track_processed = false
  local track_count = reaper.CountTracks(0)

  for track_idx = 0, track_count - 1 do
    local track = reaper.GetTrack(0, track_idx)
    local track_fx_count = reaper.TrackFX_GetCount(track)
    local fx = reaper.TrackFX_GetChainVisible(track)
    -- if reaper.IsTrackSelected(track) and track_fx_count > 0 then
    if reaper.IsTrackSelected(track) then
      track_processed = true
    end
  end

  for track_idx = 0, track_count - 1 do
    local track = reaper.GetTrack(0, track_idx)
    local track_fx_count = reaper.TrackFX_GetCount(track)
    local fx = reaper.TrackFX_GetChainVisible(track)
    if not reaper.IsTrackSelected(track) or track_fx_count <= 0 then
      reaper.PreventUIRefresh(1)
      -- if not track_keep or track_processed then
      if not track_keep then
        reaper.TrackFX_SetOpen(track, fx, false)
      end
    else
      if not hasTrackFxOpen(track) then
        reaper.TrackFX_SetOpen(track, tracks_fx[track_idx] or fx, true)
      end
    end
    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)
  end

  reaper.defer(main)
  
end

main()