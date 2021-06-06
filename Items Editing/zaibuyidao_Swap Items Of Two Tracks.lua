--[[
 * ReaScript Name: Swap Items Of Two Tracks
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.1 (2021-6-6)
  + 修復Track不能正確選定的問題
 * v1.0 (2021-6-6)
  + Initial release
--]]

local function Msg(str)
    reaper.ShowConsoleMsg(tostring(str).."\n")
end

function UnselectAllTracks()
    first_track = reaper.GetTrack(0, 0)
    reaper.SetOnlyTrackSelected(first_track)
    reaper.SetTrackSelected(first_track, false)
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

UnselectAllTracks()

local count_sel_items = reaper.CountSelectedMediaItems(0)

for m = 0, count_sel_items - 1  do
    local item = reaper.GetSelectedMediaItem(0, m)
    local track = reaper.GetMediaItem_Track(item)
    reaper.SetTrackSelected(track, true)
end

count_sel_track = reaper.CountSelectedTracks(0)
if count_sel_track ~= 2 then return end

track_n = {}

for i = 0, count_sel_track - 1 do
    track = reaper.GetSelectedTrack(0, i)
    track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
    track_n[#track_n+1] = track
end

for i = 0, count_sel_track - 1 do
    count_item_a = reaper.CountTrackMediaItems(track_n[1])
    count_item_b = reaper.CountTrackMediaItems(track_n[2])

    track_a = {}
    item_a_new = {}
    item_a_new_order = 1 

    for j = 0, count_item_a - 1  do
        item_a = reaper.GetTrackMediaItem(track_n[1], j)

        if reaper.IsMediaItemSelected(item_a) == true then
            track_a[item_a_new_order] = item_a
            item_a_new[item_a_new_order] = reaper.GetMediaItemInfo_Value(item_a, "IP_ITEMNUMBER")
            item_a_new_order = item_a_new_order + 1
        end
    end

    track_b = {}
    item_b_new = {}
    item_b_new_order = 1 

    for k = 0, count_item_b - 1  do
        item_b = reaper.GetTrackMediaItem(track_n[2], k)

        if reaper.IsMediaItemSelected(item_b) == true then
            track_b[item_b_new_order] = item_b
            item_b_new[item_b_new_order] = reaper.GetMediaItemInfo_Value(item_b, "IP_ITEMNUMBER")
            item_b_new_order = item_b_new_order + 1
        end
    end
end

for x = 1, item_a_new_order-1  do
    local item_a = track_a[x]
    if reaper.IsMediaItemSelected(item_a) == true then
        reaper.MoveMediaItemToTrack(item_a, track_n[2])
    end
end

for y = 1, item_b_new_order-1  do
    local item_b = track_b[y]
    if reaper.IsMediaItemSelected(item_b) == true then
        reaper.MoveMediaItemToTrack(item_b, track_n[1])
    end
end

reaper.Undo_EndBlock('Swap Items Of Two Tracks', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()