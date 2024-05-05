-- @description Batch Rename Markers in Marker Manager
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Batch Rename Script Series - Use the filter "zaibuyidao batch" in ReaPack or Actions to access all related scripts.

local bias = 0.003 -- 補償偏差值

local ZBYDFuncPath = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Utility/zaibuyidao_Functions.lua'
if reaper.file_exists(ZBYDFuncPath) then
  dofile(ZBYDFuncPath)
  if not checkSWSExtension() or not checkJSAPIExtension() then return end
else
  local errorMsg = "Error - Missing Script (错误 - 缺失脚本)\n\n" ..
  "[English]\nThe required 'zaibuyidao Functions' script file was not found. Please ensure the file is correctly placed at:\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\nIf the file is missing, you can install it via ReaPack by searching for 'zaibuyidao Functions' in the ReaPack package browser.\n\n" ..
  "[中文]\n必需的 'zaibuyidao Functions' 脚本文件未找到。请确保文件正确放置在以下位置：\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\n如果文件缺失，您可以通过 ReaPack 包浏览器搜索并安装 'zaibuyidao Functions'。\n"

  reaper.MB(errorMsg, "Missing Script Error/脚本文件缺失错误", 0)

  if reaper.APIExists('ReaPack_BrowsePackages') then
    reaper.ReaPack_BrowsePackages('zaibuyidao Functions')
  else
    local reapackErrorMsg = "Error - ReaPack Not Found (错误 - 未找到 ReaPack)\n\n" ..
    "[English]\nThe ReaPack extension is not found. Please install ReaPack to manage and install REAPER scripts and extensions easily. Visit https://reapack.com for installation instructions.\n\n" ..
    "[中文]\n未找到 ReaPack 扩展。请安装 ReaPack 来便捷地管理和安装 REAPER 脚本及扩展。访问 https://reapack.com 获取安装指南。\n"

    reaper.MB(reapackErrorMsg, "ReaPack Not Found/未找到 ReaPack", 0)
  end
  return
end

local language = getSystemLanguage()

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

function utf8_sub(str,startChar,endChars)
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

function utf8_insert(str, position, content, from)
  position = tonumber(position)
  local utf8 = require("utf8")

  if from == "end" then
    if position == 0 then
      position = utf8.len(str)
    else
      position = utf8.len(str) - position
    end
  end

  -- 使用utf8.offset来精确获取插入点的字节位置
  local bytePos = utf8.offset(str, position + 1)
  return str:sub(1, bytePos - 1) .. content .. str:sub(bytePos)
end

function utf8_reverse(str)
  local result = {}
  for p, c in utf8.codes(str) do
    table.insert(result, 1, utf8.char(c))
  end
  return table.concat(result)
end

function utf8_remove(str, position, length, from)
  local utf8 = require("utf8")
  local str_reverse = false
  position = tonumber(position)
  position_tag = position
  length = tonumber(length)

  if from == "end" then
    -- 反转字符串
    str = utf8_reverse(str)
    str_reverse = true
  end

  position = position + 1
  startByte = utf8.offset(str, position)
  endByte = utf8.offset(str, position + length)

  -- 检查startByte和endByte是否为nil，如果为nil则设为合理的边界值
  if not startByte or not endByte then
    -- if not startByte then
    --   startByte = 1  -- 如果开始字节是nil，则设置为字符串的开始
    -- end
    -- if not endByte then
    --   endByte = #str + 1  -- 如果结束字节是nil，则设置为字符串的结束后一位
    -- end3
    error("Invalid position or length leading to nil index values.")
  end

  -- 进行字符串切割
  str = str:sub(1, startByte - 1) .. str:sub(endByte)

  if str_reverse then
    -- 如果处理的是反转后的字符串，最后需要再次反转回来
    str = utf8_reverse(str)
  end

  return str
end

function checkPlaceholder(input)
  local placeholders = {
    "仅限数字",
    "僅限數字",
    "正数从开头计数; 负数从末尾反向计数",
    "正數從開頭計數; 負數從末尾反向計數",
    "Numbers only",
    "Positive from start; negative from end",
  }
  for _, placeholder in ipairs(placeholders) do
    if input == placeholder then
      return "0"
    end
  end
  return input
end

function get_all_regions()
  local result = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
    if retval ~= nil and not isrgn then
      pos2 = string.sub(string.format("%.10f", pos), 1, -8) -- 截取到小數點3位數
      rgnend2 = string.sub(string.format("%.10f", rgnend), 1, -8) -- 截取到小數點3位數

      table.insert(result, {
        index = markrgnindexnumber,
        isrgn = isrgn,
        left = pos2,
        right = rgnend2,
        name = name,
        color = color,
        left_ori = pos
      })
    end
  end
  return result
end

