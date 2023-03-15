-- @description Batch Rename Track
-- @version 1.1.6
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

local show_msg = reaper.GetExtState("BATCH_RENAME_TRACK", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
  if language == "简体中文" then
    script_name = "批量重命名轨道"
    text = "$trackname: 轨道名称\n$foldername: 文件夹名称\n$tracknum: 轨道编号\n$GUID: Track guid\nv=01: 轨道计数\nv=01-05 or v=05-01: 循环轨道计数\na=a: Letter count 字母计数\na=a-e or a=e-a: 循环字母顺序\nr=10: 随机字符串长度\n\n脚本功能说明：\n\n1.仅重命名\n重命名\n\n2.截取字符串\n截取开头\n截取结尾\n\n3.指定位置插入或删除\n指定位置\n插入\n移除\n\n4.查找和替换\n查找\n替换\n\n查找支持两个模式修饰符：* 和 ?\n\n5.循环计数\n限制或反转循环计数。输入1为启用，0为不启用\n"
    text = text.."\n下次还显示此页面吗？"
    heading = "通配符 :\n\n"
  elseif language == "繁体中文" then
    script_name = "批量重命名軌道"
    text = "$trackname: 軌道名稱\n$foldername: 文件夾名稱\n$tracknum: 軌道編號\n$GUID: Track guid\nv=01: 軌道計數\nv=01-05 or v=05-01: 循環軌道計數\na=a: Letter count 字母計數\na=a-e or a=e-a: 循環字母計數\nr=10: 隨機字符串長度\n\n脚本功能説明：\n\n1.僅重命名\n重命名\n\n2.截取字符串\n截取開頭\n截取結尾\n\n3.指定位置插入或刪除\n指定位置\n插入\n移除\n\n4.查找和替換\n查找\n替換\n\n查找支持两個模式修飾符：* 和 ?\n\n5.循環計數\n限制或反轉循環計數。輸入1為啓用，0為不啓用\n"
    text = text.."\n下次還顯示此頁面嗎？"
    heading = "通配符 :\n\n"
  else
    script_name = "Batch Rename Track"
    text = "$trackname: Track name\n$foldername: Foldername\n$tracknum: Track number\n$GUID: Track guid\nv=01: Track count\nv=01-05 or v=05-01: Loop track count\na=a: Letter count\na=a-e or a=e-a: Loop letter count\nr=10: Random string length\n\nScript function description:\n\n1.Rename only\nRename\n\n2.String interception\nFrom beginning\nFrom end\n\n3.Specify position, insert or remove\nAt position\nTo insert\nRemove\n\n4.Find and Replace\nFind what\nReplace with\n\nFind supports two pattern modifiers: * and ?\n\n5.Loop count\nLimit or reverse cycle count. Enter 1 to enable, 0 to disable\n"
    text = text.."\nWill this list be displayed next time?"
    heading = "Wildcards :\n\n"
  end

  local box_ok = reaper.ShowMessageBox(heading .. text, script_name, 4)

  if box_ok == 7 then
    show_msg = "false"
    reaper.SetExtState("BATCH_RENAME_TRACK", "ShowMsg", show_msg, true)
  end
end

count_sel_tracks = reaper.CountSelectedTracks(0)
if count_sel_tracks == 0 then return end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local pattern, begin_str, end_str, position, insert, delete, find, replace, reverse = '', '0', '0', '0', '', '0', '', '', '1'

if language == "简体中文" then
  title = "批量重命名轨道"
  uok, uinput = reaper.GetUserInputs(title, 9, "1.重命名,2.截取开头,   截取结尾,3.指定位置,   插入,   移除,4.查找,   替换,5.循环计数,extrawidth=200", pattern ..','.. begin_str .. ','.. end_str ..','.. position ..','.. insert ..','.. delete ..','.. find ..','.. replace ..','.. reverse)
elseif language == "繁体中文" then
  title = "批量重命名軌道"
  uok, uinput = reaper.GetUserInputs(title, 9, "1.重命名,2.截取開頭,   截取結尾,3.指定位置,   插入,   移除,4.查找,   替換,5.循環計數,extrawidth=200", pattern ..','.. begin_str .. ','.. end_str ..','.. position ..','.. insert ..','.. delete ..','.. find ..','.. replace ..','.. reverse)
else
  title = "Batch Rename Track"
  uok, uinput = reaper.GetUserInputs(title, 9, "1.Rename,2.From beginning,   From end,3.At position,   To insert,   Remove,4.Find what,   Replace with,5.Loop count,extrawidth=200", pattern ..','.. begin_str .. ','.. end_str ..','.. position ..','.. insert ..','.. delete ..','.. find ..','.. replace ..','.. reverse)
end

if not uok then return end

pattern, begin_str, end_str, position, insert, delete, find, replace, reverse = uinput:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
find = find:gsub('-', '%%-')
find = find:gsub('+', '%%+')
find = find:gsub('*', '.*')
find = find:gsub('?', '.?')

function build_name(build_pattern, origin_name, i)
  build_pattern = build_pattern:gsub("%$trackname", origin_name)
  build_pattern = build_pattern:gsub('%$tracknum', track_num)
  build_pattern = build_pattern:gsub('%$GUID', track_guid)
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

for i = 0, count_sel_tracks - 1 do -- 遍歷選中軌道
  local track = reaper.GetSelectedTrack(0, i)
  local retval, track_name = reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', "", false)

  parent_track = reaper.GetParentTrack(track)
  track_guid = reaper.BR_GetMediaTrackGUID(track)
  track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
  track_num = string.format("%0" .. 2 .. "d", track_num)

  if parent_track ~= nil then
    _, parent_buf = reaper.GetTrackName(parent_track)
  else
    parent_buf = ''
  end

  local origin_name = track_name

  if pattern ~= "" then -- 重命名
    track_name = build_name(pattern, origin_name, i + 1)
  end

  track_name = utf8_sub1(track_name, begin_str, end_str)
  track_name = utf8_sub2(track_name, 0, position) .. insert .. utf8_sub3(track_name, position + delete)
  if find ~= "" then track_name = string.gsub(track_name, find, replace) end
  
  if insert ~= '' then -- 指定位置插入内容
    track_name = build_name(track_name, origin_name, i + 1)
  end

  reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', track_name, true)
end

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()