--[[
 * ReaScript Name: Move Items To Track (Explode)
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
 * v1.0 (2021-6-12)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end

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

-- init_sel_tracks = {}
-- SaveSelectedTracks(init_sel_tracks)

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock() -- 撤消塊開始

count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items < 1 then return end
tracks = reaper.CountTracks(0)

for i = 0, count_sel_items - 1 do
  sel_item = reaper.GetSelectedMediaItem(0, i)
  if i == 0 then 
    track = reaper.GetMediaItem_Track(sel_item)
  end
  reaper.MoveMediaItemToTrack(sel_item, track)
end

item_first = reaper.GetSelectedMediaItem(0, 0)
track_first = reaper.GetMediaItem_Track(item_first)
track_num = reaper.GetMediaTrackInfo_Value(track_first, "IP_TRACKNUMBER")

count_sel_track = reaper.CountSelectedTracks(0)

for i = 0, count_sel_track - 1 do
    track = reaper.GetSelectedTrack(0, i)
    count_track_items = reaper.CountTrackMediaItems(track_first)
    sel_item_track = {}
    item_num_new = {}
    item_num_order = 1 

    for j = 0, count_track_items - 1  do
      item = reaper.GetTrackMediaItem(track_first, j)
      if reaper.IsMediaItemSelected(item) == true then
          sel_item_track[item_num_order] = item
          item_num_new[item_num_order] = reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
          item_num_order = item_num_order + 1
      end
    end
end

track_cur = tracks - track_num + 1
track_offset = item_num_order - track_cur - 1

for k = 1, track_offset do
  if item_num_order > track_cur then
    reaper.Main_OnCommand(40001, 0) -- Track: Insert new track
  end
end

for k = 1, item_num_order-1 do
  new_track = reaper.GetTrack(0, track_num-2+k)
  reaper.MoveMediaItemToTrack(sel_item_track[k], new_track)
end

-- RestoreSelectedTracks(init_sel_tracks)

reaper.Undo_EndBlock("Move Items To Track (Explode)", -1) -- 撤消塊結束
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()