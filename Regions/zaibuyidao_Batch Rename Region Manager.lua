--[[
 * ReaScript Name: Batch Rename Region Manager
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-6-10)
  + Initial release
--]]

function Msg(str)
  reaper.ShowConsoleMsg(tostring(str) .. "\n")
end

function dight_num(num)
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

function add_zero_front_num(dest_dight, num)
  local num_dight = dight_num(num)
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

function get_precise_decimal(num, n)
  if	type(num) ~= "number" then
    return num
  end
  n = n or 0
  n = math.floor(n)
  if	n < 0 then n = 0 end
  local decimal = 10 ^ n
  local temp = math.floor(num * decimal)
  return temp / decimal
end

function key_of(name, left, right)
  return tostring(name .. " " .. tostring(get_precise_decimal(left,2)) .. " " .. tostring(get_precise_decimal(right,2)))
end

function collect_regions()
  local result = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions-1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)

    if retval ~= nil then
      if isrgn then

        result[key_of(name, pos, rgnend)] = {
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

function GetRegionManager()
  local title = reaper.JS_Localize("Region/Marker Manager", "common")
  local arr = reaper.new_array({}, 1024)
  reaper.JS_Window_ArrayFind(title, true, arr)
  local adr = arr.table()
  for j = 1, #adr do
    local hwnd = reaper.JS_Window_HandleFromAddress(adr[j])
    -- verify window by checking if it also has a specific child.
    if reaper.JS_Window_FindChildByID(hwnd, 1056) then -- 1045:ID of clear button
      return hwnd
    end 
  end
end

local show_msg = reaper.GetExtState("BatchRenameRegionManager", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
    script_name = "批量重命名區域管理器"
    text = "$name -- 區域名稱\n$number -- 區域編號\n"
    text = text.."\n下次還顯示此列表嗎？"
    local box_ok = reaper.ShowMessageBox("可用鍵 :\n\n"..text, script_name, 4)

    if box_ok == 7 then
        show_msg = "false"
        reaper.SetExtState("BatchRenameRegionManager", "ShowMsg", show_msg, true)
    end
end

local hWnd = GetRegionManager()
if hWnd == nil then return end  

local container = reaper.JS_Window_FindChildByID(hWnd, 1071)

sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(container)
if sel_count == 0 then return end 

rgname = {}
left_t = {}
right_t = {}

nt = {}
lt = {}
rt = {}
regions = {}
cur = {}
i = 0

for index in string.gmatch(sel_indexes, '[^,]+') do

  i = i + 1
  rgname[i] = reaper.JS_ListView_GetItemText(container, tonumber(index), 2)
  left_t[i] = reaper.JS_ListView_GetItemText(container, tonumber(index), 3)
  right_t[i] = reaper.JS_ListView_GetItemText(container, tonumber(index), 4)

  beat_L = reaper.TimeMap2_beatsToTime(0, string.match(left_t[i], "%d+.%d+$")-1, string.match(left_t[i], "^%d+")-1) -- 將節拍轉爲秒
  beat_R = reaper.TimeMap2_beatsToTime(0, string.match(right_t[i], "%d+.%d+$")-1, string.match(right_t[i], "^%d+")-1)

  nt[#nt+1] = rgname[i]
  lt[#lt+1] = beat_L
  rt[#rt+1] = beat_R

  cur = {
    regionname = nt[i],
    left = lt[i],
    right = rt[i]
  }

  table.insert(regions, cur)

end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local all_regions = collect_regions()
local pattern, cnt, tail, begin_str, end_str, position, insert, delete, find, replace = '', '1', '0', '0', '0', '0', '', '0', '', ''

-- for key,region in pairs(all_regions) do
--   Msg("all:" .. key)
-- end

local ok, retvals_csv = reaper.GetUserInputs("Batch Reanme Region Manager", 10, "Rename 重命名,Order 順序,Tail 尾部 (ms),From beginning 截取開頭,From end 截取結尾 (負數),At position 位置,To insert 插入,Remove 移除,Find what 查找,Replace with 替換,extrawidth=200", pattern ..','.. cnt ..','.. tail ..','.. begin_str .. ','.. end_str ..','.. position ..','.. insert ..','.. delete ..','.. find ..','.. replace)
if not ok then return end

pattern, cnt, tail, begin_str, end_str, position, insert, delete, find, replace = retvals_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")

cnt = cnt -1
begin_str = begin_str + 1
end_str = end_str - 1
tail = tail / 1000

name_t = {}

for i, region in ipairs(regions) do
  local matched = all_regions[key_of(region.regionname, region.left, region.right)]
  if matched then
    name_t[#name_t+1] = matched.name
  end
end

for i, region in ipairs(regions) do

  -- Msg("finding:" .. key_of(region.left, region.right))
  local matched = all_regions[key_of(region.regionname, region.left, region.right)]
  if matched then

    if pattern ~= "" then matched.name = pattern end

    matched.name = matched.name:gsub("$name", name_t[i])
    matched.name = matched.name:gsub("$number", function ()
      cnt = add_zero_front_num(2, math.floor(cnt+1))
      return tostring(cnt)
    end)

    matched.name = string.sub(matched.name, begin_str, end_str)
    matched.name = string.sub(matched.name, 1, position) .. insert .. string.sub(matched.name, position+1+delete)
    matched.name = string.gsub(matched.name, find, replace)

    set_region(matched)
    
  end

end

-- print(regions)
-- print(all_regions)
reaper.Undo_EndBlock('Batch Rename Region Manager', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()