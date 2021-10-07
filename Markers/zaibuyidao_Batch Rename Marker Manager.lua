--[[
 * ReaScript Name: Batch Rename Marker Manager
 * Version: 1.2
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0 or newer recommended
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-7-17)
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

function utf8len(str)
  local len = 0
  local currentIndex = 1
  while currentIndex <= #str do
    local char = string.byte(str,currentIndex)
    currentIndex = currentIndex + chsize(char)
    len = len + 1
  end
  return len
end

function utf8sub(str,startChar,endChars)
  local startIndex = 1
  startChar = startChar + 1
  while startChar > 1 do
    local char = string.byte(str,startIndex)
    startIndex = startIndex + chsize(char)
    startChar = startChar - 1
  end
  local currentIndex = startChar
  newChars = utf8len(str) - endChars
  while newChars > 0 and currentIndex <= #str do
    local char = string.byte(str,currentIndex)
    currentIndex = currentIndex + chsize(char)
    newChars = newChars - 1
  end
  return str:sub(startIndex,currentIndex - 1)
end

function utf8sub2(str,startChar,endChars)
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

function utf8sub_del(str,startChar)
  local startIndex = 1
  startChar = startChar + 1
  while startChar > 1 do
      local char = string.byte(str,startIndex)
      startIndex = startIndex + chsize(char)
      startChar = startChar - 1
  end
  return str:sub(startIndex)
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

local show_msg = reaper.GetExtState("BatchRenameMarkerManager", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
    script_name = "批量重命名標記管理器"
    text = "$markername -- 標記名稱\nv=001 -- Timeline order 時間順序\na=a -- Letter order 字母順序\n"
    text = text.."\nWill this list be displayed next time?\n下次還顯示此列表嗎？"
    local box_ok = reaper.ShowMessageBox("Wildcards 通配符 :\n\n"..text, script_name, 4)

    if box_ok == 7 then
        show_msg = "false"
        reaper.SetExtState("BatchRenameMarkerManager", "ShowMsg", show_msg, true)
    end
end

-- 使用標尺的時間單位 分:秒 計算標記的起點和終點位置
if reaper.GetToggleCommandStateEx(0, 40367) == 1 then -- View: Time unit for ruler: Measures.Beats
  meas_beat_flag = true
  reaper.Main_OnCommand(40365, 0) -- View: Time unit for ruler: Minutes:Seconds
end

if reaper.GetToggleCommandStateEx(0, 41916) == 1 then -- View: Time unit for ruler: Measures.Beats (minimal)
  meas_beat_mini_flag = true
  reaper.Main_OnCommand(40365, 0) -- View: Time unit for ruler: Minutes:Seconds
end

if reaper.GetToggleCommandStateEx(0, 40368) == 1 then -- View: Time unit for ruler: Seconds
  seconds_flag = true
  reaper.Main_OnCommand(40365, 0) -- View: Time unit for ruler: Minutes:Seconds
end

if reaper.GetToggleCommandStateEx(0, 40369) == 1 then -- View: Time unit for ruler: Samples
  samples_flag = true
  reaper.Main_OnCommand(40365, 0) -- View: Time unit for ruler: Minutes:Seconds
end

if reaper.GetToggleCommandStateEx(0, 40370) == 1 then -- View: Time unit for ruler: Hours:Minutes:Seconds:Frames
  hours_frames_flag = true
  reaper.Main_OnCommand(40365, 0) -- View: Time unit for ruler: Minutes:Seconds
end

if reaper.GetToggleCommandStateEx(0, 41973) == 1 then -- View: Time unit for ruler: Absolute frames
  frames_flag = true
  reaper.Main_OnCommand(40365, 0) -- View: Time unit for ruler: Minutes:Seconds
end

function key_of(name, left)
  return tostring(name .. " " .. tostring(get_precise_decimal(left,10)))
end

function collect_regions()
  local result = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions-1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)

    if retval ~= nil then
      if not isrgn then
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

  msl = string.match(rgnleft, "%d+$") -- 毫秒
  sl = string.match(string.match(rgnleft, "%d+.%d+$"), "^%d+") -- 秒
  ml = string.match(string.match(rgnleft, "%d+.%d+.%d+$"), "^%d+") -- 分
  hl = string.sub(rgnleft, 1, -11) -- 時
  if hl == "" then
    lnkl = math.modf(ml * 60 + sl) .. "." .. msl
  else
    lnkl = math.modf(hl * 3600 + ml * 60 + sl) .. "." .. msl
  end

  -- Msg('SEL L : ' .. lnkl)
  nt[#nt+1] = rgname
  lt[#lt+1] = lnkl

  cur = {
    regionname = nt[i],
    left = lt[i]
  }

  table.insert(regions, cur)

end

if seconds_flag then reaper.Main_OnCommand(40368, 0) end -- View: Time unit for ruler: Seconds
if meas_beat_flag then reaper.Main_OnCommand(40367, 0) end -- View: Time unit for ruler: Measures.Beats
if meas_beat_mini_flag then reaper.Main_OnCommand(41916, 0) end -- View: Time unit for ruler: Measures.Beats (minimal)
if samples_flag then reaper.Main_OnCommand(40369, 0) end -- View: Time unit for ruler: Samples
if hours_frames_flag then reaper.Main_OnCommand(40370, 0) end -- View: Time unit for ruler: Hours:Minutes:Seconds:Frames
if frames_flag then reaper.Main_OnCommand(41973, 0) end -- View: Time unit for ruler: Absolute frames

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local all_regions = collect_regions()
local pattern, begin_str, end_str, position, insert, delete, find, replace = '', '0', '0', '0', '', '0', '', ''

-- for key,region in pairs(all_regions) do
--   Msg("all:" .. key)
-- end

local ok, retvals_csv = reaper.GetUserInputs("Batch Reanme Marker Manager", 8, "Rename 重命名,From beginning 截取開頭,From end 截取結尾,At position 位置,To insert 插入,Remove 移除,Find what 查找,Replace with 替換,extrawidth=200", pattern ..','.. begin_str .. ','.. end_str ..','.. position ..','.. insert ..','.. delete ..','.. find ..','.. replace)
if not ok then return end

pattern, begin_str, end_str, position, insert, delete, find, replace = retvals_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")

name_t = {}

for i, region in ipairs(regions) do
  local matched = all_regions[key_of(region.regionname, region.left)]
  if matched then
    name_t[#name_t+1] = matched.name
  end
end

for i, region in ipairs(regions) do

  -- Msg("finding:" .. key_of(region.regionname, region.left, region.right))
  local matched = all_regions[key_of(region.regionname, region.left)]
  if matched then

    if pattern ~= "" then
      matched.name = pattern
      matched.name = matched.name:gsub("$markername", name_t[i])
      -- matched.name = matched.name:gsub("$inctimeorder", function ()
      --   cnt = add_zero_front_num(2, math.floor(cnt+1))
      --   return tostring(cnt)
      -- end)

      if string.match(matched.name, "v=[%d+]*") ~= nil then -- 長度3
        nbr = string.match(matched.name, "v=[%d+]*")
        nbr = string.sub(nbr, 3) -- 截取3
        if tonumber(nbr) then
          matched.name = matched.name:gsub("v="..nbr, function ()
            nbr = add_zero_front_num(string.len(nbr), math.floor(nbr+(i-1)))
            return tostring(nbr)
          end)
        end
      end

      if string.match(matched.name, "a=[A-Za-z]*") ~= nil then -- 長度3
        xyz = string.match(matched.name, "a=[A-Za-z]*")
        xyz_len = string.len(xyz)
        xyz_pos = string.sub(xyz, 3, 3) -- 截取3

        -- if xyz_len == 3 then
          if string.find(xyz_pos,"(%u)") == 1 then
            letter = string.upper(xyz_pos) -- 大寫
            alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
          else
            letter = string.lower(xyz_pos) -- 小寫
            alphabet = 'abcdefghijklmnopqrstuvwxyz'
          end
  
          local letter_byte = string.char(letter:byte())
          local letter_idx = alphabet:find(letter)
          letter_idx = (letter_idx % #alphabet) + (i-1)
          letter_idx = letter_idx % #alphabet
          if letter_idx == 0 then letter_idx = #alphabet end
          letter_byte = alphabet:sub(letter_idx, letter_idx)

          matched.name = matched.name:gsub("a=" .. xyz_pos, letter_byte)
        -- end
      end
    end

    matched.name = utf8sub(matched.name,begin_str,end_str)
    matched.name = utf8sub2(matched.name,0,position)..insert..utf8sub_del(matched.name,position+delete)
    matched.name = string.gsub(matched.name, find, replace)

    if insert ~= '' then
      matched.name = matched.name:gsub("$regionname", name_t[i])
      -- matched.name = matched.name:gsub("$inctimeorder", function ()
      --   cnt = add_zero_front_num(2, math.floor(cnt+1))
      --   return tostring(cnt)
      -- end)

      if string.match(matched.name, "v=[%d+]*") ~= nil then -- 長度3
        nbr = string.match(matched.name, "v=[%d+]*")
        nbr = string.sub(nbr, 3) -- 截取3
        if tonumber(nbr) then
          matched.name = matched.name:gsub("v="..nbr, function ()
            nbr = add_zero_front_num(string.len(nbr), math.floor(nbr+(i-1)))
            return tostring(nbr)
          end)
        end
      end

      if string.match(matched.name, "a=[A-Za-z]*") ~= nil then -- 長度3
        xyz = string.match(matched.name, "a=[A-Za-z]*")
        xyz_len = string.len(xyz)
        xyz_pos = string.sub(xyz, 3, 3) -- 截取3

        -- if xyz_len == 3 then
          if string.find(xyz_pos,"(%u)") == 1 then
            letter = string.upper(xyz_pos) -- 大寫
            alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
          else
            letter = string.lower(xyz_pos) -- 小寫
            alphabet = 'abcdefghijklmnopqrstuvwxyz'
          end
  
          local letter_byte = string.char(letter:byte())
          local letter_idx = alphabet:find(letter)
          letter_idx = (letter_idx % #alphabet) + (i-1)
          letter_idx = letter_idx % #alphabet
          if letter_idx == 0 then letter_idx = #alphabet end
          letter_byte = alphabet:sub(letter_idx, letter_idx)

          matched.name = matched.name:gsub("a=" .. xyz_pos, letter_byte)
        -- end
      end
    end

    set_region(matched)
  end

end

reaper.Undo_EndBlock('Batch Rename Marker Manager', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()