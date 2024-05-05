-- @description Delete Regions Within Time Selection
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

function max(a,b)
  if a>b then
    return a
  end
  return b
end

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

function del_region(region)
  reaper.DeleteProjectMarker( 0, region.index, region.isrgn )
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
reaper.ClearConsole()

local time_sel_start, time_sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
if time_sel_start == time_sel_end then return end

local regions = {}

local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
for i = 0, num_markers + num_regions-1 do
  local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)

  if retval ~= nil then
    if isrgn then
      cur = { left = pos, right = rgnend }
      table.insert(regions, cur)
    end
  end
end

local all_regions = collect_regions()

for i, region in ipairs(regions) do

  -- Msg("finding:" .. key_of(region.left))
  local matched = all_regions[key_of(region.left, region.right)]

  if region.left >= time_sel_start then
    if region.isrgn and region.right <= time_sel_end or not region.isrgn and region.left <= time_sel_end then
      if matched then del_region(matched) end
    end
  end
  
end

reaper.Undo_EndBlock('Delete Regions Within Time Selection', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()