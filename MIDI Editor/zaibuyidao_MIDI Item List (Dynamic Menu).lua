--[[
 * ReaScript Name: MIDI Item List (Dynamic Menu)
 * Version: 1.1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-11-1)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end

if not reaper.APIExists("JS_Window_Find") then
  reaper.MB("請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'. 然後重新啟動 REAPER 並再次運行腳本. 謝謝!", "你必須安裝 JS_ReaScriptAPI", 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, "出了些問題...", 0)
  end
  return reaper.defer(function() end)
end

local count_track = reaper.CountSelectedTracks(0)
if count_track > 1 then return end
local hwnd = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(hwnd)
local track = reaper.GetMediaItemTake_Track(take)
local item_num = reaper.CountTrackMediaItems(track)

local menu = "" -- #MIDI|#item list|| -- 標題
for i = 0, item_num-1 do
  local item = reaper.GetTrackMediaItem(track, i)
  local active_take = reaper.GetActiveTake(item)
  local take_name = reaper.GetTakeName(active_take)
  if reaper.IsMediaItemSelected(item) == true then
    flag = true
  else
    flag = false
  end

  if i == item_num-1 then 
    menu = menu .. (flag and "!" or "") .. i .. " " .. take_name .. "||"
  else
    menu = menu .. (flag and "!" or "") .. i .. " " .. take_name .. "|"
  end

end

menu = menu
.. "Select all MIDI items" .. "|"
.. "Unselect all MIDI items" .. "|"

local title = "hidden " .. reaper.genGuid()
gfx.init( title, 0, 0, 0, 0, 0 )
local hwnd = reaper.JS_Window_Find( title, true )
if hwnd then
  reaper.JS_Window_Show( hwnd, "HIDE" )
end
gfx.x, gfx.y = gfx.mouse_x-0, gfx.mouse_y-0
local selection = gfx.showmenu(menu)
gfx.quit()

if selection > 0 then
  for i = 0, item_num-1 do
    local item = reaper.GetTrackMediaItem(track, i)
    if selection == i+1 then
      reaper.SetMediaItemSelected(item, true)
    else
      reaper.SetMediaItemSelected(item, false)
    end
    if selection == (item_num+1) then
      reaper.SetMediaItemSelected(item, true)
    end
    if selection == (item_num+2) then
      reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_UNSELONTRACKS"), 0) -- SWS: Unselect all items on selected track(s)
    end
  end
end

reaper.SN_FocusMIDIEditor()
reaper.defer(function() end)