--[[
 * ReaScript Name: Set Region Name
 * Version: 1.3.2
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.3 (2021-6-6)
  + 修改通配符規則以及將編號定義為$inctimeorder
 * v1.0 (2021-6-1)
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
  if cur.right - item.left > 0 then -- 判定區域是否為相交
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

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local name = reaper.GetExtState("SetRegionName", "Name")
if (name == "") then name = "Region_$inctimeorder" end
local order = reaper.GetExtState("SetRegionName", "Order")
if (order == "") then order = "1" end
local tail = reaper.GetExtState("SetRegionName", "Tail")
if (tail == "") then tail = "0" end

ok, retvals_csv = reaper.GetUserInputs("Set Region Name", 3, "Region name 區域名,Order 順序,Tail 尾部 (ms),extrawidth=200", name .. ',' .. order .. ',' .. tail)
if not ok or not tonumber(order) or not tonumber(tail) then return end
name, order, tail = retvals_csv:match("(.*),(.*),(.*)")
reaper.SetExtState("SetRegionName", "Order", order, false)
reaper.SetExtState("SetRegionName", "Name", name, false)
reaper.SetExtState("SetRegionName", "Tail", tail, false)
order = math.floor(order)-1
tail = tail / 1000

for i, region in ipairs(regions) do
  create_region(region.left, region.right+tail, name:gsub('%$inctimeorder', AddZeroFrontNum(2, i+order)))
end

reaper.Undo_EndBlock("Set Region Name", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
