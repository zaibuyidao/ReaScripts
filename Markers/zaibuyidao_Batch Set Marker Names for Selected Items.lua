-- @description Batch Set Marker Names for Selected Items
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Batch Rename Script Series - Use the filter "zaibuyidao batch" in ReaPack or Actions to access all related scripts.

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

function get_sel_regions()
  local sel_index = {}
  local item_count = reaper.CountSelectedMediaItems(0)
  if item_count == 0 then return {} end

  -- 获取item列表
  local items = {}
  for i = 1, item_count do
    local item = reaper.GetSelectedMediaItem(0, i-1)
    if item ~= nil then
      local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      local item_end = item_pos + item_len
      table.insert(items, {left=item_pos,right=item_end} )
    end
  end

  -- 合并item
  local merged_items = {}
  table.sort(items, function(a,b)
    return a.left < b.left
  end)
  local cur = {
    left = items[1].left,
    right = items[1].right
  }
  for i,item in ipairs(items) do
    if cur.right - item.left > 0 then -- 确定区域是否为相交
      cur.right = math.max(item.right,cur.right)
    else
      table.insert(merged_items, cur)
      cur = {
        left = item.left,
        right = item.right
      }
    end
  end
  table.insert(merged_items, cur)
  return merged_items
end

function create_region(reg_start, reg_end, name)
  if name == nil then return end
  local index = reaper.AddProjectMarker2(0, false, reg_start, reg_end, name, -1, 0)
end

function set_region(region)
  reaper.SetProjectMarker3(0, region.index, region.isrgn, region.left, region.right, region.name, region.color)
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local language = getSystemLanguage()

local show_msg = reaper.GetExtState("BATCH_SET_MARKER_NAMES_FOR_SELECTED_ITEMS", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
  if language == "简体中文" then
    script_name = "批量设置标记名称"
    text = "标记:\nd=01: 数字计数\nd=01-05 or d=05-01: 循环数字\na=a: 字母计数\na=a-e or a=e-a: 循环字母\nr=10: 随机字符串长度\n\n"
    text = text.."功能说明：\n\n1.仅设置名称:\n   - 标记名称\n\n2.循环模式:\n   - 启用或禁用循环数字/字母。输入 'y' 表示是，'n' 表示否。\n"
    text = text.."\n下次还显示此页面吗？"
  elseif language == "繁體中文" then
    script_name = "批量設置標記名稱"
    text = "標記:\nd=01: 數字計數\nd=01-05 or d=05-01: 循環數字\na=a: 字母計數\na=a-e or a=e-a: 循環字母\nr=10: 隨機字符串長度\n\n"
    text = text.."功能説明：\n\n1.僅設置名稱:\n   - 標記名稱\n\n2.循環模式:\n   - 啟用或禁用循環數字/字母。輸入 'y' 表示是，'n' 表示否。\n"
    text = text.."\n下次還顯示此頁面嗎？"
  else
    script_name = "Batch Set Marker Names"
    text = "Tags:\nd=01: Number count\nd=01-05 or d=05-01: Cycle number\na=a: Letter count\na=a-e or a=e-a: Cycle letter\nr=10: Random string length\n\n"
    text = text.."Function description:\n\n1.Set name only:\n   - Marker name\n\n2.Cycle Mode:\n   - Enable or disable cycle number/letter. Enter 'y' for yes or 'n' for no.\n"
    text = text.."\nWill this list be displayed next time?"
  end

  local box_ok = reaper.ShowMessageBox(text, script_name, 4)

  if box_ok == 7 then
    show_msg = "false"
    reaper.SetExtState("BATCH_SET_MARKER_NAMES_FOR_SELECTED_ITEMS", "ShowMsg", show_msg, true)
  end
end

local pattern = reaper.GetExtState("BATCH_SET_MARKER_NAMES_FOR_SELECTED_ITEMS", "Name")
if (pattern == "") then pattern = "Marker_d=0001_a=E-A_r=4" end
local reverse = reaper.GetExtState("BATCH_SET_MARKER_NAMES_FOR_SELECTED_ITEMS", "Reverse")
if (reverse == "") then reverse = "y" end

if language == "简体中文" then
  title = "批量设置标记名称"
  uok, uinput = reaper.GetUserInputs(title, 2, "标记名称,使用循环 (y/n),extrawidth=200", pattern ..','.. reverse)
elseif language == "繁體中文" then
  title = "批量設置標記名稱"
  uok, uinput = reaper.GetUserInputs(title, 2, "標記名稱,使用循環 (y/n),extrawidth=200", pattern ..','.. reverse)
else
  title = "Batch Set Marker Names"
  uok, uinput = reaper.GetUserInputs(title, 2, "Marker name,Use cycle mode (y/n),extrawidth=200", pattern ..','.. reverse)
end

if not uok then return end

pattern, reverse = uinput:match("(.*),(.*)")
if reverse ~= 'y' and reverse ~= 'n' then return end

reaper.SetExtState("BATCH_SET_MARKER_NAMES_FOR_SELECTED_ITEMS", "Name", pattern, false)
reaper.SetExtState("BATCH_SET_MARKER_NAMES_FOR_SELECTED_ITEMS", "Reverse", reverse, false)

local sel_regions = get_sel_regions()

function build_name(build_pattern, i)
  if reverse == "y" then
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

  if reverse == "y" then
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
  region.name = build_name(pattern, i)
  create_region(region.left, region.right, region.name)
end

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()