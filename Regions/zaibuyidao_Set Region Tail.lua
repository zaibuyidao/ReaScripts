--[[
 * ReaScript Name: Set Region Tail
 * Version: 1.0.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0 or newer recommended
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2022-3-22)
  + Initial release
--]]

local bias = 0.002 -- 补偿偏差值

function Msg(param) 
  reaper.ShowConsoleMsg(tostring(param) .. "\n") 
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

function get_all_regions()
  local result = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
    if retval ~= nil and isrgn then
      table.insert(result, {
        index = markrgnindexnumber,
        isrgn = isrgn,
        left = pos,
        right = rgnend,
        name = name,
        color = color
      })
    end
  end
  return result
end

function get_sel_regions(offset)
  local all_regions = get_all_regions()
  if #all_regions == 0 then return {} end
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

  -- 标记选中区间
  for _, merged_item in ipairs(merged_items) do
    local l, r = 1, #all_regions
    -- 查找第一个左端点在item左侧的区间
    while l <= r do
      local mid = math.floor((l+r)/2)
      if (all_regions[mid].left - bias) > merged_item.left then
        r = mid - 1
      else 
        l = mid + 1
      end
    end
    merged_item.right = merged_item.right + offset
    if math.abs( (merged_item.right - merged_item.left) - (all_regions[r].right - all_regions[r].left) ) <= bias * 2 then
      sel_index[r] = true
    end

    -- if merged_item.right <= all_regions[r].right + bias then
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
  reaper.SetProjectMarker3(0, region.index, region.isrgn, region.left, region.right, region.name, region.color)
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local tail = reaper.GetExtState("SetRegionTail", "Tail")
if (tail == "") then tail = "1000" end
local offset = reaper.GetExtState("SetRegionTail", "Offset")
if (offset == "") then offset = "0" end

local retval, retvals_csv = reaper.GetUserInputs("Set Region Tail", 2, "Region tail 區域尾部 (ms),Offset 偏移 (ms),extrawidth=100", tail ..',' .. offset)
if not retval or not tonumber(tail) or not tonumber(offset) then return end
tail, offset = retvals_csv:match("(.*),(.*)")
reaper.SetExtState("SetRegionTail", "Tail", tail, false)

tail = tail / 1000
offset = offset / 1000

local sel_regions = get_sel_regions(offset)

for i,region in ipairs(sel_regions) do
  region.right = region.right+tail
  set_region(region)
end

offset = offset*1000+tail*1000
a,b = math.modf(offset)
reaper.SetExtState("SetRegionTail", "Offset", a, false)

reaper.Undo_EndBlock('Set Region Tail', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()