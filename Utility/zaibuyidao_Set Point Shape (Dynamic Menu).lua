--[[
 * ReaScript Name: Set Point Shape (Dynamic Menu)
 * Version: 1.0.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-7-11)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

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

local linear, square, slow_start_end, fast_start, fast_end, bezier
local def_linear, def_square, def_slow_start_end, def_fast_start, def_fast_end, def_bezier

-- Set Point Shape 不是開關，所以無效
if reaper.GetToggleCommandStateEx(0, 40189) == 1 then linear = true end
if reaper.GetToggleCommandStateEx(0, 40190) == 1 then square = true end
if reaper.GetToggleCommandStateEx(0, 40424) == 1 then slow_start_end = true end
if reaper.GetToggleCommandStateEx(0, 40428) == 1 then fast_start = true end
if reaper.GetToggleCommandStateEx(0, 40429) == 1 then fast_end = true end
if reaper.GetToggleCommandStateEx(0, 40683) == 1 then bezier = true end
-- Default Point Shape 不是開關，所以無效
if reaper.GetToggleCommandStateEx(0, 40187) == 1 then def_linear = true end
if reaper.GetToggleCommandStateEx(0, 40188) == 1 then def_square = true end
if reaper.GetToggleCommandStateEx(0, 40425) == 1 then def_slow_start_end = true end
if reaper.GetToggleCommandStateEx(0, 40430) == 1 then def_fast_start = true end
if reaper.GetToggleCommandStateEx(0, 40431) == 1 then def_fast_end = true end
if reaper.GetToggleCommandStateEx(0, 40681) == 1 then def_bezier = true end

local menu = "" -- #Set Point Shape||
menu = menu
.. (linear and "!" or "") .. "Linear" .. "|"
.. (square and "!" or "") .. "Square" .. "|"
.. (slow_start_end and "!" or "") .. "Slow start/end" .. "|"
.. (fast_start and "!" or "") .. "Fast start" .. "|"
.. (fast_end and "!" or "") .. "Fast end" .. "|"
.. (bezier and "!" or "") .. "Bezier" .. "|"
.. ">" .. "Default Point Shape" .. "|"
.. (def_linear and "!" or "") .. "Linear" .. "|"
.. (def_square and "!" or "") .. "Square" .. "|"
.. (def_slow_start_end and "!" or "") .. "Slow start/end" .. "|"
.. (def_fast_start and "!" or "") .. "Fast start" .. "|"
.. (def_fast_end and "!" or "") .. "Fast end" .. "|"
.. (def_bezier and "!" or "") .. "Bezier" .. "|"

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
  selection = selection - 0 -- 此處selection值與標題行數關聯，標題佔用一行-1，佔用兩行則-2
  -- Set Point Shape
  if selection == 1 then reaper.Main_OnCommand(40189, 0) end -- Envelope: Set shape of selected points to linear
  if selection == 2 then reaper.Main_OnCommand(40190, 0) end -- Envelope: Set shape of selected points to square
  if selection == 3 then reaper.Main_OnCommand(40424, 0) end -- Envelope: Set shape of selected points to slow start/end
  if selection == 4 then reaper.Main_OnCommand(40428, 0) end -- Envelope: Set shape of selected points to fast start
  if selection == 5 then reaper.Main_OnCommand(40429, 0) end -- Envelope: Set shape of selected points to fast end
  if selection == 6 then reaper.Main_OnCommand(40683, 0) end -- Envelope: Set shape of selected points to bezier
  -- Default Point Shape
  if selection == 7 then reaper.Main_OnCommand(40187, 0) end -- Envelope: Set default point shape to linear
  if selection == 8 then reaper.Main_OnCommand(40188, 0) end -- Envelope: Set default point shape to square
  if selection == 9 then reaper.Main_OnCommand(40425, 0) end -- Envelope: Set default point shape to slow start/end
  if selection == 10 then reaper.Main_OnCommand(40430, 0) end -- Envelope: Set default point shape to fast start
  if selection == 11 then reaper.Main_OnCommand(40431, 0) end -- Envelope: Set default point shape to fast end
  if selection == 12 then reaper.Main_OnCommand(40681, 0) end -- Envelope: Set default point shape to bezier
end

reaper.defer(function() end)