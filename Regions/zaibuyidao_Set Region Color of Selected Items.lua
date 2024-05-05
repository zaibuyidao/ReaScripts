-- @description Set Region Color of Selected Items
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function Msg(param) 
  reaper.ShowConsoleMsg(tostring(param) .. "\n") 
end

function RegionRGB(R,G,B)
  local Region_R = R
  local Region_G = G
  local Region_B = B
  return Region_R, Region_G, Region_B
end

function RGBHexToDec(R, G, B)
  local red = string.format("%x", R)
  local green = string.format("%x", G)
  local blue = string.format("%x", B)
  if (#red < 2) then red = "0" .. red end
  if (#green < 2) then green = "0" .. green end
  if (#blue < 2) then blue = "0" .. blue end
  local color = "01" .. blue .. green .. red
  return tonumber(color, 16)
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
reaper.ClearConsole()

local all_regions = collect_regions()

isColor, get_color = reaper.GR_SelectColor()
if isColor then
  R, G, B = reaper.ColorFromNative(get_color)
end

new_color = RGBHexToDec(RegionRGB(R,G,B))

for i,region in ipairs(regions) do

  -- Msg("finding:" .. key_of(region.left, region.right))
  local matched = all_regions[key_of(region.left, region.right)]
  if matched then

    matched.color = new_color

    set_region(matched)
  end

end

reaper.Undo_EndBlock('Set Region Color of Selected Items', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()