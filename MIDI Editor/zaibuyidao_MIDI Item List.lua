--[[
 * ReaScript Name: MIDI Item List
 * Version: 1.0
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
  menu = menu .. (flag and "!" or "") .. i .. " " .. take_name .. "|"
end
menu = menu .. "Select all MIDI item" .. "|"

local title = "Hidden gfx window for showing the MIDI item list showmenu"
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

for i = 0, item_num-1 do
  item = reaper.GetTrackMediaItem(track, i)
  reaper.SetMediaItemSelected(item, false)
end

if selection > 0 then
  for i = 0, item_num-1 do
    local item = reaper.GetTrackMediaItem(track, selection - 1) -- 此處selection值與標題行數關聯，標題佔用一行-1，佔用兩行則-2
    if selection == (item_num+1) then
      item = reaper.GetTrackMediaItem(track, i)
    end
    reaper.SetMediaItemSelected(item, true)
  end
end

reaper.SN_FocusMIDIEditor()
reaper.defer(function() end)