function get_sel_regions()
  local all_regions = get_all_regions()
  if #all_regions == 0 then return {} end
  local sel_index = {}

  local rgn_name, rgn_left, mng_regions, cur = {}, {}, {}, {}
  local mrk_selected_bool = false

  j = 0
  for index in string.gmatch(sel_indexes, '[^,]+') do
    j = j + 1
    local sel_item = reaper.JS_ListView_GetItemText(container, tonumber(index), 1)

    if sel_item:find("M") ~= nil then
      rgn_name[j] = reaper.JS_ListView_GetItemText(container, tonumber(index), 2)
      rgn_left[j] = reaper.JS_ListView_GetItemText(container, tonumber(index), 3)

      cur = {
        regionname = rgn_name[j],
        left = tonumber(rgn_left[j]),
      }
    
      table.insert(mng_regions, {
        regionname = cur.regionname,
        left = cur.left
      })

      mrk_selected_bool = true
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
    -- if math.abs( (merged_rgn.right - merged_rgn.left) - (all_regions[r].right - all_regions[r].left) ) <= bias * 2 then
    --   sel_index[r] = true
    -- end

    if merged_rgn.left <= all_regions[r].left + bias then
      sel_index[r] = true
    end
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
  reaper.SetProjectMarker3(0, region.index, region.isrgn, region.left_ori, region.right, region.name, region.color)
end

