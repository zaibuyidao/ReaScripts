--[[
 * ReaScript Name: 選擇軌道(動態菜單)
 * Version: 1.0.1
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

local count_track = reaper.CountTracks(0)
local menu = "" -- #Pick Track|#Track List|| -- 標題
for i = 1, count_track do
  local track = reaper.GetTrack(0, i - 1)
  local ok, track_name = reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', '', false)
  local track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')

  if reaper.IsTrackSelected(track) == true then
    flag = true
  else
    flag = false
  end

  menu = menu .. (flag and "!" or "") .. "Track " .. i .. ": " .. track_name .. "|"
end

local title = "Hidden gfx window for showing the pick track all items showmenu"
gfx.init(title, 0, 0, 0, 0, 0)
local HWND = reaper.JS_Window_Find(title, true)
local out = 0
if HWND then
  out = 7000
  reaper.JS_Window_Move(HWND, -out, -out)
end

out = reaper.GetOS():find("OSX") and 0 or out
gfx.x, gfx.y = gfx.mouse_x-0+out, gfx.mouse_y-0+out -- 可設置彈出菜單時鼠標所處的位置
local selection = gfx.showmenu(menu)
gfx.quit()

if selection > 0 then
  for i = 0, count_track-1 do
    local track = reaper.GetTrack(0, i)

    if selection == i+1 then
      reaper.SetTrackSelected(track, true)
    else
      reaper.SetTrackSelected(track, false)
    end
  end

  local count_sel_track = reaper.CountSelectedTracks(0)
  for i = 0, count_sel_track-1 do
    local sel_track =  reaper.GetSelectedTrack(0, i)
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

reaper.SN_FocusMIDIEditor()
reaper.defer(function() end)