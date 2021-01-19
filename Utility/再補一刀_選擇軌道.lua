--[[
 * ReaScript Name: 選擇軌道
 * Version: 1.0
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * provides: [main=main,midi_editor,midi_eventlisteditor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-1-20)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end

reaper.Undo_BeginBlock() -- 撤銷塊開始
reaper.PreventUIRefresh(1)

local count_track = reaper.CountTracks(0)
local count_sel_track = reaper.CountSelectedTracks(0)
for i = 0, count_sel_track-1 do
  selected_trk = reaper.GetSelectedTrack(0, 0) -- 當軌道為多選時限定只取第一軌
  track_num = reaper.GetMediaTrackInfo_Value(selected_trk, 'IP_TRACKNUMBER')
end

track_num = math.floor(track_num)

local user_ok, user_input_CSV = reaper.GetUserInputs("選擇軌道, " .. "共 " .. count_track .." 條軌道.", 1, "軌道編號", track_num)
sel_only_num = user_input_CSV:match("(.*)")
if not tonumber(sel_only_num) then return reaper.SN_FocusMIDIEditor() end
sel_only_num = tonumber(sel_only_num)

function UnselectAllTracks()
	first_track = reaper.GetTrack(0, 0)
	reaper.SetOnlyTrackSelected(first_track)
	reaper.SetTrackSelected(first_track, false)
end

sel_only_num = sel_only_num-1

for i = 0, count_track-1 do
  if count_track > sel_only_num then
    
    UnselectAllTracks()
    local sel_track = reaper.GetTrack(0, sel_only_num)
    reaper.SetTrackSelected(sel_track, true)

    local item_num = reaper.CountTrackMediaItems(sel_track)
    if item_num == nil then return end

    reaper.SelectAllMediaItems(0, false) -- 取消選擇所有對象

    for i = 0, item_num-1 do
      local item = reaper.GetTrackMediaItem(sel_track, i)
      reaper.SetMediaItemSelected(item, true) -- 選中所有item
      reaper.UpdateItemInProject(item)
    end

  end
end

reaper.Undo_EndBlock("選擇軌道", 0) -- 撤銷塊結束
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