local show_msg = reaper.GetExtState("BATCH_RENAME_MARKERS_IN_MARKER_MANAGER", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
  if language == "简体中文" then
    script_name = "批量重命名标记管理器中的标记"
    text = "通配符:\n$marker: 标记名称\n\n标记:\nd=01: 数字计数\nd=01-05 or d=05-01: 循环数字\na=a: 字母计数\na=a-e or a=e-a: 循环字母\nr=10: 随机字符串长度\n\n"
    text = text.."功能说明：\n\n1.仅重命名:\n   - 重命名\n\n2.替换内容:\n   - 查找\n   - 替换\n\n支持两种模式修饰符：* 和 ?\n\n3.移除内容:\n   - 移除数量\n   - 定位\n   - 从首尾索引\n\n4.插入内容:\n   - 插入文本\n   - 定位\n   - 从首尾索引\n\n5.循环模式:\n   - 启用或禁用循环数字/字母。输入 'y' 表示是，'n' 表示否。\n"
    text = text.."\n下次还显示此页面吗？"
  elseif language == "繁體中文" then
    script_name = "批量重命名標記管理器中的標記"
    text = "通配符:\n$marker: 標記名稱\n\n標記:\nd=01: 數字計數\nd=01-05 or d=05-01: 循環數字\na=a: 字母計數\na=a-e or a=e-a: 循環字母\nr=10: 隨機字符串長度\n\n"
    text = text.."功能説明：\n\n1.僅重命名:\n   - 重命名\n\n2.替換内容:\n   - 查找\n   - 替換\n\n支持兩種模式修飾符：* 和 ?\n\n3.移除内容:\n   - 移除數量\n   - 定位\n   - 從首尾索引\n\n4.插入内容:\n   - 插入文本\n   - 定位\n   - 從首尾索引\n\n5.循環模式:\n   - 啟用或禁用循環數字/字母。輸入 'y' 表示是，'n' 表示否。\n"
    text = text.."\n下次還顯示此頁面嗎？"
  else
    script_name = "Batch Rename Markers in Marker Manager"
    text = "Wildcards:\n$marker: Marker name\n\nTags:\nd=01: Number count\nd=01-05 or d=05-01: Cycle number\na=a: Letter count\na=a-e or a=e-a: Cycle letter\nr=10: Random string length\n\n"
    text = text.."Function description:\n\n1.Renaming:\n   - Renaming only\n\n2.Replacing content:\n   - Find what\n   - Replace with\n\nSupports two pattern modifiers: * and ?\n\n3.Removing content:\n   - Count\n   - At position\n   - From\n\n4.Inserting content:\n   - To insert\n   - At position\n   - From\n\n5.Cycle Mode:\n   - Enable or disable cycle number/letter. Enter 'y' for yes or 'n' for no.\n"
    text = text.."\nWill this list be displayed next time?"
  end

  local box_ok = reaper.ShowMessageBox(text, script_name, 4)

  if box_ok == 7 then
    show_msg = "false"
    reaper.SetExtState("BATCH_RENAME_MARKERS_IN_MARKER_MANAGER", "ShowMsg", show_msg, true)
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

local pattern, find, replace, remove_count, remove_position, insert_content, insert_position = '', '', '', '0', '0', '', '0'

local remove_from = reaper.GetExtState("BATCH_RENAME_MARKERS_IN_MARKER_MANAGER", "RemoveFrom")
if (remove_from == "") then remove_from = "start" end

local insert_from = reaper.GetExtState("BATCH_RENAME_MARKERS_IN_MARKER_MANAGER", "InsertFrom")
if (insert_from == "") then insert_from = "start" end

local cycle = reaper.GetExtState("BATCH_RENAME_MARKERS_IN_MARKER_MANAGER", "Cycle")
if (cycle == "") then cycle = "y" end

if language == "简体中文" then
  remove_count =  "仅限数字"
  remove_position =  "仅限数字"
  insert_position =  "仅限数字"
  pattern = "(示例: $marker_d=0001_a=E-A_r=4)"
elseif language == "繁體中文" then
  remove_count = "僅限數字"
  remove_position =  "僅限數字"
  insert_position =  "僅限數字"
  pattern = "(示例:$marker_d=0001_a=E-A_r=4)"
else
  remove_count = "Numbers only"
  remove_position =  "Numbers only"
  insert_position =  "Numbers only"
  pattern = "(Example: $marker_d=0001_a=E-A_r=4)"
end

if language == "简体中文" then
  title = "批量重命名标记管理器中的标记"
  uok, uinput = reaper.GetUserInputs(title, 10, "1.重命名,2.查找,   替换,3.移除数量,   定位,   首尾索引 (start/end),4.插入内容,   定位,   首尾索引 (start/end),5.使用循环 (y/n),extrawidth=200", pattern ..','.. find ..','.. replace ..','.. remove_count ..','.. remove_position ..','.. remove_from ..','.. insert_content ..','.. insert_position ..','.. insert_from ..','.. cycle)
elseif language == "繁體中文" then
  title = "批量重命名標記管理器中的標記"
  uok, uinput = reaper.GetUserInputs(title, 10, "1.重命名,2.查找,   替換,3.移除數量,   定位,   首尾索引 (start/end),4.插入内容,   定位,   首尾索引 (start/end),5.使用循環 (y/n),extrawidth=200", pattern ..','.. find ..','.. replace ..','.. remove_count ..','.. remove_position ..','.. remove_from ..','.. insert_content ..','.. insert_position ..','.. insert_from ..','.. cycle)
else
  title = "Batch Rename Markers in Marker Manager"
  uok, uinput = reaper.GetUserInputs(title, 10, "1.Rename ,2.Find what,   Replace with,3.Remove count,   At position,   From (start/end),4.To insert,   At position,   From (start/end),5.Use cycle mode (y/n),extrawidth=200", pattern ..','.. find ..','.. replace ..','.. remove_count ..','.. remove_position ..','.. remove_from ..','.. insert_content ..','.. insert_position ..','.. insert_from ..','.. cycle)
end

if not uok then return end

pattern, find, replace, remove_count, remove_position, remove_from, insert_content, insert_position, insert_from, cycle = uinput:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
if cycle ~= 'y' and cycle ~= 'n' then return end
if pattern == "(示例: $marker_d=0001_a=E-A_r=4)" or pattern == "(Example: $marker_d=0001_a=E-A_r=4)" then pattern = "" end

remove_count = checkPlaceholder(remove_count)
remove_position = checkPlaceholder(remove_position)
insert_position = checkPlaceholder(insert_position)

find = find:gsub('-', '%%-')
find = find:gsub('+', '%%+')
find = find:gsub('*', '.*')
find = find:gsub('?', '.?')

reaper.SetExtState("BATCH_RENAME_MARKERS_IN_MARKER_MANAGER", "RemoveFrom", remove_from, false)
reaper.SetExtState("BATCH_RENAME_MARKERS_IN_MARKER_MANAGER", "InsertFrom", insert_from, false)
reaper.SetExtState("BATCH_RENAME_MARKERS_IN_MARKER_MANAGER", "Cycle", cycle, false)

function build_name(build_pattern, origin_name, i)
  build_pattern = build_pattern:gsub("$maeker", origin_name)

  if cycle == "y" then
    build_pattern = build_pattern:gsub("d=(%d+)%-(%d+)", function (start_idx, end_idx) -- 匹配循环数字序号
      local len = #start_idx
      start_idx = tonumber(start_idx)
      end_idx = tonumber(end_idx)
      if start_idx > end_idx then
        return string.format("%0" .. len .. "d", start_idx - ((i - 1) % (start_idx - end_idx + 1)))
      end
      return string.format("%0" .. len .. "d", start_idx + ((i - 1) % (end_idx - start_idx + 1)))
    end)
  end

  build_pattern = build_pattern:gsub("d=(%d+)", function (start_idx) -- 匹配数字序号
    return string.format("%0" .. #start_idx .. "d", tonumber(start_idx) + i - 1)
  end)

  build_pattern = build_pattern:gsub("r=(%d+)", function (n)
    local t = {
      "0","1","2","3","4","5","6","7","8","9",
      "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
      "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
    }
    local s = ""
    for i = 1, n do
      s = s .. t[math.random(#t)]
    end
    return s
  end)

  local ab = string.byte("a")
  local zb = string.byte("z")
  local Ab = string.byte("A")
  local Zb = string.byte("Z")

  if cycle == "y" then
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

  region.name = utf8_insert(region.name, insert_position, insert_content, insert_from)
  region.name = utf8_remove(region.name, remove_position, remove_count, remove_from)
  if find ~= "" then region.name = string.gsub(region.name, find, replace) end

  if insert ~= '' then -- 指定位置插入内容
    region.name = build_name(region.name, origin_name, i)
  end

  set_region(region)
end

reaper.Undo_EndBlock(title, -1)
HWND_Region = reaper.JS_Window_Find("Region/Marker Manager",0)
reaper.BR_Win32_SetFocus(HWND_Region)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()