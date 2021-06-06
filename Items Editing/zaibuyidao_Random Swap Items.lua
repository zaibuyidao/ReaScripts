--[[
 * ReaScript Name: Random Swap Items
 * Version: 1.0
 * Author: zaibuyidao, X-Raym
 * Reference: X-Raym_Shuffle order of selected items keeping snap offset positions and parent tracks.lua (僅適當調整)
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2021-6-6)
  + Initial release
--]]

local function Msg(str)
    reaper.ShowConsoleMsg(tostring(str).."\n")
end

local function ShuffleTable( t )
    local rand = math.random 
    local iterations = #t
    local w
    for z = iterations, 2, -1 do
        w = rand(z)
        t[z], t[w] = t[w], t[z]
    end
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

selected_items_count = reaper.CountSelectedMediaItems(0)

if selected_items_count >= 2 then
    first_track = reaper.GetTrack(0, 0)
    reaper.SetOnlyTrackSelected(first_track)
    reaper.SetTrackSelected(first_track, false)

    selected_items_count = reaper.CountSelectedMediaItems(0)
    
    for i = 0, selected_items_count - 1  do
        item = reaper.GetSelectedMediaItem(0, i)
        track = reaper.GetMediaItem_Track(item)
        reaper.SetTrackSelected(track, true)
    end

    selected_tracks_count = reaper.CountSelectedTracks(0)

    for i = 0, selected_tracks_count - 1  do
        track = reaper.GetSelectedTrack(0, i) 
        count_items_on_track = reaper.CountTrackMediaItems(track)
        sel_items_on_track = {}
        snap_sel_items_on_track = {}
        snap_sel_items_on_tracks_len = 1 

        for j = 0, count_items_on_track - 1  do
            item = reaper.GetTrackMediaItem(track, j)
            if reaper.IsMediaItemSelected(item) == true then
                sel_items_on_track[snap_sel_items_on_tracks_len] = item
                snap_sel_items_on_track[snap_sel_items_on_tracks_len] = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET") + reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                snap_sel_items_on_tracks_len = snap_sel_items_on_tracks_len + 1
            end     
        end

        ShuffleTable(snap_sel_items_on_track)

        for k = 1, snap_sel_items_on_tracks_len - 1 do
            item = sel_items_on_track[k]
            item_snap = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
            item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

            reaper.SetMediaItemInfo_Value(item, "D_POSITION", snap_sel_items_on_track[k] - item_snap)
            offset = reaper.GetMediaItemInfo_Value(item, "D_POSITION") - item_pos
            if group_state == 1 then
                group = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
                if group > 0 then
                    groups[group].offset = offset
                end
            end
        end
    end
end

reaper.Undo_EndBlock('Random Swap Items', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()