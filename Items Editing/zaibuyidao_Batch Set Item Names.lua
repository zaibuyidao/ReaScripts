-- @description Batch Set Item Names
-- @version 1.0.1
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

local show_msg = reaper.GetExtState("BATCH_SET_ITEM_NAMES", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
  if language == "简体中文" then
    script_name = "批量设置对象名称"
    text = "通配符:\n$track: 轨道名称\n$folders: 文件夹名称\n$trknumber: 轨道编号\n$GUID: 对象 GUID\n\n标记:\nd=01: 数字计数\nd=01-05 or d=05-01: 循环数字\na=a: 字母计数\na=a-e or a=e-a: 循环字母\nr=10: 随机字符串长度\n\n"
    text = text.."功能说明：\n\n1.仅设置名称:\n   - 对象名称\n\n2.循环模式:\n   - 启用或禁用循环数字/字母。输入 'y' 表示是，'n' 表示否。\n\n3.对象排序:\n   - 选择对象的排序选项: 'track', 'sequential', 或 'timeline'\n"
    text = text.."\n下次还显示此页面吗？"
  elseif language == "繁體中文" then
    script_name = "批量設置對象名稱"
    text = "通配符:\n$track: 軌道名稱\n$folders: 文件夾名稱\n$trknumber: 軌道編號\n$GUID: 對象 GUID\n\n標記:\nd=01: 數字計數\nd=01-05 or d=05-01: 循環數字\na=a: 字母計數\na=a-e or a=e-a: 循環字母\nr=10: 隨機字符串長度\n\n"
    text = text.."功能説明：\n\n1.僅設置名稱:\n   - 對象名稱\n\n2.循環模式:\n   - 啟用或禁用循環數字/字母。輸入 'y' 表示是，'n' 表示否。\n\n3.對象排序:\n   - 選擇對象的排序選項: 'track', 'sequential', 或 'timeline'\n"
    text = text.."\n下次還顯示此頁面嗎？"
  else
    script_name = "Batch Set Item Names"
    text = "Wildcards:\n$item: Item name\n$folders: Folder name\n$trknumber: Track number\n$GUID: Item GUID\n\nTags:\nd=01: Number count\nd=01-05 or d=05-01: Cycle number\na=a: Letter count\na=a-e or a=e-a: Cycle letter\nr=10: Random string length\n\n"
    text = text.."Function description:\n\n1.Set name only:\n   - Item name\n\n2.Cycle Mode:\n   - Enable or disable cycle number/letter. Enter 'y' for yes or 'n' for no.\n\n3.Items Sorting:\n   - Choose sorting options for items: 'track', 'sequential', or 'timeline'.\n"
    text = text.."\nWill this list be displayed next time?"
  end

  local box_ok = reaper.ShowMessageBox(text, script_name, 4)

  if box_ok == 7 then
    show_msg = "false"
    reaper.SetExtState("BATCH_RENAME_ITEMS", "ShowMsg", show_msg, true)
  end
end

local count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items < 0 then return end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local pattern = reaper.GetExtState("BATCH_SET_ITEM_NAMES", "Name")
if (pattern == "") then pattern = "Item_d=0001_a=E-A_r=4" end
local reverse = reaper.GetExtState("BATCH_SET_ITEM_NAMES", "Reverse")
if (reverse == "") then reverse = "y" end
local order = reaper.GetExtState("BATCH_SET_ITEM_NAMES", "Order")
if (order == "") then order = "track" end

if language == "简体中文" then
  title = "批量设置对象名称"
  uok, uinput = reaper.GetUserInputs(title, 3, "对象名称,使用循环 (y/n),排序 (track/seq/timeline),rderextrawidth=200", pattern ..','.. reverse ..','.. order)
elseif language == "繁體中文" then
  title = "批量設置對象名稱"
  uok, uinput = reaper.GetUserInputs(title, 3, "對象名稱,使用循環 (y/n),排序 (track/seq/timeline),rderextrawidth=200", pattern ..','.. reverse ..','.. order)
else
  title = "Batch Set Item Names"
  uok, uinput = reaper.GetUserInputs(title, 3, "Item name,Use cycle mode (y/n),Sorting (track/seq/timeline),rderextrawidth=200", pattern ..','.. reverse ..','.. order)
end

if not uok then return end

pattern, reverse, order = uinput:match("(.*),(.*),(.*)")
if reverse ~= 'y' and reverse ~= 'n' then return end

reaper.SetExtState("BATCH_SET_ITEM_NAMES", "Name", pattern, false)
reaper.SetExtState("BATCH_SET_ITEM_NAMES", "Reverse", reverse, false)
reaper.SetExtState("BATCH_SET_ITEM_NAMES", "Order", order, false)

function build_name(build_pattern, i)
  build_pattern = build_pattern:gsub('%$track', track_name)
  build_pattern = build_pattern:gsub('%$trknumber', track_num)
  build_pattern = build_pattern:gsub('%$GUID', take_guid)
  build_pattern = build_pattern:gsub('%$folders', parent_buf)

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

function set_take_name(take, pattern, i)
  pattern = build_name(pattern, i + 1)
  reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', pattern, true)
end

if order == "track" then
  local track_items = {}

  for i = 0, count_sel_items - 1  do
    local item = reaper.GetSelectedMediaItem(0, i)
    local track = reaper.GetMediaItem_Track(item)
    if not track_items[track] then track_items[track] = {} end
    table.insert(track_items[track], item)
  end
  
  for _, items in pairs(track_items) do
    for i, item in ipairs(items) do
      take = reaper.GetActiveTake(item)
      track = reaper.GetMediaItem_Track(item)
      track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
      track_num = string.format("%0" .. 2 .. "d", track_num)
      _, track_name = reaper.GetTrackName(track)
      parent_track = reaper.GetParentTrack(track)
      parent_track = reaper.GetParentTrack(track)
      if parent_track ~= nil then
        _, parent_buf = reaper.GetTrackName(parent_track)
      else
        parent_buf = ''
      end

      take_guid = reaper.BR_GetMediaItemTakeGUID(take)
      set_take_name(take, pattern, i - 1)
    end
  end
elseif order == "seq" then
  for z = 0, count_sel_items - 1 do -- 按順序排序
    item = reaper.GetSelectedMediaItem(0, z)
    track = reaper.GetMediaItem_Track(item)
    track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
    track_num = string.format("%0" .. 2 .. "d", track_num)
    _, track_name = reaper.GetTrackName(track)
    parent_track = reaper.GetParentTrack(track)
    if parent_track ~= nil then
      _, parent_buf = reaper.GetTrackName(parent_track)
    else
      parent_buf = ''
    end

    take = reaper.GetActiveTake(item)
    take_guid = reaper.BR_GetMediaItemTakeGUID(take)

    set_take_name(take, pattern, z)
  end
elseif order == "timeline" then -- 按時間綫排序
  local startEvents = {}
  for i = 0, count_sel_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local track = reaper.GetMediaItem_Track(item)
    local pitch = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
    local startPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local take = reaper.GetActiveTake(item)
    local takeName = reaper.GetTakeName(take)
    if startEvents[startPos] == nil then startEvents[startPos] = {} end
    local event = {
      ["startPos"]=startPos,
      ["pitch"]=pitch,
      ["takeName"]=takeName,
      ["item"]=item
    }
    
    table.insert(startEvents[startPos], event)
  end

  local tempEvents = {}
  for i in pairs(startEvents) do
    table.insert(tempEvents,i)  
  end
  table.sort(tempEvents,function(a,b)return (tonumber(a) < tonumber(b)) end) -- 對key進行升序

  local result = {}
  for i,v in pairs(tempEvents) do
    table.insert(result,startEvents[v])
  end

  j = 0
  for _, list in pairs(result) do
    for i = 1, #list do
      j = j + 1
      track = reaper.GetMediaItem_Track(list[i].item)
      track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
      track_num = string.format("%0" .. 2 .. "d", track_num)
      _, track_name = reaper.GetTrackName(track)
      parent_track = reaper.GetParentTrack(track)
      if parent_track ~= nil then
        _, parent_buf = reaper.GetTrackName(parent_track)
      else
        parent_buf = ''
      end

      take = reaper.GetActiveTake(list[i].item)
      take_guid = reaper.BR_GetMediaItemTakeGUID(take)

      set_take_name(take, pattern, j - 1)
    end
  end
end

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()