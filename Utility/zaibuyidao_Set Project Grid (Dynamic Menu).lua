-- @description Set Project Grid (Dynamic Menu)
-- @version 1.0.1
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI

function print(...)
  local args = {...}
  local str = ""
  for i = 1, #args do
    str = str .. tostring(args[i]) .. "\t"
  end
  reaper.ShowConsoleMsg(str .. "\n")
end

if not reaper.APIExists("JS_Localize") then
  reaper.MB("Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\n請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n\nThen restart REAPER and run the script again, thank you!\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n", "You must install JS_ReaScriptAPI 你必須安裝JS_ReaScriptAPI", 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, "錯誤", 0)
  end
  return reaper.defer(function() end)
end

local _, get_grid = reaper.GetSetProjectGrid(0, 0)

local menu_01, menu_02, menu_03, menu_04, menu_05, menu_06, menu_07, menu_08, menu_09, menu_10, menu_11, menu_12, menu_13, menu_14, menu_15, menu_16

if reaper.GetToggleCommandStateEx(0, 40923) == 1 then
  menu_01 = false -- Grid: Set framerate grid
  menu_02 = true  -- Grid: Set measure grid
  menu_03 = false -- Grid: Set to 1/128
  menu_04 = false -- Grid: Set to 1/64
  menu_05 = false -- Grid: Set to 1/48 (1/32 triplet)
  menu_06 = false -- Grid: Set to 1/32
  menu_07 = false -- Grid: Set to 1/24 (1/16 triplet)
  menu_08 = false -- Grid: Set to 1/16
  menu_09 = false -- Grid: Set to 1/12 (1/8 triplet)
  menu_10 = false -- Grid: Set to 1/8
  menu_11 = false -- Grid: Set to 1/6 (1/4 triplet)
  menu_12 = false -- Grid: Set to 1/4
  menu_13 = false -- Grid: Set to 1/2
  menu_14 = false -- Grid: Set to 1
  menu_15 = false -- Grid: Set to 2
  menu_16 = false -- Grid: Set to 4
elseif reaper.GetToggleCommandStateEx(0, 40904) == 1 then
  menu_01 = true -- Grid: Set framerate grid
  menu_02 = false -- Grid: Set measure grid
  menu_03 = false -- Grid: Set to 1/128
  menu_04 = false -- Grid: Set to 1/64
  menu_05 = false -- Grid: Set to 1/48 (1/32 triplet)
  menu_06 = false -- Grid: Set to 1/32
  menu_07 = false -- Grid: Set to 1/24 (1/16 triplet)
  menu_08 = false -- Grid: Set to 1/16
  menu_09 = false -- Grid: Set to 1/12 (1/8 triplet)
  menu_10 = false -- Grid: Set to 1/8
  menu_11 = false -- Grid: Set to 1/6 (1/4 triplet)
  menu_12 = false -- Grid: Set to 1/4
  menu_13 = false -- Grid: Set to 1/2
  menu_14 = false -- Grid: Set to 1
  menu_15 = false -- Grid: Set to 2
  menu_16 = false -- Grid: Set to 4
else
  if get_grid == 1/128 then menu_03 = true else menu_03 = false end -- Grid: Set to 1/128
  if get_grid == 1/64 then menu_04 = true else menu_04 = false end -- Grid: Set to 1/64
  if get_grid == 1/48 then menu_05 = true else menu_05 = false end -- Grid: Set to 1/48 (1/32 triplet)
  if get_grid == 1/32 then menu_06 = true else menu_06 = false end -- Grid: Set to 1/32
  if get_grid == 1/24 then menu_07 = true else menu_07 = false end -- Grid: Set to 1/24 (1/16 triplet)
  if get_grid == 1/16 then menu_08 = true else menu_08 = false end -- Grid: Set to 1/16
  if get_grid == 1/12 then menu_09 = true else menu_09 = false end -- Grid: Set to 1/12 (1/8 triplet)
  if get_grid == 1/8 then menu_10 = true else menu_10 = false end -- Grid: Set to 1/8
  if get_grid == 1/6 then menu_11 = true else menu_11 = false end -- Grid: Set to 1/6 (1/4 triplet)
  if get_grid == 1/4 then menu_12 = true else menu_12 = false end -- Grid: Set to 1/4
  if get_grid == 1/2 then menu_13 = true else menu_13 = false end -- Grid: Set to 1/2
  if get_grid == 1 then menu_14 = true else menu_14 = false end -- Grid: Set to 1
  if get_grid == 2 then menu_15 = true else menu_15 = false end -- Grid: Set to 2
  if get_grid == 4 then menu_16 = true else menu_16 = false end -- Grid: Set to 4
end

local menu = "" --#GRID||
menu = menu
.. (menu_01 and "!" or "") .. "Frame" .. "|"
.. (menu_02 and "!" or "") .. "Measure" .. "|"
.. (menu_03 and "!" or "") .. "1/128" .. "|"
.. (menu_04 and "!" or "") .. "1/64" .. "|"
.. (menu_05 and "!" or "") .. "1/32T" .. "|"
.. (menu_06 and "!" or "") .. "1/32" .. "|"
.. (menu_07 and "!" or "") .. "1/16T" .. "|"
.. (menu_08 and "!" or "") .. "1/16" .. "|"
.. (menu_09 and "!" or "") .. "1/8T" .. "|"
.. (menu_10 and "!" or "") .. "1/8" .. "|"
.. (menu_11 and "!" or "") .. "1/4T" .. "|"
.. (menu_12 and "!" or "") .. "1/4" .. "|"
.. (menu_13 and "!" or "") .. "1/2" .. "|"
.. (menu_14 and "!" or "") .. "1" .. "|"
.. (menu_15 and "!" or "") .. "2" .. "|"
.. (menu_16 and "!" or "") .. "4" .. "|"

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
  selection = selection - 0 -- 此处selection值与标题行数关联，标题占用一行则-1
  if selection == 1 then reaper.Main_OnCommand(40904, 0) end -- Frame
  if selection == 2 then reaper.Main_OnCommand(40923, 0) end -- Measure
  if selection == 3 then reaper.Main_OnCommand(41047, 0) end -- 1/128
  if selection == 4 then reaper.Main_OnCommand(40774, 0) end -- 1/64
  if selection == 5 then reaper.Main_OnCommand(41212, 0) end -- 1/32T
  if selection == 6 then reaper.Main_OnCommand(40775, 0) end -- 1/32
  if selection == 7 then reaper.Main_OnCommand(41213, 0) end -- 1/16T
  if selection == 8 then reaper.Main_OnCommand(40776, 0) end -- 1/16
  if selection == 9 then reaper.Main_OnCommand(40777, 0) end -- 1/8T
  if selection == 10 then reaper.Main_OnCommand(40778, 0) end -- 1/8
  if selection == 11 then reaper.Main_OnCommand(41214, 0) end -- 1/4T
  if selection == 12 then reaper.Main_OnCommand(40779, 0) end -- 1/4
  if selection == 13 then reaper.Main_OnCommand(40780, 0) end -- 1/2
  if selection == 14 then reaper.Main_OnCommand(40781, 0) end -- 1
  if selection == 15 then reaper.Main_OnCommand(41210, 0) end -- 2
  if selection == 16 then reaper.Main_OnCommand(41211, 0) end -- 4
end

reaper.defer(function() end)