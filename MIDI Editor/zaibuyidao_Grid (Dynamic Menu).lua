--[[
 * ReaScript Name: Grid (Dynamic Menu)
 * Version: 1.0.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-7-15)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local HWND = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(HWND)
local get_grid = reaper.MIDI_GetGrid(take)

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

local menu_01, menu_02, menu_03, menu_04, menu_05, menu_06, menu_07, menu_08, menu_09, menu_10, straight, triplet, dotted, swing

if reaper.GetToggleCommandStateEx(32060, 41003) == 1 then
  straight = true
  if get_grid == 1/32 then menu_01 = true else menu_01 = false end
  if get_grid == 1/16 then menu_02 = true else menu_02 = false end
  if get_grid == 1/8 then menu_03 = true else menu_03 = false end
  if get_grid == 1/4 then menu_04 = true else menu_04 = false end
  if get_grid == 1/2 then menu_05 = true else menu_05 = false end
  if get_grid == 1 then menu_06 = true else menu_06 = false end
  if get_grid == 2 then menu_07 = true else menu_07 = false end
  if get_grid == 4 then menu_08 = true else menu_08 = false end
  if get_grid == 8 then menu_09 = true else menu_09 = false end
  if get_grid == 16 then menu_10 = true else menu_10 = false end
end

if reaper.GetToggleCommandStateEx(32060, 41004) == 1 then
  triplet = true
  if get_grid == 1/48 then menu_01 = true else menu_01 = false end
  if get_grid == 1/24 then menu_02 = true else menu_02 = false end
  if get_grid == 1/12 then menu_03 = true else menu_03 = false end
  if get_grid == 1/6 then menu_04 = true else menu_04 = false end
  if get_grid == 1/3 then menu_05 = true else menu_05 = false end
  if get_grid == 1/1.5 then menu_06 = true else menu_06 = false end
  if get_grid == 1/0.75 then menu_07 = true else menu_07 = false end
  if get_grid == 1/0.375 then menu_08 = true else menu_08 = false end
  if get_grid == 1/0.1875 then menu_09 = true else menu_09 = false end
  if get_grid == 1/0.09375 then menu_10 = true else menu_10 = false end
end

if reaper.GetToggleCommandStateEx(32060, 41005) == 1 then
  dotted = true
  if get_grid == 1.5/32 then menu_01 = true else menu_01 = false end
  if get_grid == 1.5/16 then menu_02 = true else menu_02 = false end
  if get_grid == 1.5/8 then menu_03 = true else menu_03 = false end
  if get_grid == 1.5/4 then menu_04 = true else menu_04 = false end
  if get_grid == 1.5/2 then menu_05 = true else menu_05 = false end
  if get_grid == 1.5 then menu_06 = true else menu_06 = false end
  if get_grid == 3 then menu_07 = true else menu_07 = false end
  if get_grid == 6 then menu_08 = true else menu_08 = false end
  if get_grid == 12 then menu_09 = true else menu_09 = false end
  if get_grid == 24 then menu_10 = true else menu_10 = false end
end

if reaper.GetToggleCommandStateEx(32060, 41006) == 1 then
  swing = true
end

local menu = "" --#GRID||
menu = menu
.. (menu_01 and "!" or "") .. "1/128" .. "|"
.. (menu_02 and "!" or "") .. "1/64" .. "|"
.. (menu_03 and "!" or "") .. "1/32" .. "|"
.. (menu_04 and "!" or "") .. "1/16" .. "|"
.. (menu_05 and "!" or "") .. "1/8" .. "|"
.. (menu_06 and "!" or "") .. "1/4" .. "|"
.. (menu_07 and "!" or "") .. "1/2" .. "|"
.. (menu_08 and "!" or "") .. "1" .. "|"
.. (menu_09 and "!" or "") .. "2" .. "|"
.. (menu_10 and "!" or "") .. "4" .. "||"
.. ">" .. "Grid type" .. "|"
.. (straight and "!" or "") .. "straight" .. "|"
.. (triplet and "!" or "") .. "triplet" .. "|"
.. (dotted and "!" or "") .. "dotted" .. "|"
.. (swing and "!" or "") .. "swing" .. "|"

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
  selection = selection - 0 --此處selection值與標題行數關聯，標題佔用一行-1，佔用兩行則-2
  if selection == 1 then reaper.MIDIEditor_OnCommand(HWND, 41008) end -- 1/128
  if selection == 2 then reaper.MIDIEditor_OnCommand(HWND, 41009) end -- 1/64
  if selection == 3 then reaper.MIDIEditor_OnCommand(HWND, 41010) end -- 1/32
  if selection == 4 then reaper.MIDIEditor_OnCommand(HWND, 41011) end -- 1/16
  if selection == 5 then reaper.MIDIEditor_OnCommand(HWND, 41012) end -- 1/8
  if selection == 6 then reaper.MIDIEditor_OnCommand(HWND, 41013) end -- 1/4
  if selection == 7 then reaper.MIDIEditor_OnCommand(HWND, 41014) end -- 1/2
  if selection == 8 then reaper.MIDIEditor_OnCommand(HWND, 41015) end -- 1
  if selection == 9 then reaper.MIDIEditor_OnCommand(HWND, 41016) end -- 2
  if selection == 10 then reaper.MIDIEditor_OnCommand(HWND, 41017) end -- 4
  if selection == 11 then reaper.MIDIEditor_OnCommand(HWND, 41003) end -- straight
  if selection == 12 then reaper.MIDIEditor_OnCommand(HWND, 41004) end -- triplet
  if selection == 13 then reaper.MIDIEditor_OnCommand(HWND, 41005) end -- dotted
  if selection == 14 then reaper.MIDIEditor_OnCommand(HWND, 41006) end -- swing
end

reaper.SN_FocusMIDIEditor()
reaper.defer(function() end)