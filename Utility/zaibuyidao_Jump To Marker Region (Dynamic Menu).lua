--[[
 * ReaScript Name: Jump To Marker/Region (Dynamic Menu)
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
 * provides: [main=main,midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-6-30)
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

local _, num_markers, num_regions = reaper.CountProjectMarkers(0)

local menu = "" -- #REGIONS|#[ID] [Hr:Mn:Sc:Fr] [Meas:Beat] [Name]||
if num_markers < 1 and num_regions < 1 then menu = '# < no project markers/regions 沒有項目標記/區域>' end

local cur_pos = reaper.GetCursorPosition()

local markers = {}
local mrkidx = -1
while true do
  mrkidx = mrkidx + 1
  local marker_ok, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(mrkidx)
  if marker_ok == 0 then
    break
  else
    if not isrgn then -- isrgn == false 為標記
      markers[#markers + 1] = {pos = pos, name = name, mrkidx = markrgnindexnumber}
    end
  end
end

local regions = {}
local renidx = -1
while true do
  renidx = renidx + 1
  local region_ok, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(renidx)
  if region_ok == 0 then
    break
  else
    if isrgn then -- isrgn = True 為區域
      regions[#regions + 1] = {pos = pos, rgnend = rgnend, name = name, renidx = markrgnindexnumber}
    end
  end
end

for i = 1, #markers do
  local space = " "
  space = space:sub(tostring(markers[i].mrkidx):len()*2)
  local tiemcode_proj_default = reaper.format_timestr_pos(markers[i].pos, "", -1) -- 0=time, -1=proj default
  local tiemcode_0 = reaper.format_timestr_pos(markers[i].pos, "", 0) -- 0=time, -1=proj default
  local tiemcode_1 = reaper.format_timestr_pos(markers[i].pos, "", 1) -- 1=measures.beats + time
  local tiemcode_2 = reaper.format_timestr_pos(markers[i].pos, "", 2) -- 2=measures.beats
  local tiemcode_3 = reaper.format_timestr_pos(markers[i].pos, "", 3) -- 3=seconds
  local tiemcode_4 = reaper.format_timestr_pos(markers[i].pos, "", 4) -- 4=samples
  local tiemcode_5 = reaper.format_timestr_pos(markers[i].pos, "", 5) -- 5=h:m:s:f
  menu = menu .. 'Marker ' .. markers[i].mrkidx .. ': ' .. space .. (markers[i].name == "" and "" or markers[i].name) .. space .. ' [' .. tiemcode_proj_default .. '] ' .. "|"
end

for j = 1, #regions do
  local space = " "
  space = space:sub(tostring(regions[j].renidx):len() * 2)
  local tiemcode_proj_default = reaper.format_timestr_pos(regions[j].pos, "", -1) -- 0=time, -1=proj default
  local tiemcode_0 = reaper.format_timestr_pos(regions[j].pos, "", 0) -- 0=time, -1=proj default
  local tiemcode_1 = reaper.format_timestr_pos(regions[j].pos, "", 1) -- 1=measures.beats + time
  local tiemcode_2 = reaper.format_timestr_pos(regions[j].pos, "", 2) -- 2=measures.beats
  local tiemcode_3 = reaper.format_timestr_pos(regions[j].pos, "", 3) -- 3=seconds
  local tiemcode_4 = reaper.format_timestr_pos(regions[j].pos, "", 4) -- 4=samples
  local tiemcode_5 = reaper.format_timestr_pos(regions[j].pos, "", 5) -- 5=h:m:s:f
  local rgnend_proj_default = reaper.format_timestr_pos(regions[j].rgnend, "", -1) -- 0=time, -1=proj default
  local rgnend_0 = reaper.format_timestr_pos(regions[j].rgnend, "", 0) -- 0=time, -1=proj default
  local rgnend_1 = reaper.format_timestr_pos(regions[j].rgnend, "", 1) -- 1=measures.beats + time
  local rgnend_2 = reaper.format_timestr_pos(regions[j].rgnend, "", 2) -- 2=measures.beats
  local rgnend_3 = reaper.format_timestr_pos(regions[j].rgnend, "", 3) -- 3=seconds
  local rgnend_4 = reaper.format_timestr_pos(regions[j].rgnend, "", 4) -- 4=samples
  local rgnend_5 = reaper.format_timestr_pos(regions[j].rgnend, "", 5) -- 5=h:m:s:f
  menu = menu .. 'Region ' .. regions[j].renidx .. ': ' .. space .. (regions[j].name == "" and "" or regions[j].name) .. space .. ' [' .. tiemcode_proj_default .. '] ' .. space .. '-' .. space .. ' [' .. rgnend_proj_default .. '] ' .. "|"
end

local title = "Hidden gfx window for showing the jump to marker/region showmenu"
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

if #markers > 0 then
  reaper.GoToMarker(0, selection, true)
end

if #regions > 0 then
  for i = 1, #regions do
    if selection == i + #markers then
      reaper.SetEditCurPos(regions[i].pos, true, true)
    end
  end
end

local window, _, _ = reaper.BR_GetMouseCursorContext()
local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
if window == "midi_editor" and not inline_editor then reaper.SN_FocusMIDIEditor() end -- 聚焦 MIDI Editor
reaper.defer(function() end)
