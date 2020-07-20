--[[
 * ReaScript Name: Markers Lite
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Reference: amagalma_Go to region marker (choose from menu list).lua
 * REAPER: 6.0
 * provides: [main=main,midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2020-7-13)
  + Initial release
--]]

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
local _, num_markers = reaper.CountProjectMarkers(0)
if num_markers < 1 then
  reaper.MB("项目中没有标记.", "没有任何标记...", 0)
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
    if not isrgn then -- isrgn = false 则为标记
      if math.abs(cur_pos - pos) < 0.001 then
        markers[#markers + 1] = {cur = true, pos = pos, name = name, idx = markrgnindexnumber}
      else
        markers[#markers + 1] = {pos = pos, name = name, idx = markrgnindexnumber}
      end
    end
  end
end
local menu = "#MARKERS|"
for m = 1, #markers do
  local space = "       "
  space = space:sub(tostring(markers[m].idx):len()*2)
  menu = menu .. (markers[m].cur and "!" or "") .. markers[m].idx .. space .. (markers[m].name == "" and "(未命名)" or markers[m].name) .. "|"
end
local title = "Hidden gfx window for showing the markers showmenu"
gfx.init(title, 0, 0, 0, 0, 0)
local HWND = reaper.JS_Window_Find(title, true)
local out = 0
if HWND then
  out = 7000
  reaper.JS_Window_Move(HWND, -out, -out)
end
local x, y = reaper.GetMousePosition()
gfx.x, gfx.y = x - 7 + out, y - 30 + out
local selection = gfx.showmenu(menu)
gfx.quit()
if selection > 0 then
  reaper.GoToMarker(0, selection - 1, true) -- 此处对应标题行数，一行-1，两行则-2
end
local window, _, _ = reaper.BR_GetMouseCursorContext()
local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
if window == "midi_editor" and not inline_editor then reaper.SN_FocusMIDIEditor() end -- Focus MIDI Editor
reaper.defer(function() end)