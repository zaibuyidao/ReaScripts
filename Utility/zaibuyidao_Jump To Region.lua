--[[
 * ReaScript Name: Jump To Region
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * provides: [main=main,midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-6-30)
  # 將當前區域完成後再跳轉修改為立即跳轉
 * v1.0 (2020-8-12)
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

local _, _, num_regions = reaper.CountProjectMarkers(0)
if num_regions < 1 then
  reaper.MB("項目中沒有區域.", "沒有任何區域...", 0)
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
    if isrgn then -- isrgn = True 為區域
      if cur_pos >= pos and cur_pos < rgnend then
        markers[#markers + 1] = {cur = true, pos = pos, rgnend = rgnend, name = name, idx = markrgnindexnumber}
      else
        markers[#markers + 1] = {pos = pos, rgnend = rgnend, name = name, idx = markrgnindexnumber}
      end
    end
  end
end

local menu = "" -- #MARKER/REGION|#[ID] [Hr:Mn:Sc:Fr] [Meas:Beat] [Name]||
for m = 1, #markers do
  local space = " "
    space = space:sub(tostring(markers[m].idx):len() * 2)
    tiemcode_proj_default = reaper.format_timestr_pos(markers[m].pos, "", -1) -- 0=time, -1=proj default
    tiemcode_0 = reaper.format_timestr_pos(markers[m].pos, "", 0) -- 0=time, -1=proj default
    tiemcode_1 = reaper.format_timestr_pos(markers[m].pos, "", 1) -- 1=measures.beats + time
    tiemcode_2 = reaper.format_timestr_pos(markers[m].pos, "", 2) -- 2=measures.beats
    tiemcode_3 = reaper.format_timestr_pos(markers[m].pos, "", 3) -- 3=seconds
    tiemcode_4 = reaper.format_timestr_pos(markers[m].pos, "", 4) -- 4=samples
    tiemcode_5 = reaper.format_timestr_pos(markers[m].pos, "", 5) -- 5=h:m:s:f
    rgnend_proj_default = reaper.format_timestr_pos(markers[m].rgnend, "", -1) -- 0=time, -1=proj default
    rgnend_0 = reaper.format_timestr_pos(markers[m].rgnend, "", 0) -- 0=time, -1=proj default
    rgnend_1 = reaper.format_timestr_pos(markers[m].rgnend, "", 1) -- 1=measures.beats + time
    rgnend_2 = reaper.format_timestr_pos(markers[m].rgnend, "", 2) -- 2=measures.beats
    rgnend_3 = reaper.format_timestr_pos(markers[m].rgnend, "", 3) -- 3=seconds
    rgnend_4 = reaper.format_timestr_pos(markers[m].rgnend, "", 4) -- 4=samples
    rgnend_5 = reaper.format_timestr_pos(markers[m].rgnend, "", 5) -- 5=h:m:s:f
    menu = menu .. (markers[m].cur and "!" or "") .. 'Region ' .. markers[m].idx .. ': ' .. space .. (markers[m].name == "" and "" or markers[m].name) .. space .. ' [' .. tiemcode_proj_default .. '] ' .. space .. '-' .. space .. ' [' .. rgnend_proj_default .. '] ' .. "|"
end

local title = "Hidden gfx window for showing the jump to region showmenu"
gfx.init(title, 0, 0, 0, 0, 0)
local hwnd = reaper.JS_Window_Find(title, true)
local out = 0
if hwnd then
  out = 7000
  reaper.JS_Window_Move(hwnd, -out, -out)
end

out = reaper.GetOS():find("OSX") and 0 or out
gfx.x, gfx.y = gfx.mouse_x-0+out, gfx.mouse_y-0+out -- 可設置彈出菜單時鼠標所處的位置
local selection = gfx.showmenu(menu)
gfx.quit()

selection = selection - 0 -- 此處selection值與標題行數關聯，標題佔用一行-1，佔用兩行則-2

if selection > 0 then
  -- reaper.GoToRegion(0, selection, true) -- 當前區域完成後再跳轉
  for i = 1, #markers do
    if selection == i then 
      reaper.SetEditCurPos(markers[i].pos, true, true)
    end
  end
end

local window, _, _ = reaper.BR_GetMouseCursorContext()
local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
if window == "midi_editor" and not inline_editor then reaper.SN_FocusMIDIEditor() end -- 聚焦 MIDI Editor
reaper.defer(function() end)
