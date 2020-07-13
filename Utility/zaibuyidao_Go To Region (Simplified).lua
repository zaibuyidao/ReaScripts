--[[
 * ReaScript Name: Go To Region (Simplified)
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Reference: amagalma_Go to region marker (choose from menu list).lua
 * REAPER: 6.0
 * provides: [main=main,midi_editor,midi_inlineeditor] .
--]]

--[[
 * Changelog:
 * v1.0 (2020-7-13)
  + Initial release
--]]

local window, _, _ = reaper.BR_GetMouseCursorContext()
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
local _, _, num_regions = reaper.CountProjectMarkers(0)
if num_regions < 1 then
  reaper.MB("项目中没有区域标记.", "没有任何区域标记...", 0)
  return reaper.defer(function() end)
end
local markers = {}
local cur_pos = reaper.GetCursorPosition()
local idx = -1
while true do
  idx = idx + 1
  local ok, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(idx)
  if ok == 0 then
    break
  else
    if isrgn then
      if cur_pos >= pos and cur_pos < rgnend then
        markers[#markers + 1] = {cur = true, pos = pos, name = name, idx = markrgnindexnumber}
      else
        markers[#markers + 1] = {pos = pos, name = name, idx = markrgnindexnumber}
      end
    end
  end
end
local menu = "#Go To Region|"
for m = 1, #markers do
  local space = "      "
    space = space:sub(tostring(markers[m].idx):len() * 2)
    menu = menu .. (markers[m].cur and "!" or "") .. markers[m].idx .. space .. (markers[m].name == "" and "(未命名)" or markers[m].name) .. "|"
end
reaper.Undo_BeginBlock()
local title = "Hidden gfx window for showing the markers showmenu"
gfx.init(title, 0, 0, 0, 0, 0)
local hwnd = reaper.JS_Window_Find(title, true)
local out = 0
if hwnd then
    out = 7000
    reaper.JS_Window_Move(hwnd, -out, -out)
end
local x, y = reaper.GetMousePosition()
gfx.x, gfx.y = x - 7 + out, y - 30 + out
local selection = gfx.showmenu(menu)
gfx.quit()
if selection > 0 then reaper.GoToRegion(0, selection - 1, true) end
if window == "midi_editor" then reaper.SN_FocusMIDIEditor() end
reaper.defer(function() end)
reaper.Undo_EndBlock("Go To Region (Simplified)", 0)
reaper.UpdateArrange()