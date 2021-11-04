--[[
 * ReaScript Name: Open FX Panel For Selected Track
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
 * v1.0 (2021-11-4)
  + Initial release
--]]

function Msg(string) reaper.ShowConsoleMsg(tostring(string) .. '\n') end

keep_fx = true        -- true or false -- Keep window open when no track is selected
opened_fx_tracks = {} -- 已經打開的fx窗口的track

function forEachSelectedTracks(block) -- 遍歷選中track
  local master_track = reaper.GetMasterTrack(0)
  if reaper.IsTrackSelected(master_track) then
    block(master_track, -1)
  end

  local selected_track_count = reaper.CountSelectedTracks(0)
  for track_idx = 0, selected_track_count - 1 do
    block(reaper.GetSelectedTrack(0, track_idx), track_idx)
  end
end

function forEachSelectedFxTracks(block) -- 遍歷帶有fx的選中track
  forEachSelectedTracks(function (track, id)
    local fx_count = reaper.TrackFX_GetCount(track)
    if fx_count > 0 then
      block(track, id, fx_count)
    end
  end)
end

function countSelectedFxTracks()
  local count = 0
  forEachSelectedFxTracks(function () count = count + 1 end)
  return count
end

function hasTrackFxOpen(track) -- track是否存在一個打開的fx窗口
  local cnt = reaper.TrackFX_GetCount(track)
  for i = 0, cnt - 1 do
    if reaper.TrackFX_GetOpen(track, i) then
      return true
    end
  end
  return false
end

function openTrackFx(track)
  if not hasTrackFxOpen(track) then
    -- 防止track被刪除
    pcall(function ()
      value = reaper.TrackFX_GetCount(track)
      reaper.TrackFX_SetOpen(track, (value - 1) or 0, true)
    end)
  end
end

function closeOpenedFxTracks(cond)
  for track in pairs(opened_fx_tracks) do
    if cond == nil or cond(track) then
      pcall(function ()
        reaper.TrackFX_SetOpen(track, 0, false)
      end)
    end
  end
end

-- 更新已打開的fx窗口(track)
for track_idx = 0, reaper.CountTracks(0) - 1 do
  local track = reaper.GetTrack(0, track_idx)
  if hasTrackFxOpen(track) then opened_fx_tracks[track] = true end
end

function main()
    reaper.PreventUIRefresh(1)

    local selected_track_count = countSelectedFxTracks()
    
    if selected_track_count > 0 then
      local selected_tracks = {}
      -- 打開選中的track fx窗口
      forEachSelectedFxTracks(function (track)
        selected_tracks[track] = true
        openTrackFx(track)
      end)
      -- 關閉先前的track fx窗口
      closeOpenedFxTracks(function (track)
        return selected_tracks[track] == nil
      end)
      opened_fx_tracks = selected_tracks -- 更新已打開的track fx窗口
    elseif not keep_fx then -- 沒有選中任何項, 並且不保持窗口
      -- 全部關閉
      closeOpenedFxTracks()
      opened_fx_tracks = {}
    end
    -- 沒有選中任何項, 且保持窗口. 不做任何處理

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

main()