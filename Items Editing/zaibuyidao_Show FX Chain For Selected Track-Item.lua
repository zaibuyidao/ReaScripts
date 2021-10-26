--[[
 * ReaScript Name: Show FX Chain For Selected Track-Item
 * Version: 1.0.3
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

keep_fx = true  -- true or false -- Keep window open when no item/track is selected 沒有選中item/track時，保持窗口打開
tracks_fx = {}  -- 記錄track對應的上一次打開的fx窗口最後一次選中的fx條目
items_fx = {}   -- 記錄item對應的上一次打開的fx窗口最後一次選中的fx條目
opened_fx_tracks = {} -- 已經打開的fx窗口的track
opened_fx_items = {}  -- 已經打開的fx窗口的item

function forEachSelectedItems(block) -- 遍歷選中item
  local selected_item_count = reaper.CountSelectedMediaItems(0)
  for item_idx = 0, selected_item_count - 1 do
    block(reaper.GetSelectedMediaItem(0, item_idx), item_idx)
  end
end

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

function forEachSelectedFxItems(block) -- 遍歷帶有fx的選中item
  forEachSelectedItems(function (item, id)
    local take = reaper.GetActiveTake(item, 0)
    if take ~= nil then
      local fx_count = reaper.TakeFX_GetCount(take)
      if fx_count > 0 then
        block(item, id, fx_count)
      end
    end
  end)
end

function forEachSelectedFxTracks(block) -- 遍歷帶有fx的選中track
  forEachSelectedTracks(function (track, id)
    local fx_count = reaper.TrackFX_GetCount(track)
    if fx_count > 0 then
      block(track, id, fx_count)
    end
  end)
end

function countSelectedFxItems()
  local count = 0
  forEachSelectedFxItems(function () count = count + 1 end)
  return count
end

function countSelectedFxTracks()
  local count = 0
  forEachSelectedFxTracks(function () count = count + 1 end)
  return count
end

function updateTracksFx() -- 更新track fx窗口選擇條目
  forEachSelectedTracks(function (track)
    value = reaper.CF_EnumSelectedFX(reaper.CF_GetTrackFXChain(track), -1)
    if value >= 0 then tracks_fx[track] = value end
  end)
end

function updateItemsFx() -- 更新item fx窗口選擇條目
  forEachSelectedItems(function (item)
    value = reaper.CF_EnumSelectedFX(reaper.CF_GetTakeFXChain(reaper.GetActiveTake(item, 0)), -1)
    if value >= 0 then items_fx[item] = value end
  end)
end

function hasTakeFxOpen(take) -- take是否存在一個打開的fx窗口
  if take == nil then return false end
  local cnt = reaper.TakeFX_GetCount(take)
  for i = 0, cnt - 1 do
    if reaper.TakeFX_GetOpen(take, i) then
      return true
    end
  end
  return false
end

function hasItemFxOpen(item) -- item是否存在一個打開的fx窗口
  local take = reaper.GetActiveTake(item, 0)
  if take ~= nil then
    return hasTakeFxOpen(take)
  end
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

function openItemFx(item)
  if not hasItemFxOpen(item) then
    -- 防止item被刪除
    pcall(function ()
      reaper.TakeFX_SetOpen(reaper.GetActiveTake(item, 0), items_fx[item] or 0, true)
    end)
  end
end

function openTrackFx(track)
  if not hasTrackFxOpen(track) then
    -- 防止track被刪除
    pcall(function ()
      reaper.TrackFX_SetOpen(track, tracks_fx[track] or 0, true)
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

function closeOpenedFxItems(cond)
  for item in pairs(opened_fx_items) do
    if cond == nil or cond(item) then
      pcall(function ()
        reaper.TakeFX_SetOpen(reaper.GetActiveTake(item, 0), 0, false)
      end)
    end
  end
end

-- 更新已打開的fx窗口(track)
for track_idx = 0, reaper.CountTracks(0) - 1 do
  local track = reaper.GetTrack(0, track_idx)
  if hasTrackFxOpen(track) then opened_fx_tracks[track] = true end
end
-- 更新已打開的fx窗口(item)
for item_idx = 0, reaper.CountMediaItems(0) - 1 do
  local item = reaper.GetMediaItem(0, item_idx)
  if hasItemFxOpen(item) then opened_fx_items[item] = true end
end

function main()
    reaper.PreventUIRefresh(1)
    updateTracksFx()
    updateItemsFx()

    local selected_item_count = countSelectedFxItems()
    local selected_track_count = countSelectedFxTracks()
    
    if selected_item_count > 0 then -- 情況1, 選中了item
      local selected_items = {}
      -- 打開選中的item fx窗口
      forEachSelectedFxItems(function (item)
        selected_items[item] = true
        openItemFx(item)
      end)
      -- 關閉先前的item fx窗口
      closeOpenedFxItems(function (item)
        return selected_items[item] == nil
      end)
      opened_fx_items = selected_items -- 更新已打開的item fx窗口

      -- 關閉所有track fx窗口
      closeOpenedFxTracks()
      opened_fx_tracks = {}
    elseif selected_track_count > 0 then -- 情況2, 選中了track但沒有選中item
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
      -- 關閉所有item fx窗口
      closeOpenedFxItems()
      opened_fx_items = {}
    elseif not keep_fx then -- 情況3, 沒有選中任何項, 並且不保持窗口
      -- 全部關閉
      closeOpenedFxItems()
      opened_fx_items = {}
      closeOpenedFxTracks()
      opened_fx_tracks = {}
    end
    -- 情況4, 沒有選中任何項, 且保持窗口. 不做任何處理

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.defer(main)
end

local _, _, sectionId, cmdId = reaper.get_action_context()
if sectionId ~= -1 then
  reaper.SetToggleCommandState(sectionId, cmdId, 1)
  reaper.RefreshToolbar2(sectionId, cmdId)
  main()
  reaper.atexit(function()
    reaper.SetToggleCommandState(sectionId, cmdId, 0)
    reaper.RefreshToolbar2(sectionId, cmdId)
  end)
end