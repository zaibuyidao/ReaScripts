--[[
 * ReaScript Name: Show FX Chain For Selected Track-Item
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

function Msg(string) reaper.ShowConsoleMsg(tostring(string) .. '\n') end

item_keep = false
track_keep = false

function main()
  -- 標記某個item的fx窗口是否已生效(被打開), 如果已生效後續操作將關閉所有item/track的fx窗口
  local item_processed = false
  local track_processed = false
  local closes = {}

  -- item 處理
  local item_count = reaper.CountMediaItems(0)
  for item_idx = 0, item_count - 1 do
    local item = reaper.GetMediaItem(0, item_idx)
    local take = reaper.GetTake(item, 0)
    take_fx_count = reaper.TakeFX_GetCount(take)
    if reaper.IsMediaItemSelected(item) and take_fx_count > 0 then
      item_processed = true
    end
  end

  for item_idx = 0, item_count - 1 do
    local item = reaper.GetMediaItem(0, item_idx)
    local take = reaper.GetTake(item, 0)
    take_fx_count = reaper.TakeFX_GetCount(take)
    fx = reaper.TakeFX_GetChainVisible(take)
    if not reaper.IsMediaItemSelected(item) or take_fx_count <= 0 then
      if not item_keep or item_processed then
        reaper.TakeFX_SetOpen(take, fx, false)
      end
    else
      item_processed = true
      if not reaper.TakeFX_GetOpen(take, 0) then
        reaper.TakeFX_SetOpen(take, fx, true)
      end
    end
  end

  -- track 處理
  local track_count = reaper.CountTracks(0)

  for track_idx = 0, track_count - 1 do
    local track = reaper.GetTrack(0, track_idx)
    local track_fx_count = reaper.TrackFX_GetCount(track)
    local fx = reaper.TrackFX_GetChainVisible(track)
    if not item_processed and reaper.IsTrackSelected(track) and track_fx_count > 0 then
      track_processed = true
    end
  end

  for track_idx = 0, track_count - 1 do
    local track = reaper.GetTrack(0, track_idx)
    local track_fx_count = reaper.TrackFX_GetCount(track)
    local fx = reaper.TrackFX_GetChainVisible(track)
    if item_processed or not reaper.IsTrackSelected(track) or track_fx_count <= 0 then
      if not track_keep or track_processed then
        reaper.TrackFX_SetOpen(track, fx, false)
      end
    else
      if not reaper.TrackFX_GetOpen(track, 0) then
        reaper.TrackFX_SetOpen(track, fx, true)
      end
    end
  end

  reaper.defer(main)
end

main()