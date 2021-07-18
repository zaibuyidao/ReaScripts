--[[
 * ReaScript Name: Set Marker Color Within Time Selection
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0 or newer recommended
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-7-18)
  + Initial release
--]]

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

function print(param)
  if type(param) == "table" then
      table.print(param)
      return
  end
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end
function table.print(t)
  local print_r_cache = {}
  local function sub_print_r(t, indent)
      if (print_r_cache[tostring(t)]) then
          print(indent .. "*" .. tostring(t))
      else
          print_r_cache[tostring(t)] = true
          if (type(t) == "table") then
              for pos, val in pairs(t) do
                  if (type(val) == "table") then
                      print(indent .. "[" .. pos .. "] => " .. tostring(t) .. " {")
                      sub_print_r(val, indent .. string.rep(" ", string.len(pos) + 8))
                      print(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
                  elseif (type(val) == "string") then
                      print(indent .. "[" .. pos .. '] => "' .. val .. '"')
                  else
                      print(indent .. "[" .. pos .. "] => " .. tostring(val))
                  end
              end
          else
              print(indent .. tostring(t))
          end
      end
  end
  if (type(t) == "table") then
      print(tostring(t) .. " {")
      sub_print_r(t, "  ")
      print("}")
  else
      sub_print_r(t, "  ")
  end
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

function key_of(left)
  return tostring(get_precise_decimal(left,10))
end

function collect_regions()
  local result = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions-1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)

    if retval ~= nil then
      if not isrgn then
        result[key_of(pos)] = {
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

function set_marker(marker)
  reaper.SetProjectMarker3(0, marker.index, marker.isrgn, marker.left, marker.right, marker.name, marker.color)
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
    if not isrgn then
      cur = { left = pos }
      table.insert(regions, cur)
    end
  end
end

local all_regions = collect_regions()

isColor, get_color = reaper.GR_SelectColor()
if isColor then
  R, G, B = reaper.ColorFromNative(get_color)
end

new_color = RGBHexToDec(RegionRGB(R,G,B))

for i, region in ipairs(regions) do

  -- Msg("finding:" .. key_of(region.left))
  local matched = all_regions[key_of(region.left)]

  if region.left >= time_sel_start then
    if region.isrgn and region.right <= time_sel_end or not region.isrgn and region.left <= time_sel_end then
      if matched then
        matched.color = new_color
        set_marker(matched)
      end
    end
  end
  
end

reaper.Undo_EndBlock('Set Marker Color Within Time Selection', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()