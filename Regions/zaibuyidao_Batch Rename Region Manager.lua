--[[
 * ReaScript Name: Batch Rename Region Manager
 * Version: 1.7.5
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0 or newer recommended
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.7.4 (2022-3-19)
  + 修復部分region無法匹配問題，同時優化查找/替換功能。
 * v1.0 (2021-6-10)
  + Initial release
--]]

local bias = 0.002 -- 補償偏差值

function Msg(param) 
  reaper.ShowConsoleMsg(tostring(param) .. "\n") 
end

if not reaper.BR_Win32_SetFocus then
    local retval = reaper.ShowMessageBox("這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
    if retval == 1 then
      Open_URL("http://www.sws-extension.org/download/pre-release/")
    end
end

if not reaper.APIExists("JS_Localize") then
  reaper.MB("請右鍵單擊並安裝'js_ReaScriptAPI: API functions for ReaScripts'。然後重新啟動REAPER並再次運行腳本，謝謝！", "你必須安裝 JS_ReaScriptAPI", 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, "錯誤", 0)
  end
  return reaper.defer(function() end)
end

function GetRegionManager()
  local title = reaper.JS_Localize("Region/Marker Manager", "common")
  local arr = reaper.new_array({}, 1024)
  reaper.JS_Window_ArrayFind(title, true, arr)
  local adr = arr.table()
  for j = 1, #adr do
    local hwnd = reaper.JS_Window_HandleFromAddress(adr[j])
    -- verify window by checking if it also has a specific child.
    if reaper.JS_Window_FindChildByID(hwnd, 1056) then -- 1045:ID of clear button
      return hwnd
    end 
  end
end

local hWnd = GetRegionManager()
if hWnd == nil then return end
local container = reaper.JS_Window_FindChildByID(hWnd, 1071)
local sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(container)
if sel_count == 0 then return end

function chsize(char)
  if not char then
    return 0
  elseif char > 240 then
    return 4
  elseif char > 225 then
    return 3
  elseif char > 192 then
    return 2
  else
    return 1
  end
end

function utf8_len(str)
  local len = 0
  local currentIndex = 1
  while currentIndex <= #str do
    local char = string.byte(str,currentIndex)
    currentIndex = currentIndex + chsize(char)
    len = len + 1
  end
  return len
end

function utf8_sub1(str,startChar,endChars)
  local startIndex = 1
  startChar = startChar + 1
  while startChar > 1 do
    local char = string.byte(str,startIndex)
    startIndex = startIndex + chsize(char)
    startChar = startChar - 1
  end
  local currentIndex = startChar
  newChars = utf8_len(str) - endChars
  while newChars > 0 and currentIndex <= #str do
    local char = string.byte(str,currentIndex)
    currentIndex = currentIndex + chsize(char)
    newChars = newChars - 1
  end
  return str:sub(startIndex,currentIndex - 1)
end

function utf8_sub2(str,startChar,endChars)
  local startIndex = 1
  startChar = startChar + 1
  while startChar > 1 do
    local char = string.byte(str,startIndex)
    startIndex = startIndex + chsize(char)
    startChar = startChar - 1
  end
  local currentIndex = startChar
  while tonumber(endChars) > 0 and currentIndex <= #str do
    local char = string.byte(str,currentIndex)
    currentIndex = currentIndex + chsize(char)
    endChars = endChars - 1
  end
  return str:sub(startIndex,currentIndex - 1)
end

function utf8_sub3(str,startChar)
  local startIndex = 1
  startChar = startChar + 1
  while startChar > 1 do
      local char = string.byte(str,startIndex)
      startIndex = startIndex + chsize(char)
      startChar = startChar - 1
  end
  return str:sub(startIndex)
end

function get_all_regions()
  local result = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
    if retval ~= nil and isrgn then
      pos2 = string.sub(string.format("%.10f", pos), 1, -8) -- 截取到小數點3位數
      rgnend2 = string.sub(string.format("%.10f", rgnend), 1, -8) -- 截取到小數點3位數

      table.insert(result, {
        index = markrgnindexnumber,
        isrgn = isrgn,
        left = pos2,
        right = rgnend2,
        name = name,
        color = color,
        left_ori = pos,
        right_ori = rgnend
      })
    end
  end
  return result
end

function get_sel_regions()
  local all_regions = get_all_regions()
  if #all_regions == 0 then return {} end
  local sel_index = {}

  local rgn_name, rgn_left, rgn_right, mng_regions, cur = {}, {}, {}, {}, {}
  local rgn_selected_bool = false

  j = 0
  for index in string.gmatch(sel_indexes, '[^,]+') do
    j = j + 1
    local sel_item = reaper.JS_ListView_GetItemText(container, tonumber(index), 1)

    if sel_item:find("R") ~= nil then
      rgn_name[j] = reaper.JS_ListView_GetItemText(container, tonumber(index), 2)
      rgn_left[j] = reaper.JS_ListView_GetItemText(container, tonumber(index), 3)
      rgn_right[j] = reaper.JS_ListView_GetItemText(container, tonumber(index), 4)

      cur = {
        regionname = rgn_name[j],
        left = tonumber(rgn_left[j]),
        right = tonumber(rgn_right[j])
      }
    
      table.insert(mng_regions, {
        regionname = cur.regionname,
        left = cur.left,
        right = cur.right
      })

      rgn_selected_bool = true
    end
  end

  -- 标记选中区域
  for _, merged_rgn in ipairs(mng_regions) do
    local l, r = 1, #all_regions
    -- 查找第一个左端点在左侧的区域
    while l <= r do
      local mid = math.floor((l+r)/2)
      if (all_regions[mid].left - bias) > merged_rgn.left then
        r = mid - 1
      else
        l = mid + 1
      end
    end
    if math.abs( (merged_rgn.right - merged_rgn.left) - (all_regions[r].right - all_regions[r].left) ) <= bias * 2 then
      sel_index[r] = true
    end

    -- if merged_rgn.right <= all_regions[r].right + bias then
    --   sel_index[r] = true
    -- end
  end

  -- 处理结果
  local result = {}
  local indexs = {}
  for k, _ in pairs(sel_index) do table.insert(indexs, k) end
  table.sort(indexs)
  for _, v in ipairs(indexs) do table.insert(result, all_regions[v]) end

  return result
end

function set_region(region)
  reaper.SetProjectMarker3(0, region.index, region.isrgn, region.left_ori, region.right_ori, region.name, region.color)
end

local show_msg = reaper.GetExtState("BatchRenameRegionManager", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
  script_name = "批量重命名區域管理器"
  text = "$regionname: Region name 區域名稱\nv=01: Region count 區域計數\nv=01-05 or v=05-01: Loop region count 循環區域計數\na=a: Letter count 字母計數\na=a-e or a=e-a: Loop letter count 循環字母計數\n\nScript function description:\n脚本功能説明：\n\n1.Rename only\nRename 重命名\n\n2.String interception\nFrom beginning 截取開頭\nFrom end 截取結尾\n\n3.Specify position, insert or remove\nAt position 指定位置\nTo insert 插入\nRemove 移除\n\n4.Find and Replace\nFind what 查找\nReplace with 替換\n\nFind supports two pattern modifiers: * and ?\n查找支持两個模式修飾符：* 和 ?\n\n5.Loop count\nLimit or reverse cycle count. Enter 1 to enable, 0 to disable\n限制或反轉循環計數。輸入1為啓用，0為不啓用\n"
  text = text.."\nWill this list be displayed next time?\n下次還顯示此列表嗎？"
  local box_ok = reaper.ShowMessageBox("Wildcards 通配符:\n\n"..text, script_name, 4)

  if box_ok == 7 then
    show_msg = "false"
    reaper.SetExtState("BatchRenameRegionManager", "ShowMsg", show_msg, true)
  end
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

-- 默認使用標尺的時間單位:秒
if reaper.GetToggleCommandStateEx(0, 40365) == 1 then -- View: Time unit for ruler: Minutes:Seconds
  minutes_seconds_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

if reaper.GetToggleCommandStateEx(0, 40367) == 1 then -- View: Time unit for ruler: Measures.Beats
  meas_beat_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

if reaper.GetToggleCommandStateEx(0, 41916) == 1 then -- View: Time unit for ruler: Measures.Beats (minimal)
  meas_beat_mini_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

if reaper.GetToggleCommandStateEx(0, 40368) == 1 then -- View: Time unit for ruler: Seconds
  seconds_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

if reaper.GetToggleCommandStateEx(0, 40369) == 1 then -- View: Time unit for ruler: Samples
  samples_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

if reaper.GetToggleCommandStateEx(0, 40370) == 1 then -- View: Time unit for ruler: Hours:Minutes:Seconds:Frames
  hours_frames_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

if reaper.GetToggleCommandStateEx(0, 41973) == 1 then -- View: Time unit for ruler: Absolute frames
  frames_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

local sel_regions = get_sel_regions()

if minutes_seconds_flag then reaper.Main_OnCommand(40365, 0) end -- View: Time unit for ruler: Minutes:Seconds
if seconds_flag then reaper.Main_OnCommand(40368, 0) end -- View: Time unit for ruler: Seconds
if meas_beat_flag then reaper.Main_OnCommand(40367, 0) end -- View: Time unit for ruler: Measures.Beats
if meas_beat_mini_flag then reaper.Main_OnCommand(41916, 0) end -- View: Time unit for ruler: Measures.Beats (minimal)
if samples_flag then reaper.Main_OnCommand(40369, 0) end -- View: Time unit for ruler: Samples
if hours_frames_flag then reaper.Main_OnCommand(40370, 0) end -- View: Time unit for ruler: Hours:Minutes:Seconds:Frames
if frames_flag then reaper.Main_OnCommand(41973, 0) end -- View: Time unit for ruler: Absolute frames

local pattern, begin_str, end_str, position, insert, delete, find, replace, reverse = '', '0', '0', '0', '', '0', '', '', '1'

local retval, retvals_csv = reaper.GetUserInputs("Batch Reanme Region Manager", 9, "Rename 重命名,From beginning 截取開頭,From end 截取結尾,At position 指定位置,To insert 插入,Remove 移除,Find what 查找,Replace with 替換,Loop count 循環計數,extrawidth=200", pattern ..','.. begin_str .. ','.. end_str ..','.. position ..','.. insert ..','.. delete ..','.. find ..','.. replace ..','.. reverse)
if not retval then return end

pattern, begin_str, end_str, position, insert, delete, find, replace, reverse = retvals_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
find = find:gsub('-', '%%-')
find = find:gsub('+', '%%+')
find = find:gsub('*', '.*')
find = find:gsub('?', '.?')

function build_name(build_pattern, origin_name, i)
  build_pattern = build_pattern:gsub("$regionname", origin_name)

  if reverse == "1" then
    build_pattern = build_pattern:gsub("v=(%d+)%-(%d+)", function (start_idx, end_idx) -- 匹配循环数字序号
      local len = #start_idx
      start_idx = tonumber(start_idx)
      end_idx = tonumber(end_idx)
      if start_idx > end_idx then
        return string.format("%0" .. len .. "d", start_idx - ((i - 1) % (start_idx - end_idx + 1)))
      end
      return string.format("%0" .. len .. "d", start_idx + ((i - 1) % (end_idx - start_idx + 1)))
    end)
  end

  build_pattern = build_pattern:gsub("v=(%d+)", function (start_idx) -- 匹配数字序号
    return string.format("%0" .. #start_idx .. "d", tonumber(start_idx) + i - 1)
  end)

  local ab = string.byte("a")
  local zb = string.byte("z")
  local Ab = string.byte("A")
  local Zb = string.byte("Z")

  if reverse == "1" then
    build_pattern = build_pattern:gsub("a=([A-Z])%-([A-Z])", function(c1, c2) -- 匹配循环大写字母
      local c1b = c1:byte()
      local c2b = c2:byte()
      if c1b > c2b then
        return string.char(c1b - ((i - 1) % (c1b - c2b + 1)))
      end
      return string.char(c1b + ((i - 1) % (c2b - c1b + 1)))
    end)
  
    build_pattern = build_pattern:gsub("a=([a-z])%-([a-z])", function(c1, c2) -- 匹配循环小写字母
      local c1b = c1:byte()
      local c2b = c2:byte()
      if c1b > c2b then
        return string.char(c1b - ((i - 1) % (c1b - c2b + 1)))
      end
      return string.char(c1b + ((i - 1) % (c2b - c1b + 1)))
    end)
  end

  build_pattern = build_pattern:gsub("a=([A-Za-z])", function(c) -- 匹配字母
    local cb = c:byte()
    if cb >= ab and cb <= zb then
      return string.char(ab + ((cb - ab) + (i - 1)) % 26)
    elseif cb >= Ab and cb <= Zb then
      return string.char(Ab + ((cb - Ab) + (i - 1)) % 26)
    end
  end)

  return build_pattern
end

for i,region in ipairs(sel_regions) do
  local origin_name = region.name

  if pattern ~= "" then -- 重命名
    region.name = build_name(pattern, origin_name, i)
  end

  region.name = utf8_sub1(region.name, begin_str, end_str)
  region.name = utf8_sub2(region.name, 0, position) .. insert .. utf8_sub3(region.name, position + delete)
  if find ~= "" then region.name = string.gsub(region.name, find, replace) end

  if insert ~= '' then -- 指定位置插入内容
    region.name = build_name(region.name, origin_name, i)
  end

  set_region(region)
end

reaper.Undo_EndBlock('Batch Rename Region Manager', -1)
HWND_Region = reaper.JS_Window_Find("Region/Marker Manager",0)
reaper.BR_Win32_SetFocus(HWND_Region)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()