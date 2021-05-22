--[[
 * ReaScript Name: Track Follows Item/Razor Selection
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Reference: Lokasenna_Track selection follows item selection.lua (Optimize only)
 * REAPER: 6.0
--]]

local function Msg(str)
	reaper.ShowConsoleMsg(tostring(str).."\n")
end

local sel_items, sel_tracks, sel_razor = {}, {}, {}

local function ShallowEqual(t1, t2)
  if #t1 ~= #t2 then return false end
  for k, v in pairs(t1) do
    if v ~= t2[k] then return false end
  end
  return true
end

local function GetRazorTracks()
  local tracks = {}
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, str = reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", "", false)
    if str ~= "" then table.insert(tracks, track) end
  end
  return tracks
end

local function ProcessTracks(tracks)
  if #tracks > 0 then
    reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
    reaper.SetOnlyTrackSelected(tracks[1])
    for _, v in pairs(tracks) do reaper.SetTrackSelected(v, true) end
    reaper.Main_OnCommand(40914, 0) -- Track: Set first selected track as last touched track
  end
end

-- State: On/Off
(function()
  local _, _, sectionId, cmdId = reaper.get_action_context()
  if sectionId ~= -1 then
    reaper.SetToggleCommandState(sectionId, cmdId, 1)
    reaper.RefreshToolbar2(sectionId, cmdId)
    reaper.atexit(function()
      reaper.SetToggleCommandState(sectionId, cmdId, 0)
      reaper.RefreshToolbar2(sectionId, cmdId)
    end)
  end
end)()

local function Main()
  reaper.PreventUIRefresh(1)
	local num_tracks = reaper.CountSelectedTracks(0)
	local cur_tracks = {}
	for i = 1, num_tracks do
		cur_tracks[i] = reaper.GetSelectedTrack(0, i - 1)
  end
  if ShallowEqual(sel_tracks, cur_tracks) then
    local cur_razor = GetRazorTracks()
    if not ShallowEqual(sel_razor, cur_razor) then
      sel_razor = cur_razor
      ProcessTracks(sel_razor)
    elseif #cur_razor == 0 then
      local num_items = reaper.CountSelectedMediaItems(0)
      local cur_items = {}
      for i = 1, num_items do
        cur_items[i] = reaper.GetSelectedMediaItem(0, i - 1)
      end
      if not ShallowEqual(sel_items, cur_items) then
        sel_items = cur_items
        local tracks = {}
        for i = 1, num_items do
          tracks[i] = reaper.GetMediaItem_Track(sel_items[i])
        end
        ProcessTracks(tracks)
        if num_items > 0 then
          reaper.SetMixerScroll(reaper.GetSelectedTrack(0, 0))
        end
      end
    end
  else
    sel_tracks = cur_tracks
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
	reaper.defer(Main)
end
Main()