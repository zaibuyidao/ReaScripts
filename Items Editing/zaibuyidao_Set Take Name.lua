--[[
 * ReaScript Name: Set Take Name
 * Version: 1.2.6
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-5-23)
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

local show_msg = reaper.GetExtState("SetTakeName", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
  script_name = "設置片段名稱" text = "$trackname: 軌道名稱\n$foldername: 文件夾名稱\n$tracknum: 軌道編號\n$GUID: Take guid\nv=01: Take count 片段計數\nv=01-05 or v=05-01: Loop take count 循環片段計數\na=a: Letter count 字母計數\na=a-e or a=e-a: Loop letter count 循環字母範圍\nr=10: Random string length 隨機字符串長度\n\n1.Set name only\nTrack name 軌道名稱\n\n2.Loop count\nLimit or reverse cycle count. Enter 1 to enable, 0 to disable\n限制或反轉循環計數。輸入1為啓用，0為不啓用\n\n3.Take order\nDetermine Takes order. Enter 0 to Track, 1 to Wrap, 2 to Timeline\n確定片段順序。輸入0為軌道，1為換行，2為時間綫\n\n"
  text = text.."\nWill this list be displayed next time?\n下次還顯示此列表嗎？"
  local box_ok = reaper.ShowMessageBox("Wildcards 通配符 :\n\n"..text, script_name, 4)

  if box_ok == 7 then
    show_msg = "false"
    reaper.SetExtState("SetTakeName", "ShowMsg", show_msg, true)
  end
end

local count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items < 0 then return end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local pattern = reaper.GetExtState("SetTakeName", "Name")
if (pattern == "") then pattern = "Take_v=001" end
local reverse = reaper.GetExtState("SetTakeName", "Reverse")
if (reverse == "") then reverse = "1" end
local order = reaper.GetExtState("SetTakeName", "Order")
if (order == "") then order = "0" end

local retval, retvals_csv = reaper.GetUserInputs("Set Take Name", 3, "Take name 片段名稱,Loop count 循環計數,Take order 片段排序,rderextrawidth=200", pattern ..','.. reverse ..','.. order)
if not retval then return end
pattern, reverse, order = retvals_csv:match("(.*),(.*),(.*)")

reaper.SetExtState("SetTakeName", "Name", pattern, false)
reaper.SetExtState("SetTakeName", "Reverse", reverse, false)
reaper.SetExtState("SetTakeName", "Order", order, false)

function build_name(build_pattern, i)
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

function set_take_name(take, pattern, i)
  pattern = build_name(pattern, i + 1)
  reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', pattern, true)
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
    take_guid = reaper.BR_GetMediaItemTakeGUID(take)

    set_take_name(take, pattern, z)
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
      take_guid = reaper.BR_GetMediaItemTakeGUID(take)

      set_take_name(take, pattern, j - 1)
    end
  end
end

reaper.Undo_EndBlock('Set Take Name', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()