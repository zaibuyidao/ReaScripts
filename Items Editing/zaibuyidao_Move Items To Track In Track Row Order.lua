--[[
 * ReaScript Name: Move Items To Track In Track Row Order
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2022-3-27)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local function unselect_all_tracks()
  local first_track = reaper.GetTrack(0, 0)
  if first_track ~= nil then
    reaper.SetOnlyTrackSelected(first_track)
    reaper.SetTrackSelected(first_track, false)
  end
end

local function save_selected_tracks(t)
  for i = 0, reaper.CountSelectedTracks(0)-1 do
    t[i+1] = reaper.GetSelectedTrack(0, i)
  end
end

local function restore_selected_tracks(t)
  unselect_all_tracks()
  for _, track in ipairs(t) do
    reaper.SetTrackSelected(track, true)
  end
end

init_sel_tracks = {}
save_selected_tracks(init_sel_tracks)

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items == 0 then return end
tracks = reaper.CountTracks(0)

for i = 0, count_sel_items - 1 do
  sel_item = reaper.GetSelectedMediaItem(0, i)
  if i == 0 then 
    track = reaper.GetMediaItem_Track(sel_item)
  end
  reaper.MoveMediaItemToTrack(sel_item, track)
end

local item_first = reaper.GetSelectedMediaItem(0, 0)
local track_first = reaper.GetMediaItem_Track(item_first)
local track_num = reaper.GetMediaTrackInfo_Value(track_first, "IP_TRACKNUMBER")

for i = 0, count_sel_items - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  local track = reaper.GetMediaItem_Track(item)
  local count_track_items = reaper.CountTrackMediaItems(track)
  sel_item_track = {}
  item_num_new = {}
  item_num_order = 1 

  for j = 0, count_track_items - 1 do
    local item = reaper.GetTrackMediaItem(track, j)
    if reaper.IsMediaItemSelected(item) == true then
      sel_item_track[item_num_order] = item
      item_num_new[item_num_order] = reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
      item_num_order = item_num_order + 1
    end
  end
end

local track_cur = tracks - track_num + 1
local track_offset = item_num_order - track_cur - 1

for k = 1, track_offset do
  if item_num_order > track_cur then
    reaper.Main_OnCommand(40001, 0) -- Track: Insert new track
  end
end

for k = 1, item_num_order-1 do
  new_track = reaper.GetTrack(0, track_num-2+k)
  reaper.MoveMediaItemToTrack(sel_item_track[k], new_track)
end

restore_selected_tracks(init_sel_tracks)

reaper.Undo_EndBlock("Move Items To Track In Track Row Order", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()