--[[
 * ReaScript Name: Set CC Curve Shape (Dynamic Menu)
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
 * v1.0 (2020-8-29)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local HWND = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(HWND)

if not reaper.APIExists("JS_Window_Find") then
  reaper.MB("请右键单击并安装 'js_ReaScriptAPI: API functions for ReaScripts'. 然后重新启动 REAPER 并再次运行脚本. 谢谢!", "你必须安装 JS_ReaScriptAPI", 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, "出了些问题...", 0)
  end
  return reaper.defer(function() end)
end

local square, linear, slow_start_end, fast_start, fast_end, bezier
local def_square, def_linear, def_slow_start_end, def_fast_start, def_fast_end, def_bezier

-- CC曲线形状勾选状态，如果状态为1则勾选。
if reaper.GetToggleCommandStateEx(32060, 42081) == 1 then square = true end
if reaper.GetToggleCommandStateEx(32060, 42080) == 1 then linear = true end
if reaper.GetToggleCommandStateEx(32060, 42082) == 1 then slow_start_end = true end
if reaper.GetToggleCommandStateEx(32060, 42083) == 1 then fast_start = true end
if reaper.GetToggleCommandStateEx(32060, 42084) == 1 then fast_end = true end
if reaper.GetToggleCommandStateEx(32060, 42085) == 1 then bezier = true end
-- 默认CC曲线形状勾选状态，如果状态为1则勾选。
if reaper.GetToggleCommandStateEx(32060, 42087) == 1 then def_square = true end
if reaper.GetToggleCommandStateEx(32060, 42086) == 1 then def_linear = true end
if reaper.GetToggleCommandStateEx(32060, 42088) == 1 then def_slow_start_end = true end
if reaper.GetToggleCommandStateEx(32060, 42089) == 1 then def_fast_start = true end
if reaper.GetToggleCommandStateEx(32060, 42090) == 1 then def_fast_end = true end
if reaper.GetToggleCommandStateEx(32060, 42091) == 1 then def_bezier = true end

local menu = "" -- #CC curve shape||
menu = menu
.. (square and "!" or "") .. "Square" .. "|"
.. (linear and "!" or "") .. "Linear" .. "|"
.. (slow_start_end and "!" or "") .. "Slow start/end" .. "|"
.. (fast_start and "!" or "") .. "Fast start" .. "|"
.. (fast_end and "!" or "") .. "Fast end" .. "|"
.. (bezier and "!" or "") .. "Bezier" .. "|"
.. ">" .. "Default CC curve shape" .. "|"
.. (def_square and "!" or "") .. "Square" .. "|"
.. (def_linear and "!" or "") .. "Linear" .. "|"
.. (def_slow_start_end and "!" or "") .. "Slow start/end" .. "|"
.. (def_fast_start and "!" or "") .. "Fast start" .. "|"
.. (def_fast_end and "!" or "") .. "Fast end" .. "|"
.. (def_bezier and "!" or "") .. "Bezier" .. "|"

local title = "Hidden gfx window for showing the CC curve shape showmenu"
gfx.init(title, 0, 0, 0, 0, 0)
local dyn_win = reaper.JS_Window_Find(title, true)
local out = 0
if dyn_win then
  out = 7000
  reaper.JS_Window_Move(dyn_win, -out, -out)
end

out = reaper.GetOS():find("OSX") and 0 or out
gfx.x, gfx.y = gfx.mouse_x-0+out, gfx.mouse_y-0+out -- 可设置弹出菜单时鼠标所处的位置
local selection = gfx.showmenu(menu)
gfx.quit()

if selection > 0 then
  selection = selection - 0 -- 此处selection值与标题行数关联，标题占用一行-1，占用两行则-2
  -- 设置CC曲线形状
  if selection == 1 then reaper.MIDIEditor_OnCommand(HWND, 42081) end -- Set CC shape to square
  if selection == 2 then reaper.MIDIEditor_OnCommand(HWND, 42080) end -- Set CC shape to linear
  if selection == 3 then reaper.MIDIEditor_OnCommand(HWND, 42082) end -- Set CC shape to slow start/end
  if selection == 4 then reaper.MIDIEditor_OnCommand(HWND, 42083) end -- Set CC shape to fast start
  if selection == 5 then reaper.MIDIEditor_OnCommand(HWND, 42084) end -- Set CC shape to fast end
  if selection == 6 then reaper.MIDIEditor_OnCommand(HWND, 42085) end -- Set CC shape to bezier
  -- 设置默认CC曲线形状
  if selection == 7 then reaper.MIDIEditor_OnCommand(HWND, 42087) end -- Set default CC shape to square
  if selection == 8 then reaper.MIDIEditor_OnCommand(HWND, 42086) end -- Set default CC shape to linear
  if selection == 9 then reaper.MIDIEditor_OnCommand(HWND, 42088) end -- Set default CC shape to slow start/end
  if selection == 10 then reaper.MIDIEditor_OnCommand(HWND, 42089) end -- Set default CC shape to fast start
  if selection == 11 then reaper.MIDIEditor_OnCommand(HWND, 42090) end -- Set default CC shape to fast end
  if selection == 12 then reaper.MIDIEditor_OnCommand(HWND, 42091) end -- Set default CC shape to bezier
end

reaper.SN_FocusMIDIEditor()
reaper.defer(function() end)