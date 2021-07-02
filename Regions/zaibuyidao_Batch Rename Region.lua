--[[
 * ReaScript Name: Batch Rename Region
 * Version: 1.2
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.2 (2021-7-3)
  + 插入支持通配符
 * v1.0 (2021-6-5)
  + Initial release
--]]

function Msg(param) 
  reaper.ShowConsoleMsg(tostring(param) .. "\n") 
end

function DightNum(num)
  if math.floor(num) ~= num or num < 0 then
      return -1
  elseif 0 == num then
      return 1
  else
      local tmp_dight = 0
      while num > 0 do
          num = math.floor(num/10)
          tmp_dight = tmp_dight + 1
      end
      return tmp_dight 
  end
end

function AddZeroFrontNum(dest_dight, num)
  local num_dight = DightNum(num)
  if -1 == num_dight then 
      return -1 
  elseif num_dight >= dest_dight then
      return tostring(num)
  else
      local str_e = ""
      for var =1, dest_dight - num_dight do
          str_e = str_e .. "0"
      end
      return str_e .. tostring(num)
  end
end

function max(a,b)
  if a>b then
    return a
  end
  return b
end

function create_region(reg_start, reg_end, name)
  if name == nil then return end
  local index = reaper.AddProjectMarker2(0, true, reg_start, reg_end, name, -1, 0)
end

function rename_region(name)
  if name == nil then return end
  reaper.SetProjectMarker3(0, markrgnindexnumber, isrgn, pos, rgnend, name, color)
end

local show_msg = reaper.GetExtState("BatchRenameRegion", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
    script_name = "批量重命名區域"
    text = "$regionname -- 區域名稱\n$inctimeorder -- 區域順序\n"
    text = text.."\n下次還顯示此列表嗎？"
    local box_ok = reaper.ShowMessageBox("可用鍵 :\n\n"..text, script_name, 4)

    if box_ok == 7 then
        show_msg = "false"
        reaper.SetExtState("BatchRenameRegion", "ShowMsg", show_msg, true)
    end
end

item_count = reaper.CountSelectedMediaItems(0)
if item_count == 0 then return end

local items = {}

for i = 1, reaper.CountSelectedMediaItems(0) do
  local item = reaper.GetSelectedMediaItem(0, i-1)
  if item ~= nil then
    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = item_pos + item_len
    table.insert( items,{ left=item_pos,right=item_end } )
  end
end

if #items <= 0 then return end

table.sort(items,function(a,b)
  return a.left < b.left
end)

local regions = {}
local left_t = {}

local cur = {
  left = items[1].left,
  right = items[1].right
}

for i,item in ipairs(items) do
  if cur.right - item.left > 0 then -- 確定區域是否為相交
    cur.right = max(item.right,cur.right)
  else
    table.insert(regions, cur)
    cur = {
      left = item.left,
      right = item.right
    }
  end
end

table.insert(regions, cur)

function get_precise_decimal(num, n)
  if type(num) ~= "number" then
    return num
  end
  n = n or 0
  n = math.floor(n)
  if	n < 0 then n = 0 end
  local decimal = 10 ^ n
  local temp = math.floor(num * decimal)
  return temp / decimal
end

function key_of(left, right)
  return tostring(get_precise_decimal(left,10)) .. " " .. tostring(get_precise_decimal(right,10))
end

function collect_regions()
  local result = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions-1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
    
    if retval ~= nil then
      if isrgn then
        result[key_of(pos, rgnend)] = {
          index = markrgnindexnumber,
          isrgn = isrgn,
          left = pos,
          right = rgnend,
          name = name,
          color = color
        }
      end
    end
  end
  return result
end

function set_region(region)
  reaper.SetProjectMarker3(0, region.index, region.isrgn, region.left, region.right, region.name, region.color)
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local all_regions = collect_regions()
local pattern, cnt, tail, begin_str, end_str, position, insert, delete, find, replace = '', '1', '0', '0', '0', '0', '', '0', '', ''

-- for key,region in pairs(all_regions) do
--   Msg("all:" .. key)
-- end

local ok, retvals_csv = reaper.GetUserInputs("Batch Reanme Region", 10, "Rename 重命名,Order 順序,Tail 尾部 (ms),From beginning 截取開頭,From end 截取結尾 (負數),At position 位置,To insert 插入,Remove 移除,Find what 查找,Replace with 替換,extrawidth=200", pattern ..','.. cnt ..','.. tail ..','.. begin_str .. ','.. end_str ..','.. position ..','.. insert ..','.. delete ..','.. find ..','.. replace)
if not ok then return end

pattern, cnt, tail, begin_str, end_str, position, insert, delete, find, replace = retvals_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")

cnt = cnt -1
begin_str = begin_str + 1
end_str = end_str - 1
tail = tail / 1000

name_t = {}
for i,region in ipairs(regions) do
  local matched = all_regions[key_of(region.left, region.right+tail)]
  if matched then
    name_t[#name_t+1] = matched.name
  end
end

for i,region in ipairs(regions) do

  -- Msg("finding:" .. key_of(region.left, region.right))
  local matched = all_regions[key_of(region.left, region.right+tail)]
  if matched then

    if pattern ~= "" then matched.name = pattern end

    matched.name = matched.name:gsub("$regionname", name_t[i])
    matched.name = matched.name:gsub("$inctimeorder", function ()
      cnt = AddZeroFrontNum(2, math.floor(cnt+1))
      return tostring(cnt)
    end)

    matched.name = string.sub(matched.name, begin_str, end_str)
    matched.name = string.sub(matched.name, 1, position) .. insert .. string.sub(matched.name, position+1+delete)
    matched.name = string.gsub(matched.name, find, replace)

    if insert ~= '' then
      matched.name = matched.name:gsub("$regionname", name_t[i])
      matched.name = matched.name:gsub("$inctimeorder", function ()
        cnt = AddZeroFrontNum(2, math.floor(cnt+1))
        return tostring(cnt)
      end)
    end

    set_region(matched)
  end

end

reaper.Undo_EndBlock('Batch Rename Region', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()