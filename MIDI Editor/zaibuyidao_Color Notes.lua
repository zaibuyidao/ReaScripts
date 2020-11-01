--[[
 * ReaScript Name: Color Notes
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

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local HWND = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(HWND)

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

local velocity, channel, pitch, source, track, media_item, voice, sel_body, sel_border, unsel_body, unsel_border

-- 顏色音符勾選狀態，如果狀態為1則勾選。
if reaper.GetToggleCommandStateEx(32060, 40738) == 1 then velocity = true else velocity = false end
if reaper.GetToggleCommandStateEx(32060, 40739) == 1 then channel = true else channel = false end
if reaper.GetToggleCommandStateEx(32060, 40740) == 1 then pitch = true else pitch = false end
if reaper.GetToggleCommandStateEx(32060, 40741) == 1 then source = true else source = false end
if reaper.GetToggleCommandStateEx(32060, 40768) == 1 then track = true else track = false end
if reaper.GetToggleCommandStateEx(32060, 40769) == 1 then media_item = true else media_item = false end
if reaper.GetToggleCommandStateEx(32060, 41114) == 1 then voice = true else voice = false end
if reaper.GetToggleCommandStateEx(32060, 42095) == 1 then sel_body = true else sel_body = false end
if reaper.GetToggleCommandStateEx(32060, 42096) == 0 then sel_border = false else sel_border = true end -- 該狀態僅有off
if reaper.GetToggleCommandStateEx(32060, 42097) == 0 then unsel_body = false else unsel_body = true end -- 該狀態僅有off
if reaper.GetToggleCommandStateEx(32060, 42098) == 0 then unsel_border = false else unsel_border = true end -- 該狀態僅有off

local menu = "" -- #Color notes||
menu = menu
.. (velocity and "!" or "") .. "Velocity" .. "|"
.. (channel and "!" or "") .. "Channel" .. "|"
.. (pitch and "!" or "") .. "Pitch" .. "|"
.. (source and "!" or "") .. "Source, using color map" .. "|"
.. (track and "!" or "") .. "Track" .. "|"
.. (media_item and "!" or "") .. "Media item" .. "|"
.. (voice and "!" or "") .. "Voice" .. "||"
.. ">" .. "When coloring by track or media item" .. "|"
.. (sel_body and "!" or "") .. "Use theme color for selected note body" .. "|"
.. (sel_border and "!" or "") .. "Use theme color for selected note border" .. "|"
.. (unsel_body and "!" or "") .. "Use theme color for unselected note body" .. "|"
.. (unsel_border and "!" or "") .. "Use theme color for unselected note border" .. "|"

local title = "Hidden gfx window for showing the Color notes showmenu"
gfx.init(title, 0, 0, 0, 0, 0)
local dyn_win = reaper.JS_Window_Find(title, true)
local out = 0
if dyn_win then
  out = 7000
  reaper.JS_Window_Move(dyn_win, -out, -out)
end

out = reaper.GetOS():find("OSX") and 0 or out
gfx.x, gfx.y = gfx.mouse_x-0+out, gfx.mouse_y-0+out -- 可設置彈出菜單時鼠標所處的位置
local selection = gfx.showmenu(menu)
gfx.quit()

if selection > 0 then
  selection = selection - 0 -- 此處selection值與標題行數關聯，標題佔用一行-1，佔用兩行則-2
  if selection == 1 then reaper.MIDIEditor_OnCommand(HWND, 40738) end -- Color notes by velocity
  if selection == 2 then reaper.MIDIEditor_OnCommand(HWND, 40739) end -- Color notes/CC by channel
  if selection == 3 then reaper.MIDIEditor_OnCommand(HWND, 40740) end -- Color notes by pitch
  if selection == 4 then reaper.MIDIEditor_OnCommand(HWND, 40741) end -- Color notes/CC by source, using colormap
  if selection == 5 then reaper.MIDIEditor_OnCommand(HWND, 40768) end -- Color notes/CC by track custom color
  if selection == 6 then reaper.MIDIEditor_OnCommand(HWND, 40769) end -- Color notes/CC by media item custom color
  if selection == 7 then reaper.MIDIEditor_OnCommand(HWND, 41114) end -- Color notes by voice
  if selection == 8 then reaper.MIDIEditor_OnCommand(HWND, 42095) end -- Use theme color for selected note body when coloring by track or media item
  if selection == 9 then reaper.MIDIEditor_OnCommand(HWND, 42096) end -- Use theme color for selected note border when coloring by track or media item
  if selection == 10 then reaper.MIDIEditor_OnCommand(HWND, 42097) end -- Use theme color for unselected note body when coloring by track or media item
  if selection == 11 then reaper.MIDIEditor_OnCommand(HWND, 42098) end -- Use theme color for unselected note border when coloring by track or media item
end

reaper.SN_FocusMIDIEditor()
reaper.defer(function() end)