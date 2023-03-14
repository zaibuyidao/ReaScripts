-- @description Batch Rename Take
-- @version 1.4.8
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function print(...)
  local args = {...}
  local str = ""
  for i = 1, #args do
    str = str .. tostring(args[i]) .. "\t"
  end
  reaper.ShowConsoleMsg(str .. "\n")
end

if not reaper.SNM_GetIntConfigVar then
  local retval = reaper.ShowMessageBox("This script requires the SWS Extension.\n該脚本需要 SWS 擴展。\n\nDo you want to download it now? \n你想現在就下載它嗎？", "Warning 警告", 1)
  if retval == 1 then
    if not OS then local OS = reaper.GetOS() end
    if OS=="OSX32" or OS=="OSX64" then
      os.execute("open " .. "http://www.sws-extension.org/download/pre-release/")
    else
      os.execute("start " .. "http://www.sws-extension.org/download/pre-release/")
    end
  end
  return
end

if not reaper.APIExists("JS_Localize") then
  reaper.MB("Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\n請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n\nThen restart REAPER and run the script again, thank you!\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n", "You must install JS_ReaScriptAPI 你必須安裝JS_ReaScriptAPI", 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, "錯誤", 0)
  end
  return reaper.defer(function() end)
end

function getSystemLanguage()
  local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))
  local os = reaper.GetOS()
  local lang

  if os == "Win32" or os == "Win64" then -- Windows
    if locale == 936 then -- Simplified Chinese
      lang = "简体中文"
    elseif locale == 950 then -- Traditional Chinese
      lang = "繁體中文"
    else -- English
      lang = "English"
    end
  elseif os == "OSX32" or os == "OSX64" then -- macOS
    local handle = io.popen("/usr/bin/defaults read -g AppleLocale")
    local result = handle:read("*a")
    handle:close()
    lang = result:gsub("_", "-"):match("[a-z]+%-[A-Z]+")
    if lang == "zh-CN" then -- 简体中文
      lang = "简体中文"
    elseif lang == "zh-TW" then -- 繁体中文
      lang = "繁體中文"
    else -- English
      lang = "English"
    end
  elseif os == "Linux" then -- Linux
    local handle = io.popen("echo $LANG")
    local result = handle:read("*a")
    handle:close()
    lang = result:gsub("%\n", ""):match("[a-z]+%-[A-Z]+")
    if lang == "zh_CN" then -- 简体中文
      lang = "简体中文"
    elseif lang == "zh_TW" then -- 繁體中文
      lang = "繁體中文"
    else -- English
      lang = "English"
    end
  end

  return lang
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

local language = getSystemLanguage()

