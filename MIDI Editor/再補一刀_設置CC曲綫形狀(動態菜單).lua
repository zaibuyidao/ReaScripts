--[[
 * ReaScript Name: 設置CC曲綫形狀(動態菜單)
 * Version: 1.0.1
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-8-29)
  + 初始發行
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

local square, linear, slow_start_end, fast_start, fast_end, bezier
local def_square, def_linear, def_slow_start_end, def_fast_start, def_fast_end, def_bezier

-- CC曲線形狀勾選狀態，如果狀態為1則勾選。
if reaper.GetToggleCommandStateEx(32060, 42081) == 1 then square = true end
if reaper.GetToggleCommandStateEx(32060, 42080) == 1 then linear = true end
if reaper.GetToggleCommandStateEx(32060, 42082) == 1 then slow_start_end = true end
if reaper.GetToggleCommandStateEx(32060, 42083) == 1 then fast_start = true end
if reaper.GetToggleCommandStateEx(32060, 42084) == 1 then fast_end = true end
if reaper.GetToggleCommandStateEx(32060, 42085) == 1 then bezier = true end
-- 默認CC曲線形狀勾選狀態，如果狀態為1則勾選。
if reaper.GetToggleCommandStateEx(32060, 42087) == 1 then def_square = true end
if reaper.GetToggleCommandStateEx(32060, 42086) == 1 then def_linear = true end
if reaper.GetToggleCommandStateEx(32060, 42088) == 1 then def_slow_start_end = true end
if reaper.GetToggleCommandStateEx(32060, 42089) == 1 then def_fast_start = true end
if reaper.GetToggleCommandStateEx(32060, 42090) == 1 then def_fast_end = true end
if reaper.GetToggleCommandStateEx(32060, 42091) == 1 then def_bezier = true end

local menu = "" -- #CC curve shape||
menu = menu
.. (square and "!" or "") .. "正方形" .. "|"
.. (linear and "!" or "") .. "綫性" .. "|"
.. (slow_start_end and "!" or "") .. "緩慢開始/結束" .. "|"
.. (fast_start and "!" or "") .. "快速開始" .. "|"
.. (fast_end and "!" or "") .. "快速結束" .. "|"
.. (bezier and "!" or "") .. "貝塞爾" .. "|"
.. ">" .. "默認 CC 曲綫形狀" .. "|"
.. (def_square and "!" or "") .. "正方形" .. "|"
.. (def_linear and "!" or "") .. "綫性" .. "|"
.. (def_slow_start_end and "!" or "") .. "緩慢開始/結束" .. "|"
.. (def_fast_start and "!" or "") .. "快速開始" .. "|"
.. (def_fast_end and "!" or "") .. "快速結束" .. "|"
.. (def_bezier and "!" or "") .. "貝塞爾" .. "|"

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
  -- 設置CC曲線形狀
  if selection == 1 then reaper.MIDIEditor_OnCommand(HWND, 42081) end -- Set CC shape to square
  if selection == 2 then reaper.MIDIEditor_OnCommand(HWND, 42080) end -- Set CC shape to linear
  if selection == 3 then reaper.MIDIEditor_OnCommand(HWND, 42082) end -- Set CC shape to slow start/end
  if selection == 4 then reaper.MIDIEditor_OnCommand(HWND, 42083) end -- Set CC shape to fast start
  if selection == 5 then reaper.MIDIEditor_OnCommand(HWND, 42084) end -- Set CC shape to fast end
  if selection == 6 then reaper.MIDIEditor_OnCommand(HWND, 42085) end -- Set CC shape to bezier
  -- 設置默認CC曲線形狀
  if selection == 7 then reaper.MIDIEditor_OnCommand(HWND, 42087) end -- Set default CC shape to square
  if selection == 8 then reaper.MIDIEditor_OnCommand(HWND, 42086) end -- Set default CC shape to linear
  if selection == 9 then reaper.MIDIEditor_OnCommand(HWND, 42088) end -- Set default CC shape to slow start/end
  if selection == 10 then reaper.MIDIEditor_OnCommand(HWND, 42089) end -- Set default CC shape to fast start
  if selection == 11 then reaper.MIDIEditor_OnCommand(HWND, 42090) end -- Set default CC shape to fast end
  if selection == 12 then reaper.MIDIEditor_OnCommand(HWND, 42091) end -- Set default CC shape to bezier
end

reaper.SN_FocusMIDIEditor()
reaper.defer(function() end)