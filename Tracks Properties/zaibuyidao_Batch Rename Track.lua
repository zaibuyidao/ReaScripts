--[[
 * ReaScript Name: Batch Rename Track
 * Version: 1.1.5
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-7-17)
  + Initial release
--]]

local function Msg(str)
  reaper.ShowConsoleMsg(tostring(str).."\n")
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

local show_msg = reaper.GetExtState("SetTrackName", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
  script_name = "批量重命名軌道" text = "$trackname: 軌道名稱\n$foldername: 文件夾名稱\n$tracknum: 軌道編號\n$GUID: Track guid\nv=01: Track count 軌道計數\nv=01-05 or v=05-01: Loop track count 循環軌道計數\na=a: Letter count 字母順序\na=a-e or a=e-a: Loop letter count 循環字母計數\nr=10: Random string length 隨機字符串長度\n\nScript function description:\n脚本功能説明：\n\n1.Rename only\nRename 重命名\n\n2.String interception\nFrom beginning 截取開頭\nFrom end 截取結尾\n\n3.Specify position, insert or remove\nAt position 指定位置\nTo insert 插入\nRemove 移除\n\n4.Find and Replace\nFind what 查找\nReplace with 替換\n\nFind supports two pattern modifiers: * and ?\n查找支持两個模式修飾符：* 和 ?\n\n5.Loop count\nLimit or reverse cycle count. Enter 1 to enable, 0 to disable\n限制或反轉循環計數。輸入1為啓用，0為不啓用\n"
  text = text.."\nWill this list be displayed next time?\n下次還顯示此列表嗎？"
  local box_ok = reaper.ShowMessageBox("Wildcards 通配符 :\n\n"..text, script_name, 4)

  if box_ok == 7 then
      show_msg = "false"
      reaper.SetExtState("SetTrackName", "ShowMsg", show_msg, true)
  end
end

count_sel_tracks = reaper.CountSelectedTracks(0)
if count_sel_tracks == 0 then return end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local pattern, begin_str, end_str, position, insert, delete, find, replace, reverse = '', '0', '0', '0', '', '0', '', '', '1'

local retval, retvals_csv = reaper.GetUserInputs("Batch Rename Track", 9, "Rename 重命名,From beginning 截取開頭,From end 截取結尾,At position 指定位置,To insert 插入,Remove 移除,Find what 查找,Replace with 替換,Loop count 循環計數,extrawidth=200", pattern ..','.. begin_str .. ','.. end_str ..','.. position ..','.. insert ..','.. delete ..','.. find ..','.. replace ..','.. reverse)
if not retval then return end

pattern, begin_str, end_str, position, insert, delete, find, replace, reverse = retvals_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
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

reaper.Undo_EndBlock('Batch Rename Track', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()