local show_msg = reaper.GetExtState("BATCH_RENAME_TAKE", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then


  if language == "简体中文" then
    script_name = "批量重命名片段" text = "$takename: 片段名称\n$trackname: 轨道名称\n$foldername: 文件夹名称\n$tracknum: 轨道编号\n$GUID: Take guid\nv=01: 片段计数\nv=01-05 or v=05-01: 循环片段计数\na=a: 字母计数\na=a-e or a=e-a: 循环字母范围\nr=10: 随机字符串长度\n\n脚本功能説明：\n\n1.仅重命名\n重命名\n\n2.截取字符串\n截取开头\n截取结尾\n\n3.指定位置插入或删除\n指定位置\n插入\n移除\n\n4.查找和替换\n查找\n替換\n\n查找支持两种模式修饰符：* 和 ?\n\n5.循环计数\n限制或反转循环计数。输入1为启用，0为不启用\n\n6.片段排序\n确定片段顺序。输入0为轨道，1为换行，2为时间线\n"
    text = text.."\n下次还显示此页面吗？"
    heading = "通配符 :\n\n"
  elseif language == "繁体中文" then
    script_name = "批量重命名片段" text = "$takename: 片段名稱\n$trackname: 軌道名稱\n$foldername: 文件夾名稱\n$tracknum: 軌道編號\n$GUID: Take guid\nv=01: 片段計數\nv=01-05 or v=05-01: 循環片段計數\na=a: 字母計數\na=a-e or a=e-a: 循環字母範圍\nr=10: 隨機字符串長度\n\n脚本功能説明：\n\n1.僅重命名\n重命名\n\n2.截取字符串\n截取開頭\n截取結尾\n\n3.指定位置插入或刪除\n指定位置\n插入\n移除\n\n4.查找和替換\n查找\n替換\n\n查找支持两個模式修飾符：* 和 ?\n\n5.循環計數\n限制或反轉循環計數。輸入1為啓用，0為不啓用\n\n6.片段排序\n確定片段順序。輸入0為軌道，1為換行，2為時間綫\n"
    text = text.."\n下次還顯示此頁面嗎？"
    heading = "通配符 :\n\n"
  else
    script_name = "Batch Rename Take" text = "$takename: Take name\n$trackname: Track name\n$foldername: Folder name\n$tracknum: Track number\n$GUID: Take guid\nv=01: Take count\nv=01-05 or v=05-01: Loop take count\na=a: Letter count\na=a-e or a=e-a: Loop letter count\nr=10: Random string length\n\nScript function description:\n\n1.Rename only\nRename\n\n2.String interception\nFrom beginning\nFrom end\n\n3.Specify position, insert or remove\nAt position\nTo insert\nRemove\n\n4.Find and Replace\nFind what\nReplace with\n\nFind supports two pattern modifiers: * and ?\n\n5.Loop count\nLimit or reverse cycle count. Enter 1 to enable, 0 to disable\n\n6.Take order\nDetermine Takes order. Enter 0 to Track, 1 to Wrap, 2 to Timeline\n"
    text = text.."\nWill this list be displayed next time?"
    heading = "Wildcards :\n\n"
  end

  local box_ok = reaper.ShowMessageBox(heading .. text, script_name, 4)

  if box_ok == 7 then
      show_msg = "false"
      reaper.SetExtState("BATCH_RENAME_TAKE", "ShowMsg", show_msg, true)
  end
end

local count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items < 0 then return end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local pattern, begin_str, end_str, position, insert, delete, find, replace, reverse, order = '', '0', '0', '0', '', '0', '', '', '1', '0'
language = "简体中文" 
if language == "简体中文" then
  title = "批量重命名片段"
  uok, uinput = reaper.GetUserInputs(title, 10, "1.重命名,2.截取开头,   截取结尾,3.指定位置,   插入,   移除,4.查找,   替换,5.循环计数,6.片段排序,extrawidth=200", pattern ..','.. begin_str .. ','.. end_str ..','.. position ..','.. insert ..','.. delete ..','.. find ..','.. replace ..','.. reverse ..','.. order)
elseif language == "繁体中文" then
  title = "批量重命名片段"
  uok, uinput = reaper.GetUserInputs(title, 10, "1.重命名,2.截取開頭,   截取結尾,3.指定位置,   插入,   移除,4.查找,   替換,5.循環計數,6.片段排序,extrawidth=200", pattern ..','.. begin_str .. ','.. end_str ..','.. position ..','.. insert ..','.. delete ..','.. find ..','.. replace ..','.. reverse ..','.. order)
else
  title = "Batch Rename Take"
  uok, uinput = reaper.GetUserInputs("Batch Rename Take", 10, "1.Rename,2.From beginning,   From end,3.At position,   To insert,   Remove,4.Find what,   Replace with,5.Loop count,6.Take order,extrawidth=200", pattern ..','.. begin_str .. ','.. end_str ..','.. position ..','.. insert ..','.. delete ..','.. find ..','.. replace ..','.. reverse ..','.. order)
end

if not uok then return end

pattern, begin_str, end_str, position, insert, delete, find, replace, reverse, order = uinput:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
begin_str = tostring(begin_str)
find = find:gsub('-', '%%-')
find = find:gsub('+', '%%+')
find = find:gsub('*', '.*')
find = find:gsub('?', '.?')

function build_name(build_pattern, origin_name, i)
  build_pattern = build_pattern:gsub("%$takename", origin_name)
  build_pattern = build_pattern:gsub('%$trackname', track_name)
  build_pattern = build_pattern:gsub('%$tracknum', track_num)
  build_pattern = build_pattern:gsub('%$GUID', take_guid)
  build_pattern = build_pattern:gsub('%$foldername', parent_buf)

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

function set_take_name(take, take_name, i)
  if pattern ~= "" then -- 重命名
    take_name = build_name(pattern, origin_name, i + 1)
  end
  
  take_name = utf8_sub1(take_name, begin_str, end_str)
  take_name = utf8_sub2(take_name, 0, position) .. insert .. utf8_sub3(take_name, position + delete)
  if find ~= "" then take_name = string.gsub(take_name, find, replace) end

  if insert ~= '' then -- 指定位置插入内容
    take_name = build_name(take_name, origin_name, i + 1)
  end

  reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', take_name, true)
end

if order == "0" then
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
      if parent_track ~= nil then
        _, parent_buf = reaper.GetTrackName(parent_track)
      else
        parent_buf = ''
      end

      take_name = reaper.GetTakeName(take)
      take_guid = reaper.BR_GetMediaItemTakeGUID(take)
      origin_name = reaper.GetTakeName(take)

      set_take_name(take, take_name, i - 1)
    end
  end
elseif order == "1" then
  for z = 0, count_sel_items - 1 do -- 按換行順序排序
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
    take_name = reaper.GetTakeName(take)
    take_guid = reaper.BR_GetMediaItemTakeGUID(take)
    origin_name = reaper.GetTakeName(take)

    set_take_name(take, take_name, z)
  end
elseif order == "2" then -- 按時間綫順序排序
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
      take_name = reaper.GetTakeName(take)
      take_guid = reaper.BR_GetMediaItemTakeGUID(take)
      origin_name = reaper.GetTakeName(take)

      set_take_name(take, take_name, j - 1)
    end
  end
end

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()