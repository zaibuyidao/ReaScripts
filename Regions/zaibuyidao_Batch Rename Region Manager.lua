--[[
 * ReaScript Name: Batch Rename Region Manager
 * Version: 1.4.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.4 (2021-7-3)
  + 插入支持通配符
 * v1.3 (2021-6-15)
  + 修復匹配問題
 * v1.2 (2021-6-11)
  + 解決標尺時間單位換算錯誤
 * v1.1 (2021-6-10)
  + 支持標尺時間單位
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

local hWnd = GetRegionManager()
if hWnd == nil then return end

local container = reaper.JS_Window_FindChildByID(hWnd, 1071)

sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(container)
if sel_count == 0 then return end 

local show_msg = reaper.GetExtState("BatchRenameRegionManager", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
    script_name = "批量重命名區域管理器"
    text = "$regionname -- 區域名稱\n$inctimeorder -- 區域順序\n"
    text = text.."\n下次還顯示此列表嗎？"
    local box_ok = reaper.ShowMessageBox("可用鍵 :\n\n"..text, script_name, 4)

    if box_ok == 7 then
        show_msg = "false"
        reaper.SetExtState("BatchRenameRegionManager", "ShowMsg", show_msg, true)
    end
end

if reaper.GetToggleCommandStateEx(0, 40365) == 1 then -- View: Time unit for ruler: Minutes:Seconds
  minutes_seconds_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

if reaper.GetToggleCommandStateEx(0, 40367) == 1 then -- View: Time unit for ruler: Measures.Beats
  meas_beat_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

if reaper.GetToggleCommandStateEx(0, 41916) == 1 then -- View: Time unit for ruler: Measures.Beats (minimal)
  meas_beat_mini_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

if reaper.GetToggleCommandStateEx(0, 40369) == 1 then -- View: Time unit for ruler: Samples
  samples_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

if reaper.GetToggleCommandStateEx(0, 40370) == 1 then -- View: Time unit for ruler: Hours:Minutes:Seconds:Frames
  hours_frames_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

if reaper.GetToggleCommandStateEx(0, 41973) == 1 then -- View: Time unit for ruler: Absolute frames
  frames_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

function key_of(name, left, right)
  return tostring(name .. " " .. tostring(get_precise_decimal(left,3)) .. " " .. tostring(get_precise_decimal(right,3)))
end

function collect_regions()
  local result = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions-1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)

    if retval ~= nil then
      if isrgn then
        pos_left = pos
        rgnend_right = rgnend
        pos = string.format("%.10f", pos) -- 保留13位數用於截取
        rgnend = string.format("%.10f", rgnend)
        pos = string.sub(pos, 1, -8) -- 保留小數點3位數
        rgnend = string.sub(rgnend, 1, -8)
        --Msg('ALL L : '.. pos ..' ALL R : '..rgnend)

        result[key_of(name, pos, rgnend)] = {
          index = markrgnindexnumber,
          isrgn = isrgn,
          left = pos_left,
          right = rgnend_right,
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

nt, lt, rt, regions, cur = {}, {}, {}, {}, {}

i = 0

for index in string.gmatch(sel_indexes, '[^,]+') do

  i = i + 1
  rgname = reaper.JS_ListView_GetItemText(container, tonumber(index), 2)
  rgnleft = reaper.JS_ListView_GetItemText(container, tonumber(index), 3)
  rgnright = reaper.JS_ListView_GetItemText(container, tonumber(index), 4)

  --Msg('SEL L : ' .. rgnleft ..' SEL R : '..rgnright)
  nt[#nt+1] = rgname
  lt[#lt+1] = rgnleft
  rt[#rt+1] = rgnright

  cur = {
    regionname = nt[i],
    left = lt[i],
    right = rt[i]
  }

  table.insert(regions, cur)

end

if minutes_seconds_flag then reaper.Main_OnCommand(40365, 0) end -- View: Time unit for ruler: Minutes:Seconds
if meas_beat_flag then reaper.Main_OnCommand(40367, 0) end -- View: Time unit for ruler: Measures.Beats
if meas_beat_mini_flag then reaper.Main_OnCommand(41916, 0) end -- View: Time unit for ruler: Measures.Beats (minimal)
if samples_flag then reaper.Main_OnCommand(40369, 0) end -- View: Time unit for ruler: Samples
if hours_frames_flag then reaper.Main_OnCommand(40370, 0) end -- View: Time unit for ruler: Hours:Minutes:Seconds:Frames
if frames_flag then reaper.Main_OnCommand(41973, 0) end -- View: Time unit for ruler: Absolute frames

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local all_regions = collect_regions()
local pattern, cnt, begin_str, end_str, position, insert, delete, find, replace = '', '1', '0', '0', '0', '', '0', '', ''

-- for key,region in pairs(all_regions) do
--   Msg("all:" .. key)
-- end

local ok, retvals_csv = reaper.GetUserInputs("Batch Reanme Region Manager", 9, "Rename 重命名,Order 順序,From beginning 截取開頭,From end 截取結尾 (負數),At position 位置,To insert 插入,Remove 移除,Find what 查找,Replace with 替換,extrawidth=200", pattern ..','.. cnt ..','.. begin_str .. ','.. end_str ..','.. position ..','.. insert ..','.. delete ..','.. find ..','.. replace)
if not ok then return end

pattern, cnt, begin_str, end_str, position, insert, delete, find, replace = retvals_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")

cnt = cnt -1
begin_str = begin_str + 1
end_str = end_str - 1

name_t = {}

for i, region in ipairs(regions) do
  local matched = all_regions[key_of(region.regionname, region.left, region.right)]
  if matched then
    name_t[#name_t+1] = matched.name
  end
end

for i, region in ipairs(regions) do

  -- Msg("finding:" .. key_of(region.regionname, region.left, region.right))
  local matched = all_regions[key_of(region.regionname, region.left, region.right)]
  if matched then

    if pattern ~= "" then
      matched.name = pattern
      matched.name = matched.name:gsub("$regionname", name_t[i])
      matched.name = matched.name:gsub("$inctimeorder", function ()
        cnt = add_zero_front_num(2, math.floor(cnt+1))
        return tostring(cnt)
      end)
    end

    matched.name = string.sub(matched.name, begin_str, end_str)
    matched.name = string.sub(matched.name, 1, position) .. insert .. string.sub(matched.name, position+1+delete)
    matched.name = string.gsub(matched.name, find, replace)

    if insert ~= '' then
      matched.name = matched.name:gsub("$regionname", name_t[i])
      matched.name = matched.name:gsub("$inctimeorder", function ()
        cnt = add_zero_front_num(2, math.floor(cnt+1))
        return tostring(cnt)
      end)
    end

    set_region(matched)
  end

end

reaper.Undo_EndBlock('Batch Rename Region Manager', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()