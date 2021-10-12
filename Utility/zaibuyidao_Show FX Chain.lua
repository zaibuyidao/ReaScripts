--[[
 * ReaScript Name: Show FX Chain
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
 * v1.0 (2021-10-13)
  + Initial release
--]]

function Msg(string) reaper.ShowConsoleMsg(tostring(string)..'\n') end
function NoUndoPoint() end

local function UnselAllTrack()
  local first_track = reaper.GetTrack(0, 0)
  if first_track ~= nil then
      reaper.SetOnlyTrackSelected(first_track)
      reaper.SetTrackSelected(first_track, false)
  end
end

local function SaveSelectedItems(t)
  for i = 0, reaper.CountSelectedMediaItems(0)-1 do
      t[i+1] = reaper.GetSelectedMediaItem(0, i)
  end
end

local function RestoreSelectedItems(t)
  reaper.Main_OnCommand(40289, 0) -- Item: Unselect all items
  for _, item in ipairs(t) do
      reaper.SetMediaItemSelected(item, true)
  end
end

local function SaveSelectedTracks(t)
  for i = 0, reaper.CountSelectedTracks(0)-1 do
      t[i+1] = reaper.GetSelectedTrack(0, i)
  end
end

local function RestoreSelectedTracks(t)
  UnselAllTrack()
  for _, track in ipairs(t) do
      reaper.SetTrackSelected(track, true)
  end
end

init_sel_items = {}
init_sel_tracks = {}

SaveSelectedItems(init_sel_items)
SaveSelectedTracks(init_sel_tracks)

function main()
  reaper.PreventUIRefresh(1)

  local item_ret, item_mouse_pos = reaper.BR_ItemAtMouseCursor()
  local track_ret, context, track_mouse_pos = reaper.BR_TrackAtMouseCursor()

  if item_ret then
    local track = reaper.GetMediaItem_Track(item_ret)
    local item = reaper.CountTrackMediaItems(track)
    if reaper.GetMediaItemInfo_Value(item_ret, "B_UISEL") == 0 then
      reaper.SetMediaItemSelected(item_ret, true)
      isItemSelected = true
    end

    reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_WNCLS4"), 0) -- SWS/S&M: Close all FX chain windows
    reaper.Main_OnCommand(40638, 0) -- Item: Show FX chain for item take

    if isItemSelected then
      reaper.SetMediaItemSelected(item_ret, false) 
    end

  elseif track_ret then

    reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_WNCLS4"), 0) -- SWS/S&M: Close all FX chain windows
    get_chain = reaper.TrackFX_GetChainVisible(track_ret)

    if get_chain ~= nil then
        reaper.TrackFX_Show(track_ret, get_chain, 1) -- select in fx chain
    end

    --reaper.Main_OnCommand(40291, 0) -- Track: View FX chain for current/last touched track
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end

main()

RestoreSelectedItems(init_sel_items)
RestoreSelectedTracks(init_sel_tracks)

reaper.defer(NoUndoPoint)