--[[
 * ReaScript Name: Batch Rename Take
 * Version: 1.4.4
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0 or newer recommended
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.4.2 (2022-3-18)
  + 優化匹配功能，優化查找/替換功能。
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

local show_msg = reaper.GetExtState("BatchRenameTake", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
  script_name = "批量重命名片段" text = "$takename: 片段名稱\n$trackname: 軌道名稱\n$foldername: 文件夾名稱\n$tracknum: 軌道編號\n$GUID: Take guid\nv=01: Take count 片段計數\nv=01-05 or v=05-01: Loop take count 循環片段計數\na=a: Letter count 字母計數\na=a-e or a=e-a: Loop letter count 循環字母範圍\n\nScript function description:\n脚本功能説明：\n\n1.Rename only\nRename 重命名\n\n2.String interception\nFrom beginning 截取開頭\nFrom end 截取結尾\n\n3.Specify position, insert or remove\nAt position 指定位置\nTo insert 插入\nRemove 移除\n\n4.Find and Replace\nFind what 查找\nReplace with 替換\n\nFind supports two pattern modifiers: * and ?\n查找支持两個模式修飾符：* 和 ?\n\n5.Loop count\nLimit or reverse cycle count. Enter 1 to enable, 0 to disable\n限制或反轉循環計數。輸入1為啓用，0為不啓用\n\n6.Take order\nDetermine Takes order. Enter 0 to Track, 1 to Wrap, 2 to Timeline\n確定片段順序。輸入0為軌道，1為換行，2為時間綫\n"
  text = text.."\nWill this list be displayed next time?\n下次還顯示此列表嗎？"
  local box_ok = reaper.ShowMessageBox("Wildcards 通配符 :\n\n"..text, script_name, 4)

  if box_ok == 7 then
      show_msg = "false"
      reaper.SetExtState("BatchRenameTake", "ShowMsg", show_msg, true)
  end
end

local count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items < 0 then return end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local pattern, begin_str, end_str, position, insert, delete, find, replace, reverse, order = '', '0', '0', '0', '', '0', '', '', '1', '0'

local retval, retvals_csv = reaper.GetUserInputs("Batch Rename Take", 10, "Rename 重命名,From beginning 截取開頭,From end 截取結尾,At position 指定位置,To insert 插入,Remove 移除,Find what 查找,Replace with 替換,Loop count 循環計數,Take order 片段排序,extrawidth=200", pattern ..','.. begin_str .. ','.. end_str ..','.. position ..','.. insert ..','.. delete ..','.. find ..','.. replace ..','.. reverse ..','.. order)
if not retval then return end

pattern, begin_str, end_str, position, insert, delete, find, replace, reverse, order = retvals_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
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

for i = 0, count_sel_items - 1  do
  local item = reaper.GetSelectedMediaItem(0, i)
  local track = reaper.GetMediaItem_Track(item)
  local count_track_items = reaper.CountTrackMediaItems(track)

  track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
  track_num = string.format("%0" .. 2 .. "d", track_num)

  if order == "0" then
    sel_item_track = {}
    item_num_new = {}
    item_num_order = 1 
    
    for j = 0, count_track_items - 1  do -- 對選中的take重新排序
      local item = reaper.GetTrackMediaItem(track, j)
      if reaper.IsMediaItemSelected(item) == true then
        sel_item_track[item_num_order] = item
        item_num_new[item_num_order] = reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
        item_num_order = item_num_order + 1
      end
    end

    for k = 1, item_num_order - 1 do -- 按軌道順序排序
      item = sel_item_track[k]
      track = reaper.GetMediaItem_Track(item)
      track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
      track_num = string.format("%0" .. 2 .. "d", track_num)
      _, track_name = reaper.GetTrackName(track)
      if parent_track ~= nil then
        _, parent_buf = reaper.GetTrackName(parent_track)
      else
        parent_buf = ''
      end

      take = reaper.GetActiveTake(item)
      take_name = reaper.GetTakeName(take)
      take_guid = reaper.BR_GetMediaItemTakeGUID(take)
  
      origin_name = reaper.GetTakeName(take)
  
      set_take_name(take, take_name, k - 1)
    end
  elseif order == "1" then
    for z = 0, count_sel_items - 1 do -- 按換行順序排序
      item = reaper.GetSelectedMediaItem(0, z)
      track = reaper.GetMediaItem_Track(item)
      track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
      track_num = string.format("%0" .. 2 .. "d", track_num)
      _, track_name = reaper.GetTrackName(track)
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
end

reaper.Undo_EndBlock('Batch Rename Take', